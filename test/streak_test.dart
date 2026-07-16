import 'package:flutter_test/flutter_test.dart';
import 'package:takken_simple/data/progress_repository.dart';

void main() {
  group('StreakData', () {
    test('初回の学習で1日目になる', () {
      final streak = const StreakData().markStudied(DateTime(2026, 7, 15, 9));
      expect(streak.current, 1);
      expect(streak.best, 1);
    });

    test('同じ日に何度解いても増えない', () {
      var streak = const StreakData().markStudied(DateTime(2026, 7, 15, 9));
      streak = streak.markStudied(DateTime(2026, 7, 15, 23));
      expect(streak.current, 1);
    });

    test('翌日に解けば継続する', () {
      var streak = const StreakData().markStudied(DateTime(2026, 7, 15, 9));
      streak = streak.markStudied(DateTime(2026, 7, 16, 9));
      expect(streak.current, 2);
      expect(streak.best, 2);
    });

    test('1日でも空けば1日目に戻るが、最高記録は残る', () {
      var streak = const StreakData().markStudied(DateTime(2026, 7, 15));
      streak = streak.markStudied(DateTime(2026, 7, 16));
      streak = streak.markStudied(DateTime(2026, 7, 18));
      expect(streak.current, 1);
      expect(streak.best, 2);
    });

    test('月をまたいでも継続を正しく判定する', () {
      var streak = const StreakData().markStudied(DateTime(2026, 7, 31, 23));
      streak = streak.markStudied(DateTime(2026, 8, 1, 1));
      expect(streak.current, 2);
    });

    test('書き出して読み戻しても同じ内容になる', () {
      final streak = const StreakData().markStudied(DateTime(2026, 7, 15, 9));
      final restored = StreakData.fromJson(streak.toJson());
      expect(restored.current, streak.current);
      expect(restored.best, streak.best);
      expect(restored.lastStudyDate, streak.lastStudyDate);
    });
  });
}
