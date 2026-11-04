import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// 作品カタログ。同梱の版か保存済みの版をすぐ出し、裏で新しい版を取りに行く。圏外でも使える
class CatalogRepository {
  CatalogRepository({http.Client? client, Future<Directory> Function()? directory, AssetBundle? bundle})
    : _http = client ?? http.Client(),
      _directory = directory ?? getApplicationSupportDirectory,
      _bundle = bundle ?? rootBundle;

  static const url = 'https://gikyokutosyokan.com/api/app/catalog';
  static const _etagKey = 'catalog_etag';

  final http.Client _http;
  final Future<Directory> Function() _directory;
  final AssetBundle _bundle;

  Future<File> _file() async => File('${(await _directory()).path}/catalog.json');

  Future<Catalog> load() async {
    try {
      final f = await _file();
      if (await f.exists()) return _parse(await f.readAsString());
    } catch (_) {
      // 保存した版が壊れていたら同梱の版を使う
    }
    return _parse(await _bundle.loadString('assets/catalog.json'));
  }

  Catalog _parse(String body) => Catalog.fromJson(jsonDecode(body) as Map<String, dynamic>);

  /// 新しい版があれば保存して返す。変更なし・失敗は null（今の版を使い続ける）
  Future<Catalog?> refresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final etag = prefs.getString(_etagKey);
      final res = await _http.get(Uri.parse(url), headers: {'If-None-Match': ?etag}).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final body = utf8.decode(res.bodyBytes);
      final catalog = _parse(body);
      await (await _file()).writeAsString(body, flush: true);
      final newTag = res.headers['etag'];
      if (newTag != null) await prefs.setString(_etagKey, newTag);
      return catalog;
    } catch (_) {
      return null;
    }
  }
}
