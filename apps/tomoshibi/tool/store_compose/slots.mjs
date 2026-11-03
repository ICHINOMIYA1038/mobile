// App Store の画像の中身（文言・素材）。compose.mjs が読む。
// 見出しの書き方: [語] = 赤いマーカー、{語} = 1.3倍、改行は配列で。バッジの *数字* = 金色で大きく。
// raw は raw/iphone|ipad/ の画面（tool/screenshots.sh で撮ったもの。場面は tool/build_scene_urls.py の SHOTS）。
// 数字の出典: 器具 22 種・6 メーカーは Web 版 tomoshibi の src/lighting/fixtureTypes.ts（FIXTURE_PROFILES、2026-10-24 時点）。
// 「無料」は書かない（ガイドライン 2.3.7 で却下された前例がある）。

export const slots = [
  {
    id: '01_audience',
    badge: '器具 *22*種を収録',
    head: ['舞台照明を', '[3Dで]確かめる'],
    sub: '客席からの見え方を、仕込む前に',
    iphone: { raw: '01_audience.png' },
    ipad: { raw: '01_audience.png' },
  },
  {
    id: '02_aerial',
    badge: '視点は *4*つ',
    head: ['吊り位置も', '[俯瞰で]ひと目で'],
    sub: '客席・俯瞰・袖・自由をワンタップで',
    iphone: { raw: '02_aerial.png' },
    ipad: { raw: '02_aerial.png' },
  },
  {
    id: '03_sidewing',
    badge: '物理ベースの描画',
    head: ['ヘイズの中の', '[ビームと影]まで'],
    sub: '袖からの抜けも同じシーンで',
    iphone: { raw: '03_sidewing.png' },
    ipad: { raw: '03_sidewing.png' },
  },
  {
    id: '04_houselights',
    badge: '客電 *ON*/OFF',
    head: ['作業灯と本番を', '[見比べる]'],
    sub: '本番の暗さで明かりを確かめる',
    iphone: { raw: '04_houselights.png' },
    ipad: { raw: '04_houselights.png' },
  },
  {
    id: '05_panel',
    badge: '*6*メーカー＋在来機材',
    head: ['PARから', '[LED]まで'],
    sub: '実機に近いプロファイルの器具を選ぶ',
    iphone: { raw: '05_panel.png' },
    ipad: { raw: '05_panel.png' },
  },
];
