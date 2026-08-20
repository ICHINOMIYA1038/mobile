import '../models/measurement_result.dart';
import '../models/suggestion.dart';
import 'noise_level.dart';

class _SoundCategory {
  const _SoundCategory({required this.keywords, required this.suggestions});

  /// 音源ラベル(識別子)にこれらの単語のいずれかが含まれていれば一致とみなす。
  /// SNClassifySoundRequestの識別子の正確な表記は端末実測で随時見直す。
  final List<String> keywords;
  final List<Suggestion> suggestions;
}

const _categories = <_SoundCategory>[
  _SoundCategory(
    keywords: ['traffic', 'vehicle', 'car', 'truck', 'motorcycle', 'bus'],
    suggestions: [
      Suggestion(
        title: '二重窓・防音窓に交換する',
        description: '車の走行音は主に窓から侵入します。二重窓や防音ガラスへの交換が効果的です。',
      ),
      Suggestion(
        title: '防音カーテンを設置する',
        description: '厚手の防音カーテンは中〜高音域の走行音を軽減します。',
      ),
    ],
  ),
  _SoundCategory(
    keywords: ['siren', 'alarm', 'horn'],
    suggestions: [
      Suggestion(
        title: '窓・玄関の隙間を塞ぐ',
        description: 'サイレンやクラクションのような突発音は窓枠や玄関ドアの隙間から侵入しやすいため、隙間テープが有効です。',
      ),
    ],
  ),
  _SoundCategory(
    keywords: ['dog', 'bark', 'animal', 'cat', 'bird'],
    suggestions: [
      Suggestion(
        title: 'ベランダ・窓側に吸音パネルを置く',
        description: '鳴き声のような中高音域の音は、吸音材で反射を抑えると体感音量を下げられます。',
      ),
    ],
  ),
  _SoundCategory(
    keywords: ['speech', 'talk', 'crowd', 'shout', 'laughter', 'conversation'],
    suggestions: [
      Suggestion(
        title: '厚手のカーテン・ラグを敷く',
        description: '話し声などの生活音は、部屋内の反響を抑えるカーテンやラグでも体感を下げられます。',
      ),
      Suggestion(
        title: '壁に吸音パネルを設置する',
        description: '壁越しの話し声が気になる場合は、壁面への吸音パネル設置も効果的です。',
      ),
    ],
  ),
  _SoundCategory(
    keywords: ['construction', 'drill', 'hammer', 'saw', 'tool'],
    suggestions: [
      Suggestion(
        title: '耳栓・イヤーマフを併用する',
        description: '工事音は低音域を含み建材の防音だけでは軽減しづらいため、耳栓の併用も検討してください。',
      ),
      Suggestion(
        title: '防音カーテン・遮音シートを窓に追加する',
        description: '工事現場からの音は窓からの侵入が大きいため、遮音シート入りカーテンが効果的です。',
      ),
    ],
  ),
  _SoundCategory(
    keywords: [
      'air_conditioner',
      'airconditioner',
      'fan',
      'generator',
      'compressor',
      'hvac',
      'motor',
    ],
    suggestions: [
      Suggestion(
        title: '防振ゴムを設置する',
        description: 'エアコン室外機やモーター音のような低音域の振動音は、機器の下に防振ゴムを敷くと軽減できます。',
      ),
      Suggestion(
        title: '防音パネルで囲う',
        description: '室外機などの機械音は、周囲を防音パネルで囲うことで直接音を遮れます。',
      ),
    ],
  ),
  _SoundCategory(
    keywords: ['music', 'instrument', 'singing', 'bass', 'drum'],
    suggestions: [
      Suggestion(
        title: '壁に吸音パネルを設置する',
        description: '音楽や楽器音は低音域を含むことが多く、壁面の吸音パネルや防振材が効果的です。',
      ),
    ],
  ),
  _SoundCategory(
    keywords: ['footstep', 'walk', 'door', 'slam', 'knock'],
    suggestions: [
      Suggestion(
        title: '床にラグ・防音マットを敷く',
        description: '足音やドアの開閉音は建具や床からの振動が原因のことが多く、防音マットが効果的です。',
      ),
    ],
  ),
  _SoundCategory(
    keywords: ['rain', 'wind', 'thunder'],
    suggestions: [
      Suggestion(
        title: '窓のパッキンを確認する',
        description: '雨風の音は窓の隙間から侵入しやすいため、サッシのパッキンの劣化を確認し、必要なら交換してください。',
      ),
    ],
  ),
  _SoundCategory(
    keywords: ['aircraft', 'airplane', 'helicopter', 'train', 'railway', 'subway'],
    suggestions: [
      Suggestion(
        title: '防音窓・二重サッシを検討する',
        description: '航空機や電車の音は低音域を多く含み遠くまで届くため、防音性能の高い窓への交換が最も効果的です。',
      ),
    ],
  ),
];

const _lowFreqSuggestions = [
  Suggestion(
    title: '防振ゴム・防振マットを使う',
    description: '低い音(250Hz以下)は振動として建物を伝わりやすいため、発生源の下に防振ゴムを敷くと効果的です。',
  ),
  Suggestion(
    title: '重量のある遮音材を使う',
    description: '低音は薄い素材では防ぎにくいため、遮音シートや重量のあるカーテンで軽減します。',
  ),
];

const _midFreqSuggestions = [
  Suggestion(
    title: '吸音材・カーペットを取り入れる',
    description: '中音域(250Hz〜2kHz)の音は生活音や話し声に多く、吸音材やカーペットで反響を抑えると体感音量が下がります。',
  ),
];

const _highFreqSuggestions = [
  Suggestion(
    title: '隙間テープ・厚手カーテンで塞ぐ',
    description: '高い音(2kHz以上)は窓やドアの小さな隙間からも侵入しやすいため、隙間テープや厚手のカーテンが効果的です。',
  ),
];

/// 計測結果(検出音源ラベル・支配的な周波数帯)からルールベースで対策を提案する。
/// ネットワーク通信・LLMは使わずオフラインで完結させる。
///
/// 静かな環境(目安40dB未満)では、特定の音源が確信度高く検出されない限り
/// 対策は提案しない。騒音が無いのに汎用の対策を出すのは誤りなので、
/// 周波数帯起点の汎用提案は実際にある程度の音量があった場合に限る。
class SuggestionEngine {
  const SuggestionEngine();

  static const _labelConfidenceThreshold = 0.4;

  List<Suggestion> suggest(MeasurementResult result) {
    final suggestions = <Suggestion>[];

    for (final label in result.soundLabels) {
      if (label.avgConfidence < _labelConfidenceThreshold) continue;
      final normalized = label.identifier.toLowerCase();
      for (final category in _categories) {
        final matches = category.keywords.any(normalized.contains);
        if (!matches) continue;
        for (final suggestion in category.suggestions) {
          if (!suggestions.contains(suggestion)) {
            suggestions.add(suggestion);
          }
        }
      }
    }

    if (noiseLevelForDb(result.overallLeqDb) != NoiseLevel.quiet) {
      final dominantBand = result.dominantBand;
      if (dominantBand != null) {
        for (final suggestion in _suggestionsForFrequency(dominantBand.centerHz)) {
          if (!suggestions.contains(suggestion)) {
            suggestions.add(suggestion);
          }
        }
      }
    }

    return suggestions;
  }

  List<Suggestion> _suggestionsForFrequency(double centerHz) {
    if (centerHz < 250) return _lowFreqSuggestions;
    if (centerHz < 2000) return _midFreqSuggestions;
    return _highFreqSuggestions;
  }
}
