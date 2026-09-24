import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/score.dart';
import '../services/ruby_layout.dart';
import '../theme/app_theme.dart';

/// 段(system)画像の上に、各音符ヘッドの位置へドレミのルビを重ねる表示。
/// 和音は上から下へ縦に並べる。ルビはタップで修正・削除、
/// 空いている場所をタップすると読み落とした音を追加できる。
class PanelsView extends StatelessWidget {
  final List<ScorePanel> panels;

  /// (panelIndex, chordIndex, rubyIndex, 新しいルビ or null=削除)
  final void Function(int panel, int chord, int ruby, String? value) onEdit;

  /// 読み落とした音の手動追加。(panelIndex, 挿入位置, 追加する和音)
  final void Function(int panel, int index, PanelChord chord)? onAdd;

  /// true なら清書（組版し直したきれいな楽譜）がある段はそれを表示。
  final bool showClean;

  const PanelsView(
      {super.key,
      required this.panels,
      required this.onEdit,
      this.onAdd,
      this.showClean = false});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: panels.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Text(
              showClean
                  ? '読み取れた段は、見やすい楽譜に描き直しています。直したいときは「原本＋修正」へ'
                  : 'ドレミをタップ→修正、読み落とした音符をタップ→追加できます',
              style: const TextStyle(color: AppColors.muted, fontSize: 12));
        }
        final panel = panels[i - 1];
        if (showClean && panel.hasClean) {
          final image = AspectRatio(
            aspectRatio: panel.cleanAspect,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                Uint8List.fromList(panel.cleanBytes!),
                fit: BoxFit.fill,
                gaplessPlayback: true,
              ),
            ),
          );
          if (panel.cleanTrusted) return image;
          // 検証に落ちた段: 正しそうに見える間違いを黙って渡さない
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              image,
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text('⚠️ 読み取りが不完全な可能性があります。「原本＋修正」で確認を',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.brandDark)),
              ),
            ],
          );
        }
        return _Panel(
            panel: panel, panelIndex: i - 1, onEdit: onEdit, onAdd: onAdd);
      },
    );
  }
}

class _Panel extends StatelessWidget {
  final ScorePanel panel;
  final int panelIndex;
  final void Function(int panel, int chord, int ruby, String? value) onEdit;
  final void Function(int panel, int index, PanelChord chord)? onAdd;
  const _Panel(
      {required this.panel,
      required this.panelIndex,
      required this.onEdit,
      this.onAdd});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final h = w / panel.aspect;
      final boxes = layoutRubies(panel, w, h);
      return SizedBox(
        width: w,
        height: h,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTapUp: onAdd == null
                    ? null
                    : (d) => _add(context, d.localPosition.dx / w,
                        d.localPosition.dy / h),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(
                    Uint8List.fromList(panel.imageBytes),
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
            for (final b in boxes)
              Positioned(
                // タップしやすいよう、当たり判定は最低44px幅に広げる
                // （見た目のチップ幅 chipW はそのまま）
                left: b.left - (b.chipW < 44 ? (44 - b.chipW) / 2 : 0),
                top: b.top,
                width: b.chipW < 44 ? 44 : b.chipW,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var ri = 0;
                        ri < panel.chords[b.chordIndex].rubies.length;
                        ri++)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _edit(context, b.chordIndex, ri),
                        child: SizedBox(
                          height: b.chipH,
                          child: Center(
                            child: Container(
                              width: b.chipW,
                              height: b.chipH,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  panel.chords[b.chordIndex].rubies[ri],
                                  style: TextStyle(
                                    color: AppColors.brandDark,
                                    fontSize: b.fontSize,
                                    fontWeight: FontWeight.w800,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }

  /// ドレミ選択シート。deletable=true なら削除ボタン付き。
  Future<String?> _pickRuby(BuildContext context,
      {required String title, required bool deletable}) {
    const steps = ['ド', 'レ', 'ミ', 'ファ', 'ソ', 'ラ', 'シ'];
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in steps) ...[
                    _pick(ctx, s),
                    _pick(ctx, '$s♯'),
                    _pick(ctx, '$s♭'),
                  ],
                ],
              ),
              if (deletable) ...[
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: () => Navigator.of(ctx).pop('__delete__'),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('この音を削除',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, int chordIndex, int rubyIndex) async {
    final current = panel.chords[chordIndex].rubies[rubyIndex];
    final result =
        await _pickRuby(context, title: '「$current」を修正', deletable: true);
    if (result == null) return;
    onEdit(panelIndex, chordIndex, rubyIndex,
        result == '__delete__' ? null : result);
  }

  /// 空きスペースのタップ = 読み落とした音の追加。
  /// タップ位置に近いスタッフへ入れ、左→右の並び順を保つ位置に挿入する。
  Future<void> _add(BuildContext context, double xFrac, double yFrac) async {
    final result =
        await _pickRuby(context, title: 'この位置に音を追加', deletable: false);
    if (result == null) return;
    // タップのyに最も近いスタッフ
    var staff = 1;
    double best = double.infinity;
    for (final s in panel.staves) {
      final d = ((s.topFrac + s.bottomFrac) / 2 - yFrac).abs();
      if (d < best) {
        best = d;
        staff = s.staff;
      }
    }
    if (panel.staves.isEmpty && panel.chords.isNotEmpty) {
      // 五線情報がなければ、yが近い既存和音のスタッフに合わせる
      final nearest = panel.chords.reduce((a, b) =>
          (a.yFrac - yFrac).abs() < (b.yFrac - yFrac).abs() ? a : b);
      staff = nearest.staff;
    }
    var index = panel.chords.length;
    for (var i = 0; i < panel.chords.length; i++) {
      final c = panel.chords[i];
      if (c.staff > staff || (c.staff == staff && c.xFrac > xFrac)) {
        index = i;
        break;
      }
    }
    onAdd?.call(panelIndex, index,
        PanelChord(xFrac: xFrac, yFrac: yFrac, staff: staff, rubies: [result]));
  }

  Widget _pick(BuildContext ctx, String label) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: const BorderSide(color: AppColors.line),
        foregroundColor: AppColors.ink,
      ),
      onPressed: () => Navigator.of(ctx).pop(label),
      child: Text(label, style: const TextStyle(fontSize: 16)),
    );
  }
}
