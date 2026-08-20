import 'package:flutter/material.dart';

/// 配信のシチュエーション。ホーム画面のタイル・お題の分類軸になる。
class Situation {
  const Situation({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
}

const kSituations = [
  Situation(
    id: 'opening',
    label: 'オープニング',
    description: '配信開始の挨拶ネタ',
    icon: Icons.wb_sunny_rounded,
  ),
  Situation(
    id: 'newcomer',
    label: '初見さん向け',
    description: '自己紹介・アイスブレイク',
    icon: Icons.emoji_people_rounded,
  ),
  Situation(
    id: 'regular',
    label: '常連さん向け',
    description: '固定リスナー向けの小ネタ',
    icon: Icons.favorite_rounded,
  ),
  Situation(
    id: 'game_bridge',
    label: 'ゲーム実況つなぎ',
    description: 'プレイの合間の一言ネタ',
    icon: Icons.videogame_asset_rounded,
  ),
  Situation(
    id: 'collab',
    label: 'コラボ配信',
    description: '他の配信者とのアイスブレイク',
    icon: Icons.groups_rounded,
  ),
  Situation(
    id: 'endurance',
    label: '耐久・長時間配信',
    description: 'ストックが尽きないロングテールネタ',
    icon: Icons.hourglass_bottom_rounded,
  ),
  Situation(
    id: 'audience_participation',
    label: 'リスナー参加型',
    description: '投票・質問形式のお題',
    icon: Icons.how_to_vote_rounded,
  ),
];

Situation situationById(String id) =>
    kSituations.firstWhere((s) => s.id == id);
