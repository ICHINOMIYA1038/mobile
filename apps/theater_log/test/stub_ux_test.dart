import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theater_log/app_scope.dart';
import 'package:theater_log/catalog/achievements.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import 'package:theater_log/catalog/theater_log.dart';
import 'package:theater_log/screens/log_screen.dart';
import 'package:theater_log/screens/stamp_book_screen.dart';
import 'package:theater_log/theme.dart';
import 'package:theater_log/widgets/pon_stamp.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support.dart';

TheaterLogEntry _e(String id, {int month = 1, String? venue, String note = '', int? playId}) => TheaterLogEntry(id: id, title: '舞台$id', watchedOn: DateTime(2026, month, 1), venue: venue, note: note, playId: playId);

Widget _scope(TheaterLog log, Widget child) => AppScope(
  catalog: Catalog(generatedAt: DateTime.utc(2026), categories: const [], plays: const [Play(id: 7, title: '赤鬼', author: '野田秀樹')]),
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
}
