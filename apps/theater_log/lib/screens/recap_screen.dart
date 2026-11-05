import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_scope.dart';
import '../catalog/log_stats.dart';
import '../theme.dart';

/// 年間ふりかえり。SNS に載せられる 1 枚にする
class RecapScreen extends StatefulWidget {
  const RecapScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const RecapScreen(), settings: const RouteSettings(name: 'recap')),
  );

  @override
  State<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends State<RecapScreen> {
  final _key = GlobalKey();
  int _year = DateTime.now().year;

  Future<void> _share(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${(await getTemporaryDirectory()).path}/gikyoku_recap_$_year.png');
    await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
    AppInsights.logEvent('recap_share');
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'image/png')], sharePositionOrigin: origin));
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final prefs = {for (final v in scope.catalog.venues) v.name: v.prefecture};
    final recap = YearRecap.of(scope.log.entries, _year, prefs);
    return Scaffold(
      appBar: AppBar(title: const Text('ふりかえり')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(tooltip: '前の年', onPressed: () => setState(() => _year--), icon: const Icon(Icons.chevron_left)),
              Text('$_year年', style: const TextStyle(fontWeight: FontWeight.w700)),
              IconButton(tooltip: '次の年', onPressed: _year >= DateTime.now().year ? null : () => setState(() => _year++), icon: const Icon(Icons.chevron_right)),
            ],
          ),
          RepaintBoundary(key: _key, child: RecapCard(recap: recap)),
          const SizedBox(height: 16),
          if (recap.count > 0)
            Builder(
              builder: (c) => FilledButton.icon(key: const Key('recap-share'), style: FilledButton.styleFrom(backgroundColor: Palette.vermilion, minimumSize: const Size.fromHeight(46)), onPressed: () => _share(c), icon: const Icon(Icons.ios_share), label: const Text('画像を共有')),
            ),
        ],
      ),
    );
  }
}

class RecapCard extends StatelessWidget {
  const RecapCard({super.key, required this.recap});
  final YearRecap recap;

  @override
  Widget build(BuildContext context) {
    final r = recap;
    const paper = Palette.paper;
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: titleFont, fontSize: 17, fontWeight: FontWeight.w700, height: 1.3, color: paper)),
        ],
      ),
    );
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        padding: const EdgeInsets.all(22),
        color: Palette.navy,
        child: r.count == 0
            ? Center(child: Text('${r.year}年の記録はありません', key: const Key('recap-empty'), style: const TextStyle(color: paper)))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${r.year}年の観劇', style: const TextStyle(fontFamily: titleFont, fontSize: 16, color: paper)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('${r.count}', key: const Key('recap-count'), style: const TextStyle(fontFamily: titleFont, fontSize: 68, fontWeight: FontWeight.w800, height: 1.15, color: Color(0xFFE9A23B))),
                      const SizedBox(width: 6),
                      const Text('本', style: TextStyle(fontFamily: titleFont, fontSize: 22, color: paper)),
                    ],
                  ),
                  if (r.venueCount > 0) Text('${r.venueCount} の劇場${r.prefectureCount > 0 ? '・${r.prefectureCount} 都道府県' : ''}', style: const TextStyle(fontSize: 14, color: paper)),
                  if (r.topVenue != null) line('いちばん通った劇場', '${r.topVenue!.key}（${r.topVenue!.value} 回）'),
                  if (r.topGroup != null) line('いちばん観た劇団', '${r.topGroup!.key}（${r.topGroup!.value} 本）'),
                  line('いちばん観た月', '${r.bestMonth}月（${r.bestMonthCount} 本）'),
                  if (r.favorites.isNotEmpty) line('★5 をつけた舞台', r.favorites.join('、')),
                  const Spacer(),
                  const Align(alignment: Alignment.bottomRight, child: Text('ゲキタビ', style: TextStyle(fontFamily: titleFont, fontSize: 12, color: paper))),
                ],
              ),
      ),
    );
  }
}
