import 'package:shared_preferences/shared_preferences.dart';

/// ベストスコア・累計コイン・クリア済みステージなどの進捗を端末に保存する。
class SaveService {
  static const _bestScoreKey = 'korokoro.bestScore';
  static const _totalCoinsKey = 'korokoro.totalCoins';
  static const _clearedStagesKey = 'korokoro.clearedStages';

  Future<Map<String, Object>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'bestScore': prefs.getInt(_bestScoreKey) ?? 0,
      'totalCoins': prefs.getInt(_totalCoinsKey) ?? 0,
      'clearedStages': prefs.getStringList(_clearedStagesKey) ?? const <String>[],
    };
  }

  Future<void> save({
    required int bestScore,
    required int totalCoins,
    List<String> clearedStages = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bestScoreKey, bestScore);
    await prefs.setInt(_totalCoinsKey, totalCoins);
    await prefs.setStringList(_clearedStagesKey, clearedStages);
  }
}
