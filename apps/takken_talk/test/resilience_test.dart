import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takken_talk/api/client.dart';
import 'package:takken_talk/screens/kakomon/explain_sheet.dart';
import 'package:takken_talk/screens/kakomon_screen.dart';
import 'package:takken_talk/screens/pro/mock_draft.dart';
import 'package:takken_talk/screens/pro/mock_screen.dart';
import 'package:takken_talk/screens/review_screen.dart';
import 'package:takken_talk/state/app_state.dart';
import 'package:takken_talk/widgets/refresh_on_resume.dart';

http.Response _ok(Object body) => http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json'});

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'ps_token': 't', 'ps_user_id': 'u_1'}));

  group('返答の途中で通信が止まる', () {
    test('何も届かなくなったら打ち切る（待ち続けない）', () async {
      final never = StreamController<List<int>>();
      addTearDown(never.close);
      final api = ApiClient(
        baseUrl: 'http://test',
        sseIdleTimeout: const Duration(milliseconds: 50),
        client: MockClient.streaming((req, _) async {
          never.add(utf8.encode('data: {"type":"text","delta":"途中"}\n\n'));
          return http.StreamedResponse(never.stream, 200);
        }),
      );
      await api.ensureUser();
      final got = <Map<String, dynamic>>[];
      await expectLater(() async {
        await for (final e in api.chat({'chapterId': 'ch01'})) {
          got.add(e);
        }
      }, throwsA(isA<TimeoutException>()));
      expect(got.single['delta'], '途中');
    });
  });

  group('AIに聞くのキャッシュ', () {
    test('学習データの削除のあとは、前の会話と回数を持ち越さない', () {
      final before = ExplainThread.of('q1')..msgs.add(ExplainMsg('user', '消えるはず'));
      ExplainThread.left = 3;
      ExplainThread.reset();
      expect(identical(ExplainThread.of('q1'), before), isFalse);
      expect(ExplainThread.of('q1').msgs, isEmpty);
      expect(ExplainThread.left, isNull);
    });
  });

  group('jstDay', () {
    test('日本時間で日付が変わる', () {
      expect(jstDay(DateTime.utc(2026, 11, 3, 14, 59)), '2026-11-03');
      expect(jstDay(DateTime.utc(2026, 11, 3, 15, 0)), '2026-11-04');
    });
  });

  group('MockDraft', () {
    final exam = {
      'id': 'm1',
      'seconds': 600,
      'questions': [
        {'id': 'q1'},
      ],
    };

    test('保存して読み直せる。別の学習者のものは読まない', () async {
      await MockDraft(userId: 'u_1', exam: exam, startedAtMs: 1000, answers: const {'q1': true, 'q2': null}).save();
      final d = await MockDraft.load('u_1');
      expect(d!.exam['id'], 'm1');
      expect(d.answers, {'q1': true, 'q2': null});
      expect(d.answeredCount, 1);
      expect(await MockDraft.load('u_2'), isNull);
      await MockDraft.clear();
      expect(await MockDraft.load('u_1'), isNull);
    });

    test('残り時間はアプリを閉じていたあいだも進む', () {
      final start = DateTime(2026, 11, 3, 10);
      final d = MockDraft(userId: 'u_1', exam: exam, startedAtMs: start.millisecondsSinceEpoch, answers: const {});
      expect(d.leftSeconds(start.add(const Duration(minutes: 4))), 360);
      expect(d.leftSeconds(start.add(const Duration(hours: 5))), 0);
    });

    test('壊れた記録は無かったことにする', () async {
      SharedPreferences.setMockInitialValues({'mock_draft': '{壊れている'});
      expect(await MockDraft.load('u_1'), isNull);
    });
  });

  group('画面', () {
    late List<String> calls;

    AppState stateWith(Map<String, Object> Function(http.Request) respond) {
      calls = [];
      return AppState(
        ApiClient(
          baseUrl: 'http://test',
          client: MockClient((req) async {
            calls.add('${req.method} ${req.url.path}');
            return _ok(respond(req));
          }),
        ),
      )..me = const {'pro': true};
    }

    Map<String, Object> reviewBody(http.Request req) => {
      'wrong': [
        {
          'question': {'id': 'q1', 'statement': 'まちがえた問題', 'chapterId': 'ch01', 'topic': 't'},
          'chapter': {'id': 'ch01', 'order': 1, 'short': '章'},
        },
      ],
      'bookmarks': <Object>[],
      'due': <Object>[],
      'bookmarked': <Object>[],
      'correct': false,
      'explanation': '解説',
      'figures': <Object>[],
    };

    Future<void> pumpTabs(WidgetTester tester, AppState state, Widget child, {required bool visible}) async {
      await state.api.ensureUser();
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            home: Visibility(visible: visible, maintainState: true, child: child),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('復習: タブを開き直すと、答えた問題をまた解ける', (tester) async {
      await tester.runAsync(() async {
        final state = stateWith(reviewBody);
        const review = ReviewScreen();
        await pumpTabs(tester, state, review, visible: true);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        await tester.tap(find.textContaining('まちがえた').first);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.textContaining('まちがえた問題'), findsOneWidget);
        await tester.tap(find.text('○ 正しい'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        expect(find.text('○ 正しい'), findsNothing, reason: '答えた直後は結果を見せる');

        await pumpTabs(tester, state, review, visible: false);
        await pumpTabs(tester, state, review, visible: true);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        expect(find.text('○ 正しい'), findsOneWidget, reason: '開き直したらまた解ける');
      });
    });

    testWidgets('過去問: タブを開き直すと数え直す', (tester) async {
      await tester.runAsync(() async {
        final state = stateWith((_) => {'pastExams': <Object>[], 'subjects': <Object>[], 'chapters': <Object>[]});
        const screen = KakomonScreen();
        await pumpTabs(tester, state, screen, visible: true);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        final first = calls.where((c) => c.endsWith('/kakomon')).length;
        await pumpTabs(tester, state, screen, visible: false);
        await pumpTabs(tester, state, screen, visible: true);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        expect(calls.where((c) => c.endsWith('/kakomon')).length, first + 1);
      });
    });

    testWidgets('アプリに戻ったとき: 長く離れていたら取り直す。短ければ取り直さない', (tester) async {
      await tester.runAsync(() async {
        var now = DateTime(2026, 11, 3);
        final state = stateWith((_) => const {'x': 1});
        await state.api.ensureUser();
        await tester.pumpWidget(
          AppScope(
            state: state,
            child: MaterialApp(home: RefreshOnResume(now: () => now, child: const SizedBox())),
          ),
        );
        Future<void> away(Duration d) async {
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          now = now.add(d);
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }

        await away(const Duration(seconds: 10));
        expect(calls, isEmpty);
        await away(const Duration(minutes: 5));
        expect(calls, contains('GET /api/v1/me'));
      });
    });

    testWidgets('模擬試験: アプリが終了しても、答えを残して続けられる', (tester) async {
      await tester.runAsync(() async {
        final exam = {
          'id': 'm1',
          'seconds': 1800,
          'questions': [
            {'id': 'q1', 'statement': '一問目', 'subject': '業法', 'topic': 't'},
            {'id': 'q2', 'statement': '二問目', 'subject': '業法', 'topic': 't'},
          ],
        };
        final state = stateWith((_) => {'history': <Object>[]});
        await state.api.ensureUser();
        await tester.pumpWidget(
          AppScope(
            state: state,
            child: MaterialApp(home: MockExamScreen(exam: exam)),
          ),
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('mock_true')));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // アプリの終了の代わりに画面を捨て、入口を開き直す
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          AppScope(
            state: state,
            child: const MaterialApp(home: MockIntroScreen()),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        expect(find.text('途中の模擬試験があります'), findsOneWidget);
        expect(find.textContaining('1問答えています'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('mock_resume')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('二問目'), findsOneWidget, reason: 'まだ答えていない問題から');
        expect(find.text('見直し 1/2'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    });
  });
}
