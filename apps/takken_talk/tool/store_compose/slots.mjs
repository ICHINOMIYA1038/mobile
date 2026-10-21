// App Store の画像の中身（文言・素材・拡大パネル）。compose.mjs が読む。
// 見出しの書き方: [語] = マーカー、{語} = 1.3倍、改行は配列で。バッジの *数字* = 黄色で大きく。
// raw は raw/iphone|ipad/ の実機の画面（integration_test で撮ったもの）。zoom は同じ画面の切り抜き（元画像の px）。
//   zoom.w = パネルの幅（キャンバスの px）。倍率はそこから決まる。x/y = パネルの左上（キャンバスの px）、x は 'right' 'left' 'center' も可。

export const slots = [
  {
    id: '01_hero',
    bg: 'yellow',
    badge: '*2027*年度試験対応',
    head: ['[AIの先生]と話して', '宅建がわかる'],
    sub: 'つまずいた所で何度でも聞ける',
    iphone: { raw: '01_hero.png', zoom: { x: 'right', y: 'auto', w: 1150, crop: [52, 1915, 1218, 470] } },
    ipad: { raw: '01_hero.png', zoom: { x: 'auto', y: 'auto', crop: [330, 700, 1400, 360] } },
  },
  {
    id: '02_figure',
    bg: 'yellow',
    badge: '図解 *411*枚',
    head: ['むずかしい論点も', '[図で]スッと入る'],
    sub: '会話の中に図解が出てくる',
    iphone: { raw: '02_figure.png', zoom: { x: 'center', y: 'auto', w: 1120, crop: [62, 1655, 690, 410] } },
    ipad: { raw: '02_figure.png', zoom: { x: 'auto', y: 'auto', crop: [1020, 540, 700, 290] } },
  },
  {
    id: '03_kakomon',
    bg: 'yellow',
    badge: '○×で *1,763*問',
    head: ['過去問{13回分}を', '[AIが]解説'],
    sub: '平成27年〜令和7年の本試験から',
    iphone: { raw: '03_kakomon.png', zoom: { x: 'left', y: 'auto', w: 1210, crop: [36, 1035, 1250, 380] } },
    ipad: { raw: '03_kakomon.png', zoom: { x: 'auto', y: 'auto', crop: [400, 880, 1260, 300] } },
  },
  {
    id: '04_forecast',
    bg: 'green',
    pro: true,
    isNew: true,
    head: ['いまの実力を', '50点満点で[予測]'],
    sub: '科目ごとに、あと何点かわかる',
    note: '※予測は目安です',
    iphone: { raw: '04_forecast.png', zoom: { x: 'center', y: 1110, w: 1180, crop: [72, 415, 810, 315] } },
    ipad: { raw: '04_forecast.png', zoom: { x: 'auto', y: 'auto', crop: [370, 195, 560, 215] } },
  },
  {
    id: '05_plan',
    bg: 'green',
    pro: true,
    head: ['今日やることは', '[AIが]決めてくれる'],
    sub: '解けば自動でチェックがつく',
    iphone: { raw: '05_plan.png', zoom: { x: 'center', y: 'auto', w: 1200, crop: [96, 600, 1130, 660] } },
  },
  {
    id: '06_mock',
    bg: 'green',
    pro: true,
    head: ['本番と同じ比率の', '[模擬試験]50問'],
    sub: '30分で解いてAIが講評',
    iphone: { raw: '06_mock.png', zoom: { x: 'center', y: 'auto', w: 1220, crop: [52, 1585, 1218, 430] } },
    ipad: { raw: '06_mock.png', zoom: { x: 'auto', y: 'auto', crop: [360, 985, 1350, 175] } },
  },
  {
    id: '07_weak',
    bg: 'yellow',
    pro: true,
    head: ['よく出るのに苦手', 'を[先に]教える'],
    sub: 'まちがえた問題もすぐ復習',
    iphone: { raw: '07_weak.png', zoom: { x: 'center', y: 'auto', w: 1200, crop: [52, 615, 1218, 555] } },
  },
  {
    id: '08_curriculum',
    bg: 'yellow',
    head: ['配点の大きい順に', '[迷わず]進める'],
    sub: '本試験50問の内訳つき',
    iphone: { raw: '08_curriculum.png' },
  },
];
