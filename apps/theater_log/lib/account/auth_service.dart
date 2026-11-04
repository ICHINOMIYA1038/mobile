import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

/// トークンの保存先。テストでは差し替える
abstract class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureTokenStore implements TokenStore {
  static const _s = FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) => _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

class Pkce {
  Pkce(this.verifier) : challenge = base64Url.encode(sha256.convert(ascii.encode(verifier)).bytes).replaceAll('=', '');
  final String verifier;
  final String challenge;

  factory Pkce.generate() {
    final r = Random.secure();
    return Pkce(base64Url.encode(List.generate(48, (_) => r.nextInt(256))).replaceAll('=', ''));
  }
}

class AccountUser {
  const AccountUser(this.id, this.displayName, {this.banned = false});
  final String id;
  final String? displayName;

  /// 運営が公開を止めている
  final bool banned;
}

class SignInCancelled implements Exception {}

typedef WebAuth = Future<String> Function(String url, String scheme);

/// 戯曲 ID（Supabase Auth）でのログイン。アプリ内のブラウザで PKCE を行う
class AuthService extends ChangeNotifier {
  AuthService({http.Client? client, TokenStore? store, WebAuth? webAuth, DateTime Function()? now})
    : _http = client ?? http.Client(),
      _store = store ?? SecureTokenStore(),
      _webAuth = webAuth ?? ((url, scheme) => FlutterWebAuth2.authenticate(url: url, callbackUrlScheme: scheme)),
      _now = now ?? DateTime.now;

  static const authUrl = 'https://tujkphrlvcbxbrrkagsj.supabase.co/auth/v1';
  static const apiUrl = 'https://gikyokutosyokan.com/api/app';
  // 公開してよい鍵（アプリに埋め込む前提）
  static const publishableKey = 'sb_publishable_KVrNhxScq_cRrpgSoIMQTQ_7rJK5hTL';
  static const scheme = 'gikyokutheaterlog';
  static const redirect = '$scheme://auth-callback';

  final http.Client _http;
  final TokenStore _store;
  final WebAuth _webAuth;
  final DateTime Function() _now;

  AccountUser? user;
  String? _access;
  String? _refresh;
  DateTime? _expires;

  bool get signedIn => user != null;

  Future<void> restore() async {
    _refresh = await _store.read('refresh');
    final id = await _store.read('user_id');
    if (_refresh != null && id != null) user = AccountUser(id, await _store.read('display_name'));
    notifyListeners();
  }

  Future<void> signIn(String provider) async {
    final pkce = Pkce.generate();
    final url = Uri.parse('$authUrl/authorize').replace(queryParameters: {'provider': provider, 'redirect_to': redirect, 'code_challenge': pkce.challenge, 'code_challenge_method': 's256'});
    final String result;
    try {
      result = await _webAuth(url.toString(), scheme);
    } catch (e) {
      if ('$e'.contains('CANCELED') || '$e'.contains('cancel')) throw SignInCancelled();
      rethrow;
    }
    final code = Uri.parse(result).queryParameters['code'];
    if (code == null) throw StateError('ログインの結果を受け取れませんでした');
    await _tokenRequest('pkce', {'auth_code': code, 'code_verifier': pkce.verifier});
    final res = await _http.post(Uri.parse('$apiUrl/session'), headers: {'authorization': 'Bearer $_access'}).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw StateError('サーバーに接続できませんでした（${res.statusCode}）');
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    await _setUser(AccountUser(j['id'] as String, j['displayName'] as String?, banned: j['banned'] == true));
  }

  Future<void> _setUser(AccountUser u) async {
    user = u;
    await _store.write('user_id', u.id);
    u.displayName == null ? await _store.delete('display_name') : await _store.write('display_name', u.displayName!);
    notifyListeners();
  }

  Future<void> _tokenRequest(String grant, Map<String, String> body) async {
    final res = await _http
        .post(Uri.parse('$authUrl/token?grant_type=$grant'), headers: {'apikey': publishableKey, 'content-type': 'application/json'}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw AuthExpired();
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    _access = j['access_token'] as String;
    _refresh = j['refresh_token'] as String;
    _expires = _now().add(Duration(seconds: (j['expires_in'] as num).toInt() - 60));
    await _store.write('refresh', _refresh!);
  }

  /// 有効なアクセストークン。未ログインなら null。切れていれば取り直す
  Future<String?> accessToken() async {
    if (_refresh == null) return null;
    if (_access != null && _expires != null && _now().isBefore(_expires!)) return _access;
    try {
      await _tokenRequest('refresh_token', {'refresh_token': _refresh!});
    } on AuthExpired {
      await clear();
      return null;
    }
    return _access;
  }

  /// 公開の停止など、サーバーの状態を読み直す。失敗しても今の状態のまま
  Future<void> refreshProfile() async {
    final token = await accessToken();
    if (token == null) return;
    try {
      final res = await _http.post(Uri.parse('$apiUrl/session'), headers: {'authorization': 'Bearer $token'}).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      await _setUser(AccountUser(j['id'] as String, j['displayName'] as String?, banned: j['banned'] == true));
    } catch (_) {
      // 次の起動で読み直す
    }
  }

  Future<void> setDisplayName(String name) async {
    final token = await accessToken();
    if (token == null) throw AuthExpired();
    final res = await _http.patch(Uri.parse('$apiUrl/session'), headers: {'authorization': 'Bearer $token', 'content-type': 'application/json'}, body: jsonEncode({'displayName': name})).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw StateError('名前を変更できませんでした');
    await _setUser(AccountUser(user!.id, name));
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    _expires = null;
    user = null;
    for (final k in ['refresh', 'user_id', 'display_name']) {
      await _store.delete(k);
    }
    notifyListeners();
  }
}

class AuthExpired implements Exception {}
