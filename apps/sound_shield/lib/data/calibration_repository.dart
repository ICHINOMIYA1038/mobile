import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sound_meter_service.dart';

/// 騒音レベル表示の校正(基準の騒音計との差)。
///
/// 値は「アプリの表示に足す dB」。端末に保存し、起動時と変更時にネイティブ側
/// (LevelCalibration.userAdjustmentDb) へ反映する。既定0(=内蔵の目安値のまま)。
class CalibrationRepository extends ChangeNotifier {
  CalibrationRepository({required this.soundMeter});

  static const _key = 'calibration_adjustment_db_v1';
  static const minDb = -20.0;
  static const maxDb = 20.0;

  final SoundMeterService soundMeter;

  double _adjustmentDb = 0;

  double get adjustmentDb => _adjustmentDb;
  bool get isCalibrated => _adjustmentDb != 0;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _adjustmentDb = prefs.getDouble(_key) ?? 0;
    await soundMeter.setCalibration(_adjustmentDb);
    notifyListeners();
  }

  Future<void> setAdjustment(double db) async {
    _adjustmentDb = db.clamp(minDb, maxDb);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, _adjustmentDb);
    await soundMeter.setCalibration(_adjustmentDb);
    notifyListeners();
  }

  Future<void> reset() => setAdjustment(0);
}
