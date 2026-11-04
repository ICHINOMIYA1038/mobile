import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'sse.dart';

class TrialApi {
  TrialApi({required this.exam, required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String exam;
  final String baseUrl;
  final http.Client _client;
  String? _token;

  String get _path => '/api/v1/$exam';
  String get _tokenKey => 'shikaku_trial_token_$exam';

  Future<void> _ensureUser() async {
    if (_token != null) return;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    if (_token != null) return;
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/users'),
      headers: {'content-type': 'application/json'},
    );
    if (response.statusCode != 201) throw Exception('学習者を作成できませんでした');
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    _token = data['token'] as String;
    await prefs.setString(_tokenKey, _token!);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? body,
    bool retry = true,
  }) async {
    await _ensureUser();
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll({
        'accept': 'application/json',
        'content-type': 'application/json',
        'authorization': 'Bearer $_token',
      });
    if (body != null) request.body = jsonEncode(body);
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401 && retry) {
      _token = null;
      await (await SharedPreferences.getInstance()).remove(_tokenKey);
      return _request(method, path, body: body, retry: false);
    }
    Map<String, dynamic> data;
    try {
      data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('サーバーの応答を読み取れませんでした');
    }
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? data['error'] ?? '通信に失敗しました');
    }
    return data;
  }

  Future<Map<String, dynamic>> home() => _request('GET', '$_path/home');
  Future<Map<String, dynamic>> learn(String chapter) =>
      _request('GET', '$_path/learn/${Uri.encodeComponent(chapter)}');
  Future<Map<String, dynamic>> questions(String chapter) =>
      _request('GET', '$_path/kakomon/${Uri.encodeComponent(chapter)}');
  Future<Map<String, dynamic>> answer(
    String id,
    bool value, {
    String via = 'kakomon',
  }) => _request(
    'POST',
    '$_path/answer',
    body: {'questionId': id, 'answer': value, 'via': via},
  );
  Future<Map<String, dynamic>> review() => _request('GET', '$_path/review');
  Future<Map<String, dynamic>> items() => _request('GET', '$_path/items');
  Future<Map<String, dynamic>> itemSet(String key) =>
      _request('GET', '$_path/items/${Uri.encodeComponent(key)}');
  Future<Map<String, dynamic>> itemAnswer(String id, int choice) => _request(
    'POST',
    '$_path/item-answer',
    body: {'itemId': id, 'choice': choice},
  );

  Future<void> deleteLearningData() async {
    await _request('DELETE', '/api/v1/me');
    _token = null;
    await (await SharedPreferences.getInstance()).remove(_tokenKey);
  }

  Stream<Map<String, dynamic>> chat(String chapter, String message) =>
      _chat(chapter, message, retry: true);

  Stream<Map<String, dynamic>> _chat(
    String chapter,
    String message, {
    required bool retry,
  }) async* {
    await _ensureUser();
    final request = http.Request('POST', Uri.parse('$baseUrl$_path/chat'))
      ..headers.addAll({
        'accept': 'text/event-stream',
        'content-type': 'application/json',
        'authorization': 'Bearer $_token',
      })
      ..body = jsonEncode({'chapterId': chapter, 'message': message});
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 60));
    if (response.statusCode == 401 && retry) {
      await response.stream.drain<void>();
      _token = null;
      await (await SharedPreferences.getInstance()).remove(_tokenKey);
      yield* _chat(chapter, message, retry: false);
      return;
    }
    if (response.statusCode >= 400) {
      throw Exception('先生から返答を受け取れませんでした (${response.statusCode})');
    }
    yield* decodeSse(response.stream);
  }
}
