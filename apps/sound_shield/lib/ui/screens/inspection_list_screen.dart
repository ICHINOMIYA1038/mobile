import 'package:flutter/material.dart';

import '../../data/app_scope.dart';
import '../../logic/inspection_pdf.dart';
import '../../logic/inspection_scorer.dart';
import '../../models/inspection.dart';
import 'home_screen.dart';
import 'inspection_result_screen.dart';

/// 保存した診断の一覧と比較表。
class InspectionListScreen extends StatelessWidget {
  const InspectionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('物件の比較'),
        actions: [
          IconButton(
            tooltip: '比較表をPDFで共有',
            icon: const Icon(Icons.ios_share),
            onPressed: () => _sharePdf(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: services.inspections,
          builder: (context, _) {
            final list = services.inspections.inspections;
            if (list.isEmpty) {
              return Center(
                child: Text('診断がまだありません', style: TextStyle(color: scheme.outline)),
              );
            }
            final scored = [
              for (final i in list) (i, const InspectionScorer().score(i)),
            ]..sort((a, b) => b.$2.score.compareTo(a.$2.score));
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('スコア順', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                for (final (inspection, score) in scored)
                  Dismissible(
                    key: ValueKey(inspection.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: scheme.tertiary,
                      child: Icon(Icons.delete_outline, color: scheme.onTertiary),
                    ),
                    confirmDismiss: (_) => _confirmDelete(context, inspection),
                    onDismissed: (_) =>
                        services.inspections.deleteInspection(inspection.id),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ScoreChip(score: score),
                      title: Text(inspection.name),
                      subtitle: Text(
                        '${score.score}点 ・ ${score.wall.label}'
                        '${score.weakest != null ? ' ・ 弱点: ${score.weakest!.label}' : ''}',
                        style: TextStyle(color: scheme.outline),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          settings: const RouteSettings(name: 'inspection_result'),
                          builder: (_) =>
                              InspectionResultScreen(inspection: inspection),
                        ),
                      ),
                    ),
                  ),
                if (scored.length >= 2) ...[
                  const SizedBox(height: 24),
                  Text('項目別の比較', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _CompareTable(rows: scored),
                ],
                const SizedBox(height: 16),
                Text(
                  '左にスワイプで削除。スコアは同じ端末で測った相対的な目安です。',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: scheme.outline),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, Inspection inspection) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('「${inspection.name}」を削除しますか?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _sharePdf(BuildContext context) async {
    final services = AppScope.of(context);
    await InspectionPdf.share(
      services.inspections.inspections,
      anchor: shareAnchor(context),
    );
  }
}

class _CompareTable extends StatelessWidget {
  const _CompareTable({required this.rows});

  final List<(Inspection, InspectionScore)> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const keys = ['ambient', 'window', 'wall', 'reverb', 'neighbor'];
    const labels = ['静けさ', '窓', '壁', '響き', '隣室'];
    final textStyle = Theme.of(context).textTheme.bodySmall;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        headingTextStyle: textStyle?.copyWith(fontWeight: FontWeight.w700),
        dataTextStyle: textStyle,
        columns: [
          const DataColumn(label: Text('物件')),
          const DataColumn(label: Text('点')),
          for (final l in labels) DataColumn(label: Text(l)),
        ],
        rows: [
          for (final (inspection, score) in rows)
            DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 96,
                    child: Text(inspection.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
                DataCell(
                  Text(
                    '${score.score}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scoreColor(context, score.score),
                    ),
                  ),
                ),
                for (final k in keys)
                  DataCell(_cell(score, k, scheme)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(InspectionScore score, String key, ColorScheme scheme) {
    final c = score.components.where((c) => c.key == key).firstOrNull;
    if (c == null) return Text('—', style: TextStyle(color: scheme.outline));
    final color = c.penalty <= 0
        ? scheme.secondary
        : c.penalty < 10
        ? scheme.primary
        : scheme.tertiary;
    return Text(
      c.penalty <= 0 ? '◎' : c.penalty < 10 ? '○' : '△',
      style: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }
}
