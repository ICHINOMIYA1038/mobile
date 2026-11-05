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
    this.productionId,
    this.visibility = 'private',
    this.hidden = false,
    this.dirty = true,
    this.deleted = false,
    this.onServer = false,
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
  final int? productionId;

  /// 'private' か 'public'
  final String visibility;

  /// 通報などで公開から隠された
  final bool hidden;

  /// サーバーへ送る必要がある
  final bool dirty;

  /// 削除の印（サーバーへ伝えるまで残す）
  final bool deleted;
  final bool onServer;

  TheaterLogEntry copyWith({bool? dirty, bool? deleted, bool? onServer, bool? hidden}) => TheaterLogEntry.fromJson({
    ...toJson(),
    'dirty': dirty ?? this.dirty,
    'deleted': deleted ?? this.deleted,
    'onServer': onServer ?? this.onServer,
    'hidden': hidden ?? this.hidden,
  });

  TheaterLogEntry copyWithVenue(String name) => TheaterLogEntry.fromJson({...toJson(), 'venue': name});

  static String _ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// サーバーへ送る形。写真と作者名は送らない
  Map<String, Object?> toServerJson() => {
    'title': title,
    'watchedOn': _ymd(watchedOn),
    'postId': playId,
    'productionId': productionId,
    'groupName': group,
    'venueName': venue,
    'showTime': showTime,
    'seat': seat,
    'price': price,
    'rating': rating,
    'note': note,
    'visibility': visibility,
  };

  /// サーバーの行から作る。写真と作者名は端末のものを引き継ぐ
  factory TheaterLogEntry.fromServer(Map<String, dynamic> j, TheaterLogEntry? local) => TheaterLogEntry(
    id: j['clientId'] as String,
    title: j['title'] as String,
    watchedOn: DateTime.parse(j['watchedOn'] as String),
    playId: j['postId'] as int?,
    author: local?.author,
    group: j['groupName'] as String?,
    venue: j['venueName'] as String?,
    rating: j['rating'] as int?,
    note: (j['note'] as String?) ?? '',
    showTime: j['showTime'] as String?,
    seat: j['seat'] as String?,
    price: j['price'] as int?,
    photos: local?.photos ?? const [],
    productionId: j['productionId'] as int?,
    visibility: (j['visibility'] as String?) ?? 'private',
    hidden: j['hidden'] == true,
    dirty: false,
    onServer: true,
  );

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
    'productionId': productionId,
    'visibility': visibility,
    'hidden': hidden,
    'dirty': dirty,
    'deleted': deleted,
    'onServer': onServer,
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
    productionId: j['productionId'] as int?,
    visibility: (j['visibility'] as String?) ?? 'private',
    hidden: j['hidden'] == true,
    dirty: j['dirty'] != false,
    deleted: j['deleted'] == true,
    onServer: j['onServer'] == true,
  );
}

/// 観劇の記録。端末に保存し、ログイン中はサーバーと同期する
class TheaterLog extends ChangeNotifier {
  static const _key = 'theater_log';
  final List<TheaterLogEntry> _entries = [];

  /// 記録が変わったときに呼ぶ（同期の開始に使う）
  void Function()? onDirty;

  /// 観た日が新しい順
  List<TheaterLogEntry> get entries => List.unmodifiable(_entries.where((e) => !e.deleted));

  List<TheaterLogEntry> get dirtyEntries => _entries.where((e) => e.dirty).toList();

  Future<void> markPushed(TheaterLogEntry sent, Map<String, dynamic>? server) async {
    final i = _entries.indexWhere((e) => e.id == sent.id);
    if (i < 0) return;
    // 送っている間にまた変わっていたら、次の同期に任せる
    if (!identical(_entries[i], sent)) return;
    if (sent.deleted) {
      _entries.removeAt(i);
    } else {
      _entries[i] = server == null ? sent.copyWith(dirty: false, onServer: true) : TheaterLogEntry.fromServer(server, sent);
    }
    notifyListeners();
    await _save();
  }

  Future<void> applyRemote(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    for (final r in rows) {
      final i = _entries.indexWhere((e) => e.id == r['clientId']);
      final local = i >= 0 ? _entries[i] : null;
      if (local != null && local.dirty) continue; // 端末の変更を優先する
      if (r['deleted'] == true) {
        if (local != null) {
          for (final name in local.photos) {
            await LogPhotos.delete(name);
          }
          _entries.removeAt(i);
        }
        continue;
      }
      final merged = TheaterLogEntry.fromServer(r, local);
      i >= 0 ? _entries[i] = merged : _entries.add(merged);
    }
    _sort();
    notifyListeners();
    await _save();
  }

  /// ログアウトのとき。写真も消す
  Future<void> clearAll() async {
    for (final name in _entries.expand((e) => e.photos).toList()) {
      await LogPhotos.delete(name);
    }
    _entries.clear();
    notifyListeners();
    await _save();
  }

  /// 自分が前に入れた値を、よく使う順に返す（入力の候補）
  List<String> recent(String? Function(TheaterLogEntry) pick) {
    final counts = <String, int>{};
    for (final e in entries) {
      final v = pick(e);
      if (v != null && v.isNotEmpty) counts[v] = (counts[v] ?? 0) + 1;
    }
    return (counts.keys.toList()..sort((a, b) => counts[b]! - counts[a]!));
  }

  int countInYear(int year) => entries.where((e) => e.watchedOn.year == year).length;

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
    // サーバーにある記録かどうかは、編集しても変わらない
    i >= 0 ? _entries[i] = entry.copyWith(onServer: _entries[i].onServer, dirty: true) : _entries.add(entry);
    _sort();
    notifyListeners();
    // 記録の中身は送らない
    AppInsights.logEvent('log_save', parameters: {'linked': entry.playId != null ? 1 : 0, 'has_note': entry.note.isNotEmpty ? 1 : 0});
    await _save();
    onDirty?.call();
  }

  Future<void> remove(String id) async {
    final removed = _entries.where((e) => e.id == id).expand((e) => e.photos).toList();
    for (final name in removed) {
      await LogPhotos.delete(name);
    }
    final i = _entries.indexWhere((e) => e.id == id);
    if (i >= 0) {
      // サーバーにあるものは、削除を伝えるまで印を残す
      _entries[i].onServer ? _entries[i] = _entries[i].copyWith(deleted: true, dirty: true) : _entries.removeAt(i);
    }
    notifyListeners();
    AppInsights.logEvent('log_delete');
    await _save();
    onDirty?.call();
  }
}
