import '../models/countermeasure.dart';
import '../models/measurement_result.dart';

/// 対策の定量テーブル。帯域は 31.5, 63, 125, 250, 500, 1k, 2k, 4k, 8k, 16k Hz。
///
/// 数値の出どころは各 `evidence` に記載(UIにも表示)。いずれも目安で、
/// 施工状態・音の種類で変わる。2026-08-29 に実機フィードバックを受けて
/// 全体に保守的な値へ見直した(耳栓は NRR の実効値、隙間テープは1〜3dB など)。
const countermeasures = <Countermeasure>[
  Countermeasure(
    id: 'curtain',
    name: '防音カーテン',
    routes: {NoiseRoute.window},
    attenuationDb: [0, 0, 0, 0.5, 1.5, 2.5, 3.5, 4.5, 5, 5],
    costMinMan: 0.5,
    costMaxMan: 2,
    evidence:
        '防音専門店(ピアリビング)の実測で話し声・車の音が3〜5dB低減。論文でも窓単体比1〜5dB。低域の低減はほぼ報告なし',
    summary: '窓を厚手の遮音カーテンで覆う。高い音(話し声・鳥の声)向け。',
    caveat: '車・工事の低い音にはほとんど効きません。窓より20cm以上大きいサイズが必要です。',
  ),
  Countermeasure(
    id: 'gap_tape',
    name: '窓の隙間テープ',
    routes: {NoiseRoute.window},
    attenuationDb: [0, 0, 0, 0.5, 1, 2, 3, 3, 3, 3],
    costMinMan: 0.1,
    costMaxMan: 0.3,
    evidence:
        '隙間からの漏れ(高域)を塞ぐ効果のみ。DIY実測記事で1〜3dB程度。隙間風がなければ効果なし',
    summary: 'サッシの隙間を塞ぎ、隙間から抜けてくる高い音を減らす。',
    caveat: '隙間風がない窓では効果が出ません。',
  ),
  Countermeasure(
    id: 'inner_window',
    name: '内窓(二重窓)',
    routes: {NoiseRoute.window},
    attenuationDb: [2, 4, 6, 8, 10, 12, 14, 15, 15, 15],
    costMinMan: 5,
    costMaxMan: 15,
    evidence:
        'LIXIL/YKK AP の内窓カタログ: 単板ガラス窓(T-1, 25dB)に内窓を追加すると T-2〜T-3(30〜35dB)相当。改善幅は中高域で10〜15dB、低域(交通・電車)は数dBに留まる',
    summary: '既存の窓の内側にもう1枚窓を付ける。窓が弱点なら最も効く対策。',
    caveat: '賃貸では管理会社の許可が必要。低音(交通・電車)は10dB程度に留まります。',
    diy: false,
  ),
  Countermeasure(
    id: 'soundproof_glass',
    name: '防音ガラスへ交換',
    routes: {NoiseRoute.window},
    attenuationDb: [1, 3, 5, 7, 9, 11, 12, 12, 12, 12],
    costMinMan: 5,
    costMaxMan: 12,
    evidence:
        '合わせガラス(防音合わせガラス)の遮音等級 T-2〜T-3。単板からの交換で中高域10dB前後の改善',
    summary: '合わせガラス等へ交換。内窓が付けられない場合の選択肢。',
    diy: false,
  ),
  Countermeasure(
    id: 'door_seal',
    name: 'ドアの隙間塞ぎ(戸当たりテープ+ドア下ストッパー)',
    routes: {NoiseRoute.door},
    attenuationDb: [0, 0, 0, 0.5, 1, 2, 3, 3, 3, 3],
    costMinMan: 0.1,
    costMaxMan: 0.5,
    evidence:
        'ドア下・戸当たりの隙間を塞ぐ効果のみ。隙間テープと同様に高域1〜3dB程度',
    summary: 'ドア周りの隙間を塞ぐ。廊下・隣室からの話し声向け。',
  ),
  Countermeasure(
    id: 'bookshelf',
    name: '壁際に本棚・クローゼットを置く',
    routes: {NoiseRoute.wall},
    attenuationDb: [0.5, 1, 1.5, 2, 2, 2, 2, 2, 2, 2],
    costMinMan: 0,
    costMaxMan: 0,
    evidence:
        '建築音響の質量則(面密度を足すと遮音量が増える)に基づく目安。本が詰まった本棚で1〜3dB程度、空の家具ではほぼ0',
    summary: '隣室側の壁に重い家具を密着させ、質量を足す。',
    caveat: '本がぎっしり入っていないと効果は小さいです。',
  ),
  Countermeasure(
    id: 'wall_sheet',
    name: '遮音シート+吸音材を壁に施工',
    routes: {NoiseRoute.wall},
    attenuationDb: [0.5, 1, 2, 3, 5, 7, 8, 8, 8, 8],
    costMinMan: 3,
    costMaxMan: 10,
    evidence:
        '遮音シート(面密度2kg/m²前後)+吸音材のDIY施工の実測記事で中高域3〜8dB。低域は1〜2dB',
    summary: '遮音シート(質量)と吸音材を重ねて壁に貼る。話し声・テレビ音向け。',
    caveat: '吸音材だけでは透過音は下がりません。遮音シートとの組み合わせが必須です。',
  ),
  Countermeasure(
    id: 'absorber_only',
    name: '吸音パネル(単体)',
    routes: {NoiseRoute.wall},
    attenuationDb: [0, 0, 0, 0.5, 1, 1.5, 2, 2, 2, 2],
    costMinMan: 1,
    costMaxMan: 3,
    evidence:
        '吸音材は室内の反射音を減らすだけで透過損失はほぼ増えない(建築音響の基本)。体感で0〜2dB',
    summary: '室内の反響を抑える。外からの音を止める効果は小さい。',
    caveat: '吸音材は「室内の響き」を減らすもので、隣からの音の透過はほぼ変わりません。',
  ),
  Countermeasure(
    id: 'floor_mat',
    name: '防音マット・厚手ラグ',
    routes: {NoiseRoute.floor},
    attenuationDb: [1, 2, 3, 4, 5, 6, 6, 6, 6, 6],
    costMinMan: 0.5,
    costMaxMan: 2,
    evidence:
        '軽量床衝撃音(LL)対策として、防音マット・厚手ラグで下階への伝達を数dB低減するメーカー実測。上階からの音には効かない',
    summary: '床に敷く。自分の足音を下階へ伝えにくくする。上階からの足音には効かない。',
    caveat: '上の階の足音は天井から来るため、床マットでは減りません。',
    sourceKeywords: ['footstep', 'walk', 'door', 'knock'],
  ),
  Countermeasure(
    id: 'vibration_pad',
    name: '防振ゴム(機器の下)',
    routes: {NoiseRoute.source},
    attenuationDb: [4, 4, 3, 2, 1, 0, 0, 0, 0, 0],
    costMinMan: 0.1,
    costMaxMan: 0.5,
    evidence:
        '防振ゴムの振動伝達率(メーカー公表)から、固体伝搬する低域の振動音を2〜4dB低減する目安。空気伝搬音には効かない',
    summary: '室外機・洗濯機・スピーカーの下に敷き、床へ伝わる振動を絶つ。',
    caveat: '自分の機器にしか使えません。隣家の機器が原因なら相談が必要です。',
    sourceKeywords: ['air_conditioner', 'fan', 'motor', 'generator', 'compressor', 'music', 'bass', 'washing'],
  ),
  Countermeasure(
    id: 'earplug',
    name: '耳栓・イヤーマフ',
    routes: {NoiseRoute.personal},
    attenuationDb: [8, 9, 10, 12, 14, 16, 18, 20, 22, 22],
    costMinMan: 0.05,
    costMaxMan: 0.5,
    evidence:
        '製品のNRRは25〜33dBだが、実使用では装着のずれで実効値は (NRR−7)/2 ≈ 10〜13dB と見積もるのが米OSHAの慣行。高域ほど効く',
    summary: '就寝時など自分の耳を守る。部屋の音は変わらないが体感は最も下がる。',
  ),
];

/// 計測結果に対して各対策の効果を予測する。
///
/// 予測モデル: 帯域ごとに `after = before - min(減衰量, before - 床)`。
/// 床(30dB)より下には下がらない。全体値は帯域パワーの合算で再計算する。
class CountermeasureSimulator {
  const CountermeasureSimulator();

  static const floorDb = 30.0;

  /// [routes] は内見診断などから分かっている侵入経路。空なら計測結果から推定する。
  List<CountermeasurePrediction> predict(
    MeasurementResult result, {
    List<NoiseRoute> routes = const [],
  }) {
    final inferred = routes.isNotEmpty ? routes : inferRoutes(result);
    final labels = result.soundLabels
        .map((l) => l.identifier.toLowerCase())
        .toList();
    final beforeBands = result.bands.map((b) => b.leqDb).toList();
    final beforeOverall = beforeBands.isEmpty
        ? result.overallLeqDb
        : MeasurementResult.overallFromBands(beforeBands);

    final predictions = <CountermeasurePrediction>[];
    for (final m in countermeasures) {
      if (m.sourceKeywords.isNotEmpty) {
        final matches = labels.any(
          (l) => m.sourceKeywords.any(l.contains),
        );
        if (!matches) continue;
      }
      final afterBands = <double>[];
      for (var i = 0; i < beforeBands.length; i++) {
        final att = i < m.attenuationDb.length ? m.attenuationDb[i] : 0.0;
        final reducible = (beforeBands[i] - floorDb).clamp(0.0, double.infinity);
        afterBands.add(beforeBands[i] - (att < reducible ? att : reducible));
      }
      final afterOverall = afterBands.isEmpty
          ? beforeOverall
          : MeasurementResult.overallFromBands(afterBands);
      final delta = beforeOverall - afterOverall;
      final matchesRoute =
          m.routes.contains(NoiseRoute.personal) ||
          m.routes.any(inferred.contains);
      final (verdict, reason) = _judge(m, delta, result, matchesRoute);
      predictions.add(
        CountermeasurePrediction(
          measure: m,
          beforeDb: beforeOverall,
          afterDb: afterOverall,
          beforeBands: beforeBands,
          afterBands: afterBands,
          matchesRoute: matchesRoute,
          verdict: verdict,
          reason: reason,
        ),
      );
    }
    predictions.sort((a, b) {
      // 経路が合っているものを先に、その中で効果の大きい順。
      // 耳栓のような「部屋を変えない」個人対策は参考として末尾に置く。
      final aPersonal = a.measure.routes.contains(NoiseRoute.personal);
      final bPersonal = b.measure.routes.contains(NoiseRoute.personal);
      if (aPersonal != bPersonal) return aPersonal ? 1 : -1;
      if (a.matchesRoute != b.matchesRoute) return a.matchesRoute ? -1 : 1;
      return b.deltaDb.compareTo(a.deltaDb);
    });
    return predictions;
  }

  /// 帯域分布と音源から侵入経路を推定する。
  /// 低音中心 → 壁・構造(質量が必要)、高音中心 → 窓・ドアの隙間。
  static List<NoiseRoute> inferRoutes(MeasurementResult result) {
    final routes = <NoiseRoute>[];
    final labels = result.soundLabels.map((l) => l.identifier.toLowerCase());
    if (labels.any((l) => l.contains('footstep') || l.contains('walk'))) {
      routes.add(NoiseRoute.floor);
    }
    if (result.lowShare > 0.55) {
      routes.addAll([NoiseRoute.wall, NoiseRoute.window]);
    } else if (result.highShare > 0.35) {
      routes.addAll([NoiseRoute.window, NoiseRoute.door]);
    } else {
      routes.addAll([NoiseRoute.window, NoiseRoute.wall]);
    }
    return routes;
  }

  (PredictionVerdict, String) _judge(
    Countermeasure m,
    double delta,
    MeasurementResult result,
    bool matchesRoute,
  ) {
    final lowHeavy = result.lowShare > 0.55;
    if (delta < 1) {
      final why = lowHeavy && m.attenuationDb.take(3).every((a) => a < 1)
          ? '低い音が中心のため、この対策では下がりません'
          : '今回の音にはほぼ効果がありません';
      return (PredictionVerdict.none, why);
    }
    if (!matchesRoute) {
      return (
        delta < 3 ? PredictionVerdict.small : PredictionVerdict.medium,
        '推定された侵入経路(${_routeNames(result)})とは別の場所への対策です',
      );
    }
    if (delta < 3) return (PredictionVerdict.small, '体感でわずかに変わる程度です');
    if (delta < 6) return (PredictionVerdict.medium, '「少し静かになった」と感じる差です');
    return (PredictionVerdict.large, '音量が半分近くに感じられる差です');
  }

  String _routeNames(MeasurementResult result) =>
      inferRoutes(result).map((r) => r.label).join('・');
}
