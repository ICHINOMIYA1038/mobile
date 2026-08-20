import 'package:flutter_test/flutter_test.dart';
import 'package:sound_shield/logic/suggestion_engine.dart';
import 'package:sound_shield/models/band_level.dart';
import 'package:sound_shield/models/detected_sound.dart';
import 'package:sound_shield/models/measurement_result.dart';

MeasurementResult _resultWith({
  List<DetectedSound> labels = const [],
  List<BandLevel> bands = const [],
  double overallLeqDb = 60,
}) {
  return MeasurementResult(
    durationSeconds: 15,
    overallLeqDb: overallLeqDb,
    overallPeakDb: overallLeqDb + 10,
    overallMinDb: overallLeqDb - 15,
    bands: bands,
    soundLabels: labels,
  );
}

void main() {
  final engine = const SuggestionEngine();

  test('信頼度の高い音源ラベルに一致するカテゴリの対策を返す', () {
    final result = _resultWith(
      labels: const [
        DetectedSound(
          identifier: 'vehicle_engine',
          activeShare: 0.6,
          avgConfidence: 0.8,
        ),
      ],
    );

    final suggestions = engine.suggest(result);

    expect(suggestions.any((s) => s.title.contains('防音窓')), isTrue);
  });

  test('信頼度がしきい値未満のラベルは無視される', () {
    final withLowConfidence = _resultWith(
      labels: const [
        DetectedSound(
          identifier: 'vehicle_engine',
          activeShare: 0.6,
          avgConfidence: 0.1,
        ),
      ],
    );
    final withNoLabels = _resultWith();

    expect(
      engine.suggest(withLowConfidence),
      engine.suggest(withNoLabels),
    );
  });

  test('音源ラベルが無くても支配的な周波数帯から対策を出す(低域)', () {
    final result = _resultWith(
      bands: const [
        BandLevel(centerHz: 63, leqDb: 70, peakDb: 75, minDb: 75 - 8),
        BandLevel(centerHz: 4000, leqDb: 40, peakDb: 45, minDb: 45 - 8),
      ],
    );

    final suggestions = engine.suggest(result);

    expect(suggestions.any((s) => s.title.contains('防振ゴム')), isTrue);
  });

  test('高域が支配的なら隙間対策を出す', () {
    final result = _resultWith(
      bands: const [
        BandLevel(centerHz: 63, leqDb: 40, peakDb: 45, minDb: 45 - 8),
        BandLevel(centerHz: 8000, leqDb: 70, peakDb: 75, minDb: 75 - 8),
      ],
    );

    final suggestions = engine.suggest(result);

    expect(suggestions.any((s) => s.title.contains('隙間テープ')), isTrue);
  });

  test('手がかりが何もない場合は空リストを返す(汎用フォールバックは出さない)', () {
    final suggestions = engine.suggest(_resultWith());

    expect(suggestions, isEmpty);
  });

  test('静かな環境(40dB未満)では周波数帯からの汎用提案を出さない', () {
    final result = _resultWith(
      overallLeqDb: 25,
      bands: const [
        BandLevel(centerHz: 63, leqDb: 25, peakDb: 30, minDb: 20),
        BandLevel(centerHz: 4000, leqDb: 18, peakDb: 22, minDb: 14),
      ],
    );

    final suggestions = engine.suggest(result);

    expect(suggestions, isEmpty);
  });

  test('静かな環境でも確信度の高い音源ラベルがあれば対策を出す', () {
    final result = _resultWith(
      overallLeqDb: 25,
      labels: const [
        DetectedSound(
          identifier: 'dog_bark',
          activeShare: 0.1,
          avgConfidence: 0.9,
        ),
      ],
    );

    final suggestions = engine.suggest(result);

    expect(suggestions, isNotEmpty);
    expect(suggestions.any((s) => s.title.contains('吸音パネル')), isTrue);
  });

  test('同じ対策が複数のカテゴリから重複して追加されない', () {
    final result = _resultWith(
      labels: const [
        DetectedSound(
          identifier: 'car_horn',
          activeShare: 0.5,
          avgConfidence: 0.9,
        ),
        DetectedSound(
          identifier: 'traffic_noise',
          activeShare: 0.4,
          avgConfidence: 0.9,
        ),
      ],
    );

    final suggestions = engine.suggest(result);
    final titles = suggestions.map((s) => s.title).toList();

    expect(titles.toSet().length, titles.length);
  });
}
