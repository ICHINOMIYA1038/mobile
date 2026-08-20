import 'package:flutter/material.dart';

/// 音源ラベルの大分類。時系列グラフの重ね合わせ・凡例の色分けに使う。
///
/// 色は dataviz スキルの検証スクリプト(validate_palette.js)で
/// 隣接CVD・通常視ΔE・コントラストをチェック済みの6色(黄は
/// アプリのアクセント色=ブラスと衝突するため除外)。
enum SoundCategory {
  vehicle('車・交通', Color(0xFF2A78D6), Color(0xFF3987E5)),
  siren('サイレン・警報', Color(0xFFEB6834), Color(0xFFD95926)),
  mechanical('家電・機械音', Color(0xFF1BAF7A), Color(0xFF199E70)),
  voice('人の声・音楽', Color(0xFF4A3AA7), Color(0xFF9085E9)),
  animal('動物', Color(0xFFE87BA4), Color(0xFFD55181)),
  nature('自然音', Color(0xFF008300), Color(0xFF008300));

  const SoundCategory(this.label, this._light, this._dark);

  final String label;
  final Color _light;
  final Color _dark;

  Color color(Brightness brightness) =>
      brightness == Brightness.dark ? _dark : _light;
}

/// 識別子(SNClassifySoundRequestのラベル)からカテゴリを推定する。
/// キーワードの部分一致で判定する(正確な識別子表記は端末実測で随時見直す)。
/// 一致しない場合は null(未分類)を返す。
SoundCategory? categoryForIdentifier(String identifier) {
  final normalized = identifier.toLowerCase();
  for (final entry in _keywordCategories.entries) {
    if (normalized.contains(entry.key)) return entry.value;
  }
  return null;
}

const _keywordCategories = <String, SoundCategory>{
  'traffic': SoundCategory.vehicle,
  'vehicle': SoundCategory.vehicle,
  'engine': SoundCategory.vehicle,
  'motorcycle': SoundCategory.vehicle,
  'truck': SoundCategory.vehicle,
  'bus': SoundCategory.vehicle,
  'car': SoundCategory.vehicle,
  'train': SoundCategory.vehicle,
  'subway': SoundCategory.vehicle,
  'aircraft': SoundCategory.vehicle,
  'airplane': SoundCategory.vehicle,
  'helicopter': SoundCategory.vehicle,
  'siren': SoundCategory.siren,
  'alarm': SoundCategory.siren,
  'horn': SoundCategory.siren,
  'air_conditioner': SoundCategory.mechanical,
  'fan': SoundCategory.mechanical,
  'generator': SoundCategory.mechanical,
  'motor': SoundCategory.mechanical,
  'construction': SoundCategory.mechanical,
  'drill': SoundCategory.mechanical,
  'hammer': SoundCategory.mechanical,
  'saw': SoundCategory.mechanical,
  'door': SoundCategory.mechanical,
  'footstep': SoundCategory.mechanical,
  'speech': SoundCategory.voice,
  'talk': SoundCategory.voice,
  'crowd': SoundCategory.voice,
  'shout': SoundCategory.voice,
  'laughter': SoundCategory.voice,
  'music': SoundCategory.voice,
  'instrument': SoundCategory.voice,
  'singing': SoundCategory.voice,
  'dog': SoundCategory.animal,
  'bark': SoundCategory.animal,
  'cat': SoundCategory.animal,
  'bird': SoundCategory.animal,
  'rain': SoundCategory.nature,
  'wind': SoundCategory.nature,
  'thunder': SoundCategory.nature,
};
