import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

class ApiException implements Exception {
  ApiException(this.status, this.code, [this.body]);
  final int status;
  final String code;
  final Map<String, dynamic>? body;

  bool get isPaymentRequired => status == 402;
  bool get isOverCapacity => status == 503;

  @override
  String toString() => 'ApiException($status, $code)';
}

/// バックエンドとの通信。トークンは SharedPreferences に保存する匿名IDなので、
/// アプリを消すと別人になる(復元は「購入を復元」で RevenueCat 側から行う)。
class ApiClient {
  ApiClient(this.baseUrl, {http.Client? client}) : _http = client ?? http.Client();

  final String baseUrl;
  final http.Client _http;
  String? _token;
  String? userId;

  static const _prefToken = 'tt_token';
  static const _prefUserId = 'tt_user_id';

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (_token != null) 'authorization': 'Bearer $_token',
      };

  /// 保存済みトークンを読むか、無ければ匿名ユーザーを作る。
  Future<void> ensureUser() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_prefToken);
    userId = prefs.getString(_prefUserId);
    if (_token != null && userId != null) return;
    final res = await _http.post(Uri.parse('$baseUrl/v1/users'), headers: _headers);
    if (res.statusCode != 201) throw ApiException(res.statusCode, 'create_user_failed');
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    _token = j['token'] as String;
    userId = j['userId'] as String;
    await prefs.setString(_prefToken, _token!);
    await prefs.setString(_prefUserId, userId!);
  }

  Future<void> forgetUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefToken);
    await prefs.remove(_prefUserId);
    _token = null;
    userId = null;
  }

  Future<Map<String, dynamic>> _json(String method, String path, {Object? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final req = http.Request(method, uri)..headers.addAll(_headers);
    if (body != null) req.body = jsonEncode(body);
    final streamed = await _http.send(req).timeout(const Duration(seconds: 20));
    final res = await http.Response.fromStream(streamed);
    Map<String, dynamic>? parsed;
    try {
      parsed = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {}
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, parsed?['error']?.toString() ?? 'http_${res.statusCode}', parsed);
    }
    return parsed ?? const {};
  }

  Future<Me> me() async => Me.fromJson(await _json('GET', '/v1/me'));

  Future<void> patchMe({String? examDate, String? nickname, bool clearExamDate = false}) async {
    await _json('PATCH', '/v1/me', body: {
      if (examDate != null || clearExamDate) 'examDate': examDate,
      'nickname': ?nickname,
    });
  }

  Future<void> deleteMe() async {
    await _json('DELETE', '/v1/me');
    await forgetUser();
  }

  Future<({List<HistoryMessage> messages, String? currentTopic})> messages(String chapterId) async {
    final j = await _json('GET', '/v1/chapters/$chapterId/messages');
    return (
      messages: ((j['messages'] as List?) ?? const [])
          .map((m) => HistoryMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
      currentTopic: j['currentTopic'] as String?,
    );
  }

  /// 章の図解をまとめて取る。会話の外から体系を眺めるための画面で使う。
  Future<List<Figure>> figures(String chapterId) async {
    final j = await _json('GET', '/v1/chapters/$chapterId/figures');
    return ((j['figures'] as List?) ?? const []).map((f) => Figure.fromJson(f as Map<String, dynamic>)).toList();
  }

  /// 全章の図解。図解ライブラリが章をまたいで検索するために使う。
  Future<List<Figure>> allFigures() async {
    final j = await _json('GET', '/v1/figures');
    return ((j['figures'] as List?) ?? const []).map((f) => Figure.fromJson(f as Map<String, dynamic>)).toList();
  }

  Future<Entitlement> entitlement(String chapterId) async =>
      Entitlement.fromJson(await _json('GET', '/v1/chapters/$chapterId/entitlement'));

  /// 1ターン送って、SSE をイベントの Stream にして返す。
  /// 402(要課金)/503(混雑) はストリームが始まる前に [ApiException] で投げる。
  Stream<TutorEvent> chat({
    required String chapterId,
    String? message,
    ({String questionId, bool answer})? answer,
    bool start = false,
  }) async* {
    final req = http.Request('POST', Uri.parse('$baseUrl/v1/chat'))
      ..headers.addAll(_headers)
      ..body = jsonEncode({
        'chapterId': chapterId,
        'message': ?message,
        if (answer != null) 'answer': {'questionId': answer.questionId, 'answer': answer.answer},
        if (start) 'start': true,
      });
    final res = await _http.send(req).timeout(const Duration(seconds: 30));
    if (res.statusCode >= 400) {
      final text = await res.stream.bytesToString();
      Map<String, dynamic>? parsed;
      try {
        parsed = jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {}
      throw ApiException(res.statusCode, parsed?['error']?.toString() ?? 'http_${res.statusCode}', parsed);
    }
    var buffer = '';
    await for (final chunk in res.stream.transform(utf8.decoder)) {
      buffer += chunk;
      while (true) {
        final idx = buffer.indexOf('\n\n');
        if (idx < 0) break;
        final frame = buffer.substring(0, idx);
        buffer = buffer.substring(idx + 2);
        for (final line in frame.split('\n')) {
          if (!line.startsWith('data:')) continue;
          final data = line.substring(5).trim();
          if (data.isEmpty) continue;
          try {
            final ev = TutorEvent.fromJson(jsonDecode(data) as Map<String, dynamic>);
            if (ev != null) yield ev;
          } catch (_) {
            // 壊れたフレームは読み飛ばす
          }
        }
      }
    }
  }
}
