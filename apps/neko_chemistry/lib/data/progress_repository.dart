import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 単元ごとの回答数・正解数。
class UnitStats {
  const UnitStats({this.answered = 0, this.correct = 0});

  final int answered;
  final int correct;

  double get accuracy => answered == 0 ? 0 : correct / answered;

  UnitStats copyWith({int? answered, int? correct}) {
    return UnitStats(
      answered: answered ?? this.answered,
      correct: correct ?? this.correct,
    );
  }

  Map<String, dynamic> toJson() => {'answered': answered, 'correct': correct};

  factory UnitStats.fromJson(Map<String, dynamic> json) {
    return UnitStats(
      answered: (json['answered'] as num?)?.toInt() ?? 0,
      correct: (json['correct'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 連続学習日数の記録。
class StreakData {
  const StreakData({
    this.current = 0,
    this.best = 0,
    this.lastStudyDate,
  });

  final int current;
  final int best;
  final String? lastStudyDate; // 'yyyy-MM-dd'形式

  Map<String, dynamic> toJson() => {
    'current': current,
    'best': best,
    'lastStudyDate': lastStudyDate,
  };

  factory StreakData.fromJson(Map<String, dynamic> json) {
    return StreakData(
      current: (json['current'] as num?)?.toInt() ?? 0,
      best: (json['best'] as num?)?.toInt() ?? 0,
      lastStudyDate: json['lastStudyDate'] as String?,
    );
  }
}

/// 猫の学習進捗を端末内に保存するリポジトリ。
/// takken_simpleのProgressRepositoryと同じ方針(shared_preferences +
/// バージョン付きJSONキー、読み込み失敗時は空デフォルトにフォールバック)を踏襲している。
class ProgressRepository {
  static const _progressKey = 'progress_v1';
  static const _streakKey = 'streak_v1';
  static const _unlocksKey = 'unlocks_v1';
  static const _notificationsKey = 'notifications_enabled_v1';
  static const _notificationAskedKey = 'notification_asked_v1';
  static const _onboardingSeenKey = 'onboarding_seen_v1';

  /// アクセサリーの実績ID。`CatAccessory` enum(cat_mascot.dart)の名前と対応させる。
  static const accessoryRibbon = 'ribbon';
  static const accessoryCrown = 'crown';
  static const accessorySunglasses = 'sunglasses';
  static const accessoryScarf = 'scarf';

  Future<Set<String>> loadWeakQuestionIds() async {
    final data = await _loadProgress();
    return (data['weak'] as List).cast<String>().toSet();
  }

  /// ブックマークした問題ID一覧。苦手問題(自動記録)とは別に、
  /// ユーザーが自分の意思で「あとで見返したい」と選んだ問題。
  Future<Set<String>> loadBookmarkedQuestionIds() async {
    final data = await _loadProgress();
    return (data['bookmarks'] as List).cast<String>().toSet();
  }

  Future<void> toggleBookmark(String questionId) async {
    final data = await _loadProgress();
    final bookmarks = (data['bookmarks'] as List).cast<String>().toSet();
    if (!bookmarks.remove(questionId)) {
      bookmarks.add(questionId);
    }
    data['bookmarks'] = bookmarks.toList();
    await _saveProgress(data);
  }

  Future<Map<String, UnitStats>> loadUnitStats() async {
    final data = await _loadProgress();
    final raw = (data['unitStats'] as Map).cast<String, dynamic>();
    return raw.map(
      (unit, json) =>
          MapEntry(unit, UnitStats.fromJson((json as Map).cast())),
    );
  }

  Future<int> loadTotalAnswered() async {
    final data = await _loadProgress();
    return (data['totalAnswered'] as num?)?.toInt() ?? 0;
  }

  Future<int> loadTotalCorrect() async {
    final data = await _loadProgress();
    return (data['totalCorrect'] as num?)?.toInt() ?? 0;
  }

  /// 1問の回答結果を記録する。苦手問題集合・単元別統計・累計数をまとめて更新する。
  Future<void> recordAnswer({
    required String questionId,
    required String unit,
    required bool correct,
  }) async {
    final data = await _loadProgress();

    final weak = (data['weak'] as List).cast<String>().toSet();
    if (correct) {
      weak.remove(questionId);
    } else {
      weak.add(questionId);
    }
    data['weak'] = weak.toList();

    final unitStatsRaw = (data['unitStats'] as Map).cast<String, dynamic>();
    final current = unitStatsRaw[unit] == null
        ? const UnitStats()
        : UnitStats.fromJson((unitStatsRaw[unit] as Map).cast());
    final updated = current.copyWith(
      answered: current.answered + 1,
      correct: current.correct + (correct ? 1 : 0),
    );
    unitStatsRaw[unit] = updated.toJson();
    data['unitStats'] = unitStatsRaw;

    data['totalAnswered'] = ((data['totalAnswered'] as num?)?.toInt() ?? 0) + 1;
    if (correct) {
      data['totalCorrect'] =
          ((data['totalCorrect'] as num?)?.toInt() ?? 0) + 1;
    }

    await _saveProgress(data);
  }

  Future<Map<String, dynamic>> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_progressKey);
      if (raw == null) return _emptyProgress();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {..._emptyProgress(), ...decoded};
    } catch (_) {
      return _emptyProgress();
    }
  }

  Future<void> _saveProgress(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_progressKey, jsonEncode(data));
    } catch (_) {
      // 保存に失敗しても学習は続けられるようにする。
    }
  }

  Map<String, dynamic> _emptyProgress() => {
    'weak': <String>[],
    'bookmarks': <String>[],
    'unitStats': <String, dynamic>{},
    'totalAnswered': 0,
    'totalCorrect': 0,
  };

  Future<StreakData> loadStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_streakKey);
      if (raw == null) return const StreakData();
      return StreakData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const StreakData();
    }
  }

  /// 今日学習したことを記録し、ストリークを更新する。1日1回だけ呼んでも安全
  /// (同じ日に複数回呼んでも連続日数は二重に増えない)。
  Future<StreakData> markStudiedToday({DateTime? now}) async {
    final today = _dateKey(now ?? DateTime.now());
    final streak = await loadStreak();

    if (streak.lastStudyDate == today) return streak;

    final yesterday = _dateKey(
      (now ?? DateTime.now()).subtract(const Duration(days: 1)),
    );
    final continuing = streak.lastStudyDate == yesterday;
    final newCurrent = continuing ? streak.current + 1 : 1;
    final updated = StreakData(
      current: newCurrent,
      best: newCurrent > streak.best ? newCurrent : streak.best,
      lastStudyDate: today,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_streakKey, jsonEncode(updated.toJson()));
    } catch (_) {
      // 保存できなくても今回のセッションでは更新後の値を返す。
    }
    return updated;
  }

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<Set<String>> loadUnlockedAccessories() async {
    final data = await _loadUnlocks();
    return (data['unlocked'] as List).cast<String>().toSet();
  }

  Future<String?> loadSelectedAccessory() async {
    final data = await _loadUnlocks();
    return data['selected'] as String?;
  }

  Future<void> selectAccessory(String? accessoryId) async {
    final data = await _loadUnlocks();
    data['selected'] = accessoryId;
    await _saveUnlocks(data);
  }

  Future<bool> unlockAccessory(String accessoryId) async {
    final data = await _loadUnlocks();
    final unlocked = (data['unlocked'] as List).cast<String>().toSet();
    final isNew = unlocked.add(accessoryId);
    if (isNew) {
      data['unlocked'] = unlocked.toList();
      await _saveUnlocks(data);
    }
    return isNew;
  }

  /// ストリークと累計正解数から、新たに解放条件を満たしたアクセサリーを
  /// 解放して返す。既に解放済みのものは含まれない。
  Future<List<String>> checkMilestones({
    required StreakData streak,
    required int totalCorrect,
  }) async {
    final conditions = {
      accessoryRibbon: streak.current >= 3,
      accessoryCrown: streak.current >= 7,
      accessorySunglasses: totalCorrect >= 50,
      accessoryScarf: totalCorrect >= 100,
    };
    final newlyUnlocked = <String>[];
    for (final entry in conditions.entries) {
      if (entry.value && await unlockAccessory(entry.key)) {
        newlyUnlocked.add(entry.key);
      }
    }
    return newlyUnlocked;
  }

  Future<Map<String, dynamic>> _loadUnlocks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_unlocksKey);
      if (raw == null) return {'unlocked': <String>[], 'selected': null};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {'unlocked': <String>[], 'selected': null, ...decoded};
    } catch (_) {
      return {'unlocked': <String>[], 'selected': null};
    }
  }

  Future<void> _saveUnlocks(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_unlocksKey, jsonEncode(data));
    } catch (_) {
      // 保存できなくても致命的ではないため無視する。
    }
  }

  Future<bool> loadNotificationsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_notificationsKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationsKey, enabled);
    } catch (_) {
      // 保存できなくても致命的ではないため無視する。
    }
  }

  /// 通知の許可を一度でも求めたことがあるか。初回クイズ完了後にだけ
  /// 許可ダイアログを出すためのフラグ。
  Future<bool> hasAskedNotificationPermission() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_notificationAskedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> markAskedNotificationPermission() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationAskedKey, true);
    } catch (_) {
      // 保存できなくても致命的ではないため無視する。
    }
  }

  /// 初回起動時の使い方説明(オンボーディング)を見せたかどうか。
  Future<bool> hasSeenOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_onboardingSeenKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> markOnboardingSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingSeenKey, true);
    } catch (_) {
      // 保存できなくても致命的ではないため無視する。
    }
  }

  /// 苦手問題・ブックマーク・単元別統計・ストリーク・解放済みアクセサリーを
  /// すべて消す。通知の許可を求めたかどうか・オンボーディング既読フラグは、
  /// OS側の許可状態や初見扱いと無関係に再度出すと煩わしいため、あえて残す。
  Future<void> resetAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_progressKey);
      await prefs.remove(_streakKey);
      await prefs.remove(_unlocksKey);
      await prefs.remove(_notificationsKey);
    } catch (_) {
      // 失敗しても学習は続けられる。
    }
  }
}
