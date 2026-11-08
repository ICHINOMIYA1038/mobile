import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theater_log/app_scope.dart';
import 'package:theater_log/catalog/theater_log.dart';
import 'package:theater_log/screens/account_screen.dart';
import 'package:theater_log/screens/log_edit_screen.dart';
import 'package:theater_log/screens/log_screen.dart';
import 'package:theater_log/screens/recap_screen.dart';
import 'package:theater_log/screens/stamp_book_screen.dart';
import 'package:theater_log/theme.dart';
import 'package:theater_log/widgets/community_widgets.dart';

import 'test_support.dart';

Widget _scope(TheaterLog log, Widget child) => AppScope(
  catalog: Catalog(generatedAt: DateTime.utc(2026), categories: const [], plays: const [Play(id: 7, title: '赤鬼', author: '野田秀樹')], venues: const [Venue(1, '東京芸術劇場 シアターイースト', '東京都')]),
  log: log,
  auth: offlineAuth(),
  sync: offlineSync(offlineAuth(), log),
  child: MaterialApp(theme: buildTheme(), home: Scaffold(body: child)),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  // 小さな画面（iPhone SE）と大きな文字の設定で、主な画面がはみ出さないこと
  final problems = <String>[];
  tearDownAll(() => expect(problems, isEmpty, reason: problems.join('\n')));

  for (final (size, scale) in const [(Size(375, 667), 1.0), (Size(375, 667), 1.35), (Size(375, 667), 2.0), (Size(393, 852), 2.0)]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()} @$scale';
    Future<void> setup(WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }

    void check(WidgetTester tester, String where) {
      final e = tester.takeException();
      if (e != null) problems.add('$tag $where: ${e.toString().split('\n').first}');
    }

    testWidgets('記録の手順 $tag', (tester) async {
      await setup(tester);
      final log = TheaterLog();
      await tester.pumpWidget(_scope(log, const LogScreen()));
      await tester.pumpAndSettle();
      check(tester, 'empty log');
      await tester.ensureVisible(find.byKey(const Key('first-stub')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('first-stub')));
      await tester.pumpAndSettle();
      check(tester, 'title step');
      await tester.enterText(find.byKey(const Key('quick-title')), '赤鬼という長い長い題名の公演の記録');
      await tester.pumpAndSettle();
      check(tester, 'title typed');
      await tester.tap(find.byKey(const Key('flow-next')));
      await tester.pumpAndSettle();
      check(tester, 'place step');
      await tester.ensureVisible(find.byKey(const Key('venue-open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('venue-open')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('venue-query')), '東京');
      await tester.pumpAndSettle();
      check(tester, 'venue search');
      await tester.ensureVisible(find.byKey(const Key('venue-hit-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('venue-hit-1')));
      await tester.pumpAndSettle();
      check(tester, 'venue chosen');
      await tester.tap(find.byKey(const Key('flow-next')));
      await tester.pumpAndSettle();
      check(tester, 'rating step');
      await tester.ensureVisible(find.byKey(const Key('quick-star-4')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick-star-4')));
      await tester.enterText(find.byKey(const Key('quick-note')), '感想 ' * 40);
      await tester.pumpAndSettle();
      check(tester, 'rating typed');
      await tester.tap(find.byKey(const Key('flow-next')));
      await tester.pumpAndSettle();
      check(tester, 'photo step');
      await tester.tap(find.byKey(const Key('quick-finish')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      check(tester, 'stamped');
      await tester.tap(find.byKey(const Key('stamped-close')));
      await tester.pumpAndSettle();
      check(tester, 'log with entry');
    });

    testWidgets('主な画面 $tag', (tester) async {
      await setup(tester);
      final log = TheaterLog();
      for (var i = 0; i < 6; i++) {
        await log.upsert(TheaterLogEntry(id: 'e$i', title: '長い題名の公演 第$i 回 ふたたび', watchedOn: DateTime(2026, 11, 1 + i), venue: '東京芸術劇場 シアターイースト', group: '劇団', rating: 4, note: '感想'));
      }
      for (final (name, w) in [('stamp book', const StampBookScreen()), ('account', const AccountScreen()), ('recap', const RecapScreen())]) {
        await tester.pumpWidget(_scope(log, w));
        await tester.pumpAndSettle();
        check(tester, name);
      }
      await tester.pumpWidget(_scope(log, LogEditScreen(entry: log.entries.first)));
      await tester.pumpAndSettle();
      check(tester, 'edit');
      await tester.pumpWidget(_scope(log, Builder(builder: (c) => TextButton(onPressed: () => CommunityRules.confirm(c), child: const Text('go')))));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      check(tester, 'rules dialog');
    });
  }
}
