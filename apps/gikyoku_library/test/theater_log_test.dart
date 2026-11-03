import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gikyoku_library/app_scope.dart';
import 'package:gikyoku_library/catalog/models.dart';
import 'package:gikyoku_library/catalog/shortlist.dart';
import 'package:gikyoku_library/catalog/theater_log.dart';
import 'package:gikyoku_library/screens/log_screen.dart';
import 'package:gikyoku_library/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _catalog = Catalog(
  generatedAt: DateTime.utc(2026, 11, 4),
  categories: const [],
  plays: const [Play(id: 7, title: '赤鬼', author: '野田秀樹', groups: ['ある劇団'])],
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

  testWidgets('自由入力でも作品からでも記録でき、作品を選ぶと台本へつながる', (tester) async {
    final log = TheaterLog();
    await tester.pumpWidget(
      AppScope(
        catalog: _catalog,
        shortlist: Shortlist(),
        log: log,
        child: MaterialApp(theme: buildTheme(), home: const LogScreen()),
      ),
    );
    expect(find.textContaining('観た舞台を記録しましょう'), findsOneWidget);

    await tester.tap(find.byKey(const Key('log-add')));
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
    await tester.tap(find.byKey(const Key('star-5')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('log-save')));
    await tester.pumpAndSettle();

    expect(log.entries.single.playId, 7);
    expect(log.entries.single.group, 'ある劇団');
    expect(log.entries.single.rating, 5);
    expect(find.byKey(const Key('log-to-play')), findsOneWidget);
    expect(find.textContaining('これまで 1 本'), findsOneWidget);
  });
}
