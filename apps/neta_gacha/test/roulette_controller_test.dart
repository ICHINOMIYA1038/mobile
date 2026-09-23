import 'package:flutter_test/flutter_test.dart';
import 'package:neta_gacha/data/ng_settings_repository.dart';
import 'package:neta_gacha/logic/roulette_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('直近に出したお題は繰り返さない(履歴の上限まで)', () async {
    final controller = RouletteController(situationId: 'opening');
    await controller.load();
    final seen = <String>[];
    for (var i = 0; i < 50; i++) {
      expect(await controller.draw(), isTrue);
      seen.add(controller.currentPrompt!.id);
    }
    expect(seen.toSet().length, seen.length, reason: '50回以内で同じお題が出た');
  });

  test('表示しないテーマのお題はプールから外れる', () async {
    final before = RouletteController(situationId: 'regular');
    await before.load();
    await NgSettingsRepository().toggleTag('religion');
    final after = RouletteController(situationId: 'regular');
    await after.load();
    expect(after.poolSize, lessThan(before.poolSize));
  });
}
