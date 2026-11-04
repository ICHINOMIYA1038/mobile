import 'package:flutter_test/flutter_test.dart';
import 'package:gikyoku_library/catalog/catalog_repository.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('本番の API から新しい版を取り、次は変更なしになる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = CatalogRepository();
    final fresh = await tester.runAsync(repository.refresh);
    expect(fresh, isNotNull);
    expect(fresh!.plays.length, greaterThan(1000));
    expect(fresh.plays.where((p) => p.synopsis != null), isNotEmpty);
    expect(await tester.runAsync(repository.refresh), isNull);
    final loaded = await tester.runAsync(repository.load);
    expect(loaded!.plays.length, fresh.plays.length);
    expect(loaded.plays.where((p) => p.synopsis != null), isNotEmpty);
  });
}
