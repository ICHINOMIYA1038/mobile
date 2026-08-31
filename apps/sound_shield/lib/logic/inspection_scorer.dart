import '../models/countermeasure.dart';
import '../models/impulse_result.dart';
import '../models/inspection.dart';

/// 壁の重さの推定。ノック音の「余韻の長さ」と「低域の共振の強さ」で分ける。
///
/// 根拠: 石膏ボード+空洞の軽量壁は板が太鼓のように共振し、低く(数百Hz以下)
/// 「ボン・コン」と鳴って余韻が残る。RC・厚い壁は叩いても板振動が起きず、
/// 短く詰まった「コツ」という音で余韻がほぼない。
/// ESC-50 の木製ドア(中空パネル)のノック録音27本では、スペクトル重心の中央値
/// 約220Hz・低域(500Hz未満)比 0.7〜0.99・T20 0.05〜0.2s だった
/// (`tool/impulse_lab` で再現可)。実際の壁での閾値調整は実機で行うこと。
/// 絶対的な閾値は端末・叩き方で動くので、判定は3段階にとどめ、SNRが低い場合は判定しない。
enum WallEstimate {
  heavy('重い壁(RC・厚壁相当)', '短く詰まった音で余韻がほぼありません。遮音性は高めです。'),
  medium('中程度の壁', '一般的な間仕切り壁相当です。'),
  light('軽い壁(石膏ボード・中空壁相当)', '低く響いて余韻が残る音。板が共振する中空の壁で、話し声が通りやすい構造です。'),
  unknown('判定できず', 'ノック音が小さすぎました。もう少し強めに叩いてください。');

  const WallEstimate(this.label, this.description);

  final String label;
  final String description;

  /// 余韻(T20、無ければT10×2)がこれ以上なら共振している=軽い壁。
  static const longRingSeconds = 0.12;

  /// 余韻がこれ未満で低域も支配的でなければ、板振動のない重い壁。
  static const shortRingSeconds = 0.06;

  /// 500Hz未満のパワー比がこれ以上なら「低域共振が強い」。
  static const resonantLowShare = 0.8;

  static WallEstimate fromKnock(ImpulseResult? knock) {
    if (knock == null) return unknown;
    if (knock.snrDb < 10) return unknown;
    final ring = knock.t20 ?? (knock.t10 == null ? null : knock.t10! * 2);
    final resonant = knock.lowShare >= resonantLowShare;
    if (ring != null && ring >= longRingSeconds) return light;
    if (resonant && ring != null && ring >= shortRingSeconds) return light;
    if (ring != null && ring < shortRingSeconds && !resonant) return heavy;
    if (ring == null && !resonant) return heavy;
    return medium;
  }
}

/// 減点1項目分。
class ScoreComponent {
  const ScoreComponent({
    required this.key,
    required this.label,
    required this.penalty,
    required this.detail,
    this.route,
  });

  final String key;
  final String label;
  final double penalty;
  final String detail;

  /// この項目が示す侵入経路(対策シミュレーターへ渡す)。
  final NoiseRoute? route;
}

class InspectionScore {
  const InspectionScore({
    required this.score,
    required this.components,
    required this.wall,
    required this.rt60,
    required this.measuredSteps,
  });

  final int score;
  final List<ScoreComponent> components;
  final WallEstimate wall;
  final double? rt60;
  final int measuredSteps;

  String get grade {
    if (score >= 80) return 'A';
    if (score >= 65) return 'B';
    if (score >= 50) return 'C';
    if (score >= 35) return 'D';
    return 'E';
  }

  String get gradeLabel {
    switch (grade) {
      case 'A':
        return '静かな部屋';
      case 'B':
        return 'おおむね良好';
      case 'C':
        return '対策があると安心';
      case 'D':
        return '騒音が気になりやすい';
      default:
        return '騒音リスク高';
    }
  }

  /// 最も減点が大きい項目(弱点)。減点がなければ null。
  ScoreComponent? get weakest {
    ScoreComponent? worst;
    for (final c in components) {
      if (c.penalty <= 0) continue;
      if (worst == null || c.penalty > worst.penalty) worst = c;
    }
    return worst;
  }

  /// 弱点から推定した侵入経路(減点の大きい順、最大2つ)。
  List<NoiseRoute> get routes {
    final sorted = [...components.where((c) => c.penalty > 0 && c.route != null)]
      ..sort((a, b) => b.penalty.compareTo(a.penalty));
    return sorted.map((c) => c.route!).take(2).toList();
  }
}

/// 内見診断の採点。未計測ステップは減点しない(ただしスコア表示時に
/// 「n/5項目」と明示する)。
class InspectionScorer {
  const InspectionScorer();

  static const ambientQuietDb = 40.0;

  InspectionScore score(Inspection inspection) {
    final components = <ScoreComponent>[];
    var measured = 0;

    final ambient = inspection.ambient;
    if (ambient != null) {
      measured++;
      final over = ambient.overallLeqDb - ambientQuietDb;
      final penalty = (over * 1.5).clamp(0.0, 30.0);
      components.add(
        ScoreComponent(
          key: 'ambient',
          label: '室内の静けさ',
          penalty: penalty,
          detail: '${ambient.overallLeqDb.round()}dB'
              '${over > 0 ? '(目安の${ambientQuietDb.round()}dBを${over.round()}dB超過)' : '(静か)'}',
          route: ambient.lowShare > 0.5 ? NoiseRoute.wall : NoiseRoute.window,
        ),
      );
    }

    final window = inspection.window;
    if (window != null) {
      measured++;
      final delta = ambient == null
          ? 0.0
          : window.overallLeqDb - ambient.overallLeqDb;
      final penalty = ((delta - 2) * 3).clamp(0.0, 20.0);
      final kind = window.highShare > window.lowShare ? '高音中心(隙間・ガラス)' : '低音中心(交通・構造)';
      components.add(
        ScoreComponent(
          key: 'window',
          label: '窓からの音',
          penalty: penalty,
          detail: ambient == null
              ? '${window.overallLeqDb.round()}dB'
              : '中央より${delta >= 0 ? '+' : ''}${delta.round()}dB ・ $kind',
          route: NoiseRoute.window,
        ),
      );
    }

    final wall = WallEstimate.fromKnock(inspection.knock);
    if (inspection.knock != null) {
      measured++;
      final penalty = switch (wall) {
        WallEstimate.heavy => 0.0,
        WallEstimate.medium => 8.0,
        WallEstimate.light => 20.0,
        WallEstimate.unknown => 5.0,
      };
      components.add(
        ScoreComponent(
          key: 'wall',
          label: '壁の重さ',
          penalty: penalty,
          detail: wall.label,
          route: NoiseRoute.wall,
        ),
      );
    }

    final rt60 = inspection.clap?.rt60;
    if (inspection.clap != null) {
      measured++;
      final penalty = rt60 == null
          ? 0.0
          : rt60 < 0.5
          ? 0.0
          : rt60 < 0.8
          ? 3.0
          : rt60 < 1.2
          ? 6.0
          : 10.0;
      components.add(
        ScoreComponent(
          key: 'reverb',
          label: '部屋の響き',
          penalty: penalty,
          detail: rt60 == null
              ? '測定できず'
              : '残響 ${rt60.toStringAsFixed(1)}秒${rt60 >= 0.8 ? '(空室では高めに出ます)' : ''}',
        ),
      );
    }

    final neighbor = inspection.neighbor;
    if (neighbor != null) {
      measured++;
      final delta = ambient == null
          ? 0.0
          : neighbor.overallLeqDb - ambient.overallLeqDb;
      final penalty = ((delta - 2) * 3).clamp(0.0, 15.0);
      components.add(
        ScoreComponent(
          key: 'neighbor',
          label: '隣室・廊下側',
          penalty: penalty,
          detail: ambient == null
              ? '${neighbor.overallLeqDb.round()}dB'
              : '中央より${delta >= 0 ? '+' : ''}${delta.round()}dB',
          route: NoiseRoute.door,
        ),
      );
    }

    final total = components.fold(0.0, (sum, c) => sum + c.penalty);
    return InspectionScore(
      score: (100 - total).round().clamp(0, 100),
      components: components,
      wall: wall,
      rt60: rt60,
      measuredSteps: measured,
    );
  }
}
