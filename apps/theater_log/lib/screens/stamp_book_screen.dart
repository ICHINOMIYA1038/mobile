import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/illustrations.dart';
import '../app_scope.dart';
import '../catalog/achievements.dart';
import '../catalog/log_stats.dart';
import '../theme.dart';
import '../widgets/pon_stamp.dart';
import 'log_stats_screen.dart';
import 'recap_screen.dart';
import 'venue_stamps_screen.dart';

class StampBookScreen extends StatelessWidget {
  const StampBookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final log = AppScope.of(context).log;
    // 紙の画面なので、時刻や電池の表示は黒に
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: log,
          builder: (context, _) {
            final items = achievementsOf(log.entries);
            final done = items.where((a) => a.earned).length;
            final year = DateTime.now().year;
            final stats = LogStats.of(log.entries, year);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Center(child: StageArt.lanterns(key: const Key('art-lanterns'), width: 180)),
                const SizedBox(height: 4),
                const Text(
                  'スタンプ帳',
                  style: TextStyle(fontFamily: displayFont, fontWeight: FontWeight.w800, fontSize: 30, height: 1.1, color: Palette.sumi),
                ),
                const SizedBox(height: 6),
                Text(
                  '${items.length} 個のうち $done 個を押しました',
                  key: const Key('stamp-count'),
                  style: const TextStyle(fontSize: 13, color: Palette.inkSoft),
                ),
                const SizedBox(height: 18),
                // 帳面の 1 ページ。押したものは朱の印、まだのものは点線の枠
                LayoutBuilder(
                  builder: (context, c) {
                    const cols = 3;
                    final w = (c.maxWidth - 8 * (cols - 1)) / cols;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 18,
                      children: [
                        for (final a in items)
                          SizedBox(
                            width: w,
                            child: _Stamp(a, size: math.min(96, w * 0.82)),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 30),
                const _Rule(),
                const SizedBox(height: 18),
                const VenueStampSummary(),
                const SizedBox(height: 26),
                const _Rule(),
                if (log.entries.isNotEmpty) _Row(key: const Key('open-recap'), title: '$year年のふりかえり', sub: '観た本数と、よく行った劇場を 1 枚に', onTap: () => RecapScreen.open(context)),
                _Row(key: const Key('open-stats'), title: '$year年は ${stats.count} 本', sub: '月ごとの本数、よく行く劇場、よく観る劇団', onTap: () => LogStatsScreen.open(context)),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 区切りの墨の線
class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => const Divider(height: 1, thickness: 1.5, color: Palette.ink);
}

/// 罫線で区切った 1 行の入口
class _Row extends StatelessWidget {
  const _Row({super.key, required this.title, required this.sub, required this.onTap});
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Palette.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Palette.ink),
                ),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Palette.ink),
        ],
      ),
    ),
  );
}

/// ハンコの中での折り返し
const _sealLabels = {
  'five': '常連の\n入口',
  'ten': '客席の\n住人',
  'thirty': '劇場に\n住む',
  'hundred': '百本\nの幕',
  'venue3': '劇場\nめぐり',
  'venue10': '旅する\n観客',
  'group5': '劇団\nめぐり',
  'month3': '今月は\n当たり月',
  'script3': '台本にも\n興味',
  'note5': '語りたく\nなる',
};

/// 劇場や劇団に行くと押す印は角印、本数などは丸印
const _squareIds = {'venue3', 'venue10', 'group5'};

class _Stamp extends StatelessWidget {
  const _Stamp(this.a, {required this.size});
  final Achievement a;
  final double size;

  @override
  Widget build(BuildContext context) {
    final on = a.earned;
    final square = _squareIds.contains(a.id);
    // 押した向きを少しずつ変える（同じ印はいつも同じ向き）
    final tilt = ((a.id.codeUnits.fold(0, (x, y) => x + y) % 7) - 3) * 0.05;
    final left = a.goal - math.min(a.current, a.goal);
    return Tooltip(
      message: a.description,
      child: Column(
        children: [
          SizedBox.square(
            dimension: size,
            child: on
                ? Transform.rotate(
                    angle: tilt,
                    child: PonSeal(key: Key('stamp-${a.id}'), size: size, label: _sealLabels[a.id] ?? a.title, square: square, fontSize: size * 0.19),
                  )
                : CustomPaint(
                    key: Key('stamp-${a.id}'),
                    painter: _EmptySlot(square: square),
                    child: Center(
                      child: Text(
                        'あと$left',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFA3A39D)),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            a.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: on ? Palette.ink : Palette.inkSoft),
          ),
          const SizedBox(height: 1),
          Text(
            a.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, height: 1.35, color: Palette.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// まだ押していない印の場所。点線の枠だけを描く
class _EmptySlot extends CustomPainter {
  const _EmptySlot({required this.square});
  final bool square;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFC4C4BC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rect = (Offset.zero & size).deflate(2);
    final path = square ? (Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)))) : (Path()..addOval(rect));
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 8) {
        canvas.drawPath(m.extractPath(d, math.min(d + 4, m.length)), p);
      }
    }
  }

  @override
  bool shouldRepaint(_EmptySlot old) => old.square != square;
}
