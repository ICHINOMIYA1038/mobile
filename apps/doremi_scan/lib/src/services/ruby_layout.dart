import '../models/score.dart';

/// 1和音ぶんのルビ列の配置（自動レイアウトの計算結果）。
class ChordBox {
  final int chordIndex;
  final double left;
  final double top;
  final double chipW;
  final double chipH;
  final double fontSize;
  const ChordBox(this.chordIndex, this.left, this.top, this.chipW, this.chipH,
      this.fontSize);
}

/// ルビの自動レイアウト（画面表示とPDFで共通）。
/// - いちばん上のスタッフ: 五線のすぐ上のレーンに整列
/// - それ以外のスタッフ(大譜表のヘ音など): 五線のすぐ下のレーンに整列
///   （市販のドレミ付き楽譜の左手表記と同じ。上に置くと段間の空白に浮いて
///   自分の音符から離れて見える）
/// - 五線の位置が下半分にある単独スタッフも下レーン（上の空間は別の段の絵）
/// - 文字サイズは音符の間隔から自動計算、横に重なるときだけ隣の行へ逃がす
List<ChordBox> layoutRubies(ScorePanel panel, double w, double h) {
  final boxes = <ChordBox>[];
  final byStaff = <int, List<int>>{};
  for (var i = 0; i < panel.chords.length; i++) {
    byStaff.putIfAbsent(panel.chords[i].staff, () => []).add(i);
  }
  // パネル内でいちばん上にあるスタッフ（このスタッフだけ上レーン候補）
  int? topmostStaff;
  double topmostTop = double.infinity;
  for (final s in panel.staves) {
    if (s.topFrac < topmostTop) {
      topmostTop = s.topFrac;
      topmostStaff = s.staff;
    }
  }
  for (final entry in byStaff.entries) {
    final staff = entry.key;
    final idxs = List<int>.from(entry.value)
      ..sort(
          (a, b) => panel.chords[a].xFrac.compareTo(panel.chords[b].xFrac));
    final st = panel.staves.where((s) => s.staff == staff).toList();
    // 上レーンか下レーンか
    bool above;
    double laneEdge; // above: レーン下端 / below: レーン上端
    if (st.isNotEmpty) {
      above = staff == topmostStaff && st.first.topFrac <= 0.45;
      laneEdge = above ? st.first.topFrac * h - 3 : st.first.bottomFrac * h + 4;
    } else {
      above = true;
      laneEdge = idxs
              .map((i) => panel.chords[i].yFrac)
              .reduce((a, b) => a < b ? a : b) *
          h -
          5;
    }
    // 文字サイズ: 隣り合う和音の間隔(中央値)に合わせる
    final gaps = <double>[];
    for (var k = 1; k < idxs.length; k++) {
      gaps.add(
          (panel.chords[idxs[k]].xFrac - panel.chords[idxs[k - 1]].xFrac) * w);
    }
    gaps.sort();
    final medGap = gaps.isEmpty ? 40.0 : gaps[gaps.length ~/ 2];
    final chipW = (medGap * 0.95).clamp(16.0, 32.0);
    final fontSize = (chipW * 0.42).clamp(7.5, 13.0);
    final chipH = fontSize + 5.0;
    // 互い違い配置: 横に重なるときだけ隣の行へ（上レーンはさらに上、下レーンはさらに下）
    final rowRight = <double>[-1e9, -1e9];
    double row0Edge = above ? 1e9 : -1e9; // 行0の列の外側端
    for (final ci in idxs) {
      final chord = panel.chords[ci];
      final left = chord.xFrac * w - chipW / 2;
      final colH = chipH * chord.rubies.length;
      int row;
      if (left >= rowRight[0] + 1) {
        row = 0;
      } else if (left >= rowRight[1] + 1) {
        row = 1;
      } else {
        row = rowRight[0] <= rowRight[1] ? 0 : 1;
      }
      double top;
      if (above) {
        var bottom = laneEdge;
        if (row == 1) {
          bottom = (laneEdge - chipH - 2) < (row0Edge - 2)
              ? laneEdge - chipH - 2
              : row0Edge - 2;
        }
        top = (bottom - colH).clamp(0.0, h - chipH);
        if (row == 0) row0Edge = top;
      } else {
        top = laneEdge;
        if (row == 1) {
          top = (laneEdge + chipH + 2) > (row0Edge + 2)
              ? laneEdge + chipH + 2
              : row0Edge + 2;
        }
        top = top.clamp(0.0, h - colH);
        if (row == 0) row0Edge = top + colH;
      }
      rowRight[row] = left + chipW;
      boxes.add(ChordBox(ci, left, top, chipW, chipH, fontSize));
    }
  }
  return boxes;
}
