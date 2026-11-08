import 'package:shared_preferences/shared_preferences.dart';

/// 記録の手順で「次回から出さない」にした画面。選べるのはチケットと写真だけ
/// （劇場と評価は、スタンプや一覧に使うので毎回聞く）
class LogFlowPrefs {
  static const _hideTicket = 'log_flow_hide_ticket';
  static const _hidePhotos = 'log_flow_hide_photos';

  static Future<({bool ticket, bool photos})> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      return (ticket: !(p.getBool(_hideTicket) ?? false), photos: !(p.getBool(_hidePhotos) ?? false));
    } catch (_) {
      return (ticket: true, photos: true);
    }
  }

  static Future<void> showTicket(bool show) async => (await SharedPreferences.getInstance()).setBool(_hideTicket, !show);
  static Future<void> showPhotos(bool show) async => (await SharedPreferences.getInstance()).setBool(_hidePhotos, !show);
}
