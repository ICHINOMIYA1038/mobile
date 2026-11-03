// App Store の画像を組み立てる（実機の画面 + 見出し + CSS で描いた端末の枠 + 同じ画面の拡大パネル）。
// apps/takken_talk/tool/store_compose/compose.mjs を TOMOSHIBI の配色にしたもの。
//   node tool/store_compose/compose.mjs [--only 01_hero,04_forecast] [--device iphone|ipad] [--out <dir>]
// 文言と切り抜きは slots.mjs、素材は raw/iphone・raw/ipad（tool/screenshots.sh で撮った screenshots/・screenshots_ipad/ をコピーしたもの）。
// 出力の既定は ios/fastlane/screenshots/ja/（iPhone 1320×2868 → 01_hero.png、iPad 2048×2732 → 01_hero_ipad.png）。
// Chrome（headless）で HTML を撮り、ImageMagick で正確な大きさ・アルファなしにする。
import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { slots } from './slots.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const app = resolve(here, '../..');
const args = process.argv.slice(2);
const opt = (k) => {
  const i = args.indexOf(k);
  return i >= 0 ? args[i + 1] : undefined;
};
const only = opt('--only')?.split(',');
const devices = opt('--device') ? [opt('--device')] : ['iphone', 'ipad'];
const outDir = resolve(opt('--out') ?? join(app, 'ios/fastlane/screenshots/ja'));
const work = join(here, 'build');
mkdirSync(work, { recursive: true });
mkdirSync(outDir, { recursive: true });
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

// TOMOSHIBI のアイコンと同じ配色: 暗転した舞台・クリーム色の文字・テーマの赤・光の金色
const C = { stage: '#0E0B12', cream: '#FFF6E6', red: '#C8482D', gold: '#FFD58A', deep: '#1E1620' };

// 端末ごとの寸法（raw は実機の画面の px）
const DEV = {
  iphone: {
    W: 1320, H: 2868, rawW: 1320, rawH: 2868,
    head: 140, sub: 60, badge: 46, pill: 52, note: 28,
    top: 96, // 文字の始まり
    devW: 1136, devTop: 790, bezel: 20, outerR: 176, screenR: 156, // 端末（幅は 86%）
    devX: null, // null = 中央
  },
  ipad: {
    W: 2048, H: 2732, rawW: 2064, rawH: 2752,
    head: 180, sub: 72, badge: 56, pill: 62, note: 34,
    top: 110,
    devW: 1700, devTop: 850, bezel: 38, outerR: 96, screenR: 60,
    devX: null, // TOMOSHIBI は拡大パネルを使わないので中央
  },
};

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;');
const headHtml = (line) =>
  esc(line)
    .replace(/\[(.+?)\]/g, '<span class="mk">$1</span>')
    .replace(/\{(.+?)\}/g, '<span class="big">$1</span>');
const badgeHtml = (s) => esc(s).replace(/\*(.+?)\*/g, '<b>$1</b>');

function html(slot, dev, d) {
  const green = true; // TOMOSHIBI は全枚を暗い背景にする（影・バッジの濃さは暗い背景用の値を使う）
  const bg = C.stage;
  const fg = C.cream;
  const subFg = C.gold;
  const markerBg = C.red;
  const raw = join(here, 'raw', dev, d.raw);
  if (!existsSync(raw)) throw new Error(`no raw: ${raw}`);
  const s = DEV[dev];
  const screenW = s.devW - s.bezel * 2;
  const k = screenW / s.rawW; // 画面の縮尺
  const screenH = Math.round(s.rawH * k);
  const devH = screenH + s.bezel * 2;
  const devX = s.devX ?? Math.round((s.W - s.devW) / 2);
  // 見出しのブロック: 端末の上の領域の中で縦に中央
  let zoom = '';
  if (d.zoom) {
    const [cx, cy, cw, ch] = d.zoom.crop;
    const pad = dev === 'ipad' ? 22 : 18;
    // x: 'auto'（iPad）= 元の位置の左端から右へ、キャンバスの右端まで（倍率は端末の画面の zmax 倍まで）
    let pw = d.zoom.w;
    let autoLeft = 0;
    if (d.zoom.x === 'auto') {
      autoLeft = Math.round(devX + s.bezel + cx * k - 40);
      const room = s.W - 56 - autoLeft;
      pw = Math.round(Math.min(room, cw * k * (d.zoom.zmax ?? 2) + pad * 2));
      autoLeft = s.W - 56 - pw;
    }
    const iw = pw - pad * 2;
    const z = iw / cw;
    const ih = Math.round(ch * z);
    const px = d.zoom.x === 'auto' ? autoLeft : d.zoom.x === 'right' ? s.W - pw - (dev === 'ipad' ? 64 : 34) : d.zoom.x === 'left' ? (dev === 'ipad' ? 64 : 34) : d.zoom.x === 'center' ? Math.round((s.W - pw) / 2) : d.zoom.x;
    // y: 'auto' = 端末の中の元の位置に重ねる（下の元の UI が二重に見えないように）
    const ph = ih + pad * 2;
    const srcMid = s.devTop + s.bezel + (cy + ch / 2) * k;
    const py = d.zoom.y === 'auto' ? Math.round(Math.min(Math.max(srcMid - ph / 2, s.devTop + 40), s.H - ph - 36)) : d.zoom.y;
    zoom = `<div class="zoom" style="left:${px}px;top:${py}px;width:${pw}px;padding:${pad}px">
      <div class="crop" style="width:${iw}px;height:${ih}px;background-image:url('file://${raw}');background-size:${s.rawW * z}px ${s.rawH * z}px;background-position:${-cx * z}px ${-cy * z}px"></div>
    </div>`;
    // 倍率（端末の画面に対して）を記録
    console.log(`  ${slot.id} ${dev}: zoom ×${(z / k).toFixed(2)} (vs device)`);
  }
  const pro = slot.pro
    ? `<div class="corner">${slot.isNew ? '<span class="new">NEW</span>' : ''}<span class="pro">Pro</span></div>`
    : '';
  return `<!doctype html><html><head><meta charset="utf-8"><style>
@font-face { font-family: H8; src: local('HiraginoSans-W8'); }
@font-face { font-family: H6; src: local('HiraginoSans-W6'); }
@font-face { font-family: H7; src: local('HiraginoSans-W7'); }
* { margin: 0; padding: 0; box-sizing: border-box; }
html, body { width: ${s.W}px; height: ${s.H}px; overflow: hidden; background: radial-gradient(ellipse 70% 45% at 50% 62%, rgba(255,213,138,.22), rgba(240,138,60,.06) 60%, transparent 75%), ${bg}; }
body { position: relative; font-family: H8, 'Hiragino Sans', sans-serif; -webkit-font-smoothing: antialiased; }
.textblock { position: absolute; left: 0; right: 0; top: 0; height: ${s.devTop - 24}px; display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; padding-top: ${slot.pro ? s.pill * 0.9 : 0}px; }
.badge { display: inline-flex; align-items: baseline; gap: .1em; background: ${C.red}; color: ${C.cream}; font-family: H8; font-size: ${s.badge}px; line-height: 1; padding: ${s.badge * 0.42}px ${s.badge * 0.75}px ${s.badge * 0.36}px; border-radius: ${s.badge * 0.5}px; margin-bottom: ${s.badge * 0.75}px; letter-spacing: .02em; }
.badge b { color: ${C.gold}; font-size: 1.32em; font-weight: normal; letter-spacing: 0; line-height: .8; }
h1 { font-family: H8; font-weight: normal; font-size: ${s.head}px; line-height: 1.15; letter-spacing: -0.02em; color: ${fg}; white-space: nowrap; }
h1 .mk { position: relative; z-index: 0; color: ${C.cream}; }
h1 .mk::before { content: ''; position: absolute; z-index: -1; left: -0.1em; right: -0.1em; top: ${green ? -0.02 : 0.12}em; bottom: ${green ? -0.07 : -0.02}em; background: ${markerBg}; border-radius: 0.14em 0.22em 0.18em 0.12em; transform: rotate(-2deg) skewX(-6deg); }
h1 .big { font-size: 1.3em; line-height: 1; }
.sub { font-family: H6; font-size: ${s.sub}px; line-height: 1.3; color: ${subFg}; margin-top: ${s.sub * 0.5}px; white-space: nowrap; }
.corner { position: absolute; top: ${dev === 'ipad' ? 64 : 56}px; right: ${dev === 'ipad' ? 64 : 52}px; display: flex; gap: ${s.pill * 0.3}px; align-items: center; }
.pro { background: ${C.gold}; color: ${C.stage}; font-family: H8; font-size: ${s.pill}px; line-height: 1; padding: ${s.pill * 0.3}px ${s.pill * 0.6}px ${s.pill * 0.26}px; border-radius: 999px; letter-spacing: .01em; }
.new { color: #fff; border: ${dev === 'ipad' ? 4 : 3}px solid rgba(255,255,255,.9); font-family: H8; font-size: ${s.pill * 0.62}px; line-height: 1; padding: ${s.pill * 0.24}px ${s.pill * 0.4}px ${s.pill * 0.2}px; border-radius: 999px; letter-spacing: .06em; }
.device { position: absolute; left: ${devX}px; top: ${s.devTop}px; width: ${s.devW}px; height: ${devH}px; border-radius: ${s.outerR}px; background: #0E0E10; padding: ${s.bezel}px;
  box-shadow: 0 0 0 ${dev === 'ipad' ? 5 : 4}px #4A4A4F, 0 0 0 ${dev === 'ipad' ? 7 : 6}px #232326, 0 ${dev === 'ipad' ? 50 : 40}px ${dev === 'ipad' ? 110 : 90}px rgba(0,0,0,${green ? 0.45 : 0.28}); }
.device img { display: block; width: ${screenW}px; height: ${screenH}px; border-radius: ${s.screenR}px; }
.btn { position: absolute; background: #3A3A3E; border-radius: 3px; }
.zoom { position: absolute; background: #fff; border-radius: 32px; box-shadow: 0 30px 70px rgba(0,0,0,${green ? 0.45 : 0.22}), 0 6px 18px rgba(0,0,0,.12); }
.crop { border-radius: 16px; background-repeat: no-repeat; }
.note { position: absolute; left: 0; right: 0; bottom: ${dev === 'ipad' ? 44 : 40}px; text-align: center; font-family: H6; font-size: ${s.note}px; color: #fff; }
.notein { display: inline-block; }
</style></head><body>
<div class="textblock">
  ${slot.badge ? `<div class="badge">${badgeHtml(slot.badge)}</div>` : ''}
  <h1>${slot.head.map(headHtml).join('<br>')}</h1>
  <div class="sub">${esc(slot.sub)}</div>
</div>
${pro}
<div class="device">
  ${dev === 'iphone' ? `<div class="btn" style="left:-10px;top:${s.devW * 0.36}px;width:6px;height:${s.devW * 0.09}px"></div>
  <div class="btn" style="left:-10px;top:${s.devW * 0.5}px;width:6px;height:${s.devW * 0.14}px"></div>
  <div class="btn" style="left:-10px;top:${s.devW * 0.68}px;width:6px;height:${s.devW * 0.14}px"></div>
  <div class="btn" style="right:-10px;top:${s.devW * 0.56}px;width:6px;height:${s.devW * 0.2}px"></div>` : `<div class="btn" style="right:${s.devW * 0.1}px;top:-11px;width:${s.devW * 0.08}px;height:7px"></div>`}
  <img src="file://${raw}">
</div>
${zoom}
${slot.note ? `<div class="note"><span class="notein" style="background:rgba(200,72,45,.92);padding:${s.note * 0.4}px ${s.note * 0.9}px;border-radius:999px">${esc(slot.note)}</span></div>` : ''}
</body></html>`;
}

for (const dev of devices) {
  for (const slot of slots) {
    if (only && !only.includes(slot.id)) continue;
    const d = slot[dev];
    if (!d) continue;
    const s = DEV[dev];
    const name = dev === 'ipad' ? `${slot.id}_ipad` : slot.id;
    const htmlPath = join(work, `${name}.html`);
    writeFileSync(htmlPath, html(slot, dev, d));
    const tmp = join(work, `${name}.raw.png`);
    execFileSync(CHROME, ['--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1', '--allow-file-access-from-files', `--window-size=${s.W},${s.H}`, `--screenshot=${tmp}`, `file://${htmlPath}`], { stdio: 'ignore' });
    const out = join(outDir, `${name}.png`);
    execFileSync('magick', [tmp, '-crop', `${s.W}x${s.H}+0+0`, '+repage', '-background', '#000', '-alpha', 'remove', '-alpha', 'off', out]);
    console.log(`${out}`);
  }
}
