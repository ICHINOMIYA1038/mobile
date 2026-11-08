import 'package:flutter/material.dart';

import '../catalog/log_photos.dart';
import '../catalog/theater_log.dart';
import '../theme.dart';
import 'pon_stamp.dart';

/// 切り込みのある半券の形
class StubClipper extends CustomClipper<Path> {
  const StubClipper({this.tearAt = 86, this.notch = 9});
  final double tearAt;
  final double notch;

  @override
  Path getClip(Size size) {
    final body = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)));
    final holes = Path()
      ..addOval(Rect.fromCircle(center: Offset(tearAt, 0), radius: notch))
      ..addOval(Rect.fromCircle(center: Offset(tearAt, size.height), radius: notch));
    return Path.combine(PathOperation.difference, body, holes);
  }

  @override
  bool shouldReclip(StubClipper old) => old.tearAt != tearAt || old.notch != notch;
}

class _Perforation extends CustomPainter {
  const _Perforation(this.x, this.color);
  final double x;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    for (double y = 12; y < size.height - 10; y += 8) {
      canvas.drawLine(Offset(x, y), Offset(x, y + 4), p);
    }
  }

  @override
  bool shouldRepaint(_Perforation old) => old.x != x || old.color != color;
}

/// 記録ごとに定式幕の三色のどれかを使う（並べると幕のように見える）
const _stubColors = [Palette.sumi, Palette.kaki, Palette.moegi];

Color stubColorOf(String id) => _stubColors[id.codeUnits.fold(0, (a, b) => a + b) % _stubColors.length];

class TicketStub extends StatelessWidget {
  const TicketStub({super.key, required this.entry, this.onTap, this.trailing, this.showSeal = false, this.textInset = 8});
  final TheaterLogEntry entry;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// 押された印を右下に残す（半券帳で並べて眺めるとき）
  final bool showSeal;

  /// 本文の右の余白。大きなハンコを重ねる画面で広げる
  final double textInset;

  @override
  Widget build(BuildContext context) {
    final color = stubColorOf(entry.id);
    final d = entry.watchedOn;
    final place = [entry.group, entry.venue].whereType<String>().join('／');
    final stub = ClipPath(
      clipper: const StubClipper(),
      child: Material(
        color: Palette.card,
        child: InkWell(
          onTap: onTap,
          child: CustomPaint(
            painter: _Perforation(86, Palette.line),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 86,
                    color: color,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${d.year}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                        Text('${d.month}.${d.day}', style: const TextStyle(fontFamily: displayFont, fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white)),
                        if (entry.showTime != null) Text(entry.showTime == 'matinee' ? '昼' : '夜', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, textInset, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: titleFont, fontSize: 17, fontWeight: FontWeight.w700, height: 1.3, color: Palette.ink)),
                          if (place.isNotEmpty) ...[const SizedBox(height: 3), Text(place, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Palette.inkSoft))],
                          if (entry.rating != null) ...[const SizedBox(height: 4), Text('★' * entry.rating!, style: const TextStyle(fontSize: 13, color: Palette.vermilion))],
                          if (entry.note.isNotEmpty) ...[const SizedBox(height: 5), Text(entry.note, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.5, color: Palette.ink))],
                          if (entry.visibility == 'public') ...[const SizedBox(height: 4), Text(entry.hidden ? '通報により公開を止めています' : '公開中', style: TextStyle(fontSize: 11, color: entry.hidden ? Palette.vermilion : Palette.inkSoft))],
                        ],
                      ),
                    ),
                  ),
                  if (entry.photos.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LogPhotoImage(name: entry.photos.first, size: 62)),
                    ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!showSeal) return stub;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        stub,
        // もぎりの印。切り取り線のすぐ右、白い紙の上に押す
        Positioned(
          left: 82,
          bottom: -10,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: -0.22,
              child: PonSeal(key: Key('stub-seal-${entry.id}'), size: 40, label: '観劇'),
            ),
          ),
        ),
      ],
    );
  }
}
