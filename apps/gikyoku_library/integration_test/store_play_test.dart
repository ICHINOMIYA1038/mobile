import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gikyoku_library/account/auth_service.dart';
import 'package:gikyoku_library/catalog/catalog_repository.dart';
import 'package:gikyoku_library/catalog/shortlist.dart';
import 'package:gikyoku_library/catalog/theater_log.dart';
import 'package:gikyoku_library/main.dart';
import 'package:gikyoku_library/widgets/play_card.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ストア用の 2 枚目（作品詳細）を撮るためのテスト。ジャンルに「無料」が入らない作品を開く
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('作品詳細を開いて止める', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = CatalogRepository();
    await tester.pumpWidget(App(repository: repository, catalog: await repository.load(), shortlist: Shortlist(), log: TheaterLog(), auth: AuthService()));
    await tester.tap(find.text('台本をさがす'));
    await tester.pumpAndSettle();
    await Future<void>.delayed(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'エダニク');
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PlayCard).first);
    await tester.pumpAndSettle();
    expect(find.text('あらすじ'), findsOneWidget);
    await Future<void>.delayed(const Duration(seconds: 8));
  });
}
