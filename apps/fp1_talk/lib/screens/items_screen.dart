import 'package:flutter/material.dart';

import '../ads/ad_banner.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/readable.dart';
import 'common/parts.dart';

/// 「本試験形式」タブ（サイトの /fp1/kakomon と同じ中身）。本試験と同じ答え方（基礎編の四答択一・応用編の空欄と計算）で解く。
/// 回ごと（回×編）と章ごとの一覧。解く画面から戻ったら数え直す。
class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  Map<String, dynamic>? _data;
  Object? _error;

  /// 回ごと（本試験の並び）・章ごと（「学ぶ」のカリキュラムの順）
  String _by = 'sitting';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await AppScope.read(context).api.itemIndex();
      if (mounted) {
        setState(() {
          _data = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _open(ItemSetRow s) async {
    await openItems(context, set: s.key, label: s.label);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      // Pro でない人にだけ、一覧の下にバナー（解く画面には出さない）
      bottomNavigationBar: const AdBanner(),
      appBar: AppBar(title: const Text('本試験形式')),
      body: d == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : LoadError(error: _error!, onRetry: _load))
          : RefreshIndicator(onRefresh: _load, child: _list(d)),
    );
  }

  Widget _list(Map<String, dynamic> d) {
    final sittings = ((d['sittings'] as List?) ?? const []).map(ItemSetRow.from).toList();
    final chapters = ((d['chapters'] as List?) ?? const []).map(ItemSetRow.from).toList();
    final state = AppScope.of(context);
    // 回（2026-09）ごとに、基礎編・応用編をまとめる
    final byMonth = <String, List<ItemSetRow>>{};
    for (final s in sittings) {
      (byMonth[s.key.length >= 7 ? s.key.substring(0, 7) : s.key] ??= []).add(s);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 48),
      children: [
        Readable(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '本試験と同じ答え方で解きます。基礎編は四答択一（押したらすぐ答え合わせ）、応用編は設例を読んで空欄・計算の欄を埋めて答え合わせ。電卓はいつでも出せます。答え合わせで1日に話せる回数は減りません。',
                style: TextStyle(fontSize: 14, height: 1.7, color: Palette.inkSoft),
              ),
              if ((d['credit'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text('出典: ${d['credit']}（年度の数字などを直した問題は「一部改変」と書いています）', style: const TextStyle(fontSize: 12, height: 1.6, color: Palette.inkFaint)),
              ],
              if (sittings.isEmpty && chapters.isEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border.all(color: Palette.lineStrong), borderRadius: BorderRadius.circular(4)),
                  child: const Text('問題を準備しています。もうしばらくお待ちください。', style: TextStyle(color: Palette.inkSoft)),
                )
              else ...[
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'sitting', label: Text('回ごと')),
                    ButtonSegment(value: 'chapter', label: Text('章ごと')),
                  ],
                  selected: {_by},
                  onSelectionChanged: (v) => setState(() => _by = v.first),
                ),
                const SizedBox(height: 12),
                if (_by == 'sitting')
                  for (final MapEntry(key: month, value: rows) in byMonth.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 6),
                      child: Text(_monthLabel(month), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Palette.ink)),
                    ),
                    for (final s in rows) ItemSetTile(s, title: s.label.replaceFirst('${_monthLabel(month)} ', ''), onOpen: _open),
                  ]
                else ...[
                  const Text('「学ぶ」の章と同じ分け方です。会話で学んだ章の問題を、新しい回から解けます。', style: TextStyle(fontSize: 13, height: 1.6, color: Palette.inkSoft)),
                  for (final sub in state.subjects)
                    if (chapters.where((c) => sub.chapterIds.contains(c.key)).toList() case final rows when rows.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Text(sub.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Palette.ink)),
                      ),
                      for (final s in rows) ItemSetTile(s, onOpen: _open),
                    ],
                  // 科目に入っていない章（科目の一覧が読めないときも）
                  for (final s in chapters.where((c) => !state.subjects.any((sub) => sub.chapterIds.contains(c.key)))) ItemSetTile(s, onOpen: _open),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _monthLabel(String ym) => ym.length >= 7 ? '${ym.substring(0, 4)}年${int.tryParse(ym.substring(5, 7)) ?? ym.substring(5, 7)}月' : ym;
}

class ItemSetRow {
  const ItemSetRow(this.key, this.label, this.total, this.answered, this.correct);
  final String key;
  final String label;
  final int total;
  final int answered;
  final int correct;

  static ItemSetRow from(Object? v) {
    final j = (v as Map?)?.cast<String, dynamic>() ?? const {};
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return ItemSetRow(j['key'] as String? ?? '', j['label'] as String? ?? '', n('total'), n('answered'), n('correct'));
  }
}

/// まとまりの行: 名前と問題数、進み具合の線と数字
class ItemSetTile extends StatelessWidget {
  const ItemSetTile(this.s, {super.key, required this.onOpen, this.title});
  final ItemSetRow s;
  final String? title;
  final void Function(ItemSetRow s) onOpen;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('items-${s.key}'),
            onTap: () => onOpen(s),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(child: Text(title ?? s.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Palette.ink))),
                    Text('${s.total}問', style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
                    const Icon(Icons.chevron_right, color: Palette.inkFaint),
                  ]),
                  const SizedBox(height: 8),
                  Semantics(label: '解いた ${s.answered}/${s.total}問', child: ProgressBar(value: s.total == 0 ? 0 : s.answered / s.total)),
                  const SizedBox(height: 6),
                  Text(s.answered > 0 ? '解いた ${s.answered}・全問正解 ${s.correct}' : 'まだ解いていない', style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
                ],
              ),
            ),
          ),
        ),
      );
}
