import 'package:flutter/material.dart';

import '../models.dart';

/// 図解カード。サーバーで検証済みの内容を、型に応じたレイアウトで描く。
/// スマホの幅で崩れないことを最優先にしている（表は横スクロール、その他は縦積み）。
class FigureCard extends StatelessWidget {
  const FigureCard({super.key, required this.figure, this.compact = false});
  final Figure figure;

  /// 一覧画面など、タイトルだけ見せて中身を畳みたいとき
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = switch (figure.kind) {
      'compare' => _Compare(figure: figure),
      'buckets' => _Buckets(figure: figure),
      'numbers' => _Numbers(figure: figure),
      'flow' => _Flow(figure: figure),
      'nest' => _Nest(figure: figure),
      _ => const SizedBox.shrink(),
    };
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Icon(_iconFor(figure.kind), size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    figure.title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 12), child: body),
          if (figure.note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.push_pin_outlined, size: 14, color: theme.colorScheme.onTertiaryContainer),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(figure.note!, style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static IconData _iconFor(String kind) => switch (kind) {
        'compare' => Icons.table_chart_outlined,
        'buckets' => Icons.category_outlined,
        'numbers' => Icons.tag,
        'flow' => Icons.timeline,
        'nest' => Icons.account_tree_outlined,
        _ => Icons.image_outlined,
      };
}

/// 比較表。1列目を固定し、残りを横スクロールさせる。
class _Compare extends StatelessWidget {
  const _Compare({required this.figure});
  final Figure figure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, height: 1.4);
    final cellStyle = theme.textTheme.bodySmall?.copyWith(height: 1.4);
    final cols = figure.columns.length;
    // 列が1つなら普通の縦並び、2つ以上なら横スクロールの表にする
    final colWidth = cols >= 3 ? 150.0 : 175.0;
    final labelWidth = cols >= 3 ? 96.0 : 104.0;

    Widget cell(String text, TextStyle? style, double w, {bool header = false}) => Container(
          width: w,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: header ? theme.colorScheme.surfaceContainerHighest : null,
            border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.6)),
          ),
          child: Text(text, style: style),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cell('', labelStyle, labelWidth, header: true),
                for (final c in figure.columns)
                  cell(c, labelStyle?.copyWith(color: theme.colorScheme.primary), colWidth, header: true),
              ],
            ),
          ),
          for (final r in figure.rows)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  cell(r.label, labelStyle, labelWidth, header: true),
                  for (final c in r.cells) cell(c, cellStyle, colWidth),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// グループ分け。○と×のような対比を色で見せる。
class _Buckets extends StatelessWidget {
  const _Buckets({required this.figure});
  final Figure figure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final g in figure.groups) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: _toneColor(context, g.tone).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _toneColor(context, g.tone).withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_toneIcon(g.tone), size: 15, color: _toneColor(context, g.tone)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(g.title,
                          style: theme.textTheme.labelLarge?.copyWith(color: _toneColor(context, g.tone), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final item in g.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 6),
                          child: Container(width: 3, height: 3, decoration: BoxDecoration(color: theme.colorScheme.outline, shape: BoxShape.circle)),
                        ),
                        Expanded(child: Text(item, style: theme.textTheme.bodySmall?.copyWith(height: 1.5))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 数字の一覧。値を大きく、意味を横に。
class _Numbers extends StatelessWidget {
  const _Numbers({required this.figure});
  final Figure figure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final (i, item) in figure.items.indexed)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              border: i == figure.items.length - 1
                  ? null
                  : Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.6)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 104,
                  child: Text(
                    item.value,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, height: 1.4)),
                      if (item.note != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(item.note!,
                              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline, height: 1.4)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 流れ図。縦に並べて、番号と線でつなぐ。
class _Flow extends StatelessWidget {
  const _Flow({required this.figure});
  final Figure figure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, s) in figure.steps.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                      child: Text('${i + 1}',
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold)),
                    ),
                    if (i != figure.steps.length - 1)
                      Expanded(child: Container(width: 1.5, color: theme.colorScheme.primary.withValues(alpha: 0.3))),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: i == figure.steps.length - 1 ? 0 : 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.35)),
                        if (s.detail != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(s.detail!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline, height: 1.45)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 入れ子構造。左の縦線でくくって階層を見せる。
class _Nest extends StatelessWidget {
  const _Nest({required this.figure});
  final Figure figure;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: _build(context, figure.nodes, 0));
  }

  List<Widget> _build(BuildContext context, List<FigureNode> nodes, int depth) {
    final theme = Theme.of(context);
    final out = <Widget>[];
    for (final n in nodes) {
      out.add(Padding(
        padding: EdgeInsets.only(left: depth * 14.0, bottom: 6),
        child: Container(
          padding: EdgeInsets.only(left: depth == 0 ? 0 : 10),
          decoration: depth == 0
              ? null
              : BoxDecoration(
                  border: Border(left: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.35), width: 2)),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                n.title,
                style: depth == 0
                    ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, height: 1.35)
                    : theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, height: 1.4),
              ),
              if (n.note != null)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(n.note!, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline, height: 1.45)),
                ),
            ],
          ),
        ),
      ));
      if (n.children.isNotEmpty) out.addAll(_build(context, n.children, depth + 1));
    }
    return out;
  }
}

Color _toneColor(BuildContext context, String? tone) {
  final scheme = Theme.of(context).colorScheme;
  return switch (tone) {
    'yes' => const Color(0xFF2E7D32),
    'no' => scheme.error,
    'warn' => const Color(0xFFB26A00),
    _ => scheme.primary,
  };
}

IconData _toneIcon(String? tone) => switch (tone) {
      'yes' => Icons.check_circle_outline,
      'no' => Icons.cancel_outlined,
      'warn' => Icons.error_outline,
      _ => Icons.info_outline,
    };
