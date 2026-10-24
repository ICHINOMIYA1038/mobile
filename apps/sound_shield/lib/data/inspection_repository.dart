import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/level_scale.dart';
import 'calibration_repository.dart';
import '../models/countermeasure_record.dart';
import '../models/inspection.dart';

/// 内見診断と Before/After 記録の永続化。件数が少ない前提で
/// SharedPreferences に JSON をまるごと保存する。
///
/// キーの末尾は騒音レベルの物差しの版を兼ねる。`_v1` は 1.1.1 までの物差し(結果の dB が
/// 約83dB大きく、当時の校正値も足されている)で、読み込むときに1回だけ
/// [LevelScale.legacyFftOffsetDb] と当時の校正値を取り除いて `_v2` に書き直し、`_v1` を消す。
/// `_v2` があれば換算しないので、2回換算することはない。`_v1` が壊れていて読めないときは
/// `_v2` を書かず `_v1` も消さない(端末に残す)。
class InspectionRepository extends ChangeNotifier {
  static const inspectionsKey = 'inspections_v2';
  static const recordsKey = 'countermeasure_records_v2';
  static const legacyInspectionsKey = 'inspections_v1';
  static const legacyRecordsKey = 'countermeasure_records_v1';

  List<Inspection> _inspections = [];
  List<CountermeasureRecord> _records = [];
  bool _loaded = false;

  List<Inspection> get inspections => List.unmodifiable(_inspections);
  List<CountermeasureRecord> get records => List.unmodifiable(_records);
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    // 1.1.1 の記録には当時の校正値が足されている。校正のリセット(CalibrationRepository)が
    // 先に済んでいても、`_v1` は両方の換算が終わるまで残るので読める。
    final shift = legacyShiftDb(CalibrationRepository.legacyAdjustmentDb(prefs));
    _inspections = await _loadMigrating(
      prefs,
      key: inspectionsKey,
      legacyKey: legacyInspectionsKey,
      fromJson: Inspection.fromJson,
      toJson: (i) => i.toJson(),
      convert: (i) => convertLegacyInspection(i, shiftDb: shift),
    );
    _records = await _loadMigrating(
      prefs,
      key: recordsKey,
      legacyKey: legacyRecordsKey,
      fromJson: CountermeasureRecord.fromJson,
      toJson: (r) => r.toJson(),
      convert: (r) => convertLegacyRecord(r, shiftDb: shift),
    );
    await CalibrationRepository.removeLegacyIfMigrated(prefs);
    _loaded = true;
    notifyListeners();
  }

  /// 1.1.1 までの記録を新しい物差し(校正 ±0)にそろえるときに足す量。
  /// FFT の倍率の分([LevelScale.legacyFftOffsetDb])と、当時の校正値を取り除く。
  /// 当時の校正値が −20dB なら −83.04 − (−20) = −63.04dB。校正していなければ −83.04dB。
  static double legacyShiftDb(double legacyCalibrationDb) =>
      -LevelScale.legacyFftOffsetDb - legacyCalibrationDb;

  static Future<List<T>> _loadMigrating<T>(
    SharedPreferences prefs, {
    required String key,
    required String legacyKey,
    required T Function(Map<String, Object?>) fromJson,
    required Map<String, Object?> Function(T) toJson,
    required T Function(T) convert,
  }) async {
    if (prefs.containsKey(key)) {
      // 前回の換算で `_v2` を書いた後、`_v1` を消す前に止まっていた場合の後始末。
      // 読めない `_v1`(換算しなかったもの)は消さずに残す。
      final legacy = prefs.getString(legacyKey);
      if (legacy != null && _tryDecode(legacy, fromJson) != null) {
        await prefs.remove(legacyKey);
      }
      return _decode(prefs.getString(key), fromJson);
    }
    final legacy = prefs.getString(legacyKey);
    if (legacy == null) return [];
    final decoded = _tryDecode(legacy, fromJson);
    // 壊れていて読めなければ `_v2` を書かず `_v1` も消さない(以前と同じく端末に残す)。
    if (decoded == null) return [];
    final converted = decoded.map(convert).toList();
    // 新しいキーを書いてから古いキーを消す(途中で止まっても2回換算しない)。
    await prefs.setString(key, jsonEncode(converted.map(toJson).toList()));
    await prefs.remove(legacyKey);
    return converted;
  }

  /// 1.1.1 までの内見診断を新しい物差しに換算する。中央・窓際・隣室側の計測
  /// (AudioSpectrumAnalyzer の結果)だけ [shiftDb] ずらす。ノック・手叩き(ImpulseAnalyzer)は
  /// 以前から RMS 経路で物差しが正しいので変えない。
  static Inspection convertLegacyInspection(Inspection i, {required double shiftDb}) {
    return Inspection(
      id: i.id,
      name: i.name,
      createdAt: i.createdAt,
      memo: i.memo,
      ambient: i.ambient?.shiftLevels(shiftDb),
      window: i.window?.shiftLevels(shiftDb),
      knock: i.knock,
      clap: i.clap,
      neighbor: i.neighbor?.shiftLevels(shiftDb),
    );
  }

  /// 1.1.1 までの対策の記録(Before/After)を新しい物差しに換算する。予測ΔdB は差なので変えない。
  static CountermeasureRecord convertLegacyRecord(
    CountermeasureRecord r, {
    required double shiftDb,
  }) {
    return CountermeasureRecord(
      id: r.id,
      measureId: r.measureId,
      measureName: r.measureName,
      createdAt: r.createdAt,
      before: r.before.shiftLevels(shiftDb),
      after: r.after?.shiftLevels(shiftDb),
      predictedDeltaDb: r.predictedDeltaDb,
      place: r.place,
    );
  }

  static List<T> _decode<T>(
    String? raw,
    T Function(Map<String, Object?>) fromJson,
  ) {
    if (raw == null || raw.isEmpty) return [];
    // 壊れた保存データは読まない(計測はやり直せる)。
    return _tryDecode(raw, fromJson) ?? [];
  }

  /// 読めなければ null。
  static List<T>? _tryDecode<T>(
    String raw,
    T Function(Map<String, Object?>) fromJson,
  ) {
    if (raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => fromJson(Map<String, Object?>.from(e as Map)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  Future<void> saveInspection(Inspection inspection) async {
    final index = _inspections.indexWhere((i) => i.id == inspection.id);
    if (index >= 0) {
      _inspections[index] = inspection;
    } else {
      _inspections.insert(0, inspection);
    }
    await _persistInspections();
  }

  Future<void> deleteInspection(String id) async {
    _inspections.removeWhere((i) => i.id == id);
    await _persistInspections();
  }

  Future<void> saveRecord(CountermeasureRecord record) async {
    final index = _records.indexWhere((r) => r.id == record.id);
    if (index >= 0) {
      _records[index] = record;
    } else {
      _records.insert(0, record);
    }
    await _persistRecords();
  }

  Future<void> deleteRecord(String id) async {
    _records.removeWhere((r) => r.id == id);
    await _persistRecords();
  }

  Future<void> _persistInspections() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      inspectionsKey,
      jsonEncode(_inspections.map((i) => i.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> _persistRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      recordsKey,
      jsonEncode(_records.map((r) => r.toJson()).toList()),
    );
    notifyListeners();
  }
}
