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

  /// 毎日繰り返す通知のID(1件だけ予約する)。
  static const _dailyId = 1;

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
    // tz.local は既定でUTC。毎日同じ「壁時計の時刻」に鳴らすには端末のローカル時刻で
    // 予約する必要があるので、端末の現在オフセットを持つ固定ロケーションを local にする
    // (追加パッケージ無しで済ませる。夏時間のある地域では切替日に1時間ずれるが、
    // 起動のたびに予約し直すので実害はない)。
    final offset = DateTime.now().timeZoneOffset;
    tz.setLocalLocation(
      tz.Location(
        'device',
        [tz.minTime],
        [0],
        [tz.TimeZone(offset.inMilliseconds, isDst: false, abbreviation: 'LOCAL')],
      ),
    );

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

  /// 端末側で通知が許可されているか。判定できない環境では null。
  Future<bool?> areNotificationsAllowed() async {
    if (!_isSupported) return null;
    await _ensureInitialized();
    try {
      if (Platform.isIOS) {
        final options = await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.checkPermissions();
        return options?.isEnabled;
      }
      return await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
    } catch (_) {
      return null;
    }
  }

  /// 設定がONなら予約し直す。起動時に呼ぶ。
  Future<void> rescheduleIfEnabled() async {
    if (!_isSupported) return;
    try {
      if (!await loadEnabled()) return;
      await scheduleDailyReminder(
        minutesSinceMidnight: await loadMinutesSinceMidnight(),
      );
    } catch (_) {
      // 起動を止めない。
    }
  }

  /// 次に鳴らすべき日時。今日の指定時刻を過ぎていれば明日。
  @visibleForTesting
  static DateTime nextOccurrence(DateTime now, int minutesSinceMidnight) {
    final today = DateTime(
      now.year,
      now.month,
      now.day,
      minutesSinceMidnight ~/ 60,
      minutesSinceMidnight % 60,
    );
    return today.isAfter(now) ? today : today.add(const Duration(days: 1));
  }

  /// 毎日決まった時刻に配信前リマインダーを予約し直す。
  ///
  /// 以前は7日ぶんを個別に予約していて、設定画面を開き直さない限り8日目から
  /// 鳴らなくなっていた。今は毎日繰り返す1件だけを予約する。
  Future<void> scheduleDailyReminder({
    DateTime? now,
    required int minutesSinceMidnight,
  }) async {
    if (!_isSupported) return;
    await _ensureInitialized();

    try {
      await _plugin.cancelAll();
      final when = nextOccurrence(now ?? DateTime.now(), minutesSinceMidnight);
      await _scheduleDailyAt(when);
    } catch (_) {
      // 通知の予約に失敗してもアプリは通常どおり使える。黙って諦める。
    }
  }

  Future<void> _scheduleDailyAt(DateTime when) async {
    await _plugin.zonedSchedule(
      _dailyId,
      '配信の準備はできてる?🎙️',
      '今日のネタ、ネタガチャで引いてみませんか?',
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
      // 同じ時刻に毎日繰り返す。
      matchDateTimeComponents: DateTimeComponents.time,
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
