import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/readable.dart';
import 'common/parts.dart';

/// 学習の地図（サイトの /fp1/map）。科目 → 章 → テーマごとに「説明を聞いた論点」と「定着した問題」を出す。
/// 開くたびに GET map を取り直す（会話から戻ったときに新しい数字で見たいので、AppState には持たない）。
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Map<String, dynamic>? _data;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await AppScope.read(context).api.map();
      if (mounted) setState(() => (_data = d, _error = null));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('学習の地図', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: d == null
          ? Center(
              child: _error != null ? LoadError(error: _error!, onRetry: _load) : const CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _MapBody(data: d, onReturn: _load),
            ),
    );
  }
}

class _MapBody extends StatelessWidget {
  const _MapBody({required this.data, required this.onReturn});
  final Map<String, dynamic> data;

  /// 章の会話から戻ったら数字を取り直す
  final Future<void> Function() onReturn;

  @override
  Widget build(BuildContext context) {
    final progress = (data['progress'] as Map).cast<String, dynamic>();
    final chapters = {for (final c in (data['chapters'] as List? ?? const [])) (c as Map)['id'] as String: c.cast<String, dynamic>()};
    final byId = {for (final p in (progress['chapters'] as List? ?? const [])) (p as Map)['chapterId'] as String: p.cast<String, dynamic>()};
    final visited = ((data['visited'] as List?) ?? const []).cast<String>().toSet();
    final acc = progress['accuracy'] as num?;
    final days = progress['daysToExam'] as num?;

    Future<void> open(String id) async {
      await openChapter(context, id);
      await onReturn();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Readable(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Wrap(
                    runSpacing: 10,
                    children: [
                      _Total('説明を聞いた論点', '${progress['pointsTaught']} / ${progress['points']}'),
                      _Total('出題した問題', '${progress['seen']} / ${progress['totalQuestions']}'),
                      _Total('定着した問題', '${progress['mastered']}'),
                      _Total('正答率', acc == null ? '—' : '${(acc * 100).round()}%'),
                      _Total('合格見込み', '${progress['passScore']} / 100'),
                      _Total('試験まで', days == null ? '—' : 'あと$days日'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text('「論点」は試験範囲を、先生が1回で説明できる大きさに分けたものです。先生は説明した論点からだけ○×を出します。「定着」は、同じ問題に2回続けて正解した状態です。間違えた問題は、忘れたころに会話の中でもう一度出ます。', style: Theme.of(context).textTheme.bodySmall),
              for (final s in (data['subjects'] as List? ?? const []).cast<Map>()) ...[
                const SizedBox(height: 22),
                SubjectHeading(name: s['name'] as String, examQuestions: (s['examQuestions'] as num?)?.toInt() ?? 0),
                const SizedBox(height: 6),
                for (final id in (s['chapterIds'] as List).cast<String>())
                  if (chapters[id] != null && byId[id] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _ChapterCard(chapter: chapters[id]!, progress: byId[id]!, visited: visited, onOpen: () => open(id)),
                    ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    widthFactor: 1 / 3,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Palette.inkSoft, height: 1.4)),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Palette.ink),
        ),
      ],
    ),
  );
}

/// 章の行。開くとテーマの一覧（サイトの details 要素）。テーマを押すとその章の会話へ
class _ChapterCard extends StatelessWidget {
  const _ChapterCard({required this.chapter, required this.progress, required this.visited, required this.onOpen});
  final Map<String, dynamic> chapter;
  final Map<String, dynamic> progress;
  final Set<String> visited;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final id = chapter['id'] as String;
    final total = (p['total'] as num?)?.toInt() ?? 0;
    final mastered = (p['mastered'] as num?)?.toInt() ?? 0;
    final points = (p['points'] as num?)?.toInt() ?? 0;
    final taught = (p['pointsTaught'] as num?)?.toInt() ?? 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // ExpansionTile の上下の線を消す（カードの枠と二重になる）
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
          childrenPadding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
          title: Text(
            '第${chapter['order']}章 ${chapter['title']}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.5, color: Palette.ink),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('説明 $taught/$points・定着 $mastered/$total', style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
                    ),
                    if (total > 0 && mastered == total) const _Stamp(),
                  ],
                ),
                const SizedBox(height: 4),
                ProgressBar(value: points == 0 ? 0 : taught / points, height: 4),
              ],
            ),
          ),
          children: [
            for (final t in (p['topics'] as List? ?? const []).cast<Map>()) _TopicRow(topic: t.cast<String, dynamic>(), visited: visited.contains('$id/${t['key']}'), onTap: onOpen),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton.tonalIcon(onPressed: onOpen, icon: const Icon(Icons.forum_outlined), label: const Text('この章を話す')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic, required this.visited, required this.onTap});
  final Map<String, dynamic> topic;
  final bool visited;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = topic;
    final points = (t['points'] as num?)?.toInt() ?? 0;
    final taught = (t['pointsTaught'] as num?)?.toInt() ?? 0;
    final done = points > 0 && taught >= points;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                // 話したことのあるテーマ（会話で開いたテーマ）は塗りの丸、全部説明済みなら✓
                child: Icon(done ? Icons.check_circle : (visited ? Icons.circle : Icons.circle_outlined), size: 16, color: done ? Palette.success : (visited ? Palette.primary : Palette.lineStrong)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t['title'] as String? ?? '',
                      style: TextStyle(fontSize: 14, height: 1.5, color: visited ? Palette.ink : Palette.inkSoft, fontWeight: visited ? FontWeight.w600 : FontWeight.w400),
                    ),
                    Text('説明 $taught/$points・定着 ${t['mastered']}/${t['total']}', style: const TextStyle(fontSize: 12, color: Palette.inkFaint)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: Palette.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      border: Border.all(color: Palette.hanamaru, width: 1.5),
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Text(
      '定着',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.hanamaru),
    ),
  );
}
