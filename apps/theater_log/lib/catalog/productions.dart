import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../account/auth_service.dart';

/// 記録の入力で候補に出す公演。同じ題名でも劇場が違えば別の公演
class CurrentProduction {
  const CurrentProduction({required this.id, required this.title, required this.venueName, this.groupName, this.prefecture, this.startDate, this.endDate, this.postId, this.sourceUrl});
  final int id;
  final String title;
  final String venueName;
  final String? groupName;
  final String? prefecture;
  final String? startDate;
  final String? endDate;
  final int? postId;
  final String? sourceUrl;

  factory CurrentProduction.fromJson(Map<String, dynamic> j) => CurrentProduction(
    id: j['id'] as int,
    title: j['title'] as String,
    venueName: j['venueName'] as String,
    groupName: j['groupName'] as String?,
    prefecture: j['prefecture'] as String?,
    startDate: j['startDate'] as String?,
    endDate: j['endDate'] as String?,
    postId: j['postId'] as int?,
    sourceUrl: j['sourceUrl'] as String?,
  );

  static String _ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// [day] が上演期間に入っているか。期間が分からないときは null
  bool? includes(DateTime day) {
    if (startDate == null) return null;
    final d = _ymd(day);
    return startDate!.compareTo(d) <= 0 && (endDate ?? startDate)!.compareTo(d) >= 0;
  }

  String get dateLabel {
    String md(String ymd) => '${int.parse(ymd.substring(5, 7))}/${int.parse(ymd.substring(8, 10))}';
    if (startDate == null) return '';
    final end = endDate ?? startDate!;
    return end == startDate ? md(startDate!) : '${md(startDate!)}〜${md(end)}';
  }
}

/// ひらがなとカタカナ、全角と半角、空白や記号の違いを無視して比べる
String normalizeForSearch(String s) {
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    var c = r;
    if (c >= 0xFF01 && c <= 0xFF5E) c -= 0xFEE0; // 全角の英数字と記号
    if (c >= 0x41 && c <= 0x5A) c += 0x20;
    if (c >= 0x30A1 && c <= 0x30F6) c -= 0x60; // カタカナをひらがなに
    const skip = {0x20, 0x3000, 0x30FB, 0xFF65, 0xB7, 0x2D, 0x2010, 0x2015, 0x2013, 0x2014, 0x7E, 0x301C, 0xFF5E, 0x300C, 0x300D, 0x300E, 0x300F, 0x3010, 0x3011, 0x28, 0x29, 0x21, 0x3F, 0x3A};
    if (skip.contains(c)) continue;
    b.writeCharCode(c);
  }
  return b.toString();
}

class ProductionHit {
  const ProductionHit(this.production, {required this.sharedTitle, required this.running});
  final CurrentProduction production;

  /// 同じ題名の公演が別の劇場にもある
  final bool sharedTitle;
  final bool running;
}

/// 入力に合う公演を、上演中、題名の前方一致、題名の一致、劇団や劇場の一致の順に返す
List<ProductionHit> suggestProductions(List<CurrentProduction> rows, String query, DateTime today, {int limit = 8}) {
  final q = normalizeForSearch(query);
  if (q.isEmpty) return const [];
  final venuesByTitle = <String, Set<String>>{};
  for (final p in rows) {
    (venuesByTitle[normalizeForSearch(p.title)] ??= {}).add(normalizeForSearch(p.venueName));
  }
  final scored = <(int, CurrentProduction)>[];
  for (final p in rows) {
    final title = normalizeForSearch(p.title);
    final int match;
    if (title.startsWith(q)) {
      match = 0;
    } else if (title.contains(q)) {
      match = 1;
    } else if (normalizeForSearch(p.groupName ?? '').contains(q) || normalizeForSearch(p.venueName).contains(q)) {
      match = 2;
    } else {
      continue;
    }
    final running = p.includes(today) ?? false;
    scored.add(((running ? 0 : 10) + match, p));
  }
  scored.sort((a, b) {
    final s = a.$1.compareTo(b.$1);
    if (s != 0) return s;
    return (b.$2.startDate ?? '').compareTo(a.$2.startDate ?? '');
  });
  return [
    for (final (_, p) in scored.take(limit))
      ProductionHit(p, sharedTitle: (venuesByTitle[normalizeForSearch(p.title)]?.length ?? 0) > 1, running: p.includes(today) ?? false),
  ];
}

/// 候補の一覧を端末に持つ。入力のたびに問い合わせず、すぐ候補を出すため
class ProductionStore extends ChangeNotifier {
  ProductionStore({http.Client? client}) : _http = client ?? http.Client();
  static final instance = ProductionStore();

  static const _rowsKey = 'current_productions_v1';
  static const _atKey = 'current_productions_at_v1';
  static const _refreshAfter = Duration(hours: 6);

  final http.Client _http;
  List<CurrentProduction> _rows = const [];
  List<CurrentProduction> get rows => _rows;

  @visibleForTesting
  set rows(List<CurrentProduction> value) {
    _rows = value;
    notifyListeners();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_rowsKey);
      if (saved != null) {
        _rows = _parse(saved);
        notifyListeners();
      }
      final at = DateTime.tryParse(prefs.getString(_atKey) ?? '');
      if (at != null && DateTime.now().difference(at) < _refreshAfter) return;
      final r = await _http.get(Uri.parse('${AuthService.apiUrl}/productions/current')).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return;
      final body = utf8.decode(r.bodyBytes);
      _rows = _parse(body);
      await prefs.setString(_rowsKey, body);
      // 空の一覧のときは、次に開いたときにまた取りにいく
      if (_rows.isNotEmpty) await prefs.setString(_atKey, DateTime.now().toIso8601String());
      notifyListeners();
    } catch (e) {
      // 通信できなくても、記録はそのまま続けられる
      debugPrint('ProductionStore.load: $e');
    }
  }

  static List<CurrentProduction> _parse(String body) => [
    for (final e in (jsonDecode(body) as Map<String, dynamic>)['productions'] as List) CurrentProduction.fromJson(e as Map<String, dynamic>),
  ];
}
