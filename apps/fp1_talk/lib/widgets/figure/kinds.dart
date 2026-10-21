import 'package:flutter/widgets.dart';

import '../../models/core.dart';
import 'kinds/buckets.dart';
import 'kinds/calc.dart';
import 'kinds/common.dart';
import 'kinds/compare.dart';
import 'kinds/decision.dart';
import 'kinds/flow.dart';
import 'kinds/matrix.dart';
import 'kinds/nest.dart';
import 'kinds/numbers.dart';
import 'kinds/relation.dart';
import 'kinds/scale.dart';
import 'kinds/timeline.dart';
import 'kinds/zones.dart';

/// 図の中身（見出し・ポイント・意見の欄を除いた本体）を、種類ごとにアプリで描く。
/// 描けない種類は null を返し、FigureView がサイトの埋め込みページ（WebView）で出す。
/// 描き方はサイトの src/lib/components/FigureCard.svelte と fig/*.svelte にそろえる。
/// - illust は断面図・平面図の SVG の部品（サイトの Illust.svelte に 30 種類以上）なので、WebView のまま
Widget? nativeFigureBody(FigureData figure) {
  final raw = figure.raw;
  final body = switch (figure.kind) {
    'compare' => CompareBody(raw),
    'buckets' => BucketsBody(raw),
    'numbers' => NumbersBody(raw),
    'flow' => FlowBody(raw),
    'nest' => NestBody(raw),
    'timeline' => TimelineBody(raw),
    'calc' => CalcBody(raw),
    'matrix' => MatrixBody(raw),
    'decision' => DecisionBody(raw),
    'scale' => ScaleBody(raw),
    'zones' => ZonesBody(raw),
    'relation' => RelationBody(raw),
    _ => null,
  };
  if (body == null) return null;
  return DefaultTextStyle.merge(style: bodyStyle, child: body);
}
