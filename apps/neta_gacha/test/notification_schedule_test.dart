import 'package:flutter_test/flutter_test.dart';
import 'package:neta_gacha/data/notification_service.dart';

void main() {
  test('指定時刻がまだ来ていなければ今日、過ぎていれば明日を予約する', () {
    final now = DateTime(2026, 9, 24, 18, 30);
    expect(
      NotificationService.nextOccurrence(now, 19 * 60),
      DateTime(2026, 9, 24, 19, 0),
    );
    expect(
      NotificationService.nextOccurrence(now, 18 * 60),
      DateTime(2026, 9, 25, 18, 0),
    );
    // ちょうど同時刻は「過ぎている」扱い。
    expect(
      NotificationService.nextOccurrence(now, 18 * 60 + 30),
      DateTime(2026, 9, 25, 18, 30),
    );
  });
}
