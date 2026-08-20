/// お題に付けられる横断的なNGフラグ。NG設定画面でユーザーが個別にON/OFFできる。
class NgTag {
  const NgTag({required this.id, required this.label});

  final String id;
  final String label;
}

const kNgTags = [
  NgTag(id: 'romance', label: '恋愛'),
  NgTag(id: 'politics', label: '政治'),
  NgTag(id: 'religion', label: '宗教'),
  NgTag(id: 'money', label: 'お金・収入'),
  NgTag(id: 'appearance', label: '容姿'),
  NgTag(id: 'controversial', label: '炎上しやすい話題'),
];
