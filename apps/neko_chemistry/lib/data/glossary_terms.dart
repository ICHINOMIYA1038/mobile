class GlossaryTerm {
  const GlossaryTerm({
    required this.term,
    required this.explanation,
    required this.unit,
  });

  final String term;
  final String explanation;
  final String unit;
}

/// 高校化学の重要語句・元素記号の一覧。クイズとは別に見返せる用語集画面で使う。
const List<GlossaryTerm> kGlossaryTerms = [
  GlossaryTerm(
    term: 'H・He・Li・Be・B・C・N・O・F・Ne',
    explanation: '原子番号1〜10の元素記号。水素・ヘリウム・リチウム・ベリリウム・'
        'ホウ素・炭素・窒素・酸素・フッ素・ネオン。周期表の第1〜2周期を覚える基本。',
    unit: '周期表',
  ),
  GlossaryTerm(
    term: 'Na・Mg・Al・Si・P・S・Cl・Ar',
    explanation: '原子番号11〜18の元素記号。ナトリウム・マグネシウム・アルミニウム・'
        'ケイ素・リン・硫黄・塩素・アルゴン。第3周期の元素。',
    unit: '周期表',
  ),
  GlossaryTerm(
    term: 'モル(mol)',
    explanation: '物質量の単位。1molは6.02×10^23個(アボガドロ定数)の粒子を含む。'
        '原子・分子・イオンなど、粒子の数をまとめて扱うための単位。',
    unit: '物質量',
  ),
  GlossaryTerm(
    term: 'アボガドロ定数',
    explanation: '1molの物質に含まれる粒子の数。6.02×10^23 /mol。',
    unit: '物質量',
  ),
  GlossaryTerm(
    term: 'pH(水素イオン指数)',
    explanation: '水溶液の酸性・塩基性の強さを表す指標。pH=7が中性、7より小さいほど'
        '酸性が強く、7より大きいほど塩基性が強い。',
    unit: '酸と塩基',
  ),
  GlossaryTerm(
    term: '中和',
    explanation: '酸と塩基が反応して、互いの性質を打ち消し合う反応。'
        '一般に塩と水が生成する(酸 + 塩基 → 塩 + 水)。',
    unit: '酸と塩基',
  ),
  GlossaryTerm(
    term: '酸化・還元',
    explanation: '酸化は電子を失うこと(酸化数が増加すること)、還元は電子を'
        '受け取ること(酸化数が減少すること)。酸化と還元は必ず同時に起こる。',
    unit: '酸化還元',
  ),
  GlossaryTerm(
    term: 'イオン化傾向',
    explanation: '金属が水溶液中で陽イオンになろうとする性質の強さの順番。'
        'K>Ca>Na>Mg>Al>Zn>Fe>Ni>Sn>Pb>(H)>Cu>Hg>Ag>Pt>Au の順。',
    unit: '酸化還元',
  ),
  GlossaryTerm(
    term: '共有結合',
    explanation: '原子どうしが電子対を共有してできる結合。非金属原子どうしの'
        '結合に多く見られ、分子を形づくる基本的な結合。',
    unit: '化学結合',
  ),
  GlossaryTerm(
    term: 'イオン結合',
    explanation: '陽イオンと陰イオンが静電気的な引力で結びつく結合。'
        '金属元素と非金属元素からなる化合物(NaClなど)に見られる。',
    unit: '化学結合',
  ),
  GlossaryTerm(
    term: 'ボイルの法則',
    explanation: '温度が一定のとき、気体の体積は圧力に反比例する(PV=一定)。',
    unit: '気体の性質',
  ),
  GlossaryTerm(
    term: 'シャルルの法則',
    explanation: '圧力が一定のとき、気体の体積は絶対温度に比例する。',
    unit: '気体の性質',
  ),
  GlossaryTerm(
    term: 'モル濃度',
    explanation: '溶液1L(リットル)に溶けている溶質の物質量(mol)で表した濃度。'
        '単位はmol/L。',
    unit: '溶液',
  ),
  GlossaryTerm(
    term: 'ル・シャトリエの原理',
    explanation: '平衡状態にある反応の条件(濃度・圧力・温度)を変化させると、'
        'その変化を打ち消す方向に平衡が移動するという原理。',
    unit: '化学反応',
  ),
  GlossaryTerm(
    term: '異性体',
    explanation: '分子式は同じだが、原子のつながり方や立体的な配置が異なる'
        '化合物どうしのこと。',
    unit: '有機化学',
  ),
  GlossaryTerm(
    term: 'アルカン・アルケン・アルキン',
    explanation: '炭化水素の分類。アルカンは炭素間がすべて単結合の飽和'
        '炭化水素、アルケンは二重結合を1つ持つ、アルキンは三重結合を1つ持つ。',
    unit: '有機化学',
  ),
  GlossaryTerm(
    term: '昇華',
    explanation: '固体が液体を経ずに直接気体になる変化(またはその逆)。'
        'ドライアイスが代表例。',
    unit: '物質の三態',
  ),
  GlossaryTerm(
    term: '起電力・電池の正極/負極',
    explanation: '電池でイオン化傾向の大きい金属が使われる電極が負極、'
        '小さい方が正極。負極から正極へ外部回路を電子が流れる。',
    unit: '電池と電気分解',
  ),
  GlossaryTerm(
    term: '凝析・塩析',
    explanation: '凝析は疎水コロイドに少量の電解質を加えて沈殿させること、'
        '塩析は親水コロイドに多量の電解質を加えて沈殿させること。',
    unit: 'コロイド',
  ),
  GlossaryTerm(
    term: 'ヘスの法則',
    explanation: '反応エンタルピー(反応熱)は反応の経路によらず、'
        '反応の始めと終わりの状態だけで決まるという法則。',
    unit: '熱化学',
  ),
  GlossaryTerm(
    term: '触媒',
    explanation: '反応の前後で自身は変化せず、活性化エネルギーを下げて'
        '反応速度を大きくする物質。',
    unit: '反応速度',
  ),
];
