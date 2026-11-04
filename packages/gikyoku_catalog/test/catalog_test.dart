import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _json({int id = 1, String title = '作品', int? man, int? woman, int? others, int? total, int? minutes, String? readUrl, List<int> cats = const []}) => {
  'id': id, 'title': title, 'author': '作者', 'man': man, 'woman': woman, 'others': others, 'total': total, 'minutes': minutes,
  'synopsis': null, 'aiDescription': null, 'readUrl': readUrl, 'buyUrl': null, 'categoryIds': cats, 'awards': [], 'groups': [],
};
Play _play({int id = 1, String title = '作品', int? man, int? woman, int? others, int? total, int? minutes, String? readUrl, List<int> cats = const []}) =>
    Play.fromJson(_json(id: id, title: title, man: man, woman: woman, others: others, total: total, minutes: minutes, readUrl: readUrl, cats: cats));

class _Bundle extends CachingAssetBundle {
  _Bundle(this.body);
  final String body;
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(utf8.encode(body));
  @override
  Future<String> loadString(String key, {bool cache = true}) async => body;
}

void main() {
  group('Play', () {
    test('元データの不明な値（-1 や 0）を不明として扱う', () {
      final p = _play(man: 0, woman: 0, others: 0, total: 0, minutes: -1);
      expect(p.cast, isNull);
      expect(p.castLabel, '人数不明');
      expect(p.minutes, isNull);
    });
    test('合計が無ければ内訳から出す。内訳があれば見せる', () {
      expect(_play(man: 2, woman: 3).cast, 5);
      expect(_play(man: 2, woman: 3).castLabel, '5人（男2・女3）');
      expect(_play(total: 7).castLabel, '7人');
    });
    test('同梱のカタログを読める', () {
      final c = Catalog.fromJson(jsonDecode(File('assets/catalog.json').readAsStringSync()) as Map<String, dynamic>);
      expect(c.plays.length, greaterThan(1000));
      expect(c.plays.map((p) => p.id).toSet().length, c.plays.length);
    });
    test('知らない版のカタログは読まない', () {
      expect(() => Catalog.fromJson({'schemaVersion': 99}), throwsFormatException);
    });
  });

  group('CatalogRepository', () {
    late Directory dir;
    final fresh = jsonEncode({'schemaVersion': 1, 'generatedAt': '2026-11-04T00:00:00Z', 'categories': [], 'plays': [_json(id: 9)]});
    final bundled = jsonEncode({'schemaVersion': 1, 'generatedAt': '2026-01-01T00:00:00Z', 'categories': [], 'plays': [_json(id: 1)]});

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      dir = Directory.systemTemp.createTempSync('catalog');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    CatalogRepository repo(http.Client c) => CatalogRepository(client: c, directory: () async => dir, bundle: _Bundle(bundled));

    test('通信できなくても同梱の版を使える', () async {
      final r = repo(MockClient((_) async => throw const SocketException('offline')));
      expect((await r.load()).plays.single.id, 1);
      expect(await r.refresh(), isNull);
    });
    test('新しい版を保存し、次回はそれを読む。変更なしなら 304 で済ませる', () async {
      final seen = <String?>[];
      final r = repo(MockClient((req) async {
        seen.add(req.headers['If-None-Match']);
        if (req.headers['If-None-Match'] == 'v1') return http.Response('', 304);
        return http.Response.bytes(utf8.encode(fresh), 200, headers: {'etag': 'v1'});
      }));
      expect((await r.refresh())!.plays.single.id, 9);
      expect((await r.load()).plays.single.id, 9);
      expect(await r.refresh(), isNull);
      expect(seen, [null, 'v1']);
    });
    test('壊れた応答で今の版を壊さない', () async {
      final r = repo(MockClient((_) async => http.Response('{壊れている', 200)));
      expect(await r.refresh(), isNull);
      expect((await r.load()).plays.single.id, 1);
    });
  });
}
