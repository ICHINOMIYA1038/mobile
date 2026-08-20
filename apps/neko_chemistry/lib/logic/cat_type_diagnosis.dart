import 'package:flutter/material.dart';

import '../data/progress_repository.dart';
import '../ui/theme.dart';

enum CatType { theoretical, inorganic, organic }

class CatTypeInfo {
  const CatTypeInfo({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String label;
  final String description;
  final IconData icon;
  final Color color;
}

const _catTypeInfo = {
  CatType.theoretical: CatTypeInfo(
    label: '計算派の猫',
    description: 'モル計算やpH、酸化数の計算がお手のもの。コツコツ理論を積み上げるのが得意なタイプ。',
    icon: Icons.calculate,
    color: nekoOrange,
  ),
  CatType.inorganic: CatTypeInfo(
    label: '元素マニアの猫',
    description: '金属イオンや気体の性質を覚えるのが得意。周期表を見るとワクワクするタイプ。',
    icon: Icons.science,
    color: labMint,
  ),
  CatType.organic: CatTypeInfo(
    label: '有機化学ラブの猫',
    description: '分子の構造や異性体を考えるのが好き。パズル感覚で化学を楽しむタイプ。',
    icon: Icons.eco,
    color: Color(0xFF8A7FBB),
  ),
};

/// 単元をより大きな3分野に分類する(実際の高校化学の分野分けに準拠)。
const _theoreticalUnits = [
  '物質の構成',
  '物質量',
  '化学結合',
  '物質の三態',
  '気体の性質',
  '溶液',
  'コロイド',
  '酸と塩基',
  '酸化還元',
  '酸化数',
  '電池と電気分解',
  '熱化学',
  '反応速度',
  '化学反応',
  '周期表',
];
const _inorganicUnits = ['無機化学'];
const _organicUnits = ['有機化学'];

class CatTypeResult {
  const CatTypeResult({required this.type, required this.info});

  final CatType? type;
  final CatTypeInfo? info;

  bool get isDiagnosable => type != null;
}

/// 単元別正答数の合計から、最も得意な分野(理論・無機・有機)を診断する。
/// いずれの分野も一定数(5問)以上解いていない場合は診断不能として扱う。
CatTypeResult diagnoseCatType(Map<String, UnitStats> unitStats) {
  double accuracyFor(List<String> units) {
    var answered = 0;
    var correct = 0;
    for (final unit in units) {
      final stats = unitStats[unit];
      if (stats == null) continue;
      answered += stats.answered;
      correct += stats.correct;
    }
    if (answered < 5) return -1;
    return correct / answered;
  }

  final scores = {
    CatType.theoretical: accuracyFor(_theoreticalUnits),
    CatType.inorganic: accuracyFor(_inorganicUnits),
    CatType.organic: accuracyFor(_organicUnits),
  };

  final diagnosable = scores.entries.where((e) => e.value >= 0).toList();
  if (diagnosable.isEmpty) {
    return const CatTypeResult(type: null, info: null);
  }

  diagnosable.sort((a, b) => b.value.compareTo(a.value));
  final winner = diagnosable.first.key;
  return CatTypeResult(type: winner, info: _catTypeInfo[winner]);
}
