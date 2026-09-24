import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/doremi_engine.dart';
import '../theme/app_theme.dart';
import 'result_screen.dart';

/// 撮影ガイド付きカメラ画面。
/// プレビューをライブ解析し、認識した五線の領域をその場でくっきり重ねて表示する。
/// 複数枚撮影に対応（ズームして部分ごとに撮る→まとめて読み取り）。
class CaptureScreen extends StatefulWidget {
  final DoremiEngine engine;
  const CaptureScreen({super.key, required this.engine});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  static const MethodChannel _channel =
      MethodChannel('jp.pairof.doremi_scan/engine');

  CameraController? _controller;
  String? _error;
  bool _permissionDenied = false;
  bool _detecting = false;
  bool _shooting = false;
  DateTime _lastDetect = DateTime.fromMillisecondsSinceEpoch(0);

  /// 検出した五線領域（[y0,y1,x0,x1] 比率）。
  List<List<double>> _bands = const [];

  /// 複数枚撮影のたまり。
  final List<String> _shots = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final ctrl = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await ctrl.initialize();
      await ctrl.startImageStream(_onFrame);
      if (!mounted) return;
      setState(() => _controller = ctrl);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code.contains('AccessDenied') ||
            e.code.contains('CameraAccessDenied')) {
          _permissionDenied = true;
          _error = 'カメラへのアクセスが許可されていません。';
        } else {
          _error = 'カメラを起動できませんでした。アプリを再起動してもう一度お試しください。';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'カメラを起動できませんでした。アプリを再起動してもう一度お試しください。');
      }
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    final now = DateTime.now();
    if (_detecting ||
        _shooting ||
        now.difference(_lastDetect).inMilliseconds < 500) {
      return;
    }
    _detecting = true;
    _lastDetect = now;
    try {
      final plane = image.planes[0];
      final w = image.width, h = image.height;
      final stride = plane.bytesPerRow;
      final src = plane.bytes;
      // Y面=グレースケール。縦持ちUIに合わせて時計回り90度回転。
      final rotated = Uint8List(w * h);
      for (var y = 0; y < h; y++) {
        final rowOff = y * stride;
        for (var x = 0; x < w; x++) {
          rotated[x * h + (h - 1 - y)] = src[rowOff + x];
        }
      }
      final res = await _channel.invokeMethod<List<dynamic>>('detectStaves', {
        'gray': rotated,
        'width': h,
        'height': w,
      });
      if (!mounted) return;
      setState(() {
        _bands = (res ?? const [])
            .map((e) => (e as List).map((v) => (v as num).toDouble()).toList())
            .toList();
      });
    } catch (_) {
      // ガイド用途なので握りつぶす
    } finally {
      _detecting = false;
    }
  }

  Future<void> _shoot() async {
    final ctrl = _controller;
    if (ctrl == null || _shooting) return;
    setState(() => _shooting = true);
    try {
      final file = await ctrl.takePicture();
      if (!mounted) return;
      setState(() {
        _shots.add(file.path);
        _shooting = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _shooting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('撮影に失敗しました: $e')));
      }
    }
  }

  Future<void> _finish() async {
    if (_shots.isEmpty) return;
    final ctrl = _controller;
    try {
      await ctrl?.stopImageStream();
    } catch (_) {}
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) =>
          ResultScreen(engine: widget.engine, imagePaths: List.of(_shots)),
    ));
  }

  /// 撮影済み一覧。不要な1枚だけ削除できる（全部撮り直さなくて済むように）。
  Future<void> _showShots(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('撮影した写真（${_shots.length}枚）',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                const Text('ブレた写真は × で削除できます',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _shots.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(_shots[i]),
                              width: 90, height: 120, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Semantics(
                            button: true,
                            label: '${i + 1}枚目を削除',
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _shots.removeAt(i));
                                if (_shots.isEmpty) {
                                  Navigator.of(ctx).pop();
                                } else {
                                  setSheet(() {});
                                }
                              },
                              child: const CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.black54,
                                child: Icon(Icons.close_rounded,
                                    size: 18, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 4,
                          bottom: 4,
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.black54,
                            child: Text('${i + 1}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  /// 撮影済みがあるまま戻ろうとしたら確認する（誤スワイプで全消え防止）。
  Future<bool> _confirmDiscard() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('撮影した写真を破棄しますか？'),
        content: Text('${_shots.length}枚の写真がまだ読み取られていません。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('撮影を続ける')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('破棄する', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    return res ?? false;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// ライブ検出した五線が「読み取りに十分な大きさ」かの目安。
  /// 撮影後の写真は長辺3000pxで送るので、線間隔をその換算で見積もる。
  bool get _bandsTooSmall {
    if (_bands.isEmpty) return false;
    final maxBand = _bands
        .map((b) => b.length >= 2 ? b[1] - b[0] : 0.0)
        .reduce((a, b) => a > b ? a : b);
    return (maxBand / 4) * 3000 < 11.0;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    final found = _bands.length;
    return PopScope(
      canPop: _shots.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_shots.isEmpty ? '楽譜を撮影' : '楽譜を撮影（${_shots.length}枚目まで撮影済み）'),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.no_photography_rounded,
                        size: 56, color: Colors.white54),
                    const SizedBox(height: 16),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: Colors.white, height: 1.6)),
                    const SizedBox(height: 8),
                    if (_permissionDenied)
                      const Text('設定アプリの「ドレミふりがな」でカメラをオンにすると使えます。',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 24),
                    if (_permissionDenied)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(220, 52)),
                        onPressed: () =>
                            _channel.invokeMethod('openSettings'),
                        icon: const Icon(Icons.settings_rounded),
                        label: const Text('設定を開く'),
                      ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('もどる（写真からも選べます）',
                          style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              ),
            )
          : ctrl == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.brand))
              : Column(
                  children: [
                    Expanded(
                      child: Center(
                        // プレビューとオーバーレイを同じ矩形に揃える（座標ズレ防止）
                        child: AspectRatio(
                          aspectRatio: 1 / ctrl.value.aspectRatio,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CameraPreview(ctrl),
                              IgnorePointer(
                                child:
                                    CustomPaint(painter: _BandsPainter(_bands)),
                              ),
                              Positioned(
                                top: 12,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: found == 0
                                          ? Colors.black54
                                          : _bandsTooSmall
                                              ? const Color(0xE6C87817)
                                              : const Color(0xE62E8B6F),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      found == 0
                                          ? '楽譜にかざしてください'
                                          : _bandsTooSmall
                                              ? '楽譜が小さすぎます。近づいて1〜2段を大きく'
                                              : '♪ 五線を認識中（$found段）',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      color: Colors.black,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _shots.isEmpty
                                ? '大きな楽譜は、近づいて数回に分けて撮るときれいに読めます'
                                : '続きがあれば撮影を続け、終わったら「読み取る」へ',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              // 撮影済みサムネイル（タップで一覧・削除）
                              SizedBox(
                                width: 64,
                                height: 64,
                                child: _shots.isEmpty
                                    ? const SizedBox.shrink()
                                    : Semantics(
                                        button: true,
                                        label: '撮影した写真を確認する',
                                        child: GestureDetector(
                                          onTap: () => _showShots(context),
                                          child: Stack(
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.file(
                                                  File(_shots.last),
                                                  width: 64,
                                                  height: 64,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                              Positioned(
                                                right: 2,
                                                top: 2,
                                                child: CircleAvatar(
                                                  radius: 10,
                                                  backgroundColor:
                                                      AppColors.brand,
                                                  child: Text(
                                                    '${_shots.length}',
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.white),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                              ),
                              const Spacer(),
                              Semantics(
                                button: true,
                                label: '撮影する',
                                child: GestureDetector(
                                  onTap: _shoot,
                                  child: Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: found > 0
                                          ? AppColors.brand
                                          : Colors.white24,
                                      border: Border.all(
                                          color: Colors.white, width: 4),
                                    ),
                                    child: _shooting
                                        ? const Padding(
                                            padding: EdgeInsets.all(20),
                                            child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 3),
                                          )
                                        : const Icon(
                                            Icons.photo_camera_rounded,
                                            color: Colors.white,
                                            size: 30),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              SizedBox(
                                width: 96,
                                child: _shots.isEmpty
                                    ? const SizedBox.shrink()
                                    : FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.good,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                        ),
                                        onPressed: _finish,
                                        child: Text('読み取る\n(${_shots.length}枚)',
                                            textAlign: TextAlign.center,
                                            style:
                                                const TextStyle(fontSize: 13)),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

/// 認識した五線領域をくっきり重ねる（枠＋五線を模した5本ライン）。
class _BandsPainter extends CustomPainter {
  final List<List<double>> bands;
  _BandsPainter(this.bands);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = const Color(0x2E2E8B6F);
    final border = Paint()
      ..color = const Color(0xFF2E8B6F)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final lines = Paint()
      ..color = const Color(0xB32E8B6F)
      ..strokeWidth = 1.2;
    for (final b in bands) {
      if (b.length < 4) continue;
      final r = Rect.fromLTRB(
        b[2] * size.width,
        b[0] * size.height,
        b[3] * size.width,
        b[1] * size.height,
      );
      final rr = RRect.fromRectAndRadius(r.inflate(4), const Radius.circular(8));
      canvas.drawRRect(rr, fill..style = PaintingStyle.fill);
      canvas.drawRRect(rr, border);
      // 「認識した」感を出すため、領域内に等間隔の5本線を描く
      for (var i = 0; i < 5; i++) {
        final y = r.top + r.height * (i / 4);
        canvas.drawLine(Offset(r.left, y), Offset(r.right, y), lines);
      }
    }
  }

  @override
  bool shouldRepaint(_BandsPainter old) => old.bands != bands;
}
