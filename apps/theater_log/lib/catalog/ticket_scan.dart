import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';

import 'productions.dart';

/// チケットの写真から読み取った内容。読めなかった項目は null
class TicketScan {
  const TicketScan({this.production, this.venue, this.date, this.showTime, this.seat, this.price, this.titleCandidates = const []});
  final CurrentProduction? production;
  final Venue? venue;
  final DateTime? date;

  /// 'matinee' か 'soiree'
  final String? showTime;
  final String? seat;
  final int? price;

  /// 公演が分からなかったときに、題名として選べそうな行
  final List<String> titleCandidates;

  bool get isEmpty => production == null && venue == null && date == null && seat == null && price == null && titleCandidates.isEmpty;
}

/// 端末の中の文字認識（iOS の Vision）。写真はどこにも送らない
class TicketScanner {
  static const _channel = MethodChannel('gekipon/ocr');

  /// テストで差し替える
  @visibleForTesting
  static Future<List<String>> Function(String path)? override;

  static Future<List<String>> recognize(String path) async {
    if (override != null) return override!(path);
    final lines = await _channel.invokeListMethod<String>('recognize', path);
    return lines ?? const [];
  }
}

String _z2h(String s) => String.fromCharCodes(s.runes.map((c) => c >= 0xFF01 && c <= 0xFF5E ? c - 0xFEE0 : (c == 0x3000 ? 0x20 : c)));

/// 年が書かれていない日付は、今日にいちばん近い年にする
DateTime? _closest(int month, int day, DateTime today) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  DateTime? best;
  for (final y in [today.year - 1, today.year, today.year + 1]) {
    final d = DateTime(y, month, day);
    if (d.month != month) continue;
    if (best == null || d.difference(today).abs() < best.difference(today).abs()) best = d;
  }
  return best;
}

DateTime? parseTicketDate(String text, DateTime today) {
  final t = _z2h(text);
  final full = RegExp(r'(20\d\d)\s*[年/.\-]\s*(\d{1,2})\s*[月/.\-]\s*(\d{1,2})').firstMatch(t);
  if (full != null) {
    final y = int.parse(full[1]!), m = int.parse(full[2]!), d = int.parse(full[3]!);
    final date = DateTime(y, m, d);
    if (date.month == m && date.day == d) return date;
  }
  final md = RegExp(r'(?<![\d/.])(\d{1,2})\s*(?:月\s*(\d{1,2})\s*日|/(\d{1,2})(?![\d/]))').firstMatch(t);
  if (md != null) return _closest(int.parse(md[1]!), int.parse(md[2] ?? md[3]!), today);
  return null;
}

String? parseShowTime(String text) {
  final t = _z2h(text);
  final m = RegExp(r'開演\s*(\d{1,2})\s*[:：時]\s*(\d{2})?').firstMatch(t) ?? RegExp(r'(\d{1,2})\s*[:：]\s*(\d{2})\s*開演').firstMatch(t);
  if (m == null) return null;
  final hour = int.parse(m[1]!);
  if (hour > 23) return null;
  return hour < 16 ? 'matinee' : 'soiree';
}

String? parseSeat(String text) {
  final t = _z2h(text);
  final seat = RegExp(r'((?:\d+\s*階\s*)?(?:[A-Za-z]|\d{1,3})\s*列\s*\d{1,3}\s*番)').firstMatch(t);
  if (seat != null) return seat[1]!.replaceAll(RegExp(r'\s+'), '');
  final ticket = RegExp(r'整理番号\s*[:：]?\s*(\d{1,4})').firstMatch(t);
  if (ticket != null) return '整理番号${ticket[1]}';
  return null;
}

int? parsePrice(String text) {
  final t = _z2h(text);
  final amounts = <int>[];
  for (final m in RegExp(r'[¥￥]\s*([\d,]{3,7})|([\d,]{3,7})\s*円').allMatches(t)) {
    final v = int.tryParse((m[1] ?? m[2]!).replaceAll(',', ''));
    if (v != null && v >= 500 && v <= 100000) amounts.add(v);
  }
  if (amounts.isEmpty) return null;
  // 手数料などの小さい金額より、チケット代の大きい金額を選ぶ
  amounts.sort();
  return amounts.last;
}

const _notTitle = ['チケット', '入場券', '開演', '開場', '座席', '発行', '料金', '税込', '会場', '主催', '公演日', '日時', '整理番号', 'お問い合わせ', '払戻', '再発行', '注意', '電子', 'QR', 'www', 'http', '.com', '.jp'];

/// 読み取った行から、記録に入れる内容を取り出す
TicketScan parseTicket(List<String> lines, {required List<Venue> venues, required List<CurrentProduction> productions, required DateTime today}) {
  final text = lines.join('\n');
  final flat = normalizeForSearch(text);
  final date = parseTicketDate(text, today);

  Venue? venue;
  for (final v in venues) {
    final names = v.name.split(RegExp(r'[（）()]')).map(normalizeForSearch).where((n) => n.length >= 3);
    if (names.any(flat.contains) && (venue == null || v.name.length > venue.name.length)) venue = v;
  }

  CurrentProduction? production;
  var bestScore = 0;
  for (final p in productions) {
    final title = normalizeForSearch(p.title);
    if (title.length < 2 || !flat.contains(title)) continue;
    // 同じ題名で劇場が違う公演があるので、劇場と日付でしぼる
    var score = title.length;
    if (normalizeForSearch(p.venueName).isNotEmpty && flat.contains(normalizeForSearch(p.venueName))) score += 50;
    if (venue != null && p.venueName == venue.name) score += 50;
    if (date != null && (p.includes(date) ?? false)) score += 30;
    if (score > bestScore) {
      bestScore = score;
      production = p;
    }
  }

  final candidates = <String>[];
  if (production == null) {
    for (final raw in lines) {
      final line = raw.trim();
      if (line.length < 2 || line.length > 40) continue;
      if (_notTitle.any(line.contains)) continue;
      if (parseTicketDate(line, today) != null || parsePrice(line) != null || parseSeat(line) != null) continue;
      if (RegExp(r'^[\d\s:：/.\-()（）年月日時分]+$').hasMatch(line)) continue;
      if (venue != null && normalizeForSearch(line).contains(normalizeForSearch(venue.name))) continue;
      if (!candidates.contains(line)) candidates.add(line);
      if (candidates.length >= 6) break;
    }
  }

  return TicketScan(production: production, venue: venue, date: date, showTime: parseShowTime(text), seat: parseSeat(text), price: parsePrice(text), titleCandidates: candidates);
}
