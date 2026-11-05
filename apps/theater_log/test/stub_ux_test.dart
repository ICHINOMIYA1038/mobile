import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theater_log/app_scope.dart';
import 'package:theater_log/catalog/achievements.dart';
import 'package:theater_log/catalog/productions.dart';
import 'package:theater_log/catalog/ticket_scan.dart';
import 'package:theater_log/screens/quick_log_sheet.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import 'package:theater_log/catalog/theater_log.dart';
import 'package:theater_log/screens/log_screen.dart';
import 'package:theater_log/screens/stamp_book_screen.dart';
import 'package:theater_log/theme.dart';
import 'package:theater_log/widgets/pon_stamp.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support.dart';

TheaterLogEntry _e(String id, {int month = 1, String? venue, String note = '', int? playId}) => TheaterLogEntry(id: id, title: '舞台$id', watchedOn: DateTime(2026, month, 1), venue: venue, note: note, playId: playId);

Widget _scope(TheaterLog log, Widget child, {List<Venue> venues = const []}) => AppScope(
  catalog: Catalog(generatedAt: DateTime.utc(2026), categories: const [], plays: const [Play(id: 7, title: '赤鬼', author: '野田秀樹')], venues: venues),
  log: log,
  auth: offlineAuth(),
  sync: offlineSync(offlineAuth(), log),
  child: MaterialApp(theme: buildTheme(), home: Scaffold(body: child)),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('スタンプ', () {
    test('本数、劇場、当たり月、台本、感想で取れる', () {
      bool has(List<TheaterLogEntry> l, String id) => achievementsOf(l).firstWhere((a) => a.id == id).earned;
      expect(has([], 'first'), isFalse);
      expect(has([_e('a')], 'first'), isTrue);
      expect(has([for (var i = 0; i < 4; i++) _e('$i')], 'five'), isFalse);
      expect(has([for (var i = 0; i < 5; i++) _e('$i')], 'five'), isTrue);
      expect(has([_e('a', venue: '甲'), _e('b', venue: '甲'), _e('c', venue: '乙')], 'venue3'), isFalse);
      expect(has([_e('a', venue: '甲'), _e('b', venue: '乙'), _e('c', venue: '丙')], 'venue3'), isTrue);
      expect(has([_e('a', month: 1), _e('b', month: 2), _e('c', month: 3)], 'month3'), isFalse);
      expect(has([_e('a'), _e('b'), _e('c')], 'month3'), isTrue);
      expect(has([_e('a', playId: 1), _e('b', playId: 2), _e('c', playId: 3)], 'script3'), isTrue);
    });

    test('新しく取れたものだけ返す', () {
      expect(newlyEarned([], [_e('a')]).map((a) => a.id), ['first']);
      expect(newlyEarned([_e('a')], [_e('a'), _e('b')]), isEmpty);
    });

    test('記録を消すと、スタンプも戻る', () {
      expect(achievementsOf([]).where((a) => a.earned), isEmpty);
    });
  });

  testWidgets('最初は 1 つのボタンだけ。作品名と星で記録すると、スタンプの画面が出る', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final log = TheaterLog();
    await tester.pumpWidget(_scope(log, const LogScreen()));
    expect(find.byKey(const Key('log-add')), findsNothing);
    await tester.tap(find.byKey(const Key('first-stub')));
    await tester.pumpAndSettle();

    // 作品名が空なら保存できない
    expect(tester.widget<FilledButton>(find.byKey(const Key('quick-save'))).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('quick-title')), '赤');
    await tester.pump();
    await tester.tap(find.text('野田秀樹'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('quick-star-4')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('quick-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    final e = log.entries.single;
    expect(e.title, '赤鬼');
    expect(e.playId, 7);
    expect(e.rating, 4);
    expect(e.group, isNull);
    expect(find.byKey(const Key('stamped-count')), findsOneWidget);
    expect(find.byKey(const Key('earned-first')), findsOneWidget);

    await tester.tap(find.byKey(const Key('stamped-close')));
    await tester.pumpAndSettle();
    expect(find.text('赤鬼'), findsOneWidget);
    expect(find.text('この作品の台本（野田秀樹）'), findsOneWidget);
    expect(find.byKey(const Key('log-add')), findsOneWidget);
  });

  testWidgets('スタンプ帳は取れた数を出す', (tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final log = TheaterLog();
    await log.upsert(_e('a'));
    await tester.pumpWidget(_scope(log, const StampBookScreen()));
    expect(find.textContaining('のうち 1 個'), findsOneWidget);
    expect(find.text('初日'), findsOneWidget);
  });

  group('ポンと押す', () {
    Widget stamp({required VoidCallback onImpact, bool reduced = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: MaterialApp(
        home: Center(
          child: PonStamp(
            delay: const Duration(milliseconds: 100),
            onImpact: onImpact,
            child: const PonSeal(size: 100, label: '観劇済'),
          ),
        ),
      ),
    );

    testWidgets('押した瞬間に 1 回だけ合図し、「ポン！」は消える', (tester) async {
      var impacts = 0;
      await tester.pumpWidget(stamp(onImpact: () => impacts++));
      await tester.pump(const Duration(milliseconds: 100));
      expect(impacts, 0);
      expect(find.byKey(const Key('pon-word')), findsNothing);
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pump(const Duration(milliseconds: 16));
      expect(impacts, 1);
      expect(find.byKey(const Key('pon-word')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(impacts, 1);
      expect(find.byKey(const Key('pon-word')), findsNothing);
      expect(find.text('観劇済'), findsOneWidget);
    });

    testWidgets('動きを減らす設定では、動かさずに押された状態を見せる', (tester) async {
      var impacts = 0;
      await tester.pumpWidget(stamp(onImpact: () => impacts++, reduced: true));
      await tester.pump();
      expect(impacts, 1);
      expect(find.byKey(const Key('pon-word')), findsNothing);
      expect(find.text('観劇済'), findsOneWidget);
    });

    testWidgets('半券帳の半券に印が残る', (tester) async {
      final log = TheaterLog();
      await log.upsert(_e('a'));
      await tester.pumpWidget(_scope(log, const LogScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('stub-seal-a')), findsOneWidget);
    });
  });

  group('公演の候補', () {
    final day = DateTime(2026, 11, 6);
    const akaoniA = CurrentProduction(id: 1, title: '赤鬼', venueName: '本多劇場', groupName: '劇団甲', prefecture: '東京都', startDate: '2026-11-01', endDate: '2026-11-10');
    const akaoniB = CurrentProduction(id: 2, title: '赤鬼', venueName: 'ABCホール', groupName: '劇団乙', prefecture: '大阪府', startDate: '2026-12-01', endDate: '2026-12-05');
    const edaniku = CurrentProduction(id: 3, title: 'エダニク', venueName: 'ザ・スズナリ', startDate: '2026-10-01', endDate: '2026-10-05', postId: 7);

    test('同じ題名でも劇場ごとに別の候補になり、上演中が先に出る', () {
      final hits = suggestProductions([akaoniB, akaoniA, edaniku], '赤鬼', day);
      expect(hits.map((h) => h.production.id), [1, 2]);
      expect(hits.every((h) => h.sharedTitle), isTrue);
      expect(hits.first.running, isTrue);
      expect(hits.last.running, isFalse);
    });

    test('ひらがなでも、全角でも、劇団名でも、劇場名でも探せる', () {
      expect(suggestProductions([edaniku], 'えだにく', day).single.production.id, 3);
      expect(suggestProductions([akaoniB], 'ａｂｃ', day).single.production.id, 2);
      expect(suggestProductions([akaoniA], '劇団甲', day).single.production.id, 1);
      expect(suggestProductions([edaniku], 'スズナリ', day).single.sharedTitle, isFalse);
      expect(suggestProductions([akaoniA], '  ', day), isEmpty);
      expect(suggestProductions([akaoniA], '別の題名', day), isEmpty);
    });

    test('期間の判定と表示', () {
      expect(akaoniA.includes(day), isTrue);
      expect(edaniku.includes(day), isFalse);
      expect(akaoniA.dateLabel, '11/1〜11/10');
      expect(const CurrentProduction(id: 9, title: 't', venueName: 'v', startDate: '2026-11-03').dateLabel, '11/3');
      expect(const CurrentProduction(id: 9, title: 't', venueName: 'v').includes(day), isNull);
    });

    Future<void> openSheet(WidgetTester tester, TheaterLog log) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_scope(log, const LogScreen()));
      await tester.tap(find.byKey(const Key('first-stub')));
      await tester.pumpAndSettle();
    }

    testWidgets('題名を入れると公演名と劇場名が出て、選ぶと劇場と劇団が記録に入る', (tester) async {
      final now = DateTime.now();
      String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      ProductionStore.instance.rows = [
        CurrentProduction(id: 11, title: '赤鬼', venueName: '本多劇場', groupName: '劇団甲', prefecture: '東京都', startDate: ymd(now.subtract(const Duration(days: 1))), endDate: ymd(now.add(const Duration(days: 1))), postId: 7),
        CurrentProduction(id: 12, title: '赤鬼', venueName: 'ABCホール', groupName: '劇団乙', prefecture: '大阪府', startDate: ymd(now.add(const Duration(days: 20))), endDate: ymd(now.add(const Duration(days: 22)))),
      ];
      addTearDown(() => ProductionStore.instance.rows = const []);
      final log = TheaterLog();
      await openSheet(tester, log);

      await tester.enterText(find.byKey(const Key('quick-title')), '赤鬼');
      await tester.pump();
      expect(find.byKey(const Key('production-hit-11')), findsOneWidget);
      expect(find.byKey(const Key('production-hit-12')), findsOneWidget);
      expect(find.text('本多劇場（東京都）'), findsOneWidget);
      expect(find.text('ABCホール（大阪府）'), findsOneWidget);
      expect(find.text('上演中'), findsOneWidget);
      expect(find.byKey(const Key('production-shared-note')), findsOneWidget);

      await tester.tap(find.byKey(const Key('production-hit-11')));
      await tester.pump();
      expect(find.byKey(const Key('production-selected')), findsOneWidget);
      expect(find.byKey(const Key('production-hit-12')), findsNothing);

      await tester.tap(find.byKey(const Key('quick-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 2));
      final e = log.entries.single;
      expect(e.title, '赤鬼');
      expect(e.venue, '本多劇場');
      expect(e.group, '劇団甲');
      expect(e.productionId, 11);
      expect(e.playId, 7);
    });

    testWidgets('題名を変えると選んだ公演は外れ、候補になくてもそのまま記録できる', (tester) async {
      ProductionStore.instance.rows = const [CurrentProduction(id: 21, title: '赤鬼', venueName: '本多劇場')];
      addTearDown(() => ProductionStore.instance.rows = const []);
      final log = TheaterLog();
      await openSheet(tester, log);
      await tester.enterText(find.byKey(const Key('quick-title')), '赤鬼');
      await tester.pump();
      await tester.tap(find.byKey(const Key('production-hit-21')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('quick-title')), '自分だけの舞台');
      await tester.pump();
      expect(find.byKey(const Key('production-selected')), findsNothing);
      expect(find.byKey(const Key('production-register')), findsOneWidget);
      await tester.tap(find.byKey(const Key('quick-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 2));
      final e = log.entries.single;
      expect(e.title, '自分だけの舞台');
      expect(e.venue, isNull);
      expect(e.productionId, isNull);
    });

    for (final (name, size, keyboard) in const [('iPhone 16', Size(393, 852), 336.0), ('iPhone SE', Size(375, 667), 216.0)]) {
      testWidgets('$name でキーボードが開いても、候補が画面に収まる', (tester) async {
        ProductionStore.instance.rows = [for (var i = 0; i < 8; i++) CurrentProduction(id: 40 + i, title: '赤鬼 第$i部', venueName: '劇場$i', groupName: '劇団', startDate: '2026-11-01', endDate: '2026-11-02')];
        addTearDown(() => ProductionStore.instance.rows = const []);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_scope(TheaterLog(), const LogScreen()));
        await tester.tap(find.byKey(const Key('first-stub')));
        await tester.pumpAndSettle();
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('quick-title')), '赤鬼');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('production-hit-40')), findsOneWidget);
        expect(find.byKey(const Key('quick-star-1')), findsNothing);
        expect(find.byKey(const Key('quick-save')), findsOneWidget);
        await tester.tap(find.byKey(const Key('production-hit-40')));
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('quick-star-1')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('期間外の日を選ぶと、確かめる案内が出る', (tester) async {
      ProductionStore.instance.rows = const [CurrentProduction(id: 31, title: '赤鬼', venueName: '本多劇場', startDate: '2020-01-01', endDate: '2020-01-02')];
      addTearDown(() => ProductionStore.instance.rows = const []);
      await openSheet(tester, TheaterLog());
      await tester.enterText(find.byKey(const Key('quick-title')), '赤鬼');
      await tester.pump();
      await tester.tap(find.byKey(const Key('production-hit-31')));
      await tester.pump();
      expect(find.byKey(const Key('production-date-note')), findsOneWidget);
    });
  });

  group('チケットの読み取り', () {
    Future<QuickLogSheetState> open(WidgetTester tester, TheaterLog log, List<String> lines) async {
      TicketScanner.override = (_) async => lines;
      addTearDown(() => TicketScanner.override = null);
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_scope(log, const LogScreen(), venues: const [Venue(1, '本多劇場', '東京都')]));
      await tester.tap(find.byKey(const Key('first-stub')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quick-scan')), findsOneWidget);
      return tester.state<QuickLogSheetState>(find.byType(QuickLogSheet));
    }

    testWidgets('公演が分かれば選び、日付、座席、金額も記録に入る', (tester) async {
      ProductionStore.instance.rows = const [CurrentProduction(id: 51, title: '赤鬼', venueName: '本多劇場', groupName: '劇団甲', startDate: '2026-11-01', endDate: '2026-11-10')];
      addTearDown(() => ProductionStore.instance.rows = const []);
      final log = TheaterLog();
      final sheet = await open(tester, log, ['赤鬼', '本多劇場', '2026年11月8日(日) 13:00開演', '1階 C列 12番', '¥7,800']);
      final scope = AppScope.of(tester.element(find.byType(QuickLogSheet)));
      await sheet.scanPath('/dev/null', scope);
      await tester.pump();
      expect(find.byKey(const Key('scan-summary')), findsOneWidget);
      expect(find.byKey(const Key('production-selected')), findsOneWidget);
      expect(find.textContaining('11/8 昼'), findsOneWidget);
      await tester.tap(find.byKey(const Key('quick-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 2));
      final e = log.entries.single;
      expect([e.title, e.venue, e.group, e.productionId], ['赤鬼', '本多劇場', '劇団甲', 51]);
      expect(e.watchedOn, DateTime(2026, 11, 8));
      expect([e.showTime, e.seat, e.price], ['matinee', '1階C列12番', 7800]);
    });

    testWidgets('公演が分からなければ、題名の候補から選べる', (tester) async {
      final log = TheaterLog();
      final sheet = await open(tester, log, ['電子チケット', '誰も知らない新作', '本多劇場', '2026.11.08 開演 18:30']);
      await sheet.scanPath('/dev/null', AppScope.of(tester.element(find.byType(QuickLogSheet))));
      await tester.pump();
      await tester.tap(find.byKey(const Key('scan-title-0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('quick-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 2));
      final e = log.entries.single;
      expect([e.title, e.venue, e.showTime], ['誰も知らない新作', '本多劇場', 'soiree']);
    });

    testWidgets('何も読めなければ、撮り直しの案内を出す', (tester) async {
      final sheet = await open(tester, TheaterLog(), const []);
      await sheet.scanPath('/dev/null', AppScope.of(tester.element(find.byType(QuickLogSheet))));
      await tester.pump();
      expect(find.byKey(const Key('scan-error')), findsOneWidget);
      expect(find.byKey(const Key('scan-summary')), findsNothing);
    });
  });
}
