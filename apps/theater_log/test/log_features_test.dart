import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theater_log/app_scope.dart';
import 'package:theater_log/catalog/log_stats.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import 'package:theater_log/catalog/theater_log.dart';
import 'package:theater_log/screens/log_screen.dart';
import 'package:theater_log/screens/share_card_screen.dart';
import 'package:theater_log/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support.dart';

TheaterLogEntry _e(String id, DateTime d, {String title = '作品', String? venue, String? group, int? price, int? rating, String note = '', String? seat}) =>
    TheaterLogEntry(id: id, title: title, watchedOn: d, venue: venue, group: group, price: price, rating: rating, note: note, seat: seat);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('集計は指定した年だけを数える', () {
    final s = LogStats.of([
      _e('a', DateTime(2026, 3, 1), venue: '甲', price: 3000, rating: 4),
      _e('b', DateTime(2026, 3, 9), venue: '甲', price: 2000, rating: 2),
      _e('c', DateTime(2026, 5, 1), venue: '乙'),
      _e('d', DateTime(2025, 5, 1), venue: '丙', price: 9999),
    ], 2026);
    expect(s.count, 3);
    expect(s.spend, 5000);
    expect(s.perMonth[2], 2);
    expect(s.perMonth[4], 1);
    expect(s.topVenues.first.key, '甲');
    expect(s.averageRating, 3);
  });

  test('座席や写真も保存して読み直せる。古い記録も読める', () async {
    final e = TheaterLogEntry(id: 'a', title: '作', watchedOn: DateTime(2026), showTime: 'soiree', seat: 'C-12', price: 3500, photos: const ['1.jpg']);
    final back = TheaterLogEntry.fromJson(e.toJson());
    expect([back.showTime, back.seat, back.price, back.photos], ['soiree', 'C-12', 3500, ['1.jpg']]);
    final old = TheaterLogEntry.fromJson({'id': 'o', 'title': '古', 'watchedOn': '2026-01-01T00:00:00.000'});
    expect(old.photos, isEmpty);
    expect(old.note, '');
  });

  test('自分の入力の候補はよく使う順', () async {
    final log = TheaterLog();
    await log.upsert(_e('a', DateTime(2026), venue: '甲'));
    await log.upsert(_e('b', DateTime(2026), venue: '乙'));
    await log.upsert(_e('c', DateTime(2026), venue: '乙'));
    expect(log.recent((e) => e.venue), ['乙', '甲']);
  });

  test('作品・劇場・感想から探せる', () {
    final e = _e('a', DateTime(2026), title: '赤鬼', venue: 'アゴラ', note: '泣いた');
    expect(logMatches(e, 'あ'), isFalse);
    expect(logMatches(e, 'アゴ'), isTrue);
    expect(logMatches(e, '泣'), isTrue);
    expect(logMatches(e, ' '), isTrue);
  });

  Widget wrap(TheaterLog log, Widget child, {List<Venue> venues = const []}) => AppScope(
    catalog: Catalog(generatedAt: DateTime.utc(2026), categories: const [], plays: const [], venues: venues),
    log: log,
    auth: offlineAuth(),
    sync: offlineSync(offlineAuth(), log),
    child: MaterialApp(theme: buildTheme(), home: child),
  );

  testWidgets('カレンダーで観た日を押すと、その日の記録が出る', (tester) async {
    final log = TheaterLog();
    final now = DateTime.now();
    await log.upsert(_e('a', DateTime(now.year, now.month, 15), title: '十五日の舞台'));
    await tester.pumpWidget(wrap(log, const LogScreen()));
    await tester.tap(find.byKey(const Key('log-view-toggle')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('log-calendar-toggle')));
    await tester.pump();
    expect(find.text('十五日の舞台'), findsNothing);
    await tester.tap(find.byKey(const Key('day-15')));
    await tester.pumpAndSettle();
    expect(find.text('十五日の舞台'), findsOneWidget);
  });

  testWidgets('シェアカードは、選ぶまで感想を載せない', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final e = _e('a', DateTime(2026, 11, 4), title: '見せる題名', note: '人に見せない感想', rating: 5);
    await tester.pumpWidget(wrap(TheaterLog(), ShareCardScreen(entry: e)));
    await tester.pump();
    expect(find.text('見せる題名'), findsOneWidget);
    expect(find.text('人に見せない感想'), findsNothing);
    await tester.tap(find.byKey(const Key('card-note')));
    await tester.pump();
    expect(find.text('人に見せない感想'), findsOneWidget);
  });

  testWidgets('シェアカードは形を選べて、劇場の一覧にある劇場ならスタンプも押す', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final e = _e('a', DateTime(2026, 11, 4), title: '見せる題名', venue: '本多劇場', seat: 'C列12番', rating: 4);
    await tester.pumpWidget(wrap(TheaterLog(), ShareCardScreen(entry: e), venues: const [Venue(1, '本多劇場', '東京都')]));
    await tester.pump();
    expect(find.byKey(const Key('card-venue-seal')), findsOneWidget);
    expect(find.text('観劇済'), findsOneWidget);
    expect(find.byKey(const Key('card-seat-text')), findsNothing);
    final story = tester.getSize(find.byType(LogShareCard));
    expect(story.height / story.width, closeTo(16 / 9, 0.01));
    await tester.tap(find.byKey(const Key('card-format-square')));
    await tester.pump();
    final square = tester.getSize(find.byType(LogShareCard));
    expect(square.height, closeTo(square.width, 0.5));
    await tester.tap(find.byKey(const Key('card-seat')));
    await tester.pump();
    expect(find.byKey(const Key('card-seat-text')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('劇場の一覧にない劇場なら、劇場のスタンプは押さない', (tester) async {
    final e = _e('a', DateTime(2026, 11, 4), title: '題名', venue: '一覧にない劇場');
    await tester.pumpWidget(wrap(TheaterLog(), ShareCardScreen(entry: e)));
    await tester.pump();
    expect(find.byKey(const Key('card-venue-seal')), findsNothing);
  });
}
