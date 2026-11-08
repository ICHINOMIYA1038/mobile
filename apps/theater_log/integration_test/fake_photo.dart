import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:theater_log/catalog/log_photos.dart';

/// 舞台写真の代わりに、照明と人影だけの仮の絵を描いて保存する
Future<String> fakeStagePhoto({int seed = 0}) async {
  const w = 1170.0, h = 2532.0;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(0, h), [const Color(0xFF070B1E), HSVColor.fromAHSV(1, (220 + seed * 47) % 360.0, 0.7, 0.4).toColor(), const Color(0xFF080A18)], [0, 0.78, 1]));
  for (final (sx, tx, bw) in [(300.0, 420.0, 330.0), (880.0, 700.0, 280.0)]) {
    final path = Path()
      ..moveTo(sx - 20, 0)
      ..lineTo(sx + 20, 0)
      ..lineTo(tx + bw, h * 0.84)
      ..lineTo(tx - bw, h * 0.84)
      ..close();
    c.drawPath(path, Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(0, h * 0.84), [const Color(0x80A0B4FF), const Color(0x00A0B4FF)])..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));
  }
  c.drawOval(Rect.fromCenter(center: const Offset(w / 2, h * 0.84), width: w * 0.9, height: h * 0.16), Paint()..color = const Color(0x557890FF)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80));
  for (final (fx, fh) in [(430.0, 820.0), (760.0, 760.0)]) {
    final fy = h * 0.83, s = fh / 6;
    final p = Paint()..color = const Color(0xF0050406);
    c.drawCircle(Offset(fx, fy - fh + s * 0.8), s * 0.62, p);
    c.drawPath(
      Path()
        ..moveTo(fx - s * 1.1, fy)
        ..quadraticBezierTo(fx - s * 1.25, fy - fh * 0.62, fx - s * 0.55, fy - fh + s * 1.7)
        ..lineTo(fx + s * 0.55, fy - fh + s * 1.7)
        ..quadraticBezierTo(fx + s * 1.25, fy - fh * 0.62, fx + s * 1.1, fy)
        ..close(),
      p,
    );
  }
  final image = await rec.endRecording().toImage(w.toInt(), h.toInt());
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final tmp = File('${Directory.systemTemp.path}/stage$seed.png');
  await tmp.writeAsBytes(png!.buffer.asUint8List());
  return LogPhotos.save(tmp);
}

