import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gikyoku_library/app_scope.dart';
import 'package:gikyoku_library/catalog/models.dart';
import 'package:gikyoku_library/catalog/shortlist.dart';
import 'package:gikyoku_library/catalog/theater_log.dart';
import 'package:gikyoku_library/screens/search_screen.dart';
import 'package:gikyoku_library/screens/shortlist_screen.dart';
import 'package:gikyoku_library/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support.dart';

final _catalog = Catalog(
  generatedAt: DateTime.utc(2026, 11, 4),
  categories: const [Category(1, 'コメディ')],
  plays: const [
    Play(id: 1, title: '二人の台本', author: '甲', total: 2, minutes: 30, readUrl: 'https://example.com/a', categoryIds: [1]),
    Play(id: 2, title: '大勢の台本', author: '乙', total: 12, minutes: 90),
    Play(id: 3, title: '情報なし', author: '丙'),
  ],
);

Widget _wrap(Widget child, Shortlist s) => _scope(child, s, TheaterLog());

Widget _scope(Widget child, Shortlist s, TheaterLog log) => AppScope(
  catalog: _catalog,
  shortlist: s,
  log: log,
  auth: offlineAuth(),
  sync: offlineSync(offlineAuth(), log),
  child: MaterialApp(theme: buildTheme(), home: Scaffold(body: child)),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('人数で絞り込むと件数が変わり、消すと戻る', (tester) async {
    await tester.pumpWidget(_wrap(const SearchScreen(), Shortlist()));
    expect(find.text('3 作品'), findsOneWidget);
    await tester.tap(find.text('2人').first);
    await tester.pump();
    expect(find.text('1 作品'), findsOneWidget);
    expect(find.text('二人の台本'), findsOneWidget);
    expect(find.text('大勢の台本'), findsNothing);
    await tester.tap(find.text('条件を消す'));
    await tester.pump();
    expect(find.text('3 作品'), findsOneWidget);
  });

  testWidgets('しおりを押すと候補に入り、2 作品で比較表が出る。再起動しても残る', (tester) async {
    final s = Shortlist();
    await tester.pumpWidget(_wrap(const SearchScreen(), s));
    await tester.tap(find.byTooltip('気になる').first);
    await tester.pump();
    await tester.tap(find.byTooltip('気になる').first);
    await tester.pump();
    expect(s.ids.length, 2);

    await tester.pumpWidget(_wrap(const ShortlistScreen(), s));
    expect(find.byKey(const Key('compare-table')), findsOneWidget);
    expect(find.byKey(const Key('share-shortlist')), findsOneWidget);

    final reopened = Shortlist();
    await tester.runAsync(reopened.load);
    expect(reopened.ids, s.ids);
  });

  testWidgets('候補が空なら案内を出す', (tester) async {
    await tester.pumpWidget(_wrap(const ShortlistScreen(), Shortlist()));
    expect(find.textContaining('しおりを押すと'), findsOneWidget);
    expect(find.byKey(const Key('compare-table')), findsNothing);
  });
}
