// App Store の画像を組み立てる（実機の画面 + 見出し + CSS で描いた端末の枠 + 同じ画面の拡大パネル）。
//   node tool/store_compose/compose.mjs [--only 1,2]
// 素材は raw/（shoot.sh で撮った iPhone 16 Pro Max の画面、1320×2868）。出力は out/（1320×2868、アルファなし）。
// 1 枚目はアイコン・アプリ名・「観劇記録アプリ」・3 つの特徴を入れて、何のアプリかを伝える（2026-11-12 オーナー判断）。
// 画面の作品名・劇団名・劇場名・写真はすべて架空（integration_test/store_shots_test.dart と photos/）。photos/ は Codex の画像生成で作った架空のチラシ・舞台写真・チケット（印刷の文字は指定どおりか目で確かめた）。価格の表記は入れない（ガイドライン 2.3.7）。
import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const only = (() => {
  const i = process.argv.indexOf('--only');
  return i >= 0 ? process.argv[i + 1].split(',') : null;
})();
const work = join(here, 'build');
const out = join(here, 'out');
mkdirSync(work, { recursive: true });
mkdirSync(out, { recursive: true });
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const W = 1320, H = 2868, RW = 1320, RH = 2868;

// crop は拡大パネルに出す元画面の範囲 [x, y, 幅, 高さ]（raw の px）。photo は端末の右下に重ねる写真（photos/ の架空のチケット）
const slots = [
  { n: '1', name: '01_stamp', raw: 'stamp', head: '観た舞台を、\n半券とハンコで残す。', crop: [30, 720, 1260, 620], seal: '観劇' },
  { n: '2', name: '02_scan', raw: 'scan', head: 'チケットを撮れば、\n日付も劇場も入る。', sub: '座席や金額も読み取ります。読み取りは端末の中だけ', crop: [30, 540, 1260, 400], seal: '読取', photo: 'ticket_amayadori_crop.jpg' },
  { n: '3', name: '03_record', raw: 'rating', head: '星とひとことで、\n記録はすぐ。', sub: 'あとから感想を書き足すこともできます', crop: [30, 450, 1260, 560], seal: '記録' },
  { n: '4', name: '04_list', raw: 'list', head: '観た舞台が、\n半券になってたまる。', sub: '写真やチラシも一緒に残せます', crop: [30, 640, 1260, 640], seal: '半券' },
  { n: '5', name: '05_story', raw: 'story', head: '1 本ずつ、\n思い出をめくる。', sub: '写真を表紙に、観た日と劇場と一緒に振り返れます', crop: [0, 1760, 1100, 540], seal: '思出', dark: true },
  { n: '6', name: '06_book', raw: 'book', head: '集めたスタンプで、\n観劇の歩みが見える。', sub: '本数や劇場めぐりで、印が増えていきます', crop: [60, 880, 1200, 600], seal: '初日' },
  { n: '7', name: '07_map', raw: 'map', head: '全国の劇場を\nめぐって集める。', sub: '行った劇場にスタンプ。地図に足あとが残ります', crop: [230, 640, 1060, 760], seal: '劇場' },
  { n: '8', name: '08_recap', raw: 'recap', head: '1 年の観劇を、\n1 枚にまとめて。', sub: '観た本数やよく通った劇場をシェアできます', crop: [40, 910, 1240, 760], seal: '千秋楽' },
];

function html(s) {
  const raw = join(here, 'raw', `${s.raw}.png`);
  if (!existsSync(raw)) throw new Error(`no raw: ${raw}`);
  const bg = s.dark ? '#151515' : '#F6F6F3';
  const fg = s.dark ? '#F6F6F3' : '#161616';
  const sub = s.dark ? '#C9C9C2' : '#5E5E59';
  const shadow = 'rgba(0,0,0,.20)';
  const [cx, cy, cw, ch] = s.crop;
  const devW = 980, bez = 16, devX = 60, devTop = s.n === '1' ? 900 : 720;
  const sw = devW - bez * 2, sc = sw / RW, shH = Math.round(RH * sc);
  const pw = 1160, ps = pw / cw, py = Math.min(H - ch * ps - 110, devTop + bez + cy * sc + 120);
  const sealF = s.seal.length > 2 ? 40 : 52;
  const hero = s.n === '1'
    ? `<div class="brand"><img src="file://${join(here, 'icon.png')}"><div><b>ゲキポン</b><span>観劇記録アプリ</span></div></div>
       <div class="feat"><span>チケットを撮って記録</span><span>全国の劇場スタンプ</span><span>1 年のふりかえり</span></div>`
    : `<div class="sub">${s.sub}</div>`;
  return `<!doctype html><html><head><meta charset="utf-8"><style>
  html,body{margin:0;width:${W}px;height:${H}px;overflow:hidden;background:${bg};font-family:'Hiragino Sans','Hiragino Kaku Gothic ProN',sans-serif}
  .head{position:absolute;left:90px;right:90px;top:${s.n === '1' ? 310 : 150}px;color:${fg};font-weight:800;font-size:104px;line-height:1.26;white-space:pre-line;letter-spacing:.01em}
  .sub{position:absolute;left:94px;right:90px;top:452px;color:${sub};font-weight:600;font-size:46px;line-height:1.5}
  .brand{position:absolute;left:90px;top:110px;display:flex;align-items:center;gap:30px;color:${fg}}
  .brand img{width:150px;height:150px;border-radius:34px;box-shadow:0 10px 30px ${shadow}}
  .brand b{display:block;font-size:64px;font-weight:800;line-height:1.1}
  .brand span{display:block;font-size:44px;font-weight:700;color:${sub};margin-top:6px}
  .feat{position:absolute;left:90px;right:60px;top:610px;display:flex;flex-wrap:wrap;gap:16px}
  .feat span{font-size:38px;font-weight:700;color:${fg};border:4px solid ${fg};border-radius:999px;padding:10px 28px}
  .dev{position:absolute;left:${devX}px;top:${devTop}px;width:${devW}px;height:${shH + bez * 2}px;padding:${bez}px;background:#0E0E0E;border-radius:140px;box-sizing:border-box;box-shadow:0 30px 70px ${shadow}}
  .dev img{display:block;width:${sw}px;height:${shH}px;border-radius:124px}
  .zoom{position:absolute;left:${(W - pw) / 2 + 50}px;top:${py}px;width:${pw}px;height:${ch * ps}px;overflow:hidden;border-radius:44px;background:#fff;box-shadow:0 40px 90px ${shadow},0 0 0 6px #161616}
  .zoom img{display:block;width:${RW * ps}px;margin-left:${-cx * ps}px;margin-top:${-cy * ps}px}
  .photo{position:absolute;right:50px;bottom:520px;width:780px;transform:rotate(6deg);border-radius:18px;border:12px solid #fff;box-shadow:0 40px 90px rgba(0,0,0,.30);z-index:2}
  .seal{position:absolute;right:56px;top:${s.n === '1' ? 820 : 640}px;z-index:3;background:${bg};width:190px;height:190px;border-radius:50%;border:10px solid #D0342C;box-sizing:border-box;transform:rotate(-12deg);display:grid;place-items:center;color:#D0342C;font-family:'Hiragino Mincho ProN',serif;font-weight:800;font-size:${sealF}px}
  .seal::after{content:'';position:absolute;inset:10px;border-radius:50%;border:3px solid #D0342C}
  </style></head><body>
  ${s.n === '1' ? hero : ''}<div class="head">${s.head}</div>${s.n === '1' ? '' : hero}
  <div class="dev"><img src="file://${raw}"></div>
  <div class="zoom"><img src="file://${raw}"></div>
  ${s.photo ? `<img class="photo" src="file://${join(here, 'photos', s.photo)}">` : ''}
  <div class="seal">${s.seal}</div>
  </body></html>`;
}

for (const s of slots) {
  if (only && !only.includes(s.n)) continue;
  const page = join(work, `${s.name}.html`);
  const shot = join(work, `${s.name}.png`);
  writeFileSync(page, html(s));
  for (let t = 0; t < 3; t++) {
    try {
      execFileSync(CHROME, ['--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1', `--window-size=${W},${H}`, `--screenshot=${shot}`, `file://${page}`], { stdio: 'ignore', timeout: 60000 });
      break;
    } catch (e) {
      if (t === 2) throw e;
    }
  }
  execFileSync('magick', [shot, '-resize', `${W}x${H}!`, '-background', '#F6F6F3', '-alpha', 'remove', '-alpha', 'off', join(out, `${s.name}.png`)]);
  console.log('wrote', s.name);
}
