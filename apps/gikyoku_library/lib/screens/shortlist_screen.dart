import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../app_scope.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import '../theme.dart';
import '../widgets/play_card.dart';

/// 共有する文面。部員が開けるようにサイトの URL を添える
String shortlistShareText(List<Play> plays) => [
  '上演の候補（戯曲図書館）',
  for (final p in plays) '・${p.title}／${p.author}（${p.castLabel}、${p.minutesLabel}）\n${p.siteUrl}',
].join('\n');

class ShortlistScreen extends StatelessWidget {
  const ShortlistScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(appBar: AppBar(), body: const ShortlistScreen()),
      settings: const RouteSettings(name: 'shortlist'),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final byId = {for (final p in scope.catalog.plays) p.id: p};
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: scope.shortlist,
        builder: (context, _) {
          // カタログから消えた作品は表示しない
          final plays = scope.shortlist.ids.map((id) => byId[id]).whereType<Play>().toList();
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('気になる作品', style: TextStyle(fontFamily: titleFont, fontSize: 26, fontWeight: FontWeight.w700, color: Palette.navy)),
                    ),
                    if (plays.isNotEmpty)
                      Builder(
                        builder: (buttonContext) => TextButton.icon(
                          key: const Key('share-shortlist'),
                          onPressed: () {
                            AppInsights.logEvent('shortlist_share', parameters: {'count': plays.length});
                            final box = buttonContext.findRenderObject() as RenderBox?;
                            SharePlus.instance.share(ShareParams(text: shortlistShareText(plays), sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size));
                          },
                          icon: const Icon(Icons.ios_share, size: 18),
                          label: const Text('共有'),
                        ),
                      ),
                  ],
                ),
              ),
              if (plays.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('作品のしおりを押すと、ここに集まります。人数と時間を比べて、部員や劇団の仲間に共有できます。', style: TextStyle(height: 1.7, color: Palette.inkSoft)),
                )
              else ...[
                if (plays.length >= 2) _CompareTable(plays: plays),
                for (final p in plays) PlayCard(play: p),
              ],
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

class _CompareTable extends StatelessWidget {
  const _CompareTable({required this.plays});
  final List<Play> plays;

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.inkSoft);
    const cell = TextStyle(fontSize: 13, color: Palette.ink);
    Widget pad(Widget c) => Padding(padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8), child: c);
    return Container(
      key: const Key('compare-table'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(color: Palette.card, border: Border.all(color: Palette.line), borderRadius: BorderRadius.circular(8)),
      child: Table(
        columnWidths: const {0: FlexColumnWidth(2.2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1)},
        border: const TableBorder(horizontalInside: BorderSide(color: Palette.line)),
        children: [
          TableRow(children: [pad(const Text('作品', style: head)), pad(const Text('人数', style: head)), pad(const Text('時間', style: head))]),
          for (final p in plays)
            TableRow(
              children: [
                pad(Text(p.title, style: cell, maxLines: 2, overflow: TextOverflow.ellipsis)),
                pad(Text(p.cast == null ? '不明' : '${p.cast}人', style: cell)),
                pad(Text(p.minutes == null ? '不明' : '${p.minutes}分', style: cell)),
              ],
            ),
        ],
      ),
    );
  }
}
