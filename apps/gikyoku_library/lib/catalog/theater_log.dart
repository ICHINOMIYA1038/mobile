import 'dart:convert';

import 'package:app_insights/app_insights.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'log_photos.dart';

/// 観劇の記録 1 件。カタログの作品につながっていれば playId が入る
class TheaterLogEntry {
  const TheaterLogEntry({
    required this.id,
    required this.title,
    required this.watchedOn,
    this.playId,
    this.author,
    this.group,
    this.venue,
    this.rating,
    this.note = '',
    this.showTime,
    this.seat,
    this.price,
    this.photos = const [],
  });

  final String id;
  final String title;
  final DateTime watchedOn;
  final int? playId;
  final String? author;
  final String? group;
  final String? venue;
  final int? rating;
  final String note;

  /// 'matinee' か 'soiree'
  final String? showTime;
  final String? seat;

  /// チケット代（円）
  final int? price;

  /// 写真のファイル名（端末の中の保存先からの相対。アプリの更新で絶対パスが変わるため）
  final List<String> photos;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'watchedOn': watchedOn.toIso8601String(),
    'playId': playId,
    'author': author,
    'group': group,
    'venue': venue,
    'rating': rating,
    'note': note,
    'showTime': showTime,
    'seat': seat,
    'price': price,
    'photos': photos,
  };

  factory TheaterLogEntry.fromJson(Map<String, dynamic> j) => TheaterLogEntry(
    id: j['id'] as String,
    title: j['title'] as String,
    watchedOn: DateTime.parse(j['watchedOn'] as String),
    playId: j['playId'] as int?,
    author: j['author'] as String?,
    group: j['group'] as String?,
    venue: j['venue'] as String?,
    rating: j['rating'] as int?,
    note: (j['note'] as String?) ?? '',
    showTime: j['showTime'] as String?,
    seat: j['seat'] as String?,
    price: j['price'] as int?,
    photos: ((j['photos'] as List?) ?? const []).cast<String>(),
  );
}

/// 観劇ノート。試作の段階では端末の中だけに保存する
class TheaterLog extends ChangeNotifier {
  static const _key = 'theater_log';
  final List<TheaterLogEntry> _entries = [];

  /// 観た日が新しい順
  List<TheaterLogEntry> get entries => List.unmodifiable(_entries);

  /// 自分が前に入れた値を、よく使う順に返す（入力の候補）
  List<String> recent(String? Function(TheaterLogEntry) pick) {
    final counts = <String, int>{};
    for (final e in _entries) {
      final v = pick(e);
      if (v != null && v.isNotEmpty) counts[v] = (counts[v] ?? 0) + 1;
    }
    return (counts.keys.toList()..sort((a, b) => counts[b]! - counts[a]!));
  }

  int countInYear(int year) => _entries.where((e) => e.watchedOn.year == year).length;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    _entries.clear();
    if (raw != null) {
      try {
        _entries.addAll((jsonDecode(raw) as List).map((e) => TheaterLogEntry.fromJson(e as Map<String, dynamic>)));
      } catch (_) {
        // 壊れた記録で起動を止めない
      }
    }
    _sort();
    notifyListeners();
  }

  void _sort() => _entries.sort((a, b) => b.watchedOn.compareTo(a.watchedOn));

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_entries.map((e) => e.toJson()).toList()));
  }

  Future<void> upsert(TheaterLogEntry entry) async {
    final i = _entries.indexWhere((e) => e.id == entry.id);
    i >= 0 ? _entries[i] = entry : _entries.add(entry);
    _sort();
    notifyListeners();
    // 記録の中身は送らない
    AppInsights.logEvent('log_save', parameters: {'linked': entry.playId != null ? 1 : 0, 'has_note': entry.note.isNotEmpty ? 1 : 0});
    await _save();
  }

  Future<void> remove(String id) async {
    final removed = _entries.where((e) => e.id == id).expand((e) => e.photos).toList();
    for (final name in removed) {
      await LogPhotos.delete(name);
    }
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
    AppInsights.logEvent('log_delete');
    await _save();
  }
}
