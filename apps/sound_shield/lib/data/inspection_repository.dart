import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/countermeasure_record.dart';
import '../models/inspection.dart';

/// 内見診断と Before/After 記録の永続化。件数が少ない前提で
/// SharedPreferences に JSON をまるごと保存する。
class InspectionRepository extends ChangeNotifier {
  static const _inspectionsKey = 'inspections_v1';
  static const _recordsKey = 'countermeasure_records_v1';

  List<Inspection> _inspections = [];
  List<CountermeasureRecord> _records = [];
  bool _loaded = false;

  List<Inspection> get inspections => List.unmodifiable(_inspections);
  List<CountermeasureRecord> get records => List.unmodifiable(_records);
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _inspections = _decode(prefs.getString(_inspectionsKey), Inspection.fromJson);
    _records = _decode(prefs.getString(_recordsKey), CountermeasureRecord.fromJson);
    _loaded = true;
    notifyListeners();
  }

  static List<T> _decode<T>(
    String? raw,
    T Function(Map<String, Object?>) fromJson,
  ) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => fromJson(Map<String, Object?>.from(e as Map)))
          .toList();
    } catch (_) {
      // 壊れた保存データは捨てる(計測はやり直せる)。
      return [];
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
      _inspectionsKey,
      jsonEncode(_inspections.map((i) => i.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> _persistRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _recordsKey,
      jsonEncode(_records.map((r) => r.toJson()).toList()),
    );
    notifyListeners();
  }
}
