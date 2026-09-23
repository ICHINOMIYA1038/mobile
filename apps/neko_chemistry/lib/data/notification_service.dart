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

  /// 毎日繰り返す通知のID(1件だけ予約する)。
  static const _dailyId = 0;

  static const _channelId = 'review_reminder';

  bool _initialized = false;

  bool get _isSupported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  Future<void> _ensureInitialized() async {
    if (_initialized || !_isSupported) return;
    _initialized = true;

    tz.initializeTimeZones();
    // tz.local は既定でUTC。毎日同じ壁時計の時刻に鳴らすため、端末の現在オフセットを
    // 持つ固定ロケーションを local にする(追加パッケージ無し。夏時間のある地域では
    // 切替日に1時間ずれるが、起動のたびに予約し直すので実害はない)。
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

  /// 次に鳴らすべき日時。今日の指定時刻を過ぎていれば明日。
  @visibleForTesting
  static DateTime nextOccurrence(DateTime now, int hour, int minute) {
    final today = DateTime(now.year, now.month, now.day, hour, minute);
    return today.isAfter(now) ? today : today.add(const Duration(days: 1));
  }

  /// 毎日決まった時刻に復習リマインダーを予約し直す。時刻を省略すると19:00。
  ///
  /// 以前は7日ぶんを個別に予約していて、設定画面を開き直さない限り8日目から
  /// 鳴らなくなっていた。今は毎日繰り返す1件だけを予約する。
  Future<void> scheduleDailyReminder({
    DateTime? now,
    int hour = 19,
    int minute = 0,
  }) async {
    if (!_isSupported) return;
    await _ensureInitialized();

    try {
      await _plugin.cancelAll();
      await _scheduleDailyAt(nextOccurrence(now ?? DateTime.now(), hour, minute));
    } catch (_) {
      // 通知の予約に失敗しても学習は続けられる。黙って諦める。
    }
  }

  Future<void> _scheduleDailyAt(DateTime when) async {
    await _plugin.zonedSchedule(
      _dailyId,
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
