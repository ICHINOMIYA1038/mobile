import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theater_log/account/auth_service.dart';
import 'package:theater_log/catalog/log_photos.dart';
import 'package:theater_log/catalog/theater_log.dart';
import 'package:theater_log/main.dart';

/// 舞台写真の代わりに、照明と人影だけの仮の絵を描いて保存する
Future<String> _fakeStagePhoto() async {
  const w = 1170.0, h = 2532.0;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(0, h), [const Color(0xFF070B1E), const Color(0xFF1A2A62), const Color(0xFF080A18)], [0, 0.78, 1]));
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
  final tmp = File('${Directory.systemTemp.path}/stage.png');
  await tmp.writeAsBytes(png!.buffer.asUint8List());
  return LogPhotos.save(tmp);
}

/// 半券帳の写真表示を通す（中身は動作確認用の仮のデータ）
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('写真のある 1 本、写真のない 1 本、一覧', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const hold = Duration(seconds: 5);
    final photo = await _fakeStagePhoto();
    final repository = CatalogRepository();
    final log = TheaterLog();
    await log.upsert(TheaterLogEntry(id: 'b', title: '動作確認の長い題名の舞台', watchedOn: DateTime(2026, 10, 12), venue: '仮の劇場', rating: 3));
    await log.upsert(TheaterLogEntry(id: 'a', title: '動作確認の舞台', watchedOn: DateTime(2026, 11, 3), showTime: 'soiree', venue: '仮の劇場', seat: '2階B列3番', rating: 4, note: '動作確認用の仮の感想です。最後の場面まで表示を確かめます。', photos: [photo]));
    await tester.pumpWidget(App(repository: repository, catalog: await repository.load(), log: log, auth: AuthService()));
    await tester.pumpAndSettle();
    await Future<void>.delayed(hold);

    await tester.tapAt(const Offset(350, 400));
    await tester.pumpAndSettle();
    await Future<void>.delayed(hold);

    await tester.tap(find.byKey(const Key('log-view-toggle')));
    await tester.pumpAndSettle();
    await Future<void>.delayed(hold);
  });
}
