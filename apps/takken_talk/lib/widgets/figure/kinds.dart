import 'package:flutter/widgets.dart';

import '../../models/core.dart';

/// 図の中身（見出し・ポイント・意見の欄を除いた本体）を、種類ごとにアプリで描く。
/// まだ描けない種類は null を返し、FigureView がサイトの埋め込みページ（WebView）で出す。
/// 描き方はサイトの src/lib/components/FigureCard.svelte と fig/*.svelte にそろえる。
Widget? nativeFigureBody(FigureData figure) {
  switch (figure.kind) {
    default:
      return null;
  }
}
