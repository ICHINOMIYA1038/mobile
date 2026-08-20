import '../models/sound_segment.dart';
import 'sound_category.dart';

/// 重ね合わせグラフ描画用に整理した、重複のない連続区間。
/// [category] がnullの区間は「未分類」を表す。
class TimelineRun {
  const TimelineRun({
    required this.start,
    required this.end,
    required this.category,
  });

  final double start;
  final double end;
  final SoundCategory? category;
}

/// 重複しうる生のセグメント群を、時間軸上で重複のない区間列に変換する。
/// 同じ瞬間に複数のラベルが検出されている場合は信頼度が最も高いものを採用し、
/// 同じカテゴリが連続する区間は1本にまとめる。
List<TimelineRun> resolveSoundTimeline(
  List<SoundSegment> segments,
  double durationSeconds,
) {
  if (durationSeconds <= 0) return const [];

  final boundaries = <double>{0, durationSeconds};
  for (final segment in segments) {
    boundaries.add(segment.startSeconds.clamp(0, durationSeconds));
    boundaries.add(segment.endSeconds.clamp(0, durationSeconds));
  }
  final sortedBoundaries = boundaries.toList()..sort();

  final intervals = <TimelineRun>[];
  for (var i = 0; i < sortedBoundaries.length - 1; i++) {
    final start = sortedBoundaries[i];
    final end = sortedBoundaries[i + 1];
    if (end - start <= 0) continue;

    final mid = (start + end) / 2;
    SoundSegment? best;
    for (final segment in segments) {
      final covers = segment.startSeconds <= mid && segment.endSeconds > mid;
      if (covers && (best == null || segment.confidence > best.confidence)) {
        best = segment;
      }
    }
    final category = best == null ? null : categoryForIdentifier(best.identifier);
    intervals.add(TimelineRun(start: start, end: end, category: category));
  }

  final merged = <TimelineRun>[];
  for (final run in intervals) {
    if (merged.isNotEmpty && merged.last.category == run.category) {
      final previous = merged.removeLast();
      merged.add(TimelineRun(start: previous.start, end: run.end, category: run.category));
    } else {
      merged.add(run);
    }
  }
  return merged;
}
