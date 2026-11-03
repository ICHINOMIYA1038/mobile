import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 解いている途中の模擬試験。答えを選ぶたびに端末に残す（iOS がアプリを終了させても、答えが消えないように）。
class MockDraft {
  const MockDraft({required this.userId, required this.exam, required this.startedAtMs, required this.answers});

  final String userId;

  /// POST /pro/mock の返り値（id・seconds・passLine・questions）
  final Map<String, dynamic> exam;
  final int startedAtMs;
  final Map<String, bool?> answers;

  static const _pref = 'mock_draft';

  int get limitSeconds => (exam['seconds'] as num?)?.toInt() ?? 1800;
  int get answeredCount => answers.values.where((a) => a != null).length;
  int leftSeconds(DateTime now) => (limitSeconds - now.difference(DateTime.fromMillisecondsSinceEpoch(startedAtMs)).inSeconds).clamp(0, limitSeconds);

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pref, jsonEncode({'userId': userId, 'exam': exam, 'startedAtMs': startedAtMs, 'answers': answers}));
  }

  /// 別の学習者のものや、読めないものは無かったことにする
  static Future<MockDraft?> load(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pref);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['userId'] != userId) return null;
      return MockDraft(
        userId: j['userId'] as String,
        exam: (j['exam'] as Map).cast<String, dynamic>(),
        startedAtMs: (j['startedAtMs'] as num).toInt(),
        answers: (j['answers'] as Map).cast<String, bool?>(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pref);
  }
}
