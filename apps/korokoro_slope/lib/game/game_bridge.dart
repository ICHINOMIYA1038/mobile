import 'dart:async';
import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

import '../data/ad_service.dart';
import '../data/save_service.dart';

/// WebView内のゲーム(three.js側 `web_game/src/bridge.js`)とのJSON-RPC的な通信。
///
/// JS -> Dart: `AppBridge.postMessage(jsonEncode({id, type, payload}))`
/// Dart -> JS: `window.AppBridgeCallback(jsonEncode({id, payload}))`
class GameBridge {
  GameBridge({required this.controller, AdService? adService, SaveService? saveService})
      : _adService = adService ?? AdService(),
        _saveService = saveService ?? SaveService();

  static const channelName = 'AppBridge';

  final WebViewController controller;
  final AdService _adService;
  final SaveService _saveService;

  void attach() {
    controller.addJavaScriptChannel(
      channelName,
      onMessageReceived: (message) => unawaited(_handleMessage(message.message)),
    );
  }

  Future<void> _handleMessage(String raw) async {
    final Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final id = envelope['id'];
    final type = envelope['type'] as String?;
    final payload = envelope['payload'];

    switch (type) {
      case 'gameReady':
        return; // 応答不要のfire-and-forget通知。
      case 'requestInterstitial':
        final shown = await _adService.showInterstitial();
        _reply(id, {'shown': shown});
        return;
      case 'requestRewarded':
        final granted = await _adService.showRewarded();
        _reply(id, {'granted': granted});
        return;
      case 'saveProgress':
        final data = payload is Map ? payload : const {};
        await _saveService.save(
          bestScore: _asInt(data['bestScore']),
          totalCoins: _asInt(data['totalCoins']),
          clearedStages: _asStringList(data['clearedStages']),
        );
        _reply(id, {'ok': true});
        return;
      case 'requestSave':
        final data = await _saveService.load();
        _reply(id, data);
        return;
      default:
        return;
    }
  }

  static int _asInt(Object? value) => (value as num?)?.toInt() ?? 0;

  static List<String> _asStringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList();
  }

  void _reply(Object? id, Object? payload) {
    if (id == null) return;
    // jsonEncodeを二重に適用し、JS側に渡す文字列リテラルとして安全にエスケープする。
    final jsonPayload = jsonEncode({'id': id, 'payload': payload});
    final jsStringLiteral = jsonEncode(jsonPayload);
    controller.runJavaScript('window.AppBridgeCallback($jsStringLiteral)');
  }
}
