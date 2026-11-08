import 'package:flutter_test/flutter_test.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import 'package:theater_log/catalog/productions.dart';
import 'package:theater_log/catalog/ticket_scan.dart';

void main() {
  final today = DateTime(2026, 11, 6);
  const venues = [Venue(1, '本多劇場', '東京都'), Venue(2, 'ABCホール', '大阪府'), Venue(3, '下北沢 本多劇場グループ', '東京都')];
  const akaoniTokyo = CurrentProduction(id: 1, title: '赤鬼', venueName: '本多劇場', startDate: '2026-11-01', endDate: '2026-11-10');
  const akaoniOsaka = CurrentProduction(id: 2, title: '赤鬼', venueName: 'ABCホール', startDate: '2026-12-01', endDate: '2026-12-05');

  test('日付の書き方', () {
    expect(parseTicketDate('2026年11月8日(土)', today), DateTime(2026, 11, 8));
    expect(parseTicketDate('２０２６／１１／０８', today), DateTime(2026, 11, 8));
    expect(parseTicketDate('11月8日(土) 18:00', today), DateTime(2026, 11, 8));
    // 観た記録なので、1 週間より先になる日付は前の年にする
    expect(parseTicketDate('1/10(日)', today), DateTime(2026, 1, 10));
    expect(parseTicketDate('11/12', today), DateTime(2026, 11, 12));
    expect(parseTicketDate('10/30', today), DateTime(2026, 10, 30));
    expect(parseTicketDate('2026/02/30', today), isNull);
    expect(parseTicketDate('開演 18:30', today), isNull);
  });

  test('昼と夜、座席、金額', () {
    expect(parseShowTime('開演 13:00'), 'matinee');
    expect(parseShowTime('18:30開演'), 'soiree');
    expect(parseShowTime('開場 18:00'), isNull);
    expect(parseSeat('1階 C列 12番'), '1階C列12番');
    expect(parseSeat('座席 ２０列 ５番'), '20列5番');
    expect(parseSeat('整理番号 045'), '整理番号045');
    expect(parsePrice('全席指定 ¥7,800（税込）\nシステム利用料 330円'), 7800);
    expect(parsePrice('一般 4,500円'), 4500);
    expect(parsePrice('No. 123'), isNull);
  });

  test('同じ題名でも、チケットの劇場と日付で公演を選ぶ', () {
    final lines = ['株式会社テスト 発行', '赤鬼', '2026年12月3日(木) 19:00開演', 'ABCホール', 'S席 ¥6,000', 'B列 8番'];
    final s = parseTicket(lines, venues: venues, productions: const [akaoniTokyo, akaoniOsaka], today: today);
    expect(s.production?.id, 2);
    expect(s.venue?.name, 'ABCホール');
    expect(s.date, DateTime(2026, 12, 3));
    expect(s.showTime, 'soiree');
    expect(s.seat, 'B列8番');
    expect(s.price, 6000);
    expect(s.titleCandidates, isEmpty);
  });

  test('公演が分からないときは、題名の候補を出す', () {
    final lines = ['電子チケット', 'まだ誰も知らない新作', '本多劇場', '2026.11.08 開演 14:00', '¥5,000'];
    final s = parseTicket(lines, venues: venues, productions: const [akaoniTokyo], today: today);
    expect(s.production, isNull);
    expect(s.venue?.name, '本多劇場');
    expect(s.titleCandidates.first, 'まだ誰も知らない新作');
    expect(s.titleCandidates, isNot(contains('本多劇場')));
    expect(s.titleCandidates, isNot(contains('電子チケット')));
  });

  test('何も読めなければ空', () {
    expect(parseTicket(const [], venues: venues, productions: const [], today: today).isEmpty, isTrue);
  });
}
