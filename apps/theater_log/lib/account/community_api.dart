import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class Review {
  const Review({required this.id, required this.authorId, required this.authorName, required this.note, this.rating, this.groupName, this.venueName, this.watchedMonth, this.title, this.postId});
  final String id;
  final String authorId;
  final String authorName;
  final String note;
  final int? rating;
  final String? groupName;
  final String? venueName;
  final String? watchedMonth;
  final String? title;
  final int? postId;

  factory Review.fromJson(Map<String, dynamic> j) => Review(
    id: j['id'] as String,
    authorId: j['authorId'] as String,
    authorName: j['authorName'] as String,
    note: j['note'] as String,
    rating: j['rating'] as int?,
    groupName: j['groupName'] as String?,
    venueName: j['venueName'] as String?,
    watchedMonth: j['watchedMonth'] as String?,
    title: j['title'] as String?,
    postId: j['postId'] as int?,
  );
}

class Production {
  const Production({required this.id, required this.title, this.groupName, this.venueName, this.startDate, this.endDate, this.status = 'approved'});
  final int id;
  final String title;
  final String? groupName;
  final String? venueName;
  final String? startDate;
  final String? endDate;
  final String status;

  factory Production.fromJson(Map<String, dynamic> j) => Production(
    id: j['id'] as int,
    title: j['title'] as String,
    groupName: j['groupName'] as String?,
    venueName: j['venueName'] as String?,
    startDate: j['startDate'] as String?,
    endDate: j['endDate'] as String?,
    status: (j['status'] as String?) ?? 'approved',
  );

  String get label => [title, groupName, venueName, startDate].whereType<String>().join('／');
}

class CommunityError implements Exception {
  CommunityError(this.message);
  final String message;
}

class CommunityApi {
  CommunityApi(this.auth, {http.Client? client}) : _http = client ?? http.Client();
  final AuthService auth;
  final http.Client _http;
  static const _timeout = Duration(seconds: 20);
  Uri _u(String path, [Map<String, String>? q]) => Uri.parse('${AuthService.apiUrl}$path').replace(queryParameters: q);

  Future<Map<String, String>> _headers({bool required = false}) async {
    final t = await auth.accessToken();
    if (t == null && required) throw CommunityError('ログインしてください');
    return {if (t != null) 'authorization': 'Bearer $t', 'content-type': 'application/json'};
  }

  void _check(http.Response r) {
    if (r.statusCode == 429) throw CommunityError('短い時間に操作が集中しました。少し待ってからお試しください');
    if (r.statusCode >= 300) throw CommunityError('うまくいきませんでした。少し待ってからお試しください');
  }

  dynamic _json(http.Response r) => jsonDecode(utf8.decode(r.bodyBytes));

  Future<List<Review>> reviews({int? postId, int? productionId}) async {
    final r = await _http.get(_u('/reviews', {'postId': ?postId?.toString(), 'productionId': ?productionId?.toString()}), headers: await _headers()).timeout(_timeout);
    _check(r);
    return ((_json(r) as Map<String, dynamic>)['reviews'] as List).map((e) => Review.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Review>> feed() async {
    final r = await _http.get(_u('/feed'), headers: await _headers()).timeout(_timeout);
    _check(r);
    return ((_json(r) as Map<String, dynamic>)['reviews'] as List).map((e) => Review.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> report(String reviewId, String reason) async {
    final r = await _http.post(_u('/reports'), headers: await _headers(required: true), body: jsonEncode({'reviewId': reviewId, 'reason': reason})).timeout(_timeout);
    _check(r);
  }

  Future<void> block(String userId) async {
    final r = await _http.put(_u('/blocks/$userId'), headers: await _headers(required: true)).timeout(_timeout);
    _check(r);
  }

  Future<List<Production>> productions({String? query, int? postId}) async {
    final r = await _http.get(_u('/productions', {if (query != null && query.trim().isNotEmpty) 'q': query.trim(), 'postId': ?postId?.toString()}), headers: await _headers()).timeout(_timeout);
    _check(r);
    return ((_json(r) as Map<String, dynamic>)['productions'] as List).map((e) => Production.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Production> createProduction(Map<String, Object?> body) async {
    final r = await _http.post(_u('/productions'), headers: await _headers(required: true), body: jsonEncode(body)).timeout(_timeout);
    _check(r);
    return Production.fromJson(_json(r) as Map<String, dynamic>);
  }
}
