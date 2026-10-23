// App Store の画像の中身（文言・素材・拡大パネル）。compose.mjs が読む。
// 見出しの書き方: [語] = マーカー、{語} = 1.3倍、改行は配列で。バッジの *数字* = 金色で大きく。
// raw は raw/iphone|ipad/ の画面（integration_test/store_shots_test.dart で撮ったもの）。zoom は同じ画面の切り抜き（元画像の px）。
//   zoom.w = パネルの幅（キャンバスの px）。倍率はそこから決まる。x/y = パネルの左上（キャンバスの px）、x は 'right' 'left' 'center' も可。
// 数字は教材から数えたもの（2026-10-23。過去問 710問 = 2023年5月〜2026年9月の11回、○× 2,881問、図解 480枚）。教材が増えたら直す。

export const slots = [
  {
    id: '01_hero',
    bg: 'gold',
    badge: '*2027*年1月試験対応',
    head: ['[AIの先生]と話して', 'FP1級がわかる'],
    sub: 'つまずいた所で何度でも聞ける',
    iphone: { raw: 'chat_question.png', zoom: { x: 'center', y: 'auto', w: 1180, crop: [40, 1105, 1240, 790] } },
    ipad: { raw: 'chat_question.png', zoom: { x: 'auto', y: 'auto', crop: [350, 1490, 1350, 500] } },
  },
  {
    id: '02_figure',
    bg: 'gold',
    badge: '図解 *480*枚',
    head: ['計算の手順も', '[図で]スッと入る'],
    sub: '会話の中に図解が出てくる',
    iphone: { raw: 'chat_figure_view.png', zoom: { x: 'center', y: 'auto', w: 1150, crop: [50, 1110, 1220, 1090] } },
    ipad: { raw: 'chat_figure_view.png', zoom: { x: 'auto', y: 'auto', zmax: 1.4, crop: [330, 440, 1360, 1100] } },
  },
  {
    id: '03_kakomon',
    bg: 'gold',
    badge: '過去問 *710*問',
    head: ['本試験の形式で', '[11回分]を解く'],
    sub: '2023年5月〜2026年9月の学科試験から',
    iphone: { raw: 'kiso_result.png', zoom: { x: 'center', y: 'auto', w: 1180, crop: [40, 1610, 1240, 620] } },
    ipad: { raw: 'kiso_result.png', zoom: { x: 'auto', y: 'auto', crop: [340, 1820, 1390, 400] } },
  },
  {
    id: '04_ask',
    bg: 'gold',
    head: ['まちがえた所は', '[AIに]聞ける'],
    sub: '選んだ答えに合わせて解説',
    iphone: { raw: 'kiso_ask.png', zoom: { x: 'center', y: 'auto', w: 1180, crop: [40, 1600, 1250, 800] } },
  },
  {
    id: '05_calc',
    bg: 'gold',
    head: ['応用編の計算も', '[電卓つき]で練習'],
    sub: '計算過程の途中の値まで答え合わせ',
    iphone: { raw: 'ouyou_calc.png', zoom: { x: 'center', y: 'auto', w: 1180, crop: [10, 1590, 1300, 340] } },
    ipad: { raw: 'ouyou_calc.png', zoom: { x: 'auto', y: 'auto', crop: [560, 1900, 940, 260] } },
  },
  {
    id: '06_forecast',
    bg: 'navy',
    pro: true,
    head: ['いまの実力を', '200点満点で[予測]'],
    sub: '基礎編・応用編、分野ごとにあと何点か',
    note: '※予測は目安です。応用編の配点は推定',
    iphone: { raw: 'analysis_top.png', zoom: { x: 'center', y: 'auto', w: 1180, crop: [40, 400, 1250, 720] } },
    ipad: { raw: 'analysis_top.png', zoom: { x: 'auto', y: 'auto', crop: [350, 175, 1200, 540] } },
  },
  {
    id: '07_plan',
    bg: 'navy',
    pro: true,
    head: ['今週やることは', '[AIが]決めてくれる'],
    sub: '解けば自動でチェックがつく',
    iphone: { raw: 'analysis_1.png', zoom: { x: 'center', y: 'auto', w: 1180, crop: [90, 1270, 1140, 580] } },
  },
  {
    id: '08_mock',
    bg: 'navy',
    pro: true,
    head: ['本試験と同じ', '[150分]の模擬試験'],
    sub: '基礎編50問・応用編5設例',
    iphone: { raw: 'mock_kiso.png', zoom: { x: 'center', y: 'auto', w: 1180, crop: [40, 1160, 1250, 540] } },
    ipad: { raw: 'mock_kiso.png', zoom: { x: 'auto', y: 'auto', crop: [380, 790, 1240, 300] } },
  },
];
