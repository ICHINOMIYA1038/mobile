import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../catalog/theater_log.dart';
import 'auth_service.dart';

/// 端末の記録とサーバーをそろえる。端末で変えたものを先に送り、そのあと差分を受け取る。
/// 写真は送らない
class LogSync {
  LogSync({required this.auth, required this.log, http.Client? client}) : _http = client ?? http.Client();
  final AuthService auth;
  final TheaterLog log;
  final http.Client _http;
  bool _running = false;
  bool _again = false;

  String _sinceKey(String userId) => 'log_sync_since_$userId';

  /// 送れなかった分は dirty のまま残り、次の同期で送る
  Future<bool> run() async {
    if (_running) {
      _again = true;
      return false;
    }
    _running = true;
    try {
      do {
        _again = false;
        final token = await auth.accessToken();
        final userId = auth.user?.id;
        if (token == null || userId == null) return false;
        final headers = {'authorization': 'Bearer $token', 'content-type': 'application/json'};
        // 記録が多い人でも、1 件ごとに端末へ全件を書き直さない。最後にまとめて書く
        var pushed = 0;
        try {
          for (final e in log.dirtyEntries) {
            final url = Uri.parse('${AuthService.apiUrl}/logs/${e.id}');
            final res = e.deleted ? await _http.delete(url, headers: headers).timeout(_timeout) : await _http.put(url, headers: headers, body: jsonEncode(e.toServerJson())).timeout(_timeout);
            if (res.statusCode >= 300) return false;
            await log.markPushed(e, e.deleted ? null : jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>, persist: false);
            pushed++;
          }
        } finally {
          if (pushed > 0) await log.flush();
        }
        final prefs = await SharedPreferences.getInstance();
        // サーバーは 1 回に [_page] 件まで返す。満杯なら続きを取りに行く
        while (true) {
          final since = prefs.getString(_sinceKey(userId));
          final url = Uri.parse('${AuthService.apiUrl}/logs').replace(queryParameters: {'since': ?since});
          final res = await _http.get(url, headers: headers).timeout(_timeout);
          if (res.statusCode != 200) return false;
          final rows = ((jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>)['logs'] as List).cast<Map<String, dynamic>>();
          await log.applyRemote(rows);
          if (rows.isEmpty) break;
          await prefs.setString(_sinceKey(userId), rows.last['updatedAt'] as String);
          if (rows.length < _page) break;
        }
      } while (_again);
      return true;
    } catch (_) {
      return false;
    } finally {
      _running = false;
    }
  }

  static const _timeout = Duration(seconds: 20);
  static const _page = 1000;

  /// ログアウト。送り切ってから端末の記録を消す（共用の端末で次の人に残さない）。
  /// 送れないものがあれば、force でない限り消さずに false を返す
  Future<bool> signOut({bool force = false}) async {
    await run();
    if (!force && log.dirtyEntries.isNotEmpty) return false;
    final userId = auth.user?.id;
    if (userId != null) await (await SharedPreferences.getInstance()).remove(_sinceKey(userId));
    await log.clearAll();
    await auth.clear();
    return true;
  }
}
