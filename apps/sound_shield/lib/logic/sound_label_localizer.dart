/// 音源ラベル識別子を画面表示用の日本語名に変換する。
/// 完全一致の辞書ではなく、キーワードの部分一致で判定する
/// (SNClassifySoundRequestの識別子の正確な表記は端末実測で随時見直す)。
String describeSoundLabel(String identifier) {
  final normalized = identifier.toLowerCase();
  for (final entry in _keywordNames.entries) {
    if (normalized.contains(entry.key)) return entry.value;
  }
  return identifier;
}

const _keywordNames = <String, String>{
  'traffic': '交通音',
  'vehicle': '車の音',
  'engine': 'エンジン音',
  'motorcycle': 'バイクの音',
  'truck': 'トラックの音',
  'bus': 'バスの音',
  'car': '車の音',
  'siren': 'サイレン',
  'alarm': 'アラーム音',
  'horn': 'クラクション',
  'dog': '犬の鳴き声',
  'bark': '犬の鳴き声',
  'cat': '猫の鳴き声',
  'bird': '鳥の鳴き声',
  'speech': '話し声',
  'talk': '話し声',
  'crowd': '人混みの音',
  'shout': '叫び声',
  'laughter': '笑い声',
  'construction': '工事音',
  'drill': 'ドリル音',
  'hammer': '金づちの音',
  'saw': 'のこぎりの音',
  'air_conditioner': 'エアコンの音',
  'fan': '換気扇・ファンの音',
  'generator': '発電機の音',
  'motor': 'モーター音',
  'music': '音楽',
  'instrument': '楽器の音',
  'singing': '歌声',
  'footstep': '足音',
  'door': 'ドアの音',
  'rain': '雨音',
  'wind': '風音',
  'thunder': '雷鳴',
  'aircraft': '航空機の音',
  'airplane': '航空機の音',
  'helicopter': 'ヘリコプターの音',
  'train': '電車の音',
  'subway': '電車の音',
};
