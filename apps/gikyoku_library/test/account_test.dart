import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gikyoku_library/account/auth_service.dart';
import 'package:gikyoku_library/account/community_api.dart';
import 'package:gikyoku_library/account/log_sync.dart';
import 'package:gikyoku_library/app_scope.dart';
import 'package:gikyoku_library/catalog/models.dart';
import 'package:gikyoku_library/catalog/shortlist.dart';
import 'package:gikyoku_library/catalog/theater_log.dart';
import 'package:gikyoku_library/screens/account_screen.dart';
import 'package:gikyoku_library/theme.dart';
import 'package:gikyoku_library/widgets/community_widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support.dart';

http.Response _json(Object o, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(o)), code, headers: {'content-type': 'application/json'});

/// ログイン済みの AuthService を作る
Future<AuthService> signedIn(http.Client client, {MemoryTokenStore? store, DateTime Function()? now}) async {
  final auth = AuthService(client: client, store: store ?? MemoryTokenStore(), now: now, webAuth: (url, scheme) async => 'gikyokulibrary://auth-callback?code=abc');
  await auth.signIn('apple');
  return auth;
}

Future<http.Response> _authRoutes(http.Request req) async {
  if (req.url.path.endsWith('/token')) return _json({'access_token': 'at', 'refresh_token': 'rt2', 'expires_in': 3600});
  if (req.url.path.endsWith('/session')) return _json({'id': 'u1', 'displayName': null});
  return _json({}, 404);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('PKCE は RFC 7636 の例と一致する', () {
    expect(Pkce('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk').challenge, 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM');
    expect(Pkce.generate().verifier.length, greaterThanOrEqualTo(43));
  });

  group('ログイン', () {
    test('戻り先と PKCE を付けて開き、トークンを交換して利用者を結ぶ', () async {
      String? opened;
      Map<String, dynamic>? exchange;
      String? sessionAuth;
      final store = MemoryTokenStore();
      final auth = AuthService(
        store: store,
        webAuth: (url, scheme) async {
          opened = url;
          expect(scheme, 'gikyokulibrary');
          return 'gikyokulibrary://auth-callback?code=abc';
        },
        client: MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            expect(req.url.queryParameters['grant_type'], 'pkce');
            exchange = jsonDecode(req.body) as Map<String, dynamic>;
            return _json({'access_token': 'at', 'refresh_token': 'rt', 'expires_in': 3600});
          }
          sessionAuth = req.headers['authorization'];
          return _json({'id': 'u1', 'displayName': '舞台好き'});
        }),
      );
      await auth.signIn('google');
      final q = Uri.parse(opened!).queryParameters;
      expect(q['provider'], 'google');
      expect(q['redirect_to'], 'gikyokulibrary://auth-callback');
      expect(q['code_challenge_method'], 's256');
      expect(exchange!['auth_code'], 'abc');
      expect(Pkce(exchange!['code_verifier'] as String).challenge, q['code_challenge']);
      expect(sessionAuth, 'Bearer at');
      expect(auth.user!.displayName, '舞台好き');
      expect(store.values['refresh'], 'rt');

      final next = AuthService(store: store, client: MockClient((_) async => _json({}, 500)));
      await next.restore();
      expect(next.signedIn, isTrue);
    });

    test('やめたときはエラーにしない種類の例外を返す', () async {
      final auth = AuthService(store: MemoryTokenStore(), webAuth: (_, _) async => throw Exception('CANCELED'), client: MockClient((_) async => _json({})));
      await expectLater(auth.signIn('apple'), throwsA(isA<SignInCancelled>()));
      expect(auth.signedIn, isFalse);
    });

    test('期限が切れたら取り直し、取り直せなければログアウトする', () async {
      var now = DateTime(2026);
      var refreshOk = true;
      var refreshes = 0;
      final auth = await signedIn(
        MockClient((req) async {
          if (req.url.queryParameters['grant_type'] == 'refresh_token') {
            refreshes++;
            return refreshOk ? _json({'access_token': 'new', 'refresh_token': 'rt3', 'expires_in': 3600}) : _json({}, 400);
          }
          return _authRoutes(req);
        }),
        now: () => now,
      );
      expect(await auth.accessToken(), 'at');
      expect(refreshes, 0);
      now = now.add(const Duration(hours: 2));
      expect(await auth.accessToken(), 'new');
      expect(refreshes, 1);
      now = now.add(const Duration(hours: 2));
      refreshOk = false;
      expect(await auth.accessToken(), isNull);
      expect(auth.signedIn, isFalse);
    });
  });

  group('同期', () {
    TheaterLogEntry entry(String id, {String note = '', List<String> photos = const []}) => TheaterLogEntry(id: id, title: '舞台$id', watchedOn: DateTime(2026, 11, 3), note: note, seat: 'C-1', price: 3000, photos: photos, author: '作者');
    Map<String, dynamic> row(String id, {String note = '', bool deleted = false, String updatedAt = '2026-11-04T00:00:00.000Z', bool hidden = false}) => {
      'clientId': id, 'title': '舞台$id', 'watchedOn': '2026-11-03', 'postId': null, 'productionId': null, 'groupName': null, 'venueName': null, 'showTime': null, 'seat': 'C-1', 'price': 3000, 'rating': null, 'note': note, 'visibility': 'private', 'hidden': hidden, 'updatedAt': updatedAt, 'deleted': deleted,
    };

    test('端末の記録を送り、写真は送らず、日付は端末の日付のまま送る', () async {
      Map<String, dynamic>? sent;
      final client = MockClient((req) async {
        if (req.method == 'PUT') {
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          return _json(row('a', note: '感想'));
        }
        if (req.url.path.endsWith('/logs')) return _json({'logs': []});
        return _authRoutes(req);
      });
      final auth = await signedIn(client);
      final log = TheaterLog();
      await log.upsert(entry('a', note: '感想', photos: const ['p.jpg']));
      expect(await LogSync(auth: auth, log: log, client: client).run(), isTrue);
      expect(sent!['watchedOn'], '2026-11-03');
      expect(sent!.containsKey('photos'), isFalse);
      expect(log.dirtyEntries, isEmpty);
      expect(log.entries.single.photos, ['p.jpg']);
      expect(log.entries.single.author, '作者');
    });

    test('未ログインなら送らない', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return _json({});
      });
      final log = TheaterLog();
      await log.upsert(entry('a'));
      expect(await LogSync(auth: AuthService(store: MemoryTokenStore(), client: client), log: log, client: client).run(), isFalse);
      expect(calls, 0);
      expect(log.dirtyEntries.length, 1);
    });

    test('送れなければ残して、次の同期で送る', () async {
      var up = false;
      var puts = 0;
      final client = MockClient((req) async {
        if (req.method == 'PUT') {
          puts++;
          return up ? _json(row('a')) : _json({}, 503);
        }
        if (req.url.path.endsWith('/logs')) return _json({'logs': []});
        return _authRoutes(req);
      });
      final auth = await signedIn(client);
      final log = TheaterLog();
      await log.upsert(entry('a'));
      final sync = LogSync(auth: auth, log: log, client: client);
      expect(await sync.run(), isFalse);
      expect(log.dirtyEntries.length, 1);
      up = true;
      expect(await sync.run(), isTrue);
      expect(puts, 2);
      expect(log.dirtyEntries, isEmpty);
    });

    test('別の端末の記録を受け取り、削除も反映し、次は差分だけ頼む', () async {
      final sinces = <String?>[];
      var batch = [row('b', note: '別の端末')];
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/logs')) {
          sinces.add(req.url.queryParameters['since']);
          return _json({'logs': batch});
        }
        return _authRoutes(req);
      });
      final auth = await signedIn(client);
      final log = TheaterLog();
      final sync = LogSync(auth: auth, log: log, client: client);
      await sync.run();
      expect(log.entries.single.note, '別の端末');
      expect(log.dirtyEntries, isEmpty);
      batch = [row('b', deleted: true, updatedAt: '2026-11-05T00:00:00.000Z')];
      await sync.run();
      expect(log.entries, isEmpty);
      expect(sinces, [null, '2026-11-04T00:00:00.000Z']);
    });

    test('未送信の変更は受け取った内容で上書きしない', () async {
      final log = TheaterLog();
      await log.upsert(entry('a', note: '端末の変更'));
      await log.applyRemote([row('a', note: 'サーバーの古い内容')]);
      expect(log.entries.single.note, '端末の変更');
    });

    test('サーバーの記録の削除は、印を残して伝える。端末だけの記録はすぐ消す', () async {
      final deleted = <String>[];
      final client = MockClient((req) async {
        if (req.method == 'DELETE') {
          deleted.add(req.url.pathSegments.last);
          return http.Response('', 204);
        }
        if (req.method == 'PUT') return _json(row(req.url.pathSegments.last));
        if (req.url.path.endsWith('/logs')) return _json({'logs': []});
        return _authRoutes(req);
      });
      final auth = await signedIn(client);
      final log = TheaterLog();
      final sync = LogSync(auth: auth, log: log, client: client);
      await log.upsert(entry('local'));
      await log.remove('local');
      expect(log.dirtyEntries, isEmpty);
      await log.upsert(entry('a'));
      await sync.run();
      await log.upsert(entry('a', note: '編集'));
      await sync.run();
      await log.remove('a');
      expect(log.entries, isEmpty);
      expect(log.dirtyEntries.length, 1);
      await sync.run();
      expect(deleted, ['a']);
      expect(log.dirtyEntries, isEmpty);
    });

    test('送れない記録があれば、ログアウトで消さない', () async {
      final client = MockClient((req) async {
        if (req.method == 'PUT') return _json({}, 503);
        return _authRoutes(req);
      });
      final auth = await signedIn(client);
      final log = TheaterLog();
      await log.upsert(entry('a'));
      final sync = LogSync(auth: auth, log: log, client: client);
      expect(await sync.signOut(), isFalse);
      expect(log.entries.length, 1);
      expect(auth.signedIn, isTrue);
      expect(await sync.signOut(force: true), isTrue);
      expect(log.entries, isEmpty);
      expect(auth.signedIn, isFalse);
    });
  });

  group('みんなの感想', () {
    final review = {'id': 'r1', 'authorId': 'u9', 'authorName': '他の人', 'note': '面白かった', 'rating': 4, 'groupName': null, 'venueName': null, 'watchedMonth': '2026-11'};

    Widget scope(Widget child, AuthService auth) {
      final log = TheaterLog();
      return AppScope(
        catalog: Catalog(generatedAt: DateTime.utc(2026), categories: const [], plays: const []),
        shortlist: Shortlist(),
        log: log,
        auth: auth,
        sync: offlineSync(auth, log),
        child: MaterialApp(theme: buildTheme(), home: Scaffold(body: SingleChildScrollView(child: child))),
      );
    }

    testWidgets('感想を表示し、ブロックすると消える。通報も送れる', (tester) async {
      final calls = <String>[];
      await tester.runAsync(() async {
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/reviews')) return _json({'reviews': [review]});
          if (req.url.path.contains('/blocks/') || req.url.path.endsWith('/reports')) {
            calls.add('${req.method} ${req.url.pathSegments.last}');
            return http.Response('', 204);
          }
          return _authRoutes(req);
        });
        final auth = await signedIn(client);
        final api = CommunityApi(auth, client: client);
        await tester.pumpWidget(scope(ReviewsSection(postId: 1, api: api), auth));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        expect(find.text('面白かった'), findsOneWidget);

        await tester.tap(find.byKey(const Key('review-menu-r1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('通報する'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('スパムや宣伝'));
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        await tester.tap(find.byKey(const Key('review-menu-r1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('この人をブロック'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ブロック'));
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        expect(find.text('面白かった'), findsNothing);
      });
      expect(calls, ['POST reports', 'PUT u9']);
    });

    testWidgets('自分の感想には通報とブロックを出さない', (tester) async {
      await tester.runAsync(() async {
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/reviews')) return _json({'reviews': [{...review, 'authorId': 'u1'}]});
          return _authRoutes(req);
        });
        final auth = await signedIn(client);
        await tester.pumpWidget(scope(ReviewsSection(postId: 1, api: CommunityApi(auth, client: client)), auth));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        expect(find.text('面白かった'), findsOneWidget);
        expect(find.byKey(const Key('review-menu-r1')), findsNothing);
      });
    });

    testWidgets('未ログインの画面に Apple と Google が出る', (tester) async {
      await tester.pumpWidget(scope(const SizedBox(height: 700, child: AccountScreen()), offlineAuth()));
      expect(find.byKey(const Key('sign-in-apple')), findsOneWidget);
      expect(find.byKey(const Key('sign-in-google')), findsOneWidget);
    });
  });
}
