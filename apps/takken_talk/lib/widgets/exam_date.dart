/// 宅建試験は原則10月の第3日曜日。次に来る試験日を返す。
DateTime nextExamDate([DateTime? now]) {
  final today = now ?? DateTime.now();
  for (var y = today.year; y <= today.year + 1; y++) {
    final d = thirdSundayOfOctober(y);
    if (!d.isBefore(DateTime(today.year, today.month, today.day))) return d;
  }
  return thirdSundayOfOctober(today.year + 1);
}

DateTime thirdSundayOfOctober(int year) {
  final first = DateTime(year, 10, 1);
  final offset = (DateTime.sunday - first.weekday + 7) % 7;
  return DateTime(year, 10, 1 + offset + 14);
}

String formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String formatDateJa(DateTime d) => '${d.year}年${d.month}月${d.day}日';

int daysUntil(DateTime d, [DateTime? now]) {
  final today = now ?? DateTime.now();
  return DateTime(d.year, d.month, d.day).difference(DateTime(today.year, today.month, today.day)).inDays;
}

DateTime? parseDate(String? s) {
  if (s == null) return null;
  return DateTime.tryParse(s);
}
