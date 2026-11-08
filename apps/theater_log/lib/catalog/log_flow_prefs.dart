import 'package:shared_preferences/shared_preferences.dart';

/// 記録の手順で「次回から出さない」にした画面。選べるのは写真だけ
/// （題名・いつどこで・評価は、スタンプや一覧に使うので毎回聞く）
class LogFlowPrefs {
  static const _hidePhotos = 'log_flow_hide_photos';

  static Future<bool> showsPhotos() async {
    try {
      return !((await SharedPreferences.getInstance()).getBool(_hidePhotos) ?? false);
    } catch (_) {
      return true;
    }
  }

  static Future<void> showPhotos(bool show) async => (await SharedPreferences.getInstance()).setBool(_hidePhotos, !show);
}
