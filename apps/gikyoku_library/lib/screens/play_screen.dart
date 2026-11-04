import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_scope.dart';
import '../catalog/models.dart';
import '../theme.dart';
import '../widgets/community_widgets.dart';
import 'quick_log_sheet.dart';

class PlayScreen extends StatelessWidget {
  const PlayScreen({super.key, required this.play});
  final Play play;

  static Future<void> open(BuildContext context, Play play) {
    AppInsights.logEvent('play_open', parameters: {'play_id': play.id});
    return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PlayScreen(play: play), settings: const RouteSettings(name: 'play')));
  }

  Future<void> _open(String kind, Uri url) async {
    AppInsights.logEvent('link_open', parameters: {'kind': kind, 'play_id': play.id});
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final shortlist = scope.shortlist;
    final names = {for (final c in scope.catalog.categories) c.id: c.name};
    final genres = play.categoryIds.map((id) => names[id]).whereType<String>().toList();
    return Scaffold(
      appBar: AppBar(
        actions: [
          ListenableBuilder(
            listenable: shortlist,
            builder: (context, _) {
              final on = shortlist.contains(play.id);
              return IconButton(
                key: const Key('shortlist-toggle'),
                tooltip: on ? '気になるから外す' : '気になる',
                icon: Icon(on ? Icons.bookmark : Icons.bookmark_border, color: on ? Palette.vermilion : null),
                onPressed: () => shortlist.toggle(play.id),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text(play.title, style: const TextStyle(fontFamily: titleFont, fontSize: 26, fontWeight: FontWeight.w700, height: 1.35, color: Palette.ink)),
          const SizedBox(height: 4),
          Text(play.author, style: const TextStyle(fontSize: 15, color: Palette.inkSoft)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _Stat('登場人数', play.castLabel)),
              const SizedBox(width: 10),
              Expanded(child: _Stat('上演時間', play.minutesLabel)),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('log-this-play'),
            onPressed: () => QuickLogSheet.open(context, play: play),
            icon: const Icon(Icons.theater_comedy_outlined),
            label: const Text('この作品を観た'),
          ),
          if (play.readUrl != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('read-link'),
              onPressed: () => _open('read', Uri.parse(play.readUrl!)),
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('台本の掲載先を開く'),
            ),
          ],
          if (play.buyUrl != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: () => _open('buy', Uri.parse(play.buyUrl!)), icon: const Icon(Icons.open_in_new), label: const Text('入手先を開く')),
          ],
          ReviewsSection(postId: play.id),
          if (play.synopsis != null) _Section('あらすじ', Text(play.synopsis!, style: _body)),
          if (play.synopsis == null && play.aiDescription != null)
            _Section(
              'AI による作品概要',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(play.aiDescription!, style: _body),
                  const SizedBox(height: 6),
                  const Text('公開情報をもとに AI が作成しました。実際の内容と異なる場合があります。', style: TextStyle(fontSize: 12, height: 1.5, color: Palette.inkSoft)),
                ],
              ),
            ),
          if (genres.isNotEmpty) _Section('ジャンル', Text(genres.join('、'), style: _body)),
          if (play.awards.isNotEmpty)
            _Section(
              '賞',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final a in play.awards) Text('${a.year}年 ${a.name}（${a.type}）', style: _body)],
              ),
            ),
          if (play.groups.isNotEmpty) _Section('上演した劇団', Text(play.groups.join('、'), style: _body)),
          const _Section('上演するときは', Text('上演には、作者や権利者の許可が必要な場合があります。上演料や条件は、掲載先や権利者に確かめてください。', style: _body)),
          const SizedBox(height: 16),
          TextButton.icon(onPressed: () => _open('site', play.siteUrl), icon: const Icon(Icons.open_in_new, size: 18), label: const Text('戯曲図書館のサイトで見る')),
        ],
      ),
    );
  }
}

const _body = TextStyle(fontSize: 15, height: 1.75, color: Palette.ink);

class _Section extends StatelessWidget {
  const _Section(this.title, this.child);
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.vermilion)),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Palette.card, border: Border.all(color: Palette.line), borderRadius: BorderRadius.circular(8)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Palette.ink)),
      ],
    ),
  );
}
