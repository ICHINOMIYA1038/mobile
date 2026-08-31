import 'dart:typed_data';
import 'package:flutter/widgets.dart' show BuildContext, Offset, Rect, RenderBox;

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/inspection.dart';
import 'inspection_scorer.dart';

/// 共有ボタンの位置(iPad のポップオーバー用)。ボタンの context を渡す。
/// 取れなければ画面右上あたりを返す。
Rect? shareAnchor(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  final origin = box.localToGlobal(Offset.zero);
  return Rect.fromLTWH(
    origin.dx + box.size.width - 44,
    origin.dy,
    44,
    44,
  );
}

/// 内見診断のレポート(1件でも複数件の比較でも同じ体裁)を PDF にして共有シートへ渡す。
class InspectionPdf {
  const InspectionPdf._();

  /// [anchor] は iPad の共有ポップオーバーの出所(共有ボタンの位置)。
  static Future<void> share(List<Inspection> inspections, {Rect? anchor}) async {
    final bytes = await build(inspections);
    await Printing.sharePdf(
      bytes: bytes,
      bounds: anchor,
      filename: inspections.length == 1
          ? 'sound_shield_${_safe(inspections.first.name)}.pdf'
          : 'sound_shield_comparison.pdf',
    );
  }

  static String _safe(String s) =>
      s.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');

  static Future<Uint8List> build(List<Inspection> inspections) async {
    final fontData = await rootBundle.load('assets/fonts/NotoSansJP-Regular.ttf');
    final font = pw.Font.ttf(fontData);
    final theme = pw.ThemeData.withFont(base: font, bold: font);
    final doc = pw.Document(theme: theme);
    const scorer = InspectionScorer();
    final scored = [for (final i in inspections) (i, scorer.score(i))]
      ..sort((a, b) => b.$2.score.compareTo(a.$2.score));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          pw.Text(
            inspections.length == 1 ? '防音診断レポート' : '物件の防音比較レポート',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Sound Shield ・ ${_date(DateTime.now())} ・ 同一端末のマイクによる相対的な目安値(未校正)',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          if (scored.length >= 2) ...[
            _comparisonTable(scored),
            pw.SizedBox(height: 16),
          ],
          for (final (inspection, score) in scored) ...[
            _inspectionSection(inspection, score),
            pw.SizedBox(height: 14),
          ],
          pw.Divider(color: PdfColors.grey400),
          pw.Text(
            '判定基準: 室内の静けさは環境省「騒音に係る環境基準」の住居地域(昼間55dB/夜間45dB)を参考に'
            '40dB未満を「静か」とし、窓・隣室側は部屋中央との差分、壁はノック音のスペクトルと余韻、'
            '響きは手叩きの減衰時間(RT60換算)から評価しています。正式な音響測定・法的証明に代わるものではありません。',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _comparisonTable(List<(Inspection, InspectionScore)> rows) {
    const keys = ['ambient', 'window', 'wall', 'reverb', 'neighbor'];
    const labels = ['静けさ', '窓', '壁', '響き', '隣室'];
    String mark(InspectionScore s, String k) {
      final c = s.components.where((c) => c.key == k).firstOrNull;
      if (c == null) return '—';
      return c.penalty <= 0 ? '◎' : c.penalty < 10 ? '○' : '△';
    }

    return pw.TableHelper.fromTextArray(
      headers: ['物件', 'スコア', '等級', ...labels, '壁の推定'],
      data: [
        for (final (i, s) in rows)
          [
            i.name,
            '${s.score}',
            s.grade,
            for (final k in keys) mark(s, k),
            s.wall.label,
          ],
      ],
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  static pw.Widget _inspectionSection(Inspection i, InspectionScore s) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  i.name,
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Text(
                '${s.score}点 ・ ${s.grade} ${s.gradeLabel}',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.Text(
            '${_date(i.createdAt)} ・ ${s.measuredSteps}/${InspectionStep.values.length}項目計測'
            '${i.memo.isNotEmpty ? ' ・ ${i.memo}' : ''}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 6),
          for (final c in s.components)
            pw.Row(
              children: [
                pw.SizedBox(width: 80, child: pw.Text(c.label, style: const pw.TextStyle(fontSize: 9))),
                pw.Expanded(child: pw.Text(c.detail, style: const pw.TextStyle(fontSize: 9))),
                pw.Text(
                  c.penalty <= 0 ? '±0' : '−${c.penalty.round()}',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          if (s.weakest != null) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              '弱点: ${s.weakest!.label} — ${s.weakest!.detail}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
          if (i.knock != null)
            pw.Text(
              '壁: ${s.wall.label} — ${s.wall.description}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          if (i.ambient != null)
            pw.Text(
              '検出された音: ${i.ambient!.soundLabels.take(3).map((l) => l.identifier).join(', ')}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
        ],
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
}
