import 'package:flutter_test/flutter_test.dart';
import 'package:sound_shield/logic/sound_category.dart';
import 'package:sound_shield/logic/sound_timeline_resolver.dart';
import 'package:sound_shield/models/sound_segment.dart';

void main() {
  test('区間が無ければ0〜durationの未分類1区間になる', () {
    final runs = resolveSoundTimeline(const [], 10);

    expect(runs, hasLength(1));
    expect(runs.single.start, 0);
    expect(runs.single.end, 10);
    expect(runs.single.category, isNull);
  });

  test('重複しないセグメントはそのまま区間になる', () {
    final runs = resolveSoundTimeline(const [
      SoundSegment(
        startSeconds: 0,
        endSeconds: 3,
        identifier: 'vehicle_engine',
        confidence: 0.8,
      ),
      SoundSegment(
        startSeconds: 3,
        endSeconds: 6,
        identifier: 'dog_bark',
        confidence: 0.9,
      ),
    ], 6);

    expect(runs, hasLength(2));
    expect(runs[0].category, SoundCategory.vehicle);
    expect(runs[1].category, SoundCategory.animal);
  });

  test('重複区間は信頼度が高い方を採用する', () {
    final runs = resolveSoundTimeline(const [
      SoundSegment(
        startSeconds: 0,
        endSeconds: 5,
        identifier: 'vehicle_engine',
        confidence: 0.6,
      ),
      SoundSegment(
        startSeconds: 2,
        endSeconds: 4,
        identifier: 'air_horn',
        confidence: 0.9,
      ),
    ], 5);

    expect(runs.map((r) => r.category), [
      SoundCategory.vehicle,
      SoundCategory.siren,
      SoundCategory.vehicle,
    ]);
  });

  test('同じカテゴリが連続する区間は1本にまとめられる', () {
    final runs = resolveSoundTimeline(const [
      SoundSegment(
        startSeconds: 0,
        endSeconds: 2,
        identifier: 'vehicle_engine',
        confidence: 0.7,
      ),
      SoundSegment(
        startSeconds: 2,
        endSeconds: 4,
        identifier: 'traffic_noise',
        confidence: 0.7,
      ),
    ], 4);

    expect(runs, hasLength(1));
    expect(runs.single.start, 0);
    expect(runs.single.end, 4);
    expect(runs.single.category, SoundCategory.vehicle);
  });
}
