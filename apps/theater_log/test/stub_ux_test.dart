import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theater_log/app_scope.dart';
import 'package:theater_log/catalog/achievements.dart';
import 'package:theater_log/catalog/log_flow_prefs.dart';
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

TheaterLogEntry _e(String id, {int month = 1, String? venue, String note = '', int? playId, String? title, DateTime? on}) => TheaterLogEntry(id: id, title: title ?? '舞台$id', watchedOn: on ?? DateTime(2026, month, 1), venue: venue, note: note, playId: playId);

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

  testWidgets('最初は 1 つのボタンだけ。題名とチケット・いつどこで・評価と感想・写真と順に聞き、スタンプの画面が出る', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final log = TheaterLog();
    await tester.pumpWidget(_scope(log, const LogScreen()));
    expect(find.byKey(const Key('log-add')), findsNothing);
    await tester.tap(find.byKey(const Key('first-stub')));
    await tester.pumpAndSettle();

    // 1. 題名。チケットの読み取りも同じ画面。空なら進めない
    expect(find.text('1 / 4'), findsOneWidget);
    expect(find.byKey(const Key('scan-camera')), findsOneWidget);
    expect(find.byKey(const Key('quick-save')), findsNothing);
    expect(tester.widget<FilledButton>(find.byKey(const Key('flow-next'))).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('quick-title')), '赤');
    await tester.pump();
    await tester.tap(find.text('野田秀樹'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('flow-next')));
    await tester.pumpAndSettle();

    // 2. いつ・どこで。劇場が分からなければスキップできる
    expect(find.text('『赤鬼』'), findsOneWidget);
    expect(find.byKey(const Key('venue-open')), findsOneWidget);
    // 選ぼうとするまで、劇場の候補は出さない
    expect(find.byKey(const Key('venue-query')), findsNothing);
    await tester.tap(find.byKey(const Key('flow-skip')));
    await tester.pumpAndSettle();

    // 3. 評価と感想。どちらもなければスキップ
    expect(find.byKey(const Key('flow-skip')), findsOneWidget);
    await tester.tap(find.byKey(const Key('quick-star-4')));
    await tester.enterText(find.byKey(const Key('quick-note')), '鬼の場面が忘れられない');
    await tester.pump();
    await tester.tap(find.byKey(const Key('flow-next')));
    await tester.pumpAndSettle();

    // 4. 写真。最後は半券を切る
    expect(find.byKey(const Key('flow-photo-add')), findsOneWidget);
    expect(find.byKey(const Key('quick-save')), findsNothing);
    await tester.tap(find.byKey(const Key('quick-finish')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    final e = log.entries.single;
    expect(e.title, '赤鬼');
    expect(e.playId, 7);
    expect(e.rating, 4);
    expect(e.note, '鬼の場面が忘れられない');
    expect(e.visibility, 'private');
    expect(e.group, isNull);
    expect(e.venue, isNull);
    expect(find.byKey(const Key('stamped-count')), findsOneWidget);
    expect(find.byKey(const Key('earned-first')), findsOneWidget);
    expect(find.byKey(const Key('stamped-venue')), findsNothing);

    await tester.tap(find.byKey(const Key('stamped-close')));
    await tester.pumpAndSettle();
    expect(find.text('赤鬼'), findsOneWidget);
    expect(find.text('この作品の台本（野田秀樹）'), findsOneWidget);
    expect(find.byKey(const Key('log-add')), findsOneWidget);
  });

  group('記録の手順', () {
    Future<void> openAt(WidgetTester tester, TheaterLog log, {List<Venue> venues = const [], Size size = const Size(430, 932)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_scope(log, const LogScreen(), venues: venues));
      await tester.tap(find.byKey(const Key('first-stub')));
      await tester.pumpAndSettle();
    }

    Future<void> toPlace(WidgetTester tester, String title) async {
      await tester.enterText(find.byKey(const Key('quick-title')), title);
      await tester.pump();
      await tester.tap(find.byKey(const Key('flow-next')));
      await tester.pumpAndSettle();
    }

    Future<void> cut(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('quick-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 2));
    }

    testWidgets('題名を入れたら、どの画面からでも半券を切れる', (tester) async {
      final log = TheaterLog();
      await openAt(tester, log);
      await tester.enterText(find.byKey(const Key('quick-title')), 'ひとり芝居');
      await tester.pump();
      await cut(tester);
      final e = log.entries.single;
      expect([e.title, e.venue, e.rating], ['ひとり芝居', null, null]);
      expect(e.watchedOn, DateUtils.dateOnly(DateTime.now()));
    });

    testWidgets('劇場は一覧から選ぶか、一覧になければそのまま書ける。観た日も選べる', (tester) async {
      final log = TheaterLog();
      const venues = [Venue(1, '本多劇場', '東京都'), Venue(2, 'ABCホール', '大阪府')];
      await openAt(tester, log, venues: venues);
      await toPlace(tester, '新作');
      await tester.tap(find.byKey(const Key('flow-day-1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('venue-open')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('venue-query')), '本多');
      await tester.pump();
      await tester.tap(find.byKey(const Key('venue-hit-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('flow-venue')), findsOneWidget);
      expect(find.byKey(const Key('flow-next')), findsOneWidget);

      // 変えて、一覧にない劇場を書く
      await tester.tap(find.byKey(const Key('venue-change')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('venue-query')), '近所の公民館');
      await tester.pump();
      await tester.tap(find.byKey(const Key('venue-free')));
      await tester.pumpAndSettle();
      await cut(tester);
      final e = log.entries.single;
      expect(e.venue, '近所の公民館');
      expect(e.watchedOn, DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 1)));
    });

    testWidgets('一覧の劇場を選べば、劇場スタンプも一緒に押される', (tester) async {
      final log = TheaterLog();
      await openAt(tester, log, venues: const [Venue(1, '本多劇場', '東京都')]);
      await toPlace(tester, '新作');
      await tester.tap(find.byKey(const Key('venue-open')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('venue-query')), '本多');
      await tester.pump();
      await tester.tap(find.byKey(const Key('venue-hit-1')));
      await tester.pumpAndSettle();
      await cut(tester);
      expect(log.entries.single.venue, '本多劇場');
      expect(find.byKey(const Key('stamped-venue-auto')), findsOneWidget);
    });

    testWidgets('「次回から出さない」にした写真の画面は、次から出ない。アカウントで戻せる', (tester) async {
      final log = TheaterLog();
      await openAt(tester, log);
      await toPlace(tester, '一本目');
      await tester.tap(find.byKey(const Key('flow-skip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('flow-skip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('flow-hide-photos')));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('log_flow_hide_photos'), isTrue);
      // 出さないにしても、まだ記録はしていない
      expect(log.entries, isEmpty);
      await tester.tap(find.byKey(const Key('quick-finish')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 2));
      expect(log.entries.single.title, '一本目');
      await tester.tap(find.byKey(const Key('stamped-close')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('log-add')));
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);

      await LogFlowPrefs.showPhotos(true);
      expect(await LogFlowPrefs.showsPhotos(), isTrue);
    });

    testWidgets('題名を入れたあとで閉じるときは、やめてよいか確かめる', (tester) async {
      final log = TheaterLog();
      await openAt(tester, log);
      await toPlace(tester, '途中の舞台');
      await tester.tap(find.byKey(const Key('flow-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('flow-back')));
      await tester.pumpAndSettle();
      expect(find.text('記録をやめますか？'), findsOneWidget);
      await tester.tap(find.byKey(const Key('flow-continue')));
      await tester.pumpAndSettle();
      expect(find.byType(QuickLogSheet), findsOneWidget);
      await tester.tap(find.byKey(const Key('flow-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('flow-quit')));
      await tester.pumpAndSettle();
      expect(find.byType(QuickLogSheet), findsNothing);
      expect(log.entries, isEmpty);
    });

    testWidgets('作品のページから開くと、題名は聞かない', (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final log = TheaterLog();
      await tester.pumpWidget(_scope(log, Builder(builder: (c) => TextButton(onPressed: () => QuickLogSheet.open(c, play: const Play(id: 7, title: '赤鬼', author: '野田秀樹')), child: const Text('開く')))));
      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('『赤鬼』'), findsOneWidget);
      await cut(tester);
      expect(log.entries.single.playId, 7);
    });
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

    testWidgets('押した瞬間に 1 回だけ合図する', (tester) async {
      var impacts = 0;
      await tester.pumpWidget(stamp(onImpact: () => impacts++));
      await tester.pump(const Duration(milliseconds: 100));
      expect(impacts, 0);
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pump(const Duration(milliseconds: 16));
      expect(impacts, 1);
      await tester.pumpAndSettle();
      expect(impacts, 1);
      expect(find.bySemanticsLabel(RegExp(r'^観劇済')), findsOneWidget);
    });

    testWidgets('動きを減らす設定では、動かさずに押された状態を見せる', (tester) async {
      var impacts = 0;
      await tester.pumpWidget(stamp(onImpact: () => impacts++, reduced: true));
      await tester.pump();
      expect(impacts, 0, reason: '揺らさない');
      expect(find.bySemanticsLabel(RegExp(r'^観劇済')), findsOneWidget);
    });

    testWidgets('半券帳の一覧の半券に印が残る', (tester) async {
      final log = TheaterLog();
      await log.upsert(_e('a'));
      await tester.pumpWidget(_scope(log, const LogScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('log-view-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('stub-seal-a')), findsOneWidget);
    });
  });

  group('写真で振り返る', () {
    testWidgets('新しい順に 1 本ずつ出し、右を押すと次、左を押すと前へ。一覧から選ぶとその 1 本を出す', (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final log = TheaterLog();
      await log.upsert(_e('old', title: '前に観た舞台', on: DateTime(2026, 10, 1)));
      await log.upsert(_e('new', title: '最近観た舞台', on: DateTime(2026, 11, 3)));
      await tester.pumpWidget(_scope(log, const LogScreen()));
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('最近観た舞台'), findsOneWidget);
      expect(find.textContaining('2026年11月3日（火）'), findsOneWidget);

      await tester.tapAt(const Offset(380, 400));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.tapAt(const Offset(40, 400));
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);

      await tester.tap(find.byKey(const Key('log-view-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('前に観た舞台'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
    });

    test('日付にマチネ・ソワレを添える', () {
      expect(storyDate(TheaterLogEntry(id: 'a', title: 't', watchedOn: DateTime(2026, 11, 3), showTime: 'matinee')), '2026年11月3日（火）　マチネ');
      expect(storyDate(TheaterLogEntry(id: 'a', title: 't', watchedOn: DateTime(2026, 11, 8))), '2026年11月8日（日）');
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

    Future<void> cut(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('quick-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 2));
    }

    testWidgets('題名を入れると公演名と劇場名が出て、選ぶと劇場の確認へ進み、劇場と劇団が記録に入る', (tester) async {
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
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('flow-venue')), findsOneWidget);
      expect(find.text('本多劇場'), findsOneWidget);

      await cut(tester);
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
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('flow-back')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('quick-title')), '自分だけの舞台');
      await tester.pump();
      expect(find.byKey(const Key('production-selected')), findsNothing);
      expect(find.byKey(const Key('production-register')), findsOneWidget);
      await cut(tester);
      final e = log.entries.single;
      expect(e.title, '自分だけの舞台');
      expect(e.venue, isNull);
      expect(e.productionId, isNull);
    });

    for (final (name, size, keyboard) in const [('iPhone 16', Size(393, 852), 336.0), ('iPhone SE', Size(375, 667), 216.0)]) {
      testWidgets('$name でキーボードが開いても、公演と劇場の候補が画面に収まる', (tester) async {
        ProductionStore.instance.rows = [for (var i = 0; i < 8; i++) CurrentProduction(id: 40 + i, title: '赤鬼 第$i部', venueName: '劇場$i', groupName: '劇団', startDate: '2026-11-01', endDate: '2026-11-02')];
        addTearDown(() => ProductionStore.instance.rows = const []);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_scope(TheaterLog(), const LogScreen(), venues: [for (var i = 0; i < 8; i++) Venue(i, '劇場$i', '東京都')]));
        await tester.tap(find.byKey(const Key('first-stub')));
        await tester.pumpAndSettle();
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('quick-title')), '赤鬼');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('production-hit-40')), findsOneWidget);
        expect(find.byKey(const Key('flow-next')), findsOneWidget);
        expect(find.byKey(const Key('quick-save')), findsOneWidget);

        // 一覧にない題名で進み、劇場を探す
        await tester.enterText(find.byKey(const Key('quick-title')), '新作');
        await tester.pump();
        await tester.tap(find.byKey(const Key('flow-next')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('venue-open')));
        await tester.pump();
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        await tester.enterText(find.byKey(const Key('venue-query')), '劇場');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('venue-hit-0')), findsOneWidget);
        expect(find.byKey(const Key('flow-day-0')), findsNothing);
        await tester.tap(find.byKey(const Key('venue-hit-0')));
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('flow-day-0')), findsOneWidget);
        expect(find.byKey(const Key('flow-venue')), findsOneWidget);
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
      await tester.pumpAndSettle();
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
      expect(find.byKey(const Key('scan-camera')), findsOneWidget);
      return tester.state<QuickLogSheetState>(find.byType(QuickLogSheet));
    }

    Future<void> cut(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('quick-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 2));
    }

    testWidgets('公演が分かれば題名は聞かずに劇場の確認へ進み、日付、座席、金額も記録に入る', (tester) async {
      ProductionStore.instance.rows = const [CurrentProduction(id: 51, title: '赤鬼', venueName: '本多劇場', groupName: '劇団甲', startDate: '2026-11-01', endDate: '2026-11-10')];
      addTearDown(() => ProductionStore.instance.rows = const []);
      final log = TheaterLog();
      final sheet = await open(tester, log, ['赤鬼', '本多劇場', '2026年11月8日(日) 13:00開演', '1階 C列 12番', '¥7,800']);
      final scope = AppScope.of(tester.element(find.byType(QuickLogSheet)));
      await sheet.scanPath('/dev/null', scope);
      await tester.pumpAndSettle();
      expect(find.text('2 / 4'), findsOneWidget);
      expect(find.byKey(const Key('flow-venue')), findsOneWidget);
      expect(find.textContaining('2026年11月8日 昼の部'), findsOneWidget);
      await cut(tester);
      final e = log.entries.single;
      expect([e.title, e.venue, e.group, e.productionId], ['赤鬼', '本多劇場', '劇団甲', 51]);
      expect(e.watchedOn, DateTime(2026, 11, 8));
      expect([e.showTime, e.seat, e.price], ['matinee', '1階C列12番', 7800]);
    });

    testWidgets('読み取ったチケットの写真は 1 枚目に入り、写真の画面で外せる。撮り直すと差し替わる', (tester) async {
      final log = TheaterLog();
      final sheet = await open(tester, log, ['電子チケット', '誰も知らない新作', '本多劇場']);
      await sheet.scanPath('/dev/null', AppScope.of(tester.element(find.byType(QuickLogSheet))));
      sheet.adoptTicketPhoto('ticket1.jpg');
      sheet.adoptTicketPhoto('ticket2.jpg');
      await tester.pump();
      await tester.tap(find.byKey(const Key('scan-title-0')));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(Key(i == 0 ? 'flow-next' : (i == 1 ? 'flow-next' : 'flow-skip'))));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const Key('flow-photo-ticket')), findsOneWidget);
      expect(find.byKey(const Key('flow-photo-1')), findsNothing);
      await tester.tap(find.byKey(const Key('quick-finish')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 2));
      expect(log.entries.single.photos, ['ticket2.jpg']);
    });

    testWidgets('チケットを読み直すと、前のチケットから入れた公演と題名は外れる。× で外すと写真も外れる', (tester) async {
      ProductionStore.instance.rows = const [CurrentProduction(id: 61, title: '赤鬼', venueName: '本多劇場', startDate: '2026-11-01', endDate: '2026-11-10')];
      addTearDown(() => ProductionStore.instance.rows = const []);
      final log = TheaterLog();
      final sheet = await open(tester, log, ['赤鬼', '本多劇場', '2026年11月5日']);
      final scope = AppScope.of(tester.element(find.byType(QuickLogSheet)));
      await sheet.scanPath('/dev/null', scope);
      sheet.adoptTicketPhoto('a.jpg');
      await tester.pumpAndSettle();
      // 公演が分かって劇場の画面へ進んだので、題名の画面へ戻って別のチケットを読む
      await tester.tap(find.byKey(const Key('flow-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('production-selected')), findsOneWidget);
      TicketScanner.override = (_) async => ['電子チケット', '誰も知らない新作', '2026.11.06'];
      await sheet.scanPath('/dev/null', scope);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('production-selected')), findsNothing);
      expect(tester.widget<TextField>(find.byKey(const Key('quick-title'))).controller!.text, isEmpty);
      // × で外すと、チケットの写真も外れる
      await tester.tap(find.byKey(const Key('scan-clear')));
      await tester.pump();
      expect(find.byKey(const Key('scan-summary')), findsNothing);
      await tester.enterText(find.byKey(const Key('quick-title')), '手で入れた題名');
      await tester.pump();
      await tester.tap(find.byKey(const Key('quick-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 2));
      final e = log.entries.single;
      expect([e.title, e.productionId, e.photos], ['手で入れた題名', null, isEmpty]);
    });

    testWidgets('チケットの写真は、写真の画面で外せば記録に入らない', (tester) async {
      final log = TheaterLog();
      final sheet = await open(tester, log, ['電子チケット', '誰も知らない新作', '本多劇場']);
      await sheet.scanPath('/dev/null', AppScope.of(tester.element(find.byType(QuickLogSheet))));
      sheet.adoptTicketPhoto('ticket.jpg');
      await tester.pump();
      await tester.tap(find.byKey(const Key('scan-title-0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('flow-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('flow-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('flow-skip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('flow-photo-remove-0')));
      await tester.pump();
      expect(find.byKey(const Key('flow-photo-ticket')), findsNothing);
      await tester.tap(find.byKey(const Key('quick-finish')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 2));
      expect(log.entries.single.photos, isEmpty);
    });

    testWidgets('公演が分からなければ題名の画面のまま、チケットの候補から選べる', (tester) async {
      final log = TheaterLog();
      final sheet = await open(tester, log, ['電子チケット', '誰も知らない新作', '本多劇場', '2026.11.08 開演 18:30']);
      await sheet.scanPath('/dev/null', AppScope.of(tester.element(find.byType(QuickLogSheet))));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scan-summary')), findsOneWidget);
      await tester.tap(find.byKey(const Key('scan-title-0')));
      await tester.pump();
      await cut(tester);
      final e = log.entries.single;
      expect([e.title, e.venue, e.showTime], ['誰も知らない新作', '本多劇場', 'soiree']);
    });

    testWidgets('何も読めなければ撮り直しを案内し、そのまま題名も入れられる', (tester) async {
      final sheet = await open(tester, TheaterLog(), const []);
      await sheet.scanPath('/dev/null', AppScope.of(tester.element(find.byType(QuickLogSheet))));
      await tester.pump();
      expect(find.byKey(const Key('scan-error')), findsOneWidget);
      expect(find.byKey(const Key('scan-retry')), findsOneWidget);
      expect(find.byKey(const Key('scan-summary')), findsNothing);
      expect(find.byKey(const Key('quick-title')), findsOneWidget);
    });
  });
}
