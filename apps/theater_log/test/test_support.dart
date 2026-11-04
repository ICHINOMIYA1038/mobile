import 'package:theater_log/account/auth_service.dart';
import 'package:theater_log/account/log_sync.dart';
import 'package:theater_log/catalog/theater_log.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryTokenStore implements TokenStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// どこにも接続しない認証（未ログイン）
AuthService offlineAuth() => AuthService(store: MemoryTokenStore(), client: MockClient((_) async => http.Response('{}', 503)));

LogSync offlineSync(AuthService auth, TheaterLog log) => LogSync(auth: auth, log: log, client: MockClient((_) async => http.Response('{}', 503)));
