// App Store の画像の中身。scripts/store_compose/compose.mjs が読む（node scripts/store_compose/compose.mjs apps/neta_gacha）。
// 見出し: [語] = マーカー、{語} = 1.3倍、改行は配列で。バッジの *数字* = 強調色で大きく。
// 数字の出典: お題 980 個・シチュエーション 7 つは assets/prompts/*.json の件数（2026-10-24）。「無料」は書かない（2.3.7）。
// 配色はアイコン（icon/source/icon.json）と同じ: 朱色・白・紫。
export const theme = { bg: '#FF6B4A', fg: '#FFFFFF', sub: '#2A1F6B', marker: '#3D2B8F', markerFg: '#FFFFFF', badgeBg: '#3D2B8F', badgeFg: '#FFFFFF', badgeNum: '#FFD166', dark: false };

const both = (raw) => ({ iphone: { raw }, ipad: { raw } });
export const slots = [
  { id: '01_home', badge: 'シチュエーション *7*つ', head: ['配信の場面ごとに', '[お題]が出る'], sub: '初見さん・コラボ・耐久配信にも', ...both('01_home.png') },
  { id: '02_roulette', badge: 'お題 *980*個', head: ['ガチャを', '[回すだけ]'], sub: '迷わずすぐ使える', ...both('02_roulette.png') },
  { id: '03_result', badge: 'そのまま読み上げOK', head: ['カードで', '[ネタ]が届く'], sub: '雑談の流れを止めない', ...both('03_result.png') },
  { id: '04_favorites', badge: 'お気に入り', head: ['気に入ったネタは', '[保存]できる'], sub: '配信の定番ネタ帳に', ...both('04_favorites.png') },
  { id: '05_custom', badge: '自分のお題も追加', head: ['オリジナルの', '[ネタ帳]に育てる'], sub: 'カスタムお題を足せる', ...both('05_custom.png') },
];
