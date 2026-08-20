/// 元素のカテゴリ。周期表タイルの色分けに使う。
enum ElementCategory {
  alkaliMetal,
  alkalineEarthMetal,
  transitionMetal,
  metalloid,
  nonmetal,
  halogen,
  nobleGas,
  otherMetal,
}

class ElementInfo {
  const ElementInfo({
    required this.symbol,
    required this.name,
    required this.atomicNumber,
    required this.category,
    required this.description,
  });

  final String symbol;
  final String name;
  final int atomicNumber;
  final ElementCategory category;
  final String description;
}

/// 高校化学でよく登場する元素だけに絞った簡易周期表データ。
/// 第1〜4周期の典型元素(1・2・13〜18族)と、代表的な遷移金属をまとめている。
const kElements = <String, ElementInfo>{
  'H': ElementInfo(
    symbol: 'H',
    name: '水素',
    atomicNumber: 1,
    category: ElementCategory.nonmetal,
    description: '宇宙で最も多い元素。単体は無色・無臭の気体で、水や有機化合物の構成元素。',
  ),
  'He': ElementInfo(
    symbol: 'He',
    name: 'ヘリウム',
    atomicNumber: 2,
    category: ElementCategory.nobleGas,
    description: '反応性がほぼない貴ガス。風船や冷却剤に利用される。',
  ),
  'Li': ElementInfo(
    symbol: 'Li',
    name: 'リチウム',
    atomicNumber: 3,
    category: ElementCategory.alkaliMetal,
    description: '最も軽い金属。反応性が高いアルカリ金属で、リチウムイオン電池に利用。',
  ),
  'Be': ElementInfo(
    symbol: 'Be',
    name: 'ベリリウム',
    atomicNumber: 4,
    category: ElementCategory.alkalineEarthMetal,
    description: '軽くて硬いアルカリ土類金属。合金材料として使われる。',
  ),
  'B': ElementInfo(
    symbol: 'B',
    name: 'ホウ素',
    atomicNumber: 5,
    category: ElementCategory.metalloid,
    description: '金属と非金属の中間の性質を持つ半金属。ガラスや洗剤に利用。',
  ),
  'C': ElementInfo(
    symbol: 'C',
    name: '炭素',
    atomicNumber: 6,
    category: ElementCategory.nonmetal,
    description: '有機化合物の骨格をつくる元素。ダイヤモンドや黒鉛も炭素の単体。',
  ),
  'N': ElementInfo(
    symbol: 'N',
    name: '窒素',
    atomicNumber: 7,
    category: ElementCategory.nonmetal,
    description: '空気の約8割を占める気体。アンモニア合成などで重要。',
  ),
  'O': ElementInfo(
    symbol: 'O',
    name: '酸素',
    atomicNumber: 8,
    category: ElementCategory.nonmetal,
    description: '呼吸や燃焼に必要な気体。地殻中で最も多く存在する元素でもある。',
  ),
  'F': ElementInfo(
    symbol: 'F',
    name: 'フッ素',
    atomicNumber: 9,
    category: ElementCategory.halogen,
    description: 'ハロゲンの中で最も反応性が高い。歯磨き粉のフッ化物などに利用。',
  ),
  'Ne': ElementInfo(
    symbol: 'Ne',
    name: 'ネオン',
    atomicNumber: 10,
    category: ElementCategory.nobleGas,
    description: '反応しにくい貴ガス。ネオンサインの発光に使われる。',
  ),
  'Na': ElementInfo(
    symbol: 'Na',
    name: 'ナトリウム',
    atomicNumber: 11,
    category: ElementCategory.alkaliMetal,
    description: '水と激しく反応するアルカリ金属。食塩(NaCl)の構成元素。',
  ),
  'Mg': ElementInfo(
    symbol: 'Mg',
    name: 'マグネシウム',
    atomicNumber: 12,
    category: ElementCategory.alkalineEarthMetal,
    description: '軽量なアルカリ土類金属。葉緑素(クロロフィル)にも含まれる。',
  ),
  'Al': ElementInfo(
    symbol: 'Al',
    name: 'アルミニウム',
    atomicNumber: 13,
    category: ElementCategory.otherMetal,
    description: '軽くて加工しやすい金属。表面の酸化被膜が内部を保護する。',
  ),
  'Si': ElementInfo(
    symbol: 'Si',
    name: 'ケイ素',
    atomicNumber: 14,
    category: ElementCategory.metalloid,
    description: '地殻に酸素の次に多く存在する半金属。ガラスや半導体の材料。',
  ),
  'P': ElementInfo(
    symbol: 'P',
    name: 'リン',
    atomicNumber: 15,
    category: ElementCategory.nonmetal,
    description: 'DNAや骨の成分でもある元素。同素体に黄リン・赤リンがある。',
  ),
  'S': ElementInfo(
    symbol: 'S',
    name: '硫黄',
    atomicNumber: 16,
    category: ElementCategory.nonmetal,
    description: '火山地帯で産出する非金属。硫酸の原料として重要。',
  ),
  'Cl': ElementInfo(
    symbol: 'Cl',
    name: '塩素',
    atomicNumber: 17,
    category: ElementCategory.halogen,
    description: '刺激臭のある黄緑色の気体。水道水の殺菌にも使われるハロゲン。',
  ),
  'Ar': ElementInfo(
    symbol: 'Ar',
    name: 'アルゴン',
    atomicNumber: 18,
    category: ElementCategory.nobleGas,
    description: '空気中に約1%含まれる貴ガス。電球の封入ガスに利用。',
  ),
  'K': ElementInfo(
    symbol: 'K',
    name: 'カリウム',
    atomicNumber: 19,
    category: ElementCategory.alkaliMetal,
    description: '水と激しく反応するアルカリ金属。肥料や体内の電解質として重要。',
  ),
  'Ca': ElementInfo(
    symbol: 'Ca',
    name: 'カルシウム',
    atomicNumber: 20,
    category: ElementCategory.alkalineEarthMetal,
    description: '骨や歯の主成分であるアルカリ土類金属。石灰石にも含まれる。',
  ),
  'Ga': ElementInfo(
    symbol: 'Ga',
    name: 'ガリウム',
    atomicNumber: 31,
    category: ElementCategory.otherMetal,
    description: '融点が低く手のひらの体温でも溶ける金属。半導体材料に利用。',
  ),
  'Ge': ElementInfo(
    symbol: 'Ge',
    name: 'ゲルマニウム',
    atomicNumber: 32,
    category: ElementCategory.metalloid,
    description: 'シリコンと似た性質を持つ半金属。半導体の初期材料として使われた。',
  ),
  'As': ElementInfo(
    symbol: 'As',
    name: 'ヒ素',
    atomicNumber: 33,
    category: ElementCategory.metalloid,
    description: '毒性で知られる半金属。半導体材料としても利用される。',
  ),
  'Se': ElementInfo(
    symbol: 'Se',
    name: 'セレン',
    atomicNumber: 34,
    category: ElementCategory.nonmetal,
    description: '光を受けると電気抵抗が変わる性質を持つ非金属。',
  ),
  'Br': ElementInfo(
    symbol: 'Br',
    name: '臭素',
    atomicNumber: 35,
    category: ElementCategory.halogen,
    description: '常温で液体の数少ない元素の一つ。赤褐色でハロゲンの仲間。',
  ),
  'Kr': ElementInfo(
    symbol: 'Kr',
    name: 'クリプトン',
    atomicNumber: 36,
    category: ElementCategory.nobleGas,
    description: '反応性が低い貴ガス。高輝度の照明に利用されることがある。',
  ),
  'Fe': ElementInfo(
    symbol: 'Fe',
    name: '鉄',
    atomicNumber: 26,
    category: ElementCategory.transitionMetal,
    description: '代表的な遷移金属。合金の鋼として建築や道具に広く使われる。',
  ),
  'Cu': ElementInfo(
    symbol: 'Cu',
    name: '銅',
    atomicNumber: 29,
    category: ElementCategory.transitionMetal,
    description: '電気を通しやすい遷移金属。電線や硬貨に利用される。',
  ),
  'Zn': ElementInfo(
    symbol: 'Zn',
    name: '亜鉛',
    atomicNumber: 30,
    category: ElementCategory.transitionMetal,
    description: '鉄をさびから守るめっきに使われる遷移金属。',
  ),
  'Ag': ElementInfo(
    symbol: 'Ag',
    name: '銀',
    atomicNumber: 47,
    category: ElementCategory.transitionMetal,
    description: '金属の中で最も電気・熱を通しやすい遷移金属。',
  ),
};

/// 第1〜4周期・1,2,13〜18族だけの簡易グリッド(nullは空きマス)。
/// 各リストが1つの周期(行)、各要素が族(列: 1,2,13,14,15,16,17,18)に対応する。
const kPeriodicTableGrid = <List<String?>>[
  ['H', null, null, null, null, null, null, 'He'],
  ['Li', 'Be', 'B', 'C', 'N', 'O', 'F', 'Ne'],
  ['Na', 'Mg', 'Al', 'Si', 'P', 'S', 'Cl', 'Ar'],
  ['K', 'Ca', 'Ga', 'Ge', 'As', 'Se', 'Br', 'Kr'],
];

/// メイングリッドには収まらない代表的な遷移金属。
const kOtherElements = <String>['Fe', 'Cu', 'Zn', 'Ag'];
