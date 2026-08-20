import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// シチュエーションごとに直近N件の表示済みお題IDを覚えておき、抽選時に除外するための履歴。
///
/// グローバルな「今日出した一覧」ではなく、シチュエーションごとのリングバッファにしているのは、
/// 1回の配信中でも複数のシチュエーションを行き来する使い方(オープニングは最初に1回、
/// ゲーム実況つなぎは連発、など)に対して、無関係なシチュエーションでの連打が他の
/// シチュエーションの新鮮なお題までブロックしてしまわないようにするため。
class HistoryRepository {
  static const _key = 'history_v1';
  static const _maxPerSituation = 55;

  Future<Map<String, List<String>>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(key, (value as List).cast<String>()),
      );
    } catch (_) {
      // 破損していたら履歴なしとして扱う。抽選が止まる方が実害が大きい。
      return {};
    }
  }

  Future<void> _save(Map<String, List<String>> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(history));
  }

  Future<Set<String>> recentIdsFor(String situationId) async {
    final history = await _load();
    return (history[situationId] ?? const []).toSet();
  }

  Future<void> recordShown(String situationId, String promptId) async {
    final history = await _load();
    final ids = List<String>.from(history[situationId] ?? const []);
    ids.remove(promptId);
    ids.add(promptId);
    while (ids.length > _maxPerSituation) {
      ids.removeAt(0);
    }
    history[situationId] = ids;
    await _save(history);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
