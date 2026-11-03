import '../models/countermeasure.dart';
import '../models/impulse_result.dart';
import '../models/inspection.dart';

/// 壁の推定の文に添える但し書き(ノックは叩いた所の板の裏までしかわからない)。
const _wallEstimateNote = '叩いた所の板の裏までの音からの目安で、壁の厚さや遮音の等級を確かめたものではありません。';

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
  heavy(
    '重い壁に近い音',
    '短く詰まった音で余韻がほぼなく、RC・厚い壁に近い音です。$_wallEstimateNote',
  ),
  medium('中程度の壁に近い音', '一般的な間仕切り壁に近い音です。$_wallEstimateNote'),
  light(
    '軽い壁に近い音',
    '低く響いて余韻が残り、石膏ボードなど中が空洞の壁に近い音です。$_wallEstimateNote',
  ),
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
    // 余韻が測れなかった(叩きが弱くSNR不足、または1.2秒以内に減衰しない)ときは
    // 「重い壁」と決めつけず判定不能にする(以前は最良判定=減点0になっていた)。
    if (ring == null) return unknown;
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
    required this.takenSteps,
    required this.evaluatedSteps,
    this.notes = const [],
  });

  final int score;
  final List<ScoreComponent> components;
  final WallEstimate wall;
  final double? rt60;
  /// 測った項目の数(評価できたかどうかに関わらず、結果が保存されているステップ)。
  final int takenSteps;

  /// 点に入れた(評価できた)項目の数。
  final int evaluatedSteps;

  /// 計測したが評価できなかった項目の案内(点にも「評価できた項目」にも入れていない)。
  final List<String> notes;

  /// 評価できた項目が1つも無い(窓際だけ測った、など)ときは点を出さない。
  bool get isEvaluated => evaluatedSteps > 0;

  /// 画面・PDF に出す項目の数。測ったのに評価できなかった項目があれば、評価できた数も添える。
  String get stepsText {
    final taken = '測った項目 $takenSteps/${InspectionStep.values.length}';
    return takenSteps == evaluatedSteps ? taken : '$taken(評価できたのは$evaluatedSteps)';
  }

  /// 一覧・PDF の「スコア順」。点の高い順で、評価できた項目が無い記録(点が「—」)は後ろへ。
  static int compareByScore(InspectionScore a, InspectionScore b) {
    if (a.isEvaluated != b.isEvaluated) return a.isEvaluated ? -1 : 1;
    return b.score.compareTo(a.score);
  }

  /// 画面・PDF に出す点。評価できた項目が無ければ「—」。
  String get scoreText => isEvaluated ? '$score' : '—';

  String get grade {
    if (!isEvaluated) return '—';
    if (score >= 80) return 'A';
    if (score >= 65) return 'B';
    if (score >= 50) return 'C';
    if (score >= 35) return 'D';
    return 'E';
  }

  String get gradeLabel {
    if (!isEvaluated) return '評価できる項目がありません';
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
/// 「測った項目 n/5」と明示する)。
///
/// 窓際・隣室側は部屋の中央との差で採点するので、中央が無いときは評価できない。
/// 手叩きで残響が出なかったときも評価できない。どちらも減点0(=良い)とは扱わず、
/// 「評価できた項目」に数えず、[InspectionScore.notes] に案内を入れる。
class InspectionScorer {
  const InspectionScorer();

  static const ambientQuietDb = 40.0;

  static const needsAmbientNote = '窓際・隣室側は、部屋の中央を測ると評価できます(中央との差で採点します)。';
  static const clapRetryNote = '手叩きの残響を測れませんでした。静かにして手を1回強めに叩き、測り直してください。';

  InspectionScore score(Inspection inspection) {
    final components = <ScoreComponent>[];
    var evaluated = 0;

    final ambient = inspection.ambient;
    if (ambient != null) {
      evaluated++;
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

    final notes = <String>[];
    if (ambient == null &&
        (inspection.window != null || inspection.neighbor != null)) {
      notes.add(needsAmbientNote);
    }

    final window = inspection.window;
    if (window != null && ambient != null) {
      evaluated++;
      final delta = window.overallLeqDb - ambient.overallLeqDb;
      final penalty = ((delta - 2) * 3).clamp(0.0, 20.0);
      final kind = window.highShare > window.lowShare ? '高音中心(隙間・ガラス)' : '低音中心(交通・構造)';
      components.add(
        ScoreComponent(
          key: 'window',
          label: '窓からの音',
          penalty: penalty,
          detail: '中央より${delta >= 0 ? '+' : ''}${delta.round()}dB ・ $kind',
          route: NoiseRoute.window,
        ),
      );
    }

    final wall = WallEstimate.fromKnock(inspection.knock);
    if (inspection.knock != null) {
      evaluated++;
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
    if (inspection.clap != null && rt60 == null) notes.add(clapRetryNote);
    if (rt60 != null) {
      evaluated++;
      final penalty = rt60 < 0.5
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
          detail: '残響 ${rt60.toStringAsFixed(1)}秒${rt60 >= 0.8 ? '(空室では高めに出ます)' : ''}',
        ),
      );
    }

    final neighbor = inspection.neighbor;
    if (neighbor != null && ambient != null) {
      evaluated++;
      final delta = neighbor.overallLeqDb - ambient.overallLeqDb;
      final penalty = ((delta - 2) * 3).clamp(0.0, 15.0);
      components.add(
        ScoreComponent(
          key: 'neighbor',
          label: '隣室・廊下側',
          penalty: penalty,
          detail: '中央より${delta >= 0 ? '+' : ''}${delta.round()}dB',
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
      takenSteps: [
        inspection.ambient,
        inspection.window,
        inspection.knock,
        inspection.clap,
        inspection.neighbor,
      ].where((r) => r != null).length,
      evaluatedSteps: evaluated,
      notes: notes,
    );
  }
}
