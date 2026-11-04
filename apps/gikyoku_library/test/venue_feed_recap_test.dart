import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gikyoku_library/account/community_api.dart';
import 'package:gikyoku_library/app_scope.dart';
import 'package:gikyoku_library/catalog/log_stats.dart';
import 'package:gikyoku_library/catalog/models.dart';
import 'package:gikyoku_library/catalog/shortlist.dart';
import 'package:gikyoku_library/catalog/theater_log.dart';
import 'package:gikyoku_library/catalog/venue_stamps.dart';
import 'package:gikyoku_library/screens/feed_screen.dart';
import 'package:gikyoku_library/screens/recap_screen.dart';
import 'package:gikyoku_library/screens/venue_stamps_screen.dart';
import 'package:gikyoku_library/theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support.dart';

const _venues = [Venue(1, '甲劇場', '東京都'), Venue(2, '乙劇場', '東京都'), Venue(3, '丙劇場', '大阪府')];

TheaterLogEntry _e(String id, {int year = 2026, int month = 3, String? venue, String? group, int? rating, String note = ''}) => TheaterLogEntry(id: id, title: '舞台$id', watchedOn: DateTime(year, month, 1), venue: venue, group: group, rating: rating, note: note);

Widget _scope(TheaterLog log, Widget child, {List<Play> plays = const []}) => AppScope(
  catalog: Catalog(generatedAt: DateTime.utc(2026), categories: const [], plays: plays, venues: _venues),
  shortlist: Shortlist(),
  log: log,
  auth: offlineAuth(),
  sync: offlineSync(offlineAuth(), log),
  child: MaterialApp(theme: buildTheme(), home: Scaffold(body: child)),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('劇場スタンプ', () {
    test('カタログの劇場だけ数え、同じ劇場は 1 つ。自由入力は数えない', () {
      final s = venueStamps(_venues, [_e('a', venue: '甲劇場'), _e('b', venue: '甲劇場'), _e('c', venue: '丙劇場'), _e('d', venue: '自由入力の場所')]);
      expect(s['東京都']!.count, 1);
      expect(s['東京都']!.total, 2);
      expect(s['大阪府']!.count, 1);
    });

    test('47 都道府県が重ならずに地図にある', () {
      expect(prefectureTiles.length, 47);
      expect(prefectureTiles.values.toSet().length, 47);
    });

    testWidgets('地図の県を押すと、その県の劇場が出る', (tester) async {
      _phone(tester);
      final log = TheaterLog();
      await log.upsert(_e('a', venue: '甲劇場'));
      await tester.pumpWidget(_scope(log, const SingleChildScrollView(child: VenueStampSummary())));
      expect(find.text('劇場スタンプ 1 / 3'), findsOneWidget);
      expect(find.textContaining('関係のない'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pref-東京都')));
      await tester.pumpAndSettle();
      expect(find.text('東京都 1 / 2'), findsOneWidget);
      expect(find.text('甲劇場'), findsOneWidget);
      expect(find.text('乙劇場'), findsOneWidget);
    });
  });

  group('みんなのひとこと', () {
    final row = {'id': 'r1', 'authorId': 'u9', 'authorName': '他の人', 'note': '面白かった', 'rating': 4, 'groupName': null, 'venueName': null, 'watchedMonth': '2026-11', 'title': '赤鬼', 'postId': 7};
    CommunityApi api(List<Object> rows) => CommunityApi(offlineAuth(), client: MockClient((_) async => http.Response.bytes(utf8.encode(jsonEncode({'reviews': rows})), 200)));

    testWidgets('感想と作品名を出す', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(_scope(TheaterLog(), FeedScreen(api: api([row])), plays: const [Play(id: 7, title: '赤鬼', author: '野田秀樹')]));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        expect(find.text('面白かった'), findsOneWidget);
        expect(find.text('赤鬼'), findsOneWidget);
        expect(find.byKey(const Key('review-menu-r1')), findsOneWidget);
      });
    });

    testWidgets('空のときは正直に空と伝え、記録へ案内する', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(_scope(TheaterLog(), FeedScreen(api: api([]))));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        expect(find.byKey(const Key('feed-empty')), findsOneWidget);
      });
    });
  });

  group('ふりかえり', () {
    test('指定した年だけを、記録から計算する', () {
      final r = YearRecap.of([
        _e('a', month: 3, venue: '甲劇場', group: 'A', rating: 5),
        _e('b', month: 3, venue: '甲劇場', group: 'A', note: '感想'),
        _e('c', month: 5, venue: '丙劇場', group: 'B', rating: 5),
        _e('d', year: 2025, venue: '乙劇場', rating: 5),
      ], 2026, {'甲劇場': '東京都', '丙劇場': '大阪府', '乙劇場': '東京都'});
      expect(r.count, 3);
      expect(r.venueCount, 2);
      expect(r.prefectureCount, 2);
      expect(r.bestMonth, 3);
      expect(r.bestMonthCount, 2);
      expect(r.topVenue!.key, '甲劇場');
      expect(r.topGroup!.key, 'A');
      expect(r.favorites, ['舞台a', '舞台c']);
      expect(r.noteCount, 1);
    });

    testWidgets('カードに本数が出て、感想の本文は載らない', (tester) async {
      _phone(tester);
      final log = TheaterLog();
      final year = DateTime.now().year;
      await log.upsert(_e('a', year: year, venue: '甲劇場', note: '人に見せない感想', rating: 5));
      await tester.pumpWidget(_scope(log, const RecapScreen()));
      expect(find.byKey(const Key('recap-count')), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('人に見せない感想'), findsNothing);
      expect(find.byKey(const Key('recap-share')), findsOneWidget);
      await tester.tap(find.byTooltip('前の年'));
      await tester.pump();
      expect(find.byKey(const Key('recap-empty')), findsOneWidget);
      expect(find.byKey(const Key('recap-share')), findsNothing);
    });
  });
}
