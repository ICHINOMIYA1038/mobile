import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// 配信前リマインダー通知。neko_chemistryのNotificationServiceと同じ方針
/// (端末内で完結するローカル通知、サーバープッシュは使わない)を踏襲。
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _enabledKey = 'reminder_enabled_v1';
  static const _minutesKey = 'reminder_minutes_v1';
  static const _defaultMinutes = 19 * 60; // 19:00

  /// 何日先まで予約するか(端末側で定期実行できないため、まとめて予約する)。
  static const _daysAhead = 7;

  static const _channelId = 'stream_reminder';

  bool _initialized = false;

  bool get _isSupported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  Future<bool> loadEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  Future<int> loadMinutesSinceMidnight() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_minutesKey) ?? _defaultMinutes;
  }

  Future<void> setMinutesSinceMidnight(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_minutesKey, minutes);
  }

  Future<void> _ensureInitialized() async {
    if (_initialized || !_isSupported) return;
    _initialized = true;

    tz.initializeTimeZones();

    await _plugin.initialize(
      const InitializationSettings(
        // 許可の要求は初期化時ではなく、リマインダーをONにした瞬間に行う。
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  /// 通知の許可を求める。拒否されてもアプリの利用には何の影響もない。
  Future<bool> requestPermission() async {
    if (!_isSupported) return false;
    await _ensureInitialized();

    try {
      if (Platform.isIOS) {
        final granted = await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        return granted ?? false;
      }
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 毎日決まった時刻に配信前リマインダーを予約し直す。
  Future<void> scheduleDailyReminder({
    DateTime? now,
    required int minutesSinceMidnight,
  }) async {
    if (!_isSupported) return;
    await _ensureInitialized();

    try {
      await _plugin.cancelAll();

      final base = now ?? DateTime.now();
      final hour = minutesSinceMidnight ~/ 60;
      final minute = minutesSinceMidnight % 60;
      for (var offset = 0; offset < _daysAhead; offset++) {
        final day = DateTime(
          base.year,
          base.month,
          base.day + offset,
          hour,
          minute,
        );
        if (!day.isAfter(base)) continue;
        await _scheduleAt(id: offset, when: day);
      }
    } catch (_) {
      // 通知の予約に失敗してもアプリは通常どおり使える。黙って諦める。
    }
  }

  Future<void> _scheduleAt({required int id, required DateTime when}) async {
    await _plugin.zonedSchedule(
      id,
      '配信の準備はできてる?🎙️',
      '今日のネタ、配信ネタガチャで引いてみませんか?',
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(
        iOS: DarwinNotificationDetails(),
        android: AndroidNotificationDetails(
          _channelId,
          '配信前のお知らせ',
          channelDescription: '毎日決まった時刻に配信前リマインダーをお知らせします',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.wallClockTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// 予約済みの通知をすべて取り消す。
  Future<void> cancelAll() async {
    if (!_isSupported) return;
    await _ensureInitialized();
    try {
      await _plugin.cancelAll();
    } catch (_) {
      // 取り消せなくても実害はない。
    }
  }
}
