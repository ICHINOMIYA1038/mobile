import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/score.dart';
import 'ruby_layout.dart';

/// 認識結果を PDF に書き出す。
/// overlayOnImage=true: 元画像の上にドレミを重ねる / false: ドレミの列を大きく印字。
class PdfExport {
  /// 同梱フォント（サブセット）を優先し、万一読めなければ
  /// Google Fonts のダウンロードにフォールバック（要ネットワーク）。
  static Future<pw.Font> _font(String asset,
      Future<pw.Font> Function() fallback) async {
    try {
      return pw.Font.ttf(await rootBundle.load(asset));
    } catch (_) {
      return fallback();
    }
  }

  static Future<Uint8List> build(RecognizedScore score,
      {String title = 'ドレミ楽譜'}) async {
    final jpFont = await _font('assets/fonts/NotoSansJP-reg.ttf',
        PdfGoogleFonts.notoSansJPRegular);
    final jpBold = await _font('assets/fonts/NotoSansJP-bold.ttf',
        PdfGoogleFonts.notoSansJPBold);
    final doc =
        pw.Document(theme: pw.ThemeData.withFont(base: jpFont, bold: jpBold));

    if (score.panels.isNotEmpty) {
      // 段画像＋ルビをそのまま印刷（ドレミ付き楽譜）
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Text(title,
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            for (final panel in score.panels)
              // 清書がある段はそのまま印刷、ない段は写真＋ルビの重ね刷り
              if (panel.hasClean)
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Image(
                      pw.MemoryImage(Uint8List.fromList(panel.cleanBytes!))),
                )
              else
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.LayoutBuilder(builder: (context, cns) {
                  final w = cns!.maxWidth;
                  final h = w / panel.aspect;
                  return pw.SizedBox(
                    width: w,
                    height: h,
                    child: pw.Stack(children: [
                      pw.Positioned.fill(
                          child: pw.Image(pw.MemoryImage(
                              Uint8List.fromList(panel.imageBytes)))),
                      // 画面表示と同じ自動レイアウト（五線上のレーンに整列）
                      for (final b in layoutRubies(panel, w, h))
                        for (var ri = 0;
                            ri < panel.chords[b.chordIndex].rubies.length;
                            ri++)
                          pw.Positioned(
                            left: b.left,
                            top: b.top + ri * b.chipH,
                            child: pw.SizedBox(
                              width: b.chipW,
                              height: b.chipH,
                              child: pw.Center(
                                child: pw.Text(
                                    panel.chords[b.chordIndex].rubies[ri],
                                    style: pw.TextStyle(
                                        fontSize: b.fontSize * 0.72,
                                        color: PdfColor.fromInt(0xFFC85A17),
                                        fontWeight: pw.FontWeight.bold)),
                              ),
                            ),
                          ),
                    ]),
                  );
                }),
              ),
          ],
        ),
      );
    } else if (score.overlayOnImage) {
      final f = File(score.sourceImagePath);
      final img = f.existsSync() ? pw.MemoryImage(f.readAsBytesSync()) : null;
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Expanded(
                child: pw.LayoutBuilder(builder: (context, cns) {
                  final w = cns!.maxWidth;
                  final h = w / (score.aspect <= 0 ? 1 : score.aspect);
                  return pw.SizedBox(
                    width: w,
                    height: h,
                    child: pw.Stack(
                      children: [
                        if (img != null)
                          pw.Positioned.fill(child: pw.Image(img)),
                        for (final n in score.notes)
                          pw.Positioned(
                            left: n.xFrac * w - 6,
                            top: (n.yFrac * h - 12).clamp(0.0, h - 8),
                            child: pw.Text(n.ruby,
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColor.fromInt(0xFFC85A17),
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      );
    } else {
      // ドレミの列を、練習で読みやすい大きさで印字する
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            pw.Text(title,
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 14),
            pw.Wrap(
              spacing: 10,
              runSpacing: 12,
              children: [
                for (final n in score.notes)
                  pw.Text(n.ruby,
                      style: pw.TextStyle(
                          fontSize: 20, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        ),
      );
    }
    return doc.save();
  }
}
