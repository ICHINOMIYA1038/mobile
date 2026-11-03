import 'package:app_insights/app_insights.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 広告で来た人がどこまで進んだかを見るためのイベント。計測の失敗で学習を止めない。
class Funnel {
  Funnel._();

  static const _prefFirstChat = 'funnel_first_chat_sent';

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
}
