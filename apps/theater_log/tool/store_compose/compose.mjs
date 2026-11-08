// App Store の画像を組み立てる（実機の画面 + 見出し + CSS で描いた端末の枠）。
//   node tool/store_compose/compose.mjs [--only 01_stamp,02_record]
// 素材は raw/（shoot.sh で撮った iPhone 16 Pro Max の画面、1320×2868）。出力は out/（1320×2868、アルファなし）。
// Chrome（headless）で HTML を撮り、ImageMagick で正確な大きさ・アルファなしにする（fp1_talk の compose.mjs と同じやり方）。
// 見た目はアプリと同じ：紙の地、墨の見出し（ヒラギノ角ゴ W8）、朱のハンコ 1 つ。価格の表記（「無料」など）は入れない（ガイドライン 2.3.7）。
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

// 見出しは 2 行まで。seal はハンコの中の字
const slots = [
  { name: '01_stamp', raw: 'stamp', head: '観た舞台に、\nハンコをポン。', sub: '記録すると半券ができて、日付印が押されます', seal: '観劇' },
  { name: '02_record', raw: 'record', head: 'チケットを撮れば、\n記録はすぐ。', sub: '題名・日付・劇場・座席を読み取ります', seal: '記録' },
  { name: '03_story', raw: 'story', head: '1 本ずつ、\n思い出をめくる。', sub: '観た舞台が、日付と劇場と一緒に残ります', seal: '半券', dark: true },
  { name: '04_list', raw: 'list', head: '観た舞台が、\n半券になってたまる。', sub: '戯曲図書館の台本にもつながります', seal: '半券' },
  { name: '05_book', raw: 'book', head: '集めたスタンプで、\n観劇の歩みが見える。', sub: '本数や劇場めぐりで、印が増えていきます', seal: '初日' },
  { name: '06_map', raw: 'map', head: '全国の劇場を\nめぐって集める。', sub: '行った劇場にスタンプ。地図に足あとが残ります', seal: '劇場' },
  { name: '07_recap', raw: 'recap', head: '1 年の観劇を、\n1 枚にまとめて。', sub: '観た本数やよく通った劇場をシェアできます', seal: '千秋楽' },
];

const W = 1320, H = 2868;
const devW = 1080, bezel = 18, devTop = 800, outerR = 150, screenR = 132;
const screenW = devW - bezel * 2;
const screenH = Math.round(2868 * (screenW / 1320));

function html(s) {
  const raw = join(here, 'raw', `${s.raw}.png`);
  if (!existsSync(raw)) throw new Error(`no raw: ${raw}`);
  const bg = s.dark ? '#151515' : '#F6F6F3';
  const fg = s.dark ? '#F6F6F3' : '#151515';
  const sub = s.dark ? '#C9C9C2' : '#5E5E59';
  const seal = s.seal.length > 2 ? 40 : 52;
  return `<!doctype html><html><head><meta charset="utf-8"><style>
  html,body{margin:0;width:${W}px;height:${H}px;overflow:hidden;background:${bg};font-family:'Hiragino Sans','Hiragino Kaku Gothic ProN',sans-serif}
  .head{position:absolute;left:96px;right:96px;top:150px;color:${fg};font-weight:800;font-size:112px;line-height:1.28;letter-spacing:.01em;white-space:pre-line}
  .sub{position:absolute;left:100px;right:96px;top:480px;color:${sub};font-weight:600;font-size:44px;line-height:1.5}
  .seal{position:absolute;right:70px;top:700px;z-index:2;width:170px;height:170px;background:${bg};border-radius:50%;border:9px solid #D0342C;box-sizing:border-box;transform:rotate(-12deg);display:grid;place-items:center;color:#D0342C;
    font-family:'Hiragino Mincho ProN',serif;font-weight:800;font-size:${seal}px;opacity:.92}
  .seal::after{content:'';position:absolute;inset:9px;border-radius:50%;border:3px solid #D0342C}
  .dev{position:absolute;left:${(W - devW) / 2}px;top:${devTop}px;width:${devW}px;height:${screenH + bezel * 2}px;background:#0E0E0E;border-radius:${outerR}px;padding:${bezel}px;box-sizing:border-box;
    box-shadow:0 30px 70px rgba(0,0,0,${s.dark ? '.6' : '.18'})}
  .dev img{width:${screenW}px;height:${screenH}px;border-radius:${screenR}px;display:block}
  </style></head><body>
  <div class="head">${s.head.replace(/&/g, '&amp;').replace(/</g, '&lt;')}</div>
  <div class="sub">${s.sub}</div>
  <div class="seal">${s.seal}</div>
  <div class="dev"><img src="file://${raw}"></div>
  </body></html>`;
}

for (const s of slots) {
  if (only && !only.includes(s.name)) continue;
  const page = join(work, `${s.name}.html`);
  const shot = join(work, `${s.name}.png`);
  writeFileSync(page, html(s));
  execFileSync(CHROME, ['--headless=new', '--disable-gpu', '--hide-scrollbars', '--allow-file-access-from-files', `--window-size=${W},${H}`, '--force-device-scale-factor=1', `--screenshot=${shot}`, `file://${page}`], { stdio: 'ignore' });
  const dest = join(out, `${s.name}.png`);
  execFileSync('magick', [shot, '-crop', `${W}x${H}+0+0`, '+repage', '-background', 'white', '-alpha', 'remove', '-alpha', 'off', dest]);
  console.log('wrote', dest);
}
