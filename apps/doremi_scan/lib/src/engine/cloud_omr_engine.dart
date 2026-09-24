/// クラウドOMR（Audiveris on Cloud Run）を呼ぶエンジン。
///
/// 写真を縮小してサーバーへ送り、主旋律のドレミ列を受け取る。
/// 認識という最難関はサーバー側の専用エンジン(Audiveris)が担う。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/score.dart';
import 'doremi_engine.dart';

class CloudOmrEngine implements DoremiEngine {
  /// Cloud Run のサービスURL。ビルド時 --dart-define=OMR_API_URL=... で注入。
  static const String _baseUrl = String.fromEnvironment('OMR_API_URL');

  /// サーバーと共有する鍵。ビルド時 --dart-define=APP_KEY=... で注入。
  /// 野良クライアントからの利用を防ぎ、費用上限（サーバー側の日次回数制限）を守るためのもの。
  static const String _appKey = String.fromEnvironment('APP_KEY');

  /// 端末ごとの1日の回数制限に使う匿名ID（初回起動時に乱数で生成し端末内に保存）。
  static Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('device_id_v1');
    if (existing != null && existing.isNotEmpty) return existing;
    final rnd = Random.secure();
    final id = List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await prefs.setString('device_id_v1', id);
    return id;
  }

  final Duration timeout;
  CloudOmrEngine({this.timeout = const Duration(seconds: 120)});

  @override
  Future<bool> get isAvailable async => _baseUrl.isNotEmpty;

  @override
  Future<RecognizedScore> recognize(
    String imagePath, {
    void Function(RecognizeProgress)? onProgress,
  }) async {
    if (_baseUrl.isEmpty) {
      throw const RecognizeException(
          'サーバーURLが設定されていません（--dart-define=OMR_API_URL=...）。');
    }
    onProgress?.call(const RecognizeProgress(RecognizePhase.preparing, 0.1));

    // 長辺3000pxまでは縮小しない。2000pxまで縮めると、ページ全体のスクショで
    // 五線の間隔が5px程度になり線が消えて読み落としが激増する。
    final raw = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(raw);
    List<int> bytes = raw;
    if (decoded != null) {
      final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
      if (longest > 3000) {
        // copyResize の既定は最近傍補間で、細い五線が縮小時にごっそり抜ける
        // (iPhone の写真は 4032px なので常にここを通る)。必ず平均化する補間を使う。
        final im = img.copyResize(decoded,
            width: decoded.width >= decoded.height ? 3000 : null,
            height: decoded.height > decoded.width ? 3000 : null,
            interpolation: img.Interpolation.cubic);
        bytes = img.encodeJpg(im, quality: 92);
      }
      // 縮小不要なら元のバイト列をそのまま送る。小さい PNG を JPEG に再圧縮すると、
      // サーバー側の拡大でブロックノイズが五線に化けて段ごと落ちることがあった。
    }

    onProgress?.call(const RecognizeProgress(RecognizePhase.recognizing, 0.4));

    final uri = Uri.parse('$_baseUrl/recognize');
    final req = http.MultipartRequest('POST', uri)
      ..headers['X-App-Key'] = _appKey
      ..headers['X-Device-Id'] = await _deviceId()
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'score.jpg'));
    http.Response res;
    try {
      final streamed = await req.send().timeout(timeout);
      res = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const RecognizeException('認識がタイムアウトしました。通信環境を確認してください。');
    } catch (e) {
      throw RecognizeException('通信に失敗しました: $e');
    }

    onProgress?.call(const RecognizeProgress(RecognizePhase.rendering, 0.9));

    if (res.statusCode != 200) {
      String msg = 'HTTP ${res.statusCode}';
      try {
        msg = (jsonDecode(res.body) as Map<String, dynamic>)['error'] as String? ?? msg;
      } catch (_) {}
      // 429 は回数制限（サーバー側の費用上限）。「エラー」ではなく案内として出す。
      throw RecognizeException(res.statusCode == 429 ? msg : '認識エラー: $msg');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return _toScore(imagePath, data);
  }

  /// サーバーの panels（段画像＋音符ヘッド座標）をデコード。
  List<ScorePanel> _parsePanels(Map<String, dynamic> data) {
    final out = <ScorePanel>[];
    for (final raw in (data['panels'] as List?) ?? const []) {
      final p = Map<String, dynamic>.from(raw as Map);
      final b64 = (p['image_b64'] as String?) ?? '';
      if (b64.isEmpty) continue;
      final cleanB64 = (p['clean_b64'] as String?) ?? '';
      out.add(ScorePanel(
        imageBytes: base64Decode(b64),
        width: (p['w'] as num?)?.toInt() ?? 1,
        height: (p['h'] as num?)?.toInt() ?? 1,
        cleanBytes: cleanB64.isEmpty ? null : base64Decode(cleanB64),
        cleanWidth: (p['clean_w'] as num?)?.toInt() ?? 1,
        cleanHeight: (p['clean_h'] as num?)?.toInt() ?? 1,
        cleanTrusted: (p['clean_ok'] as bool?) ?? true,
        chords: [
          for (final c in (p['chords'] as List?) ?? const [])
            PanelChord(
              xFrac: (((c as Map)['x'] as num?) ?? 0).toDouble(),
              yFrac: ((c['y'] as num?) ?? 0).toDouble(),
              staff: ((c['staff'] as num?) ?? 1).toInt(),
              rubies: [
                for (final r in (c['rubies'] as List?) ?? const []) r as String
              ],
            ),
        ],
        staves: [
          for (final s in (p['staves'] as List?) ?? const [])
            PanelStaff(
              staff: (((s as Map)['staff'] as num?) ?? 1).toInt(),
              topFrac: ((s['top'] as num?) ?? 0).toDouble(),
              bottomFrac: ((s['bottom'] as num?) ?? 0).toDouble(),
              interlineFrac: ((s['interline'] as num?) ?? 0).toDouble(),
            ),
        ],
      ));
    }
    return out;
  }

  /// サーバーの {systems:[{measures:[{notes:[{ruby,pitch,octave,beat,dur}]}]}]} を表示用に変換。
  /// OMRは元写真のピクセル座標を返さないので、段のy=段index、x=段内で拍位置に比例、で配置する。
  RecognizedScore _toScore(String imagePath, Map<String, dynamic> data) {
    final systems = (data['systems'] as List?) ?? const [];
    final notes = <DoremiNote>[];
    for (var s = 0; s < systems.length; s++) {
      final sys = Map<String, dynamic>.from(systems[s] as Map);
      final measures = (sys['measures'] as List?) ?? const [];
      // 段の音符をフラット化（拍位置で等間隔に近い配置）
      final sysNotes = <Map<String, dynamic>>[];
      for (final m in measures) {
        final mm = Map<String, dynamic>.from(m as Map);
        for (final n in (mm['notes'] as List?) ?? const []) {
          sysNotes.add(Map<String, dynamic>.from(n as Map));
        }
      }
      final yFrac = systems.length == 1
          ? 0.4
          : 0.08 + s * (0.84 / systems.length);
      for (var i = 0; i < sysNotes.length; i++) {
        final n = sysNotes[i];
        final ruby = (n['ruby'] as String?) ?? '';
        if (ruby.isEmpty) continue;
        final xFrac = sysNotes.length == 1
            ? 0.5
            : 0.06 + (i / (sysNotes.length - 1)) * 0.88;
        notes.add(DoremiNote(
          ruby: ruby,
          pitch: (n['pitch'] as String?) ?? '',
          xFrac: xFrac,
          yFrac: yFrac,
          duration: (n['dur'] as String?) ?? '',
        ));
      }
    }
    return RecognizedScore(
      sourceImagePath: imagePath,
      imageWidth: 1000,
      imageHeight: 1400,
      elapsedMs: 0,
      notes: notes,
      panels: _parsePanels(data),
      warnings: [
        for (final w in (data['warnings'] as List?) ?? const []) w as String
      ],
      overlayOnImage: false,
      debug: 'cloud systems=${systems.length} notes=${notes.length}',
    );
  }
}
