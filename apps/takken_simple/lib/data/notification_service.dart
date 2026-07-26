import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/question.dart';
import '../models/review_state.dart';

/// 復習のお知らせ。
///
/// このアプリの中核は「忘れかけた頃に出す」間隔反復だが、アプリを開かない限り
/// その「頃」が来たことをユーザーは知りようがない。通知が無いと間隔反復は理屈倒れになる。
///
/// 方針は本体と同じで、**設定を持たせない**。時間帯の選択もオン/オフの切り替えも出さない。
/// 復習が溜まった日にだけ、1日1回だけ知らせる。
///
/// すべて端末内で完結する（ローカル通知）。サーバーからのプッシュは使わないので、
/// デバイストークンの送信も外部との通信も発生しない。
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// 通知する時刻。働きながら学ぶ人が多い試験なので夜に寄せている。
  /// ここをユーザーに選ばせない代わりに、常識的な時間を1つ選ぶ。
  static const _hour = 20;

  /// 何日先まで予約するか。
  /// 端末側で定期実行はできないため、先の日付ぶんをまとめて予約しておく必要がある。
  /// 学習のたびに組み直すので、1週間先まであれば十分。
  static const _daysAhead = 7;

  static const _channelId = 'review_reminder';

  bool _initialized = false;

  /// 通知が使えるプラットフォームか。テストや Web では何もしない。
  bool get _isSupported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  Future<void> _ensureInitialized() async {
    if (_initialized || !_isSupported) return;
    _initialized = true;

    // 予約は端末のタイムゾーンで解釈する必要がある。
    tz.initializeTimeZones();

    await _plugin.initialize(
      const InitializationSettings(
        // 許可の要求は初期化時ではなく、初回の学習を終えた後に行う（requestPermission）。
        // 起動直後に出しても、何のための通知か分からないユーザーは拒否するため。
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
  ///
  /// 呼ぶのは初回の学習を終えた直後だけ。そのタイミングなら
  /// 「この問題をいつ復習すべきか知らせます」の意味が伝わる。
  Future<bool> requestPermission() async {
    if (!_isSupported) return false;
    await _ensureInitialized();

    try {
      if (Platform.isIOS) {
        final granted = await _plugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        return granted ?? false;
      }
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return granted ?? false;
    } catch (_) {
      // 通知が出せないだけで、アプリは通常どおり使える。
      return false;
    }
  }

  /// 今後の復習予定を通知として仕込み直す。
  ///
  /// 復習が0件の日には何も出さない。用がないのに鳴らすアプリにはしない。
  Future<void> scheduleReviewReminders({
    required List<Question> questions,
    required Map<String, ReviewState> states,
    DateTime? now,
  }) async {
    if (!_isSupported) return;
    await _ensureInitialized();

    try {
      // 学習するたびに予定は変わるので、必ず全部消してから組み直す。
      await _plugin.cancelAll();

      final base = now ?? DateTime.now();
      for (var offset = 0; offset < _daysAhead; offset++) {
        final day = DateTime(base.year, base.month, base.day + offset, _hour);
        // 今日ぶんは、すでに時刻を過ぎていれば飛ばす。
        if (!day.isAfter(base)) continue;

        final due = dueCountAt(questions: questions, states: states, at: day);
        if (due == 0) continue;

        await _scheduleAt(id: offset, when: day, dueCount: due);
      }
    } catch (_) {
      // 通知の予約に失敗しても学習は続けられる。黙って諦める。
    }
  }

  /// その時点で復習期限が来ている問題数。0なら通知を出さない。
  ///
  /// 未学習は数えない。この通知は「忘れかけた頃に復習する」ことを知らせるためのもので、
  /// 手つかずの問題が残っていることを知らせるためではない。
  /// 未学習を数えると、初日から毎晩「300問あります」と鳴り続けることになる。
  @visibleForTesting
  int dueCountAt({
    required List<Question> questions,
    required Map<String, ReviewState> states,
    required DateTime at,
  }) {
    var count = 0;
    for (final q in questions) {
      final state = states[q.id];
      if (state == null || state.isNew) continue;
      if (state.isDue(at)) count++;
    }
    return count;
  }

  Future<void> _scheduleAt({
    required int id,
    required DateTime when,
    required int dueCount,
  }) async {
    await _plugin.zonedSchedule(
      id,
      '復習が$dueCount問たまっています',
      '忘れかけている頃です。今やると定着します。',
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(
        iOS: DarwinNotificationDetails(),
        android: AndroidNotificationDetails(
          _channelId,
          '復習のお知らせ',
          channelDescription: '復習すべき問題がたまった日にお知らせします',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      // 端末のローカル時刻の20時に出す。旅行や時差で絶対時刻がずれても、
      // 生活時間の夜に届いてほしいため。
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.wallClockTime,
      // 正確な時刻を要求すると Android で SCHEDULE_EXACT_ALARM の許可が要る。
      // 復習の知らせに分単位の正確さは不要なので、許可の要らない方を選ぶ。
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// 予約済みの通知を全て取り消す。学習履歴を消したときに使う。
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
