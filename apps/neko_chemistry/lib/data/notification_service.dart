import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// 復習リマインダー通知。takken_simpleのNotificationServiceと同じ方針
/// (端末内で完結するローカル通知、サーバープッシュは使わない)を踏襲しつつ、
/// neko_chemistryではSM-2式の間隔反復を持たないため「復習が溜まった日だけ」
/// という判定は行わず、有効化されていれば毎日決まった時刻に1件だけ知らせる
/// というシンプルな仕組みにしている。
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// 何日先まで予約するか(端末側で定期実行できないため、まとめて予約する)。
  static const _daysAhead = 7;

  static const _channelId = 'review_reminder';

  bool _initialized = false;

  bool get _isSupported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  Future<void> _ensureInitialized() async {
    if (_initialized || !_isSupported) return;
    _initialized = true;

    tz.initializeTimeZones();

    await _plugin.initialize(
      const InitializationSettings(
        // 許可の要求は初期化時ではなく、初回のクイズを終えた後に行う。
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  /// 通知の許可を求める。拒否されても学習には何の影響もない。
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

  /// 毎日決まった時刻に復習リマインダーを予約し直す。時刻を省略すると19:00。
  Future<void> scheduleDailyReminder({
    DateTime? now,
    int hour = 19,
    int minute = 0,
  }) async {
    if (!_isSupported) return;
    await _ensureInitialized();

    try {
      await _plugin.cancelAll();

      final base = now ?? DateTime.now();
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
      // 通知の予約に失敗しても学習は続けられる。黙って諦める。
    }
  }

  Future<void> _scheduleAt({required int id, required DateTime when}) async {
    await _plugin.zonedSchedule(
      id,
      '猫が待っています🐱',
      '今日も少しだけ化学を復習してみませんか?',
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(
        iOS: DarwinNotificationDetails(),
        android: AndroidNotificationDetails(
          _channelId,
          '復習のお知らせ',
          channelDescription: '毎日決まった時刻に復習をお知らせします',
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
