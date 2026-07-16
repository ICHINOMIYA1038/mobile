import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/review_state.dart';

/// 学習データの保存。端末内だけで完結し、サーバーには一切送らない。
///
/// 既存アプリで最も多い不満が「アプリが落ちて学習データが消えた」だったため、
/// 回答のたびに保存し、ユーザーがいつでも書き出せるようにしている。
class ProgressRepository {
  static const _statesKey = 'review_states_v1';
  static const _streakKey = 'streak_v1';

  Future<Map<String, ReviewState>> loadStates() async {
    // 読み出し全体を try で囲むこと。getString は保存値の型が想定外だと
    // それ自体が例外を投げるため、jsonDecode だけを守っても足りない。
    // ここで例外が漏れると init() が中断し、読み込み中の画面から永久に戻れなくなる。
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_statesKey);
      if (raw == null || raw.isEmpty) return {};

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(
          key,
          ReviewState.fromJson(value as Map<String, dynamic>),
        ),
      );
    } catch (_) {
      // 壊れたデータで起動不能にはしない。学習履歴は失われるが、アプリは開く。
      return {};
    }
  }

  Future<void> saveStates(Map<String, ReviewState> states) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      states.map((key, value) => MapEntry(key, value.toJson())),
    );
    await prefs.setString(_statesKey, encoded);
  }

  Future<StreakData> loadStreak() async {
    // loadStates と同じ理由で、getString も含めて丸ごと守る。
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_streakKey);
      if (raw == null || raw.isEmpty) return const StreakData();

      return StreakData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const StreakData();
    }
  }

  Future<void> saveStreak(StreakData streak) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_streakKey, jsonEncode(streak.toJson()));
  }

  /// 学習データを丸ごと書き出す。機種変更や端末故障に備えた保険。
  Future<String> exportJson() async {
    final states = await loadStates();
    final streak = await loadStreak();
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'シンプルに学ぶ宅建アプリ',
      'schema': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'streak': streak.toJson(),
      'states': states.map((key, value) => MapEntry(key, value.toJson())),
    });
  }

  /// 書き出したデータを読み戻す。形式が違えば false を返し、既存データには触れない。
  Future<bool> importJson(String raw) async {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final states = (decoded['states'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          ReviewState.fromJson(value as Map<String, dynamic>),
        ),
      );
      await saveStates(states);

      final streak = decoded['streak'];
      if (streak is Map<String, dynamic>) {
        await saveStreak(StreakData.fromJson(streak));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_statesKey);
    await prefs.remove(_streakKey);
  }
}

/// 連続学習日数。ゲーム要素は増やさず、これ一つだけに絞っている。
class StreakData {
  const StreakData({this.current = 0, this.best = 0, this.lastStudyDate});

  final int current;
  final int best;

  /// 最終学習日（日付のみ。時刻は保持しない）。
  final DateTime? lastStudyDate;

  StreakData markStudied(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final last = lastStudyDate;

    if (last != null) {
      final lastDay = DateTime(last.year, last.month, last.day);
      if (lastDay == today) return this;

      final gap = today.difference(lastDay).inDays;
      // 昨日やっていれば継続、それ以上空いたら1日目からやり直し。
      final next = gap == 1 ? current + 1 : 1;
      return StreakData(
        current: next,
        best: next > best ? next : best,
        lastStudyDate: today,
      );
    }

    return StreakData(current: 1, best: best < 1 ? 1 : best, lastStudyDate: today);
  }

  Map<String, dynamic> toJson() => {
        'current': current,
        'best': best,
        'lastStudyDate': lastStudyDate?.toIso8601String(),
      };

  factory StreakData.fromJson(Map<String, dynamic> json) {
    final raw = json['lastStudyDate'];
    return StreakData(
      current: (json['current'] as num?)?.toInt() ?? 0,
      best: (json['best'] as num?)?.toInt() ?? 0,
      lastStudyDate: raw is String ? DateTime.tryParse(raw) : null,
    );
  }
}
