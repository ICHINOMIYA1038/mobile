import 'package:flutter_test/flutter_test.dart';
import 'package:korokoro_slope/data/save_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('未保存の状態ではベストスコア・コイン・クリア済みステージともに空を返す', () async {
    final result = await SaveService().load();
    expect(result, {'bestScore': 0, 'totalCoins': 0, 'clearedStages': <String>[]});
  });

  test('保存した値をそのまま読み込める', () async {
    final service = SaveService();
    await service.save(bestScore: 250, totalCoins: 12, clearedStages: ['forest']);

    final result = await service.load();
    expect(result, {'bestScore': 250, 'totalCoins': 12, 'clearedStages': ['forest']});
  });

  test('保存を繰り返すと最新の値で上書きされる', () async {
    final service = SaveService();
    await service.save(bestScore: 100, totalCoins: 5, clearedStages: ['forest']);
    await service.save(bestScore: 300, totalCoins: 20, clearedStages: ['forest', 'rock']);

    final result = await service.load();
    expect(result, {'bestScore': 300, 'totalCoins': 20, 'clearedStages': ['forest', 'rock']});
  });
}
