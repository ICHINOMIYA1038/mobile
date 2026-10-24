import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'inspection_repository.dart';
import 'sound_meter_service.dart';

/// 騒音レベル表示の校正(基準の騒音計との差)。
///
/// 値は「アプリの表示に足す dB」。端末に保存し、起動時と変更時にネイティブ側
/// (LevelCalibration.userAdjustmentDb) へ反映する。既定0(=内蔵の目安値のまま)。
class CalibrationRepository extends ChangeNotifier {
  CalibrationRepository({required this.soundMeter});

  /// 1.1.2 の物差し(FFT のパワーを正しく割った後)で作った校正値。
  static const key = 'calibration_adjustment_db_v2';

  /// 1.1.1 までの校正値。結果の dB が約83dB大きい物差しで「基準 − Leq」を取っていたので、
  /// 新しい物差しでは意味が無い(多くは −20dB で止まっている)。読み込むときに1回だけ捨てて既定0に戻す。
  ///
  /// 保存済みの記録の換算([InspectionRepository])が当時の校正を取り除くためにこの値を読むので、
  /// 校正を戻した後もすぐには消さない。記録の換算も終わってから [removeLegacyIfMigrated] で消す。
  static const legacyKey = 'calibration_adjustment_db_v1';

  /// 1.1.1 までの校正値(無ければ0)。リセットの前後どちらでも、`_v1` が残っている間は読める。
  static double legacyAdjustmentDb(SharedPreferences prefs) {
    final v = prefs.get(legacyKey);
    return v is num ? v.toDouble() : 0;
  }

  /// 校正のリセットと記録の換算が両方終わっていれば、1.1.1 の校正値を消す。
  /// どちらの読み込みが先でも、後から終わった方で消える。
  static Future<void> removeLegacyIfMigrated(SharedPreferences prefs) async {
    if (!prefs.containsKey(legacyKey)) return;
    if (!prefs.containsKey(key)) return;
    if (prefs.containsKey(InspectionRepository.legacyInspectionsKey) ||
        prefs.containsKey(InspectionRepository.legacyRecordsKey)) {
      return;
    }
    await prefs.remove(legacyKey);
  }

  /// 古い校正値を戻したことを、校正画面で一度だけ知らせるための印。
  static const resetNoticeKey = 'calibration_reset_notice_pending';

  static const minDb = -20.0;
  static const maxDb = 20.0;

  final SoundMeterService soundMeter;

  double _adjustmentDb = 0;
  bool _resetNoticePending = false;

  double get adjustmentDb => _adjustmentDb;
  bool get isCalibrated => _adjustmentDb != 0;

  /// 1.1.2 に上がったときに古い校正値(0 以外)を戻した。校正画面で一度だけ案内する。
  bool get resetNoticePending => _resetNoticePending;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(key) && prefs.containsKey(legacyKey)) {
      final legacy = legacyAdjustmentDb(prefs);
      // 印 → 新しい値の順に書く。途中で止まっても、新しいキーがあれば2回目は戻さない。
      // 古いキーは記録の換算が読むので、ここでは消さない。
      if (legacy != 0) await prefs.setBool(resetNoticeKey, true);
      await prefs.setDouble(key, 0);
    }
    await removeLegacyIfMigrated(prefs);
    _adjustmentDb = prefs.getDouble(key) ?? 0;
    _resetNoticePending = prefs.getBool(resetNoticeKey) ?? false;
    await soundMeter.setCalibration(_adjustmentDb);
    notifyListeners();
  }

  /// 校正を戻した案内を出し終えた(次からは出さない)。
  Future<void> dismissResetNotice() async {
    if (!_resetNoticePending) return;
    _resetNoticePending = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(resetNoticeKey);
  }

  Future<void> setAdjustment(double db) async {
    _adjustmentDb = db.clamp(minDb, maxDb);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, _adjustmentDb);
    await soundMeter.setCalibration(_adjustmentDb);
    notifyListeners();
  }

  Future<void> reset() => setAdjustment(0);
}
