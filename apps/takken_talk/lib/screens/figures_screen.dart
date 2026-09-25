import 'package:flutter/material.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../widgets/figure_card.dart';

/// 章の図解をまとめて眺める画面。会話しなくても体系をつかめるようにするための場所。
class FiguresScreen extends StatefulWidget {
  const FiguresScreen({super.key, required this.chapter, this.initialFigureId});
  final Chapter chapter;
  final String? initialFigureId;

  @override
  State<FiguresScreen> createState() => _FiguresScreenState();
}

class _FiguresScreenState extends State<FiguresScreen> {
  List<Figure>? _figures;
  String? _error;
  String? _filterTopic;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final f = await AppScope.of(context).api.figures(widget.chapter.id);
      if (mounted) setState(() => _figures = f);
    } catch (_) {
      if (mounted) setState(() => _error = '図解を読み込めませんでした');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = _figures;
    final shown = all == null
        ? const <Figure>[]
        : _filterTopic == null
            ? all
            : all.where((f) => f.topicKey == _filterTopic).toList();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('第${widget.chapter.order}章の図解', style: theme.textTheme.titleMedium),
            Text(widget.chapter.short, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
      body: all == null
          ? Center(
              child: _error != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [Text(_error!), const SizedBox(height: 8), TextButton(onPressed: _load, child: const Text('再読み込み'))],
                    )
                  : const CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text('すべて ${all.length}'),
                          selected: _filterTopic == null,
                          onSelected: (_) => setState(() => _filterTopic = null),
                        ),
                      ),
                      for (final t in widget.chapter.topics)
                        if (all.any((f) => f.topicKey == t.key))
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(t.title),
                              selected: _filterTopic == t.key,
                              onSelected: (_) => setState(() => _filterTopic = t.key),
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                for (final f in shown) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(f.hint, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                  ),
                  FigureCard(figure: f),
                ],
                const SizedBox(height: 20),
                Text('図解の内容は事前に用意したもので、AIが生成したものではありません。数字や法改正はテキストでも確認してください。',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline, height: 1.5)),
              ],
            ),
    );
  }
}
