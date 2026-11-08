import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theater_log/app_scope.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import 'package:theater_log/catalog/theater_log.dart';
import 'package:theater_log/screens/log_edit_screen.dart';
import 'package:theater_log/screens/log_screen.dart';
import 'package:theater_log/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support.dart';

final _catalog = Catalog(
  generatedAt: DateTime.utc(2026, 11, 4),
  categories: const [],
  plays: const [Play(id: 7, title: '赤鬼', author: '野田秀樹', groups: ['ある劇団', '別の劇団'])],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('新しい順に並び、年ごとに数え、再起動しても残る', () async {
    final log = TheaterLog();
    await log.upsert(TheaterLogEntry(id: 'a', title: '前', watchedOn: DateTime(2025, 3, 1)));
    await log.upsert(TheaterLogEntry(id: 'b', title: '後', watchedOn: DateTime(2026, 3, 1), rating: 4, note: 'よかった', playId: 7));
    expect(log.entries.first.id, 'b');
    expect(log.countInYear(2026), 1);

    final again = TheaterLog();
    await again.load();
    expect(again.entries.map((e) => e.title), ['後', '前']);
    expect(again.entries.first.note, 'よかった');
    expect(again.entries.first.playId, 7);

    await again.remove('b');
    final third = TheaterLog();
    await third.load();
    expect(third.entries.single.id, 'a');
  });

  test('編集は同じ記録を上書きする', () async {
    final log = TheaterLog();
    await log.upsert(TheaterLogEntry(id: 'a', title: '前', watchedOn: DateTime(2026)));
    await log.upsert(TheaterLogEntry(id: 'a', title: '後', watchedOn: DateTime(2026)));
    expect(log.entries.single.title, '後');
  });

  test('壊れた保存データで止まらない', () async {
    SharedPreferences.setMockInitialValues({'theater_log': '{壊れている'});
    final log = TheaterLog();
    await log.load();
    expect(log.entries, isEmpty);
  });

  testWidgets('上演した劇団が 1 つの作品でも、劇団を自動で入れない', (tester) async {
    final log = TheaterLog();
    final one = Catalog(
      generatedAt: DateTime.utc(2026, 11, 4),
      categories: const [],
      plays: const [Play(id: 8, title: '一つだけ', author: '作者', groups: ['唯一の劇団'])],
    );
    await tester.pumpWidget(
      AppScope(
        catalog: one,
        log: log,
        auth: offlineAuth(),
        sync: offlineSync(offlineAuth(), log),
        child: MaterialApp(theme: buildTheme(), home: const _WithEditor()),
      ),
    );
    await tester.tap(find.byKey(const Key('open-editor')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('log-title')), '一つ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('作者'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('log-save')));
    await tester.pumpAndSettle();
    expect(log.entries.single.group, isNull);
  });

  testWidgets('自由入力でも作品からでも記録でき、作品を選ぶと台本へつながる', (tester) async {
    final log = TheaterLog();
    await tester.pumpWidget(
      AppScope(
        catalog: _catalog,
        log: log,
        auth: offlineAuth(),
        sync: offlineSync(offlineAuth(), log),
        child: MaterialApp(theme: buildTheme(), home: const _WithEditor()),
      ),
    );

    await tester.tap(find.byKey(const Key('open-editor')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('log-save')));
    await tester.pump();
    expect(find.text('作品名を入れてください'), findsOneWidget);
    expect(log.entries, isEmpty);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.enterText(find.byKey(const Key('log-title')), '赤');
    await tester.pumpAndSettle();
    await tester.tap(find.text('野田秀樹'));
    await tester.pumpAndSettle();
    // 劇団の候補は、劇団の欄を触るまで出さない
    expect(find.text('別の劇団'), findsNothing);
    await tester.tap(find.byKey(const Key('log-group')));
    await tester.pump();
    expect(find.text('別の劇団'), findsOneWidget);
    await tester.tap(find.byKey(const Key('suggest-別の劇団')));
    await tester.pump();
    expect(find.text('別の劇団'), findsOneWidget);
    await tester.tap(find.byKey(const Key('star-5')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('log-save')));
    await tester.pumpAndSettle();

    expect(log.entries.single.playId, 7);
    expect(log.entries.single.group, '別の劇団');
    expect(log.entries.single.rating, 5);
    expect(find.byKey(const Key('log-to-play')), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
  });
}

/// 編集画面を開くボタンつきの半券帳
class _WithEditor extends StatelessWidget {
  const _WithEditor();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: const LogScreen(),
    bottomNavigationBar: TextButton(key: const Key('open-editor'), onPressed: () => LogEditScreen.open(context), child: const Text('編集')),
  );
}
