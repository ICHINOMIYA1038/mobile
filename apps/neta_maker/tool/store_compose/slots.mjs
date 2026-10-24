// App Store の画像の中身。scripts/store_compose/compose.mjs が読む（node scripts/store_compose/compose.mjs apps/neta_maker）。
// 見出し: [語] = マーカー、{語} = 1.3倍、改行は配列で。バッジの *数字* = 強調色で大きく。
// 「無料」は書かない（2.3.7）。「脳内メーカー」は他社のアプリ名なので使わない。
// 配色はアイコン（icon/source/icon.json）と同じ: えんじ・金・ベージュ。
export const theme = { bg: '#5A1A26', fg: '#F2D27A', sub: '#E9DCC0', marker: '#E9DCC0', markerFg: '#5A1A26', badgeBg: '#E9DCC0', badgeFg: '#5A1A26', badgeNum: '#8E2A2A', dark: true };

const both = (raw) => ({ iphone: { raw }, ipad: { raw } });
export const slots = [
  { id: '01_home', badge: '診断 *3*種', head: ['名前を', '[入れるだけ]'], sub: '二つ名・前世・脳内を診断', ...both('01_home.png') },
  { id: '02_input', badge: '*3*秒でスタート', head: ['友だちの名前でも', '[すぐ診断]'], sub: '同じ名前ならいつも同じ結果', ...both('02_input.png') },
  { id: '03_result_futatsuna', badge: '二つ名', head: ['あなただけの', '[二つ名]を判定'], sub: '中二病な称号が決まる', ...both('03_result_futatsuna.png') },
  { id: '04_result_zensei', badge: '前世', head: ['あなたの', '[前世]を視る'], sub: '時代・役職・エピソードつき', ...both('04_result_zensei.png') },
  { id: '05_result_nounai', badge: '脳内', head: ['頭の中を', '[のぞき見る]'], sub: '理性と本能のキーワードで診断', ...both('05_result_nounai.png') },
];
