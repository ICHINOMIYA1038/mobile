import 'dart:async';

import 'package:app_insights/app_insights.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 初回学習・再訪・購入の計測。計測の失敗で学習と購入を止めない。
class Funnel {
  Funnel._();

  static const _prefFirstChat = 'funnel_first_chat_sent';
  static final _pending = <String, Future<void>>{};

  @visibleForTesting
  static Future<void> Function(String name, {Map<String, Object>? parameters}) log = AppInsights.logEvent;

  /// AI との最初の1往復が終わった（端末ごとに1回）。会話を開いたときの先生の第一声は数えない
  static Future<void> chatCompleted(String surface) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefFirstChat) == true) return;
      await prefs.setBool(_prefFirstChat, true);
      await log('first_chat_sent', parameters: {'surface': surface});
    } catch (_) {}
  }

  /// 回数の上限で止まった。code は user_cap / global_cap など
  static void capReached(String surface, String code) {
    log('cap_reached', parameters: {'surface': surface, 'code': code}).catchError((_) {});
  }

  static void event(String name, {Map<String, Object>? parameters}) {
    try {
      unawaited(log(name, parameters: parameters).catchError((_) {}));
    } catch (_) {}
  }

  static Future<void> _once(String userId, String key, String name, {Map<String, Object>? parameters}) {
    final pref = 'study_funnel_${userId}_$key';
    return _pending.putIfAbsent(pref, () => _recordOnce(pref, name, parameters)).whenComplete(() => _pending.remove(pref));
  }

  static Future<void> _recordOnce(String pref, String name, Map<String, Object>? parameters) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(pref) == true) return;
      await prefs.setBool(pref, true);
      await log(name, parameters: parameters);
    } catch (_) {}
  }

  static Future<void> studyStarted(String userId, String kind, String day) async {
    event('study_session_started', parameters: {'kind': kind, 'version': 1});
    if (kind != 'starter') return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'study_funnel_${userId}_first_day';
      if (prefs.containsKey(key)) return;
      await prefs.setString(key, day);
      await log('study_first_started', parameters: {'version': 1});
    } catch (_) {}
  }

  static Future<void> studyCompleted(String userId, String kind, String day, int correct, int total) async {
    await _once(userId, 'completed_$day', 'study_session_completed', parameters: {'kind': kind, 'correct': correct, 'total': total, 'version': 1});
    if (kind == 'starter') await _once(userId, 'first_completed', 'study_first_completed', parameters: {'version': 1});
  }

  static Future<void> visit(String userId, String day) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final first = prefs.getString('study_funnel_${userId}_first_day');
      if (first == null) return;
      final difference = DateTime.parse(day).difference(DateTime.parse(first)).inDays;
      if (difference == 1) await _once(userId, 'return_d1', 'study_return_d1', parameters: {'version': 1});
      if (difference == 7) await _once(userId, 'return_d7', 'study_return_d7', parameters: {'version': 1});
    } catch (_) {}
  }

  static Future<void> clearUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith('study_funnel_${userId}_'))) {
      await prefs.remove(key);
    }
  }
}
