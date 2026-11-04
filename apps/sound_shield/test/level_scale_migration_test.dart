import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_shield/data/calibration_repository.dart';
import 'package:sound_shield/data/inspection_repository.dart';
import 'package:sound_shield/data/sound_meter_service.dart';
import 'package:sound_shield/logic/inspection_scorer.dart';
import 'package:sound_shield/logic/level_scale.dart';
import 'package:sound_shield/models/band_level.dart';
import 'package:sound_shield/models/countermeasure_record.dart';
import 'package:sound_shield/models/impulse_result.dart';
import 'package:sound_shield/models/inspection.dart';
import 'package:sound_shield/models/measurement_result.dart';
import 'package:sound_shield/models/time_series_point.dart';

final _offset = LevelScale.legacyFftOffsetDb;

MeasurementResult _m(double leq) => MeasurementResult(
  durationSeconds: 15,
  overallLeqDb: leq,
  overallPeakDb: leq + 10,
  overallMinDb: leq - 10,
  bands: [
    BandLevel(centerHz: 1000, leqDb: leq - 3, peakDb: leq + 5, minDb: leq - 12),
  ],
  soundLabels: const [],
  timeSeries: [TimeSeriesPoint(t: 0, db: leq - 1), TimeSeriesPoint(t: 0.17, db: leq + 1)],
);

const _knock = ImpulseResult(
  peakDb: 80,
  floorDb: 50,
  snrDb: 30,
  t10: 0.02,
  t20: 0.04,
  rt60: 0.12,
  spectralCentroidHz: 900,
  lowShare: 0.4,
  highShare: 0.2,
  peakHz: 800,
);

const _clap = ImpulseResult(
  peakDb: 85,
  floorDb: 45,
  snrDb: 40,
  t10: 0.1,
  t20: 0.2,
  rt60: 0.6,
  spectralCentroidHz: 1500,
  lowShare: 0.2,
  highShare: 0.4,
  peakHz: 1200,
);

/// 1.1.1 までの物差しで保存された内見診断(中央 128dB ≒ 新しい物差しで 45dB)。
Inspection _legacyInspection() => Inspection(
  id: 'a',
  name: '旧い物件',
  createdAt: DateTime(2026, 9, 1),
  ambient: _m(128),
  window: _m(138),
  knock: _knock,
  clap: _clap,
  neighbor: _m(131),
);

CountermeasureRecord _legacyRecord() => CountermeasureRecord(
  id: 'r',
  measureId: 'curtain',
  measureName: '防音カーテン',
  createdAt: DateTime(2026, 9, 2),
  before: _m(140),
  after: _m(134),
  predictedDeltaDb: 5,
  place: '寝室',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('換算の係数は 10·log10(0.75·16384²) ≒ 83.0dB', () {
    expect(_offset, closeTo(83.04, 0.01));
  });

  group('保存済みの記録の換算', () {
    test('1.1.1 までの内見診断は1回だけ下げ、ノック・手叩きは変えない', () async {
      SharedPreferences.setMockInitialValues({
        InspectionRepository.legacyInspectionsKey: jsonEncode([
          _legacyInspection().toJson(),
        ]),
      });
      final repo = InspectionRepository();
      await repo.load();
      final i = repo.inspections.single;
      expect(i.ambient!.overallLeqDb, closeTo(128 - _offset, 1e-9));
      expect(i.ambient!.overallPeakDb, closeTo(138 - _offset, 1e-9));
      expect(i.ambient!.overallMinDb, closeTo(118 - _offset, 1e-9));
      expect(i.ambient!.bands.single.leqDb, closeTo(125 - _offset, 1e-9));
      expect(i.ambient!.bands.single.peakDb, closeTo(133 - _offset, 1e-9));
      expect(i.ambient!.bands.single.minDb, closeTo(116 - _offset, 1e-9));
      expect(i.ambient!.timeSeries.map((p) => p.db), [
        closeTo(127 - _offset, 1e-9),
        closeTo(129 - _offset, 1e-9),
      ]);
      expect(i.window!.overallLeqDb, closeTo(138 - _offset, 1e-9));
      expect(i.neighbor!.overallLeqDb, closeTo(131 - _offset, 1e-9));
      // ノック・手叩きは以前から RMS 経路で物差しが正しい。
      expect(i.knock!.toJson(), _knock.toJson());
      expect(i.clap!.toJson(), _clap.toJson());

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(InspectionRepository.legacyInspectionsKey), isFalse);
      expect(prefs.containsKey(InspectionRepository.inspectionsKey), isTrue);

      // もう一度読み込んでも、2回は下げない。
      final again = InspectionRepository();
      await again.load();
      expect(
        again.inspections.single.ambient!.overallLeqDb,
        closeTo(128 - _offset, 1e-9),
      );
    });

    test('新しいキーがあれば換算しない(古いキーが残っていても消すだけ)', () async {
      SharedPreferences.setMockInitialValues({
        InspectionRepository.inspectionsKey: jsonEncode([
          _legacyInspection().copyWith(ambient: _m(45)).toJson(),
        ]),
        InspectionRepository.legacyInspectionsKey: jsonEncode([
          _legacyInspection().toJson(),
        ]),
      });
      final repo = InspectionRepository();
      await repo.load();
      expect(repo.inspections.single.ambient!.overallLeqDb, 45);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(InspectionRepository.legacyInspectionsKey), isFalse);
    });

    test('1.1.2 で保存した記録は読み込んでも値が変わらない', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = InspectionRepository();
      await repo.load();
      await repo.saveInspection(
        Inspection(id: 'n', name: '新しい物件', createdAt: DateTime(2026, 10, 24), ambient: _m(42)),
      );
      final again = InspectionRepository();
      await again.load();
      expect(again.inspections.single.ambient!.overallLeqDb, 42);
    });

    test('対策の記録は前後とも下げ、実測の差と予測ΔdBは変わらない', () async {
      SharedPreferences.setMockInitialValues({
        InspectionRepository.legacyRecordsKey: jsonEncode([
          _legacyRecord().toJson(),
        ]),
      });
      final repo = InspectionRepository();
      await repo.load();
      final r = repo.records.single;
      expect(r.before.overallLeqDb, closeTo(140 - _offset, 1e-9));
      expect(r.after!.overallLeqDb, closeTo(134 - _offset, 1e-9));
      expect(r.actualDeltaDb, closeTo(6, 1e-9));
      expect(r.predictedDeltaDb, 5);
      expect(r.place, '寝室');
    });

    test('古いデータが壊れていて読めないときは _v2 を書かず _v1 も残す', () async {
      SharedPreferences.setMockInitialValues({
        InspectionRepository.legacyInspectionsKey: '{壊れた',
        InspectionRepository.legacyRecordsKey: '[{"id": 1}]',
      });
      final repo = InspectionRepository();
      await repo.load();
      expect(repo.inspections, isEmpty);
      expect(repo.records, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(InspectionRepository.inspectionsKey), isFalse);
      expect(prefs.containsKey(InspectionRepository.recordsKey), isFalse);
      expect(prefs.getString(InspectionRepository.legacyInspectionsKey), '{壊れた');
      expect(prefs.getString(InspectionRepository.legacyRecordsKey), '[{"id": 1}]');

      // 新しく保存して `_v2` ができても、読めない `_v1` は消さない。
      await repo.saveInspection(
        Inspection(id: 'n', name: '新しい物件', createdAt: DateTime(2026, 10, 24), ambient: _m(42)),
      );
      final again = InspectionRepository();
      await again.load();
      expect(again.inspections.single.id, 'n');
      expect(prefs.getString(InspectionRepository.legacyInspectionsKey), '{壊れた');
    });

    test('ネイティブが返す空の結果(値が0)はずらさない', () {
      const empty = MeasurementResult(
        durationSeconds: 0,
        overallLeqDb: 0,
        overallPeakDb: 0,
        overallMinDb: 0,
        bands: [],
        soundLabels: [],
      );
      expect(identical(empty.shiftLevels(-_offset), empty), isTrue);
    });
  });

  group('換算後の採点', () {
    test('室内の静けさは換算後の値で妥当な減点になり、差で採点する項目は変わらない', () {
      const scorer = InspectionScorer();
      final legacy = _legacyInspection();
      final converted = InspectionRepository.convertLegacyInspection(
        legacy,
        shiftDb: InspectionRepository.legacyShiftDb(0),
      );
      final before = scorer.score(legacy);
      final after = scorer.score(converted);
      double penalty(InspectionScore s, String key) =>
          s.components.firstWhere((c) => c.key == key).penalty;

      // 換算前は 128dB で 30点(上限)減点。換算後は約45dBで (45−40)×1.5 ≒ 7.4点。
      expect(penalty(before, 'ambient'), 30);
      expect(penalty(after, 'ambient'), closeTo((128 - _offset - 40) * 1.5, 1e-9));
      expect(penalty(after, 'ambient'), inInclusiveRange(7, 8));
      for (final key in ['window', 'neighbor', 'wall', 'reverb']) {
        expect(penalty(after, key), penalty(before, key), reason: key);
      }
      expect(after.score, greaterThan(before.score));
    });
  });

  group('校正のリセット', () {
    const channel = MethodChannel('jp.pairof.sound_shield/sound_meter');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final sent = <double>[];

    setUp(() {
      sent.clear();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'setCalibration') {
          sent.add((call.arguments as Map)['adjustmentDb'] as double);
        }
        return null;
      });
    });
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('1.1.1 の校正値は1回だけ0に戻し、案内を一度だけ出す', () async {
      SharedPreferences.setMockInitialValues({
        CalibrationRepository.legacyKey: -20.0,
      });
      final repo = CalibrationRepository(soundMeter: SoundMeterService());
      await repo.load();
      expect(repo.adjustmentDb, 0);
      expect(repo.resetNoticePending, isTrue);
      expect(sent, [0]);
      await repo.dismissResetNotice();
      expect(repo.resetNoticePending, isFalse);

      // 1.1.2 で校正し直した値は、次の起動で戻さない。案内も出ない。
      await repo.setAdjustment(3.5);
      final again = CalibrationRepository(soundMeter: SoundMeterService());
      await again.load();
      expect(again.adjustmentDb, 3.5);
      expect(again.resetNoticePending, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(CalibrationRepository.legacyKey), isFalse);
    });

    test('校正していなかった(0)なら案内は出さない', () async {
      SharedPreferences.setMockInitialValues({
        CalibrationRepository.legacyKey: 0.0,
      });
      final repo = CalibrationRepository(soundMeter: SoundMeterService());
      await repo.load();
      expect(repo.adjustmentDb, 0);
      expect(repo.resetNoticePending, isFalse);
    });

    test('新しく入れた人は何も変わらない', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = CalibrationRepository(soundMeter: SoundMeterService());
      await repo.load();
      expect(repo.adjustmentDb, 0);
      expect(repo.resetNoticePending, isFalse);
    });
  });

  group('当時の校正を取り除いて換算', () {
    const channel = MethodChannel('jp.pairof.sound_shield/sound_meter');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() => messenger.setMockMethodCallHandler(channel, (call) async => null));
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    // 1.1.1 で −20dB に校正していた人の記録(表示 = 古い物差し + 校正値)。
    Map<String, Object> legacyValues() => {
      CalibrationRepository.legacyKey: -20.0,
      InspectionRepository.legacyInspectionsKey: jsonEncode([
        _legacyInspection().toJson(),
      ]),
      InspectionRepository.legacyRecordsKey: jsonEncode([_legacyRecord().toJson()]),
    };

    void expectConverted(InspectionRepository repo) {
      // −83.04 − (−20) = −63.04dB ずらす。
      final shift = -_offset + 20;
      expect(shift, closeTo(-63.04, 0.01));
      final i = repo.inspections.single;
      expect(i.ambient!.overallLeqDb, closeTo(128 + shift, 1e-9));
      expect(i.ambient!.bands.single.leqDb, closeTo(125 + shift, 1e-9));
      expect(i.ambient!.timeSeries.first.db, closeTo(127 + shift, 1e-9));
      expect(i.window!.overallLeqDb, closeTo(138 + shift, 1e-9));
      expect(i.neighbor!.overallLeqDb, closeTo(131 + shift, 1e-9));
      expect(i.knock!.toJson(), _knock.toJson());
      final r = repo.records.single;
      expect(r.before.overallLeqDb, closeTo(140 + shift, 1e-9));
      expect(r.after!.overallLeqDb, closeTo(134 + shift, 1e-9));
      expect(r.actualDeltaDb, closeTo(6, 1e-9));
    }

    test('校正を先にリセットしても、古い校正値で換算し、両方終わってから _v1 を消す', () async {
      SharedPreferences.setMockInitialValues(legacyValues());
      final cal = CalibrationRepository(soundMeter: SoundMeterService());
      await cal.load();
      expect(cal.adjustmentDb, 0);
      expect(cal.resetNoticePending, isTrue);
      final prefs = await SharedPreferences.getInstance();
      // 記録の換算がまだなので、古い校正値は残っている。
      expect(prefs.getDouble(CalibrationRepository.legacyKey), -20.0);

      final repo = InspectionRepository();
      await repo.load();
      expectConverted(repo);
      expect(prefs.containsKey(CalibrationRepository.legacyKey), isFalse);

      // もう一度読み込んでも2回はずらさない。
      final again = InspectionRepository();
      await again.load();
      expectConverted(again);
    });

    test('記録を先に換算しても同じ値になり、校正のリセット後に _v1 を消す', () async {
      SharedPreferences.setMockInitialValues(legacyValues());
      final repo = InspectionRepository();
      await repo.load();
      expectConverted(repo);
      final prefs = await SharedPreferences.getInstance();
      // 校正のリセットがまだなので、古い校正値は残っている。
      expect(prefs.getDouble(CalibrationRepository.legacyKey), -20.0);

      final cal = CalibrationRepository(soundMeter: SoundMeterService());
      await cal.load();
      expect(cal.adjustmentDb, 0);
      expect(cal.resetNoticePending, isTrue);
      expect(prefs.containsKey(CalibrationRepository.legacyKey), isFalse);
    });

    test('校正していなかった(0)人と新規の人は −83.04dB のまま', () {
      expect(InspectionRepository.legacyShiftDb(0), closeTo(-83.04, 0.01));
      expect(InspectionRepository.legacyShiftDb(-20), closeTo(-63.04, 0.01));
    });

    test('古い記録が読めずに残っている間は、古い校正値も消さない', () async {
      SharedPreferences.setMockInitialValues({
        CalibrationRepository.legacyKey: -20.0,
        InspectionRepository.legacyInspectionsKey: '{壊れた',
      });
      await CalibrationRepository(soundMeter: SoundMeterService()).load();
      await InspectionRepository().load();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(CalibrationRepository.legacyKey), -20.0);
      // 校正はリセット済みで、次の起動でも戻し直さない。
      final cal = CalibrationRepository(soundMeter: SoundMeterService());
      await cal.load();
      expect(cal.adjustmentDb, 0);
    });
  });
}
