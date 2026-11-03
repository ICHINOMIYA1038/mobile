// App Store の画像の中身。scripts/store_compose/compose.mjs が読む（node scripts/store_compose/compose.mjs apps/neko_chemistry）。
// 見出し: [語] = マーカー、{語} = 1.3倍、改行は配列で。バッジの *数字* = 強調色で大きく。
// 数字の出典: 510 問は assets/questions.json、17 単元は lib/data/units.dart の kAllUnits、きせかえ 4 種は
// lib/data/progress_repository.dart の accessory*（2026-10-24）。「無料」は書かない（2.3.7）。
// 配色はアイコン（icon/source/icon.json）と同じ: クリーム・焦げ茶・オレンジ。
export const theme = { bg: '#FFF4E4', fg: '#7A3E14', sub: '#9A5A2C', marker: '#F08A3C', markerFg: '#FFFFFF', badgeBg: '#7A3E14', badgeFg: '#FFF4E4', badgeNum: '#FFC27A', dark: false };

const both = (raw) => ({ iphone: { raw }, ipad: { raw } });
export const slots = [
  { id: '01_home', badge: '高校化学 *510*問', head: ['猫といっしょに', '[化学]を解く'], sub: '高校化学の基礎をくり返し確認', ...both('01_home.png') },
  { id: '02_quiz', badge: '*17*単元から出題', head: ['すきま時間に', '[4択]で1問'], sub: 'ランダムでも、単元を選んでも', ...both('02_quiz.png') },
  { id: '03_answer', badge: '全問に解説つき', head: ['答えたら', 'すぐ[解説]'], sub: 'なぜそうなるかまで確かめる', ...both('03_answer.png') },
  { id: '04_progress', badge: '単元別の正答率', head: ['苦手な単元が', '[ひと目で]わかる'], sub: '間違えた問題だけ解き直せる', ...both('04_progress.png') },
  { id: '05_accessory', badge: 'きせかえ *4*種', head: ['続けるほど', '猫が[おしゃれ]に'], sub: '連続学習と正解数でごほうび', ...both('05_accessory.png') },
];
