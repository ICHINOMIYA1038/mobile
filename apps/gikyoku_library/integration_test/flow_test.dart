import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import 'package:gikyoku_library/catalog/shortlist.dart';
import 'package:gikyoku_library/main.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('台本を絞り込み、詳細を見て、候補で比べる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const hold = Duration(seconds: 7);
    final repository = CatalogRepository();
    final shortlist = Shortlist();
    await tester.pumpWidget(App(repository: repository, catalog: await repository.load(), shortlist: shortlist));
    await tester.pumpAndSettle();

    await tester.tap(find.text('3〜5人'));
    await tester.tap(find.text('60分まで'));
    await tester.pumpAndSettle();
    final count = int.parse((tester.widget<Text>(find.byKey(const Key('hit-count'))).data!).split(' ').first);
    expect(count, greaterThan(0));
    expect(count, lessThan(1310));
    await Future<void>.delayed(hold);

    await tester.tap(find.byTooltip('気になる').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('気になる').first);
    await tester.pumpAndSettle();
    expect(shortlist.ids.length, 2);

    await tester.tap(find.textContaining('作品').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.schedule).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shortlist-toggle')), findsOneWidget);
    await Future<void>.delayed(hold);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton).evaluate().isEmpty ? find.byKey(const Key('open-shortlist')) : find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('compare-table')), findsOneWidget);
    await Future<void>.delayed(hold);
  });
}
