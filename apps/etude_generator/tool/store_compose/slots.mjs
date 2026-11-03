// App Store の画像の中身。scripts/store_compose/compose.mjs が読む（node scripts/store_compose/compose.mjs apps/etude_generator）。
// 見出し: [語] = マーカー、{語} = 1.3倍、改行は配列で。バッジの *数字* = 強調色で大きく。
// raw は screenshots/・screenshots_ipad/ の画面（tool/screenshots.sh で撮ったもの）。
// 数字の出典: お題 1000 本は lib/data/etude_themes.dart の etudeThemes の件数（2026-10-24）。「無料」は書かない（2.3.7）。
// 配色はアイコン（icon/source/icon.json）と同じ: 幕の赤・クリーム・金。
export const theme = { bg: '#8E2A2A', fg: '#FFF6E6', sub: '#F5D447', marker: '#3A1414', markerFg: '#F5D447', badgeBg: '#3A1414', badgeFg: '#FFF6E6', badgeNum: '#F5D447', dark: true };

const both = (raw) => ({ iphone: { raw }, ipad: { raw } });
export const slots = [
  { id: '01_home', badge: 'お題 *1000*本を収録', head: ['即興のお題が', '[一瞬で]そろう'], sub: '人数とジャンルを選ぶだけ', ...both('01_home.png') },
  { id: '02_settings', badge: '人数・ジャンル・時間', head: ['稽古の条件を', '[選ぶだけ]'], sub: '準備なしですぐ始められる', ...both('02_settings.png') },
  { id: '03_result', badge: '場所・状況・秘密', head: ['お題ごとに', '[作り込み済み]'], sub: '演じる材料が一度に出そろう', ...both('03_result.png') },
  { id: '04_role_draw', badge: '役ごとに目的と秘密', head: ['役を引いて', '[秘密]を知る'], sub: '情報のずれから対話が生まれる', ...both('04_role_draw.png') },
  { id: '05_performance', badge: 'タイマーつき', head: ['そのまま', '[演じられる]'], sub: '残り時間がひと目でわかる', ...both('05_performance.png') },
  { id: '06_reflection', badge: '振り返りの問い *3*つ', head: ['演じたあとの', '[振り返り]まで'], sub: '気づきを言葉にして次の稽古へ', ...both('06_reflection.png') },
];
