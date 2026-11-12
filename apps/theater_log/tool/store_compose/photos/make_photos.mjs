// ストア画像用の架空の写真（舞台写真ふう・チラシ）を作る。作品名・劇団名・劇場名はすべて架空。
//   node tool/store_compose/photos/make_photos.mjs
import { execFileSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
const here = dirname(fileURLToPath(import.meta.url));
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const W = 1170, H = 2532;
const grain = `<svg class="grain" width="${W}" height="${H}"><filter id="g"><feTurbulence type="fractalNoise" baseFrequency=".9" numOctaves="2" stitchTiles="stitch"/><feColorMatrix values="0 0 0 0 .5 0 0 0 0 .5 0 0 0 0 .5 0 0 0 .55 0"/></filter><rect width="100%" height="100%" filter="url(#g)"/></svg>`;
const base = `html,body{margin:0;width:${W}px;height:${H}px;overflow:hidden;background:#000}
.grain{position:absolute;inset:0;mix-blend-mode:overlay;opacity:.5}
.vig{position:absolute;inset:0;background:radial-gradient(ellipse at 50% 45%,transparent 45%,rgba(0,0,0,.75) 100%)}
.beam{position:absolute;top:-100px;filter:blur(28px);transform-origin:top center}
.fig{position:absolute;filter:blur(1.5px)}`;
// 舞台写真ふう：照明の色、光の筋、床の明かり、人影と装置のシルエット
const stage = (o) => `<style>${base}</style>
<div style="position:absolute;inset:0;background:linear-gradient(180deg,${o.top} 0%,${o.mid} 62%,${o.floor} 78%,#050505 100%)"></div>
${o.beams.map(([x, rot, w, c]) => `<div class="beam" style="left:${x}px;width:${w}px;height:${H * 0.95}px;transform:rotate(${rot}deg);background:linear-gradient(180deg,${c} 0%,transparent 92%);clip-path:polygon(42% 0,58% 0,100% 100%,0 100%)"></div>`).join('')}
<div style="position:absolute;left:-10%;right:-10%;top:${H * 0.70}px;height:${H * 0.2}px;background:radial-gradient(ellipse at 50% 40%,${o.pool} 0%,transparent 65%);filter:blur(20px)"></div>
<svg class="fig" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${o.svg}</svg>
<div style="position:absolute;inset:0;background:radial-gradient(circle at 50% 30%,rgba(255,255,255,.06),transparent 60%)"></div>
<div class="vig"></div>${grain}`;
const person = (x, y, h, lean = 0, c = '#07070a') => { const s = h / 7; return `<g transform="rotate(${lean} ${x} ${y})" fill="${c}"><ellipse cx="${x}" cy="${y - h + s * 0.75}" rx="${s * 0.55}" ry="${s * 0.68}"/><path d="M${x - s * 1.05} ${y} Q${x - s * 1.3} ${y - h * 0.6} ${x - s * 0.62} ${y - h + s * 1.65} L${x + s * 0.62} ${y - h + s * 1.65} Q${x + s * 1.3} ${y - h * 0.6} ${x + s * 1.05} ${y}Z"/></g>`; };
const chair = (x, y, s = 1, c = '#08080a') => `<g fill="${c}" transform="translate(${x} ${y}) scale(${s})"><rect x="0" y="-300" width="18" height="300"/><rect x="0" y="-150" width="150" height="18"/><rect x="132" y="-150" width="18" height="150"/><rect x="0" y="-300" width="18" height="160"/></g>`;
const table = (x, y, w = 420, c = '#09090b') => `<g fill="${c}"><rect x="${x}" y="${y - 210}" width="${w}" height="22"/><rect x="${x + 20}" y="${y - 190}" width="16" height="190"/><rect x="${x + w - 36}" y="${y - 190}" width="16" height="190"/></g>`;
const windowFrame = (x, y, w, h, c) => `<g fill="none" stroke="${c}" stroke-width="16"><rect x="${x}" y="${y}" width="${w}" height="${h}"/><line x1="${x + w / 2}" y1="${y}" x2="${x + w / 2}" y2="${y + h}"/><line x1="${x}" y1="${y + h / 2}" x2="${x + w}" y2="${y + h / 2}"/></g>`;
const floorY = H * 0.80;
const photos = {
  stage_amber: stage({ top: '#1a0d05', mid: '#5a2f10', floor: '#3a1e0a', pool: 'rgba(255,190,110,.55)', beams: [[260, -12, 520, 'rgba(255,200,120,.55)'], [520, 10, 560, 'rgba(255,170,90,.45)']],
    svg: table(380, floorY, 420) + chair(250, floorY, 1) + chair(800, floorY, 1) + person(470, floorY - 20, 760, -2) + person(720, floorY, 820, 3) }),
  stage_blue: stage({ top: '#02040e', mid: '#0f2350', floor: '#0a1636', pool: 'rgba(120,160,255,.45)', beams: [[360, 4, 460, 'rgba(160,190,255,.55)']],
    svg: windowFrame(330, 520, 520, 700, 'rgba(10,14,30,.95)') + person(590, floorY, 880, 0) + chair(700, floorY, 0.9) }),
  stage_red: stage({ top: '#0a0202', mid: '#4d0b0b', floor: '#2c0606', pool: 'rgba(255,90,70,.5)', beams: [[300, 0, 580, 'rgba(255,120,100,.5)']],
    svg: chair(500, floorY, 1.15) + person(420, floorY, 860, -4) }),
  stage_green: stage({ top: '#020805', mid: '#0e3a26', floor: '#0a2a1b', pool: 'rgba(140,255,190,.35)', beams: [[100, -18, 420, 'rgba(170,255,210,.35)'], [420, -4, 420, 'rgba(170,255,210,.3)'], [720, 12, 420, 'rgba(170,255,210,.3)']],
    svg: person(320, floorY, 800, -3) + person(560, floorY + 10, 860, 0) + person(820, floorY, 780, 4) }),
  stage_dawn: stage({ top: '#1b1030', mid: '#b2563a', floor: '#3a1a14', pool: 'rgba(255,170,120,.5)', beams: [[600, 16, 520, 'rgba(255,190,150,.5)']],
    svg: `<rect x="0" y="${H * 0.38}" width="${W}" height="10" fill="rgba(0,0,0,.6)"/>` + person(330, floorY, 820, 0) + person(870, floorY, 700, 0) + `<rect x="620" y="${floorY - 600}" width="14" height="600" fill="#08070a"/><rect x="690" y="${floorY - 600}" width="14" height="600" fill="#08070a"/>${[0, 1, 2, 3, 4, 5].map(i => `<rect x="620" y="${floorY - 80 - i * 100}" width="84" height="12" fill="#08070a"/>`).join('')}` }),
};
// チラシ（架空の公演）。縦長の中央に主な文字を集め、切り抜かれても題名が残るようにする
const flyer = (o) => `<style>${base}
.f{position:absolute;inset:0;background:${o.bg};font-family:'Hiragino Sans','Hiragino Kaku Gothic ProN';color:${o.fg}}
.t{position:absolute;left:0;right:0;top:${o.ty ?? 820}px;text-align:center;font-family:${o.font ?? "'Hiragino Mincho ProN'"};font-weight:800;font-size:${o.fs ?? 190}px;line-height:1.15;letter-spacing:.06em;white-space:pre-line}
.g{position:absolute;left:0;right:0;top:${o.gy ?? 1400}px;text-align:center;font-size:52px;font-weight:700;letter-spacing:.2em}
.d{position:absolute;left:0;right:0;top:${(o.gy ?? 1400) + 110}px;text-align:center;font-size:40px;font-weight:600;letter-spacing:.08em;opacity:.85;white-space:pre-line;line-height:1.6}
</style><div class="f">${o.art ?? ''}<div class="t">${o.title}</div><div class="g">${o.group}</div><div class="d">${o.date}</div></div><div style="position:absolute;inset:0;box-shadow:inset 0 0 120px rgba(0,0,0,.25)"></div>${grain}`;
Object.assign(photos, {
  flyer_minato: flyer({ bg: 'linear-gradient(180deg,#0f3b57,#06192a)', fg: '#F4EDE0', title: '港町\nクロニクル', group: '劇団あおぞら座', date: '横浜みなと座\n3.14 fri – 3.23 sun',
    art: `<svg width="${W}" height="${H}" style="position:absolute;inset:0"><circle cx="585" cy="560" r="260" fill="#E8B04A" opacity=".9"/><path d="M0 1260 Q300 1200 585 1260 T1170 1260 V2532 H0Z" fill="#0a2a40"/><path d="M0 1320 Q300 1270 585 1320 T1170 1320" stroke="#F4EDE0" stroke-width="6" fill="none" opacity=".5"/></svg>` }),
  flyer_kujira: flyer({ bg: '#EDE6D6', fg: '#1d1d1d', title: '月曜日の鯨', fs: 150, ty: 1180, group: 'ユニット灯台', gy: 1420, date: '下北沢ほとり座\n5.8 thu – 5.18 sun',
    art: `<svg width="${W}" height="${H}" style="position:absolute;inset:0"><path d="M220 900 C300 650 760 600 930 820 C980 760 1040 740 1060 700 C1060 800 1010 860 950 900 C820 1080 380 1100 220 900Z" fill="#2B4C7E"/><circle cx="380" cy="840" r="14" fill="#EDE6D6"/></svg>` }),
  flyer_kasa: flyer({ bg: '#1a1a1a', fg: '#F3F0EA', title: '赤い傘の\n午後', ty: 1140, group: '劇団ひとつぶ', gy: 1560, date: '中野こもれび劇場\n7.2 wed – 7.13 sun',
    art: `<svg width="${W}" height="${H}" style="position:absolute;inset:0"><path d="M300 820 Q585 460 870 820 Z" fill="#D0342C"/><line x1="585" y1="560" x2="585" y2="1060" stroke="#F3F0EA" stroke-width="12"/><path d="M585 1060 q0 50 -50 50" stroke="#F3F0EA" stroke-width="12" fill="none"/>${Array.from({ length: 40 }, (_, i) => `<line x1="${(i * 97) % 1170}" y1="${(i * 211) % 700 + 100}" x2="${(i * 97) % 1170 - 20}" y2="${(i * 211) % 700 + 170}" stroke="#F3F0EA" stroke-width="4" opacity=".35"/>`).join('')}</svg>` }),
  flyer_hoshi: flyer({ bg: 'radial-gradient(circle at 50% 35%,#2a2f6b,#07081c 70%)', fg: '#F2EBD9', title: '星を数える\n部屋', ty: 1100, group: '東風舎', gy: 1520, date: '名古屋ひだまり座\n9.12 fri – 9.15 mon',
    art: `<svg width="${W}" height="${H}" style="position:absolute;inset:0">${Array.from({ length: 90 }, (_, i) => `<circle cx="${(i * 131) % 1170}" cy="${(i * 277) % 1000 + 80}" r="${(i % 4) + 2}" fill="#F2EBD9" opacity="${0.4 + (i % 5) / 10}"/>`).join('')}<rect x="420" y="620" width="330" height="330" fill="none" stroke="#F2EBD9" stroke-width="10"/></svg>` }),
  flyer_tomoshibi: flyer({ bg: '#C9A15A', fg: '#2a1a0a', title: '灯台守の娘', fs: 160, ty: 1240, group: '劇団つきよみ', gy: 1470, date: '福岡なぎさ劇場\n10.3 fri – 10.5 sun',
    art: `<svg width="${W}" height="${H}" style="position:absolute;inset:0"><path d="M520 1080 L560 520 H610 L650 1080Z" fill="#2a1a0a"/><rect x="545" y="460" width="80" height="70" fill="#F7E7B0"/><path d="M625 495 L1170 380 V610Z" fill="#F7E7B0" opacity=".55"/><rect x="0" y="1080" width="1170" height="30" fill="#2a1a0a"/></svg>` }),
});
for (const [name, body] of Object.entries(photos)) {
  const html = join(here, `${name}.html`), png = join(here, `${name}.png`), jpg = join(here, `${name}.jpg`);
  writeFileSync(html, `<!doctype html><html><head><meta charset="utf-8"></head><body>${body}</body></html>`);
  for (let t = 0; t < 3; t++) { try { execFileSync(CHROME, ['--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1', `--window-size=${W},${H}`, `--screenshot=${png}`, `file://${html}`], { stdio: 'ignore', timeout: 60000 }); break; } catch (e) {} }
  execFileSync('magick', [png, '-quality', '86', jpg]);
  execFileSync('rm', [png, html]);
}
