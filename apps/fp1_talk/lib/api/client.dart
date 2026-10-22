import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

class ApiException implements Exception {
  ApiException(this.status, this.code, [this.message]);
  final int status;

  /// サーバーの error（例: user_cap / global_cap）。無ければ `http_<status>`
  final String code;

  /// 学習者に見せてよい文（サーバーの message）。無ければ null
  final String? message;

  /// 1日の回数の上限（429）・全体の上限（503）
  bool get isOverCap => status == 429 || status == 503;

  @override
  String toString() => 'ApiException($status, $code)';
}

/// サイト（shikaku.pairof.jp）の /api/v1 との通信。仕様はサイトのリポジトリの docs/app-api.md。
/// トークンは匿名の学習者のもの。SharedPreferences に保存し、Authorization: Bearer で送る。
class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? AppConfig.apiBase,
        _http = client ?? http.Client();

  final String baseUrl;
  final http.Client _http;
  String? _token;
  String? userId;

  static const _prefToken = 'ps_token';
  static const _prefUserId = 'ps_user_id';

  String get _examPath => '/api/v1/${AppConfig.exam}';

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        'accept': 'application/json',
        if (_token != null) 'authorization': 'Bearer $_token',
      };

  /// 保存済みのトークンを読むか、無ければ匿名の学習者を作る。
  Future<void> ensureUser() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_prefToken);
    userId = prefs.getString(_prefUserId);
    if (_token != null && userId != null) return;
    await _createUser();
  }

  Future<void> _createUser() async {
    final res = await _http.post(Uri.parse('$baseUrl/api/v1/users'), headers: {'content-type': 'application/json'});
    if (res.statusCode != 201) throw ApiException(res.statusCode, 'create_user_failed');
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    await _saveToken(j['token'] as String, j['userId'] as String);
  }

  Future<void> _saveToken(String token, String id) async {
    final prefs = await SharedPreferences.getInstance();
    _token = token;
    userId = id;
    await prefs.setString(_prefToken, token);
    await prefs.setString(_prefUserId, id);
  }

  /// トークンを捨てる（学習データの削除のあと）。次の通信の前に ensureUser で作り直す。
  Future<void> forgetUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefToken);
    await prefs.remove(_prefUserId);
    _token = null;
    userId = null;
  }

  /// JSON の通信。401（知らないトークン）なら学習者を作り直して1回だけやり直す。
  /// timeout: AI が文章を書く通信（Pro の学習プラン・模擬試験の講評）は長めに待つ
  Future<Map<String, dynamic>> _json(String method, String path, {Object? body, bool retried = false, Duration timeout = const Duration(seconds: 30)}) async {
    if (_token == null) await ensureUser();
    final req = http.Request(method, Uri.parse('$baseUrl$path'))..headers.addAll(_headers);
    if (body != null) req.body = jsonEncode(body);
    final streamed = await _http.send(req).timeout(timeout);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 401 && !retried) {
      await forgetUser();
      await _createUser();
      return _json(method, path, body: body, retried: true, timeout: timeout);
    }
    Map<String, dynamic>? parsed;
    try {
      parsed = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {}
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, parsed?['error']?.toString() ?? 'http_${res.statusCode}', parsed?['message']?.toString() ?? parsed?['error']?.toString());
    }
    return parsed ?? const {};
  }

  // ---------- 試験の画面のデータ（GET /api/v1/fp1/…） ----------

  Future<Map<String, dynamic>> home() => _json('GET', '$_examPath/home');
  Future<Map<String, dynamic>> map() => _json('GET', '$_examPath/map');
  Future<Map<String, dynamic>> learn(String chapterId) => _json('GET', '$_examPath/learn/$chapterId');
  Future<Map<String, dynamic>> kakomonIndex() => _json('GET', '$_examPath/kakomon');

  /// mode: all / wrong / new
  /// point: 章のセット（ch01 など）のうち、その論点の問題だけ
  Future<Map<String, dynamic>> kakomonSet(String set, {String mode = 'all', String? point}) =>
      _json('GET', '$_examPath/kakomon/$set?mode=$mode${point == null ? '' : '&point=${Uri.encodeQueryComponent(point)}'}');
  Future<Map<String, dynamic>> review() => _json('GET', '$_examPath/review');

  /// 本試験形式の問題のまとまり → { credit, sections[], sittings[], chapters[] }（それぞれ { key, label, kind, total, answered, correct }）
  Future<Map<String, dynamic>> itemIndex() => _json('GET', '$_examPath/items');

  /// 1まとまりの問題（回×編 2026-09-kiso・章 ch04）→ { key, label, kind, items[], cases{}, chapters{} }。正解・解説は入らない
  Future<Map<String, dynamic>> itemSet(String set) => _json('GET', '$_examPath/items/${Uri.encodeComponent(set)}');
  Future<Map<String, dynamic>> figures() => _json('GET', '$_examPath/figures');
  Future<Map<String, dynamic>> settings() => _json('GET', '$_examPath/settings');

  Future<List<String>> figureBookmarks() async => ((await _json('GET', '$_examPath/figure-bookmarks'))['ids'] as List? ?? const []).cast<String>();

  /// 本試験形式の問の「AIに聞く」の会話（{ messages: [{ role, text }] }）
  Future<Map<String, dynamic>> itemExplainHistory(String itemId) => _json('GET', '$_examPath/item-explain?itemId=${Uri.encodeQueryComponent(itemId)}');

  /// その問題の「AIに聞く」の会話（{ messages: [{ id, role, text }] }）
  Future<Map<String, dynamic>> explainHistory(String questionId) => _json('GET', '$_examPath/explain?questionId=${Uri.encodeQueryComponent(questionId)}');

  // ---------- 書く ----------

  /// AI を使わない採点 → { correct, explanation, reference, mastered }
  /// via: 答えた画面（kakomon = 過去問演習 / review = 復習）。サーバーは苦手分析（まちがい方の癖・学習量）に使う
  Future<Map<String, dynamic>> answer(String questionId, bool answer, {String? via}) => _json('POST', '$_examPath/answer', body: {'questionId': questionId, 'answer': answer, 'via': ?via});

  /// 本試験形式の問題に答える（AI を使わない採点。回数は減らない）。
  /// choice: 四肢択一の番号（1〜4）、parts: 欄の label → 書いた文字、process: 欄の label → 計算過程を1行ずつ
  /// → { correct, score, answer?, choice?, explanation?, optionNotes?, parts?[{ label, response, ok, unitNote?, unreadable?, answer, unit?, process?, steps?, matchedSteps?, upTo? }] }
  Future<Map<String, dynamic>> itemAnswer(String itemId, {int? choice, Map<String, String>? parts, Map<String, List<String>>? process}) =>
      _json('POST', '$_examPath/item-answer', body: {'itemId': itemId, 'choice': ?choice, 'parts': ?parts, 'process': ?process});

  Future<void> setBookmark(String questionId, bool on) => _json('POST', '$_examPath/bookmarks', body: {'questionId': questionId, 'on': on});
  Future<void> setFigureBookmark(String figureId, bool on) => _json('POST', '$_examPath/figure-bookmarks', body: {'figureId': figureId, 'on': on});

  /// kind: answer / explain / text / other
  Future<void> reportQuestion({required String questionId, required String kind, String? note, bool? myAnswer, required String shownOn}) =>
      _json('POST', '$_examPath/question-report', body: {'questionId': questionId, 'kind': kind, 'note': ?note, 'myAnswer': myAnswer, 'shownOn': shownOn});

  /// rating: clear / unclear / wrong / idea
  Future<void> figureFeedback({required String figureId, required String rating, String? note, required String shownOn}) =>
      _json('POST', '$_examPath/figure-feedback', body: {'figureId': figureId, 'rating': rating, 'note': ?note, 'shownOn': shownOn});

  /// 先生の返答の報告。kind: wrong / confusing / off_topic / no_choice / other
  Future<void> reportMessage({required String messageId, required String kind, String? note}) =>
      _json('POST', '$_examPath/feedback', body: {'messageId': messageId, 'kind': kind, 'note': ?note});

  /// 試験日（YYYY-MM-DD か null）・呼び名・進め方（drill / standard / fast）。渡したものだけ変える
  Future<void> patchSettings(Map<String, Object?> changes) => _json('PATCH', '$_examPath/settings', body: changes);

  // ---------- Pro だけの機能（/pro/…。Pro でなければ模擬試験は 403 pro_required、分析は pro: false で科目ごとの数字だけ） ----------

  /// 苦手分析と学習プラン → { pro, report, plan, plansLeft }（形はサイトの src/lib/server/analysis.ts の Report と pro.ts の Plan。docs/pro-analysis.md）。
  /// プランはその日の最初の GET で AI が作る（10〜20秒かかる）。refresh で作り直す（1日3回まで。plansLeft）。Pro でない人は report の予測点と科目だけ
  Future<Map<String, dynamic>> proAnalysis({bool refresh = false}) => refresh
      ? _json('POST', '$_examPath/pro/analysis', body: {'refresh': true}, timeout: const Duration(seconds: 60))
      : _json('GET', '$_examPath/pro/analysis', timeout: const Duration(seconds: 60));

  /// 7日の予定のタスクを自分で済み・未済みにする（自動で済みになったものも外せる）→ { plan }（進み具合つき）
  Future<Map<String, dynamic>> checkPlanTask({required num planAt, required String taskId, required bool done}) =>
      _json('POST', '$_examPath/pro/plan/check', body: {'planAt': planAt, 'taskId': taskId, 'done': done});

  /// 模擬試験を始める（FP1 は編を選ぶ: kiso / ouyou）→ { id, section{key,label,minutes,estimated,estimateNote}, deadline, now, seconds, max, passLine, cases{}, items[…, subject, chapter, points[]] }。
  /// 正解・解説は入らない（サイトの itemmock.ts。docs/app-api.md の「本試験形式の試験（FP1）の模擬試験」）
  Future<Map<String, dynamic>> startMock(String section) => _json('POST', '$_examPath/pro/mock', body: {'section': section});

  /// 答えを出す（answers: 問の id → { choice } か { parts, process }。答えていない問は入れない）
  /// → 結果（score・max・passLine・passed・bySubject・review、items[].response・result（正解・解説・計算過程）・earned）
  Future<Map<String, dynamic>> submitMock(String id, Map<String, Object> answers, int seconds) =>
      _json('POST', '$_examPath/pro/mock/${Uri.encodeComponent(id)}', body: {'answers': answers, 'seconds': seconds}, timeout: const Duration(seconds: 60));

  /// 模擬試験の入口 → { kind: items, pro, plans[{ key, label, minutes, kind: choice|case, planned, available, maxPoints, estimated, estimateNote, missing[] }],
  /// passLine, scoreTotal, passLineNote, forecast, history[{ id, section, label, finishedAt, score, max, passLine }], open[{ id, section, label, deadline }] }
  Future<Map<String, dynamic>> mockHistory() => _json('GET', '$_examPath/pro/mock');
  Future<Map<String, dynamic>> mockResult(String id) => _json('GET', '$_examPath/pro/mock/${Uri.encodeComponent(id)}');

  // ---------- 自分 ----------

  /// ?exam= を付ける（Pro は試験ごと。付けないとサイトは宅建の Pro かを返す）
  Future<Map<String, dynamic>> me() => _json('GET', '/api/v1/me?exam=${AppConfig.exam}');

  /// 学習データを全部消して、新しい匿名の学習者になる
  Future<void> deleteMe() async {
    await _json('DELETE', '/api/v1/me');
    await forgetUser();
    await _createUser();
  }

  // ---------- SSE（会話・AIに聞く） ----------

  /// 章の会話を1ターン送る。body: { chapterId, message?, answer?: {questionId, answer}, start?, pointId? }
  /// イベントはサイトの TutorEvent（type: text / question / graded / progress / figure / topic / point / choices / navigate / done / error）
  Stream<Map<String, dynamic>> chat(Map<String, Object?> body) => _sse('$_examPath/chat', body);

  /// 過去問の「AIに聞く」。answer は画面で答えた○×（無ければヒントだけ）。イベントは text / done / error
  Stream<Map<String, dynamic>> explain({required String questionId, String? message, bool? answer}) =>
      _sse('$_examPath/explain', {'questionId': questionId, 'message': ?message, 'answer': ?answer});

  /// 本試験形式の問の「AIに聞く」。response は item-answer に送ったもの（{ choice } か { parts, process }。無ければヒントだけ）。
  /// 正解・解説はサーバーが入れる。イベントは text / done / error（explain と同じ）
  Stream<Map<String, dynamic>> itemExplain({required String itemId, String? message, Map<String, Object>? response}) =>
      _sse('$_examPath/item-explain', {'itemId': itemId, 'message': ?message, 'response': ?response});

  /// 上限（429/503）などはストリームが始まる前に ApiException で投げる。
  Stream<Map<String, dynamic>> _sse(String path, Map<String, Object?> body, {bool retried = false}) async* {
    if (_token == null) await ensureUser();
    final req = http.Request('POST', Uri.parse('$baseUrl$path'))
      ..headers.addAll(_headers)
      ..headers['accept'] = 'text/event-stream'
      ..body = jsonEncode(body);
    final res = await _http.send(req).timeout(const Duration(seconds: 60));
    if (res.statusCode == 401 && !retried) {
      await res.stream.drain<void>();
      await forgetUser();
      await _createUser();
      yield* _sse(path, body, retried: true);
      return;
    }
    if (res.statusCode >= 400) {
      final text = await res.stream.bytesToString();
      Map<String, dynamic>? parsed;
      try {
        parsed = jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {}
      throw ApiException(res.statusCode, parsed?['error']?.toString() ?? 'http_${res.statusCode}', parsed?['message']?.toString());
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
            yield jsonDecode(data) as Map<String, dynamic>;
          } catch (_) {
            // 壊れたフレームは読み飛ばす
          }
        }
      }
    }
  }
}
