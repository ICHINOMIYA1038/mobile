// 手続き的コース生成: セグメント(直線/カーブ/狭道/移動床)を連結して坂道コースを作る。
import * as THREE from 'three';
import { createPlatformBody } from './physics.js';
import { cloneModel, applyGrainIfFlat } from './models.js';

/**
 * コーステーマごとの装飾セット。segments自体の形状/難易度/色分けは共通(操作の学習を崩さないため)、
 * 変わるのは足場脇に置く装飾モデルと、その土台となる地面パッチのみ。
 */
// 既存3テーマの地面色は共通(見た目に回帰を出さないため、そのままDEFAULT_GROUND_COLORSとして残す)。
const DEFAULT_GROUND_COLORS = {
  straight: 0x8fe3a0,
  narrow: 0xffb26b,
  curveLeft: 0x8fe3a0,
  curveRight: 0x8fe3a0,
  moving: 0xc792ff,
  boost: 0x38c6ff,
};

// お菓子の国テーマの地面色。straight/curveはパステルマーブルの下地、narrowはキャンディケイン地色、
// movingはグミ、boostはレインボースプリンクルの下地。
const CANDY_GROUND_COLORS = {
  straight: 0xffd6ec,
  narrow: 0xe8384f,
  curveLeft: 0xfff0c2,
  curveRight: 0xc8f5e3,
  moving: 0xfff066,
  boost: 0xffe6f5,
};

const DEFAULT_ATMOSPHERE = {
  sky: { top: '#5fa8f5', mid: '#bfe8ff', bottom: '#eef9ff' },
  fogColor: 0xbfe8ff,
  lightTint: 0xffffff,
  cloudTint: 0xffffff,
};

const CANDY_ATMOSPHERE = {
  sky: { top: '#ff9fd0', mid: '#ffd6ec', bottom: '#e3fff2' },
  fogColor: 0xffd6ec,
  lightTint: 0xfff0f7,
  cloudTint: 0xffe3f2,
};

/**
 * コーステーマごとの世界観設定。装飾モデル/地面パッチに加え、地面の色・模様スタイル・崖面の
 * 質感・空/霧/光の色味までテーマ単位で切り替えられるようにしている(お菓子の国のように
 * 世界観を大きく作り込むテーマに対応するため)。既存3テーマは`groundStyle: 'default'`
 * `cliffStyle: 'rock'`+`DEFAULT_ATMOSPHERE`で、見た目は変更前と同一。
 */
export const THEMES = {
  forest: {
    label: '森',
    decorations: ['tree', 'tree-high', 'rocks-high', 'rocks-low', 'rocks-ramp', 'stones', 'plant'],
    patch: 'patch-grass',
    groundColors: DEFAULT_GROUND_COLORS,
    groundStyle: 'default',
    cliffStyle: 'rock',
    ...DEFAULT_ATMOSPHERE,
  },
  rock: {
    label: '岩場',
    decorations: ['rock-tall-a', 'rock-tall-d', 'rock-large-b', 'rock-large-e', 'stone-tall-c', 'cactus-tall', 'mushroom-tan-tall'],
    patch: 'rock-flat-a',
    groundColors: DEFAULT_GROUND_COLORS,
    groundStyle: 'default',
    cliffStyle: 'rock',
    ...DEFAULT_ATMOSPHERE,
  },
  snow: {
    label: '雪原',
    decorations: ['tree-snow-a', 'tree-snow-b', 'tree-snow-c', 'snow-rocks-large', 'snow-rocks-medium', 'snowman', 'snowflake-a'],
    patch: 'snow-flat',
    groundColors: DEFAULT_GROUND_COLORS,
    groundStyle: 'default',
    cliffStyle: 'rock',
    ...DEFAULT_ATMOSPHERE,
  },
  candy: {
    label: 'お菓子',
    // cloneModel()で読み込むモデル名ではなく、下のcreateCandyProp()が解釈する種類キー。
    decorations: ['candyCane', 'lollipopPink', 'lollipopMint', 'gumdropRed', 'gumdropYellow', 'donut'],
    patch: null, // cloneModel()を使わずcreateFrostingPatch()でプロシージャル生成する。
    groundColors: CANDY_GROUND_COLORS,
    groundStyle: 'candy',
    cliffStyle: 'cake',
    ...CANDY_ATMOSPHERE,
  },
};
export const DEFAULT_THEME = 'forest';

/**
 * ステージ選択の並び順(=進行制ロックの順序)。THEMESのキー順に依存せず明示的に持つ。
 * 最初のステージ以外は、1つ前のステージをクリアする(1回のランでSTAGE_CLEAR_DISTANCE以上走る)まで
 * 解放されない。
 */
export const STAGE_ORDER = ['forest', 'rock', 'snow', 'candy'];
export const STAGE_CLEAR_DISTANCE = 300;

/** そのステージが解放済みかどうか。clearedStagesは「クリア済みテーマidの配列」。 */
export function isStageUnlocked(theme, clearedStages) {
  const idx = STAGE_ORDER.indexOf(theme);
  if (idx <= 0) return true;
  return clearedStages.includes(STAGE_ORDER[idx - 1]);
}

const DEG = Math.PI / 180;
const LOOKAHEAD = 70;
const BEHIND_CULL = 25;
// 「薄い板が宙に浮いている」ように見えないよう、足場は岩の塊として十分な厚みを持たせる。
export const PLATFORM_THICKNESS = 2.2;

// --- 分岐(fork)区間: 「安全で地味な広い道」と「狭くて危険だがコインが多い道」に一時的に分かれる。
// リスクを取るほど報酬(コイン/コンボ)が増えるという駆け引きを作るための仕組み。
// 序盤で操作を覚える前にいきなり選択を迫らないよう最低到達距離を設け、連発しないようクールダウンを置く。
const FORK_MIN_START_DIST = 140;
const FORK_COOLDOWN = 90;
const FORK_STAGE_A_LENGTH = 5; // 分岐直後: まだ間隔が狭く、多少ズレていても道の上に留まれる「予告」区間
const FORK_STAGE_B_LENGTH = 11; // 本番: 間隔が広がり、選んだ道を最後まで踏み外さず走り切る必要がある区間
const FORK_SAFE_WIDTH = 4.0;
const FORK_RISK_WIDTH = 2.0;
const FORK_OFFSET_A = 1.65;
const FORK_OFFSET_B = 2.15;
const COIN_SPIN_SPEED = 2.4;
const COIN_BOB_AMPLITUDE = 0.08;
const COIN_BOB_SPEED = 3;

// コインの色はテーマを問わず共通(金貨=チョコレートコインのようにも見えるため変更不要)。
const COIN_COLOR = 0xffd447;
// キャンディ地面テクスチャの縁ストライプ等で使う共通トーン。
const CANDY_ACCENT = {
  white: '#fffaf5',
  red: '#e8384f',
  pink: '#ff6fa5',
  mint: '#7ee8c4',
  yellow: '#ffd447',
  cream: '#fff3d9',
};

function lerp(a, b, t) {
  return a + (b - a) * t;
}

/** 縁に沿った斜め黒黄の警戒ストライプを描く(narrowセグメントの危険性を視覚的に伝える)。 */
function drawHazardStripe(ctx, x, stripeSpan, height) {
  ctx.save();
  ctx.beginPath();
  ctx.rect(x, 0, stripeSpan, height);
  ctx.clip();
  ctx.fillStyle = '#2b2b2b';
  ctx.fillRect(x, 0, stripeSpan, height);
  ctx.fillStyle = '#ffd447';
  const band = 16;
  for (let y = -height; y < height * 2; y += band * 2) {
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(Math.PI / 4);
    ctx.fillRect(-height, 0, height * 3, band);
    ctx.restore();
  }
  ctx.restore();
}

/** 進行方向を示す白いシェブロン(矢印)を並べて描く(boostセグメントの推進感を演出)。 */
function drawBoostChevrons(ctx, width, height) {
  ctx.save();
  ctx.strokeStyle = 'rgba(255,255,255,0.85)';
  ctx.lineWidth = width * 0.12;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  const step = height / 3;
  for (let y = -step; y < height + step; y += step) {
    ctx.beginPath();
    ctx.moveTo(width * 0.15, y + step * 0.7);
    ctx.lineTo(width * 0.5, y + step * 0.1);
    ctx.lineTo(width * 0.85, y + step * 0.7);
    ctx.stroke();
  }
  ctx.restore();
}

/** セグメント種別ごとの路面テクスチャ(単色+粒状ノイズ、narrowは縁に警戒ストライプ、boostはシェブロン)。 */
function createGroundTexture(type, colorHex) {
  const width = 128;
  const height = 256;
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext('2d');

  const base = new THREE.Color(colorHex);
  ctx.fillStyle = `#${base.getHexString()}`;
  ctx.fillRect(0, 0, width, height);

  for (let i = 0; i < 900; i++) {
    const shade = Math.random() > 0.5 ? 255 : 0;
    ctx.fillStyle = `rgba(${shade},${shade},${shade},${0.04 + Math.random() * 0.05})`;
    const size = 2 + Math.random() * 3;
    ctx.fillRect(Math.random() * width, Math.random() * height, size, size);
  }

  if (type === 'narrow') {
    const stripeSpan = width * 0.09;
    drawHazardStripe(ctx, 0, stripeSpan, height);
    drawHazardStripe(ctx, width - stripeSpan, stripeSpan, height);
  } else if (type === 'boost') {
    drawBoostChevrons(ctx, width, height);
  }

  const texture = new THREE.CanvasTexture(canvas);
  texture.wrapS = THREE.RepeatWrapping;
  texture.wrapT = THREE.RepeatWrapping;
  texture.repeat.set(1, 5);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

/** 斜めの太いキャンディケインストライプ(全面)。narrowの警戒表示を兼ねる。 */
function drawCandyCaneStripe(ctx, width, height, stripeColor) {
  ctx.save();
  ctx.fillStyle = CANDY_ACCENT.white;
  ctx.fillRect(0, 0, width, height);
  ctx.fillStyle = stripeColor;
  const band = width * 0.32;
  for (let y = -height; y < height * 2; y += band * 2) {
    ctx.save();
    ctx.translate(0, y);
    ctx.rotate(Math.PI / 5);
    ctx.fillRect(-height, 0, height * 3, band);
    ctx.restore();
  }
  ctx.restore();
}

/** 波打つ帯を重ねたパステルマーブル模様。 */
function drawCandyMarble(ctx, width, height, colors) {
  ctx.save();
  ctx.fillStyle = colors[0];
  ctx.fillRect(0, 0, width, height);
  const bandCount = 5;
  const bandHeight = (height / bandCount) * 1.5;
  for (let i = 0; i < bandCount; i++) {
    ctx.fillStyle = colors[(i + 1) % colors.length];
    const yBase = i * (height / bandCount);
    ctx.beginPath();
    ctx.moveTo(-width * 0.5, yBase);
    for (let x = -width * 0.5; x <= width * 1.5; x += width / 10) {
      ctx.lineTo(x, yBase + Math.sin(x * 0.05 + i * 1.7) * 12);
    }
    for (let x = width * 1.5; x >= -width * 0.5; x -= width / 10) {
      ctx.lineTo(x, yBase + bandHeight + Math.sin(x * 0.05 + i * 1.7) * 12);
    }
    ctx.closePath();
    ctx.fill();
  }
  ctx.restore();
}

/** 光沢のある単色+斜めのハイライト筋(グミの艶っぽさを演出)。 */
function drawGummyGloss(ctx, width, height, colorHex) {
  ctx.save();
  ctx.fillStyle = colorHex;
  ctx.fillRect(0, 0, width, height);
  const gradient = ctx.createLinearGradient(0, 0, width, height * 0.4);
  gradient.addColorStop(0, 'rgba(255,255,255,0.55)');
  gradient.addColorStop(0.5, 'rgba(255,255,255,0.1)');
  gradient.addColorStop(1, 'rgba(255,255,255,0)');
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, width, height * 0.5);
  ctx.restore();
}

/** カラフルな粒(スプリンクル)を散らす。boostセグメントの推進シェブロンと組み合わせる。 */
function drawSprinkles(ctx, width, height) {
  const colors = [CANDY_ACCENT.red, CANDY_ACCENT.mint, CANDY_ACCENT.pink, '#4c9dff', CANDY_ACCENT.yellow];
  for (let i = 0; i < 140; i++) {
    ctx.save();
    ctx.translate(Math.random() * width, Math.random() * height);
    ctx.rotate(Math.random() * Math.PI * 2);
    ctx.fillStyle = colors[i % colors.length];
    ctx.fillRect(-4, -1.3, 8, 2.6);
    ctx.restore();
  }
}

/** お菓子の国テーマ専用の路面テクスチャ。種別ごとに完全に異なる描画関数を使う。 */
function createCandyGroundTexture(type, colorHex) {
  const width = 128;
  const height = 256;
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext('2d');

  if (type === 'narrow') {
    drawCandyCaneStripe(ctx, width, height, CANDY_ACCENT.red);
  } else if (type === 'moving') {
    drawGummyGloss(ctx, width, height, `#${new THREE.Color(colorHex).getHexString()}`);
  } else if (type === 'boost') {
    ctx.fillStyle = `#${new THREE.Color(colorHex).getHexString()}`;
    ctx.fillRect(0, 0, width, height);
    drawSprinkles(ctx, width, height);
    drawBoostChevrons(ctx, width, height);
  } else {
    const palette =
      type === 'curveLeft'
        ? [CANDY_ACCENT.cream, CANDY_ACCENT.white, '#ffe3a8']
        : type === 'curveRight'
          ? [CANDY_ACCENT.mint, CANDY_ACCENT.white, '#a8f5dd']
          : [`#${new THREE.Color(colorHex).getHexString()}`, CANDY_ACCENT.white, CANDY_ACCENT.pink];
    drawCandyMarble(ctx, width, height, palette);
  }

  const texture = new THREE.CanvasTexture(canvas);
  texture.wrapS = THREE.RepeatWrapping;
  texture.wrapT = THREE.RepeatWrapping;
  texture.repeat.set(1, 5);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

const segmentMaterialCache = new Map();

/**
 * テーマ+セグメント種別ごとにテクスチャ付きマテリアルを1つだけ生成し使い回す。
 * 全セグメントで共有するため、_disposeSegment側ではdisposeしない。
 */
function getSegmentMaterial(theme, type) {
  const key = `${theme}:${type}`;
  if (segmentMaterialCache.has(key)) return segmentMaterialCache.get(key);
  const themeConfig = THEMES[theme];
  const color = themeConfig.groundColors[type] ?? themeConfig.groundColors.straight;
  const texture =
    themeConfig.groundStyle === 'candy' ? createCandyGroundTexture(type, color) : createGroundTexture(type, color);
  const material = new THREE.MeshStandardMaterial({
    map: texture,
    roughness: 0.85,
    metalness: 0.05,
  });
  segmentMaterialCache.set(key, material);
  return material;
}

/**
 * 足場の側面用テクスチャ。'rock'=地層っぽい横縞(既存)、'cake'=ケーキの断面(スポンジ+クリーム層)。
 */
function createCliffSideTexture() {
  const width = 128;
  const height = 128;
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext('2d');

  const bandColors = ['#8a7d6c', '#7c6f5f', '#94886f', '#736656'];
  let y = 0;
  let i = 0;
  while (y < height) {
    const bandHeight = 8 + Math.random() * 16;
    ctx.fillStyle = bandColors[i % bandColors.length];
    ctx.fillRect(0, y, width, bandHeight);
    y += bandHeight;
    i++;
  }

  for (let n = 0; n < 500; n++) {
    const shade = Math.random() > 0.5 ? 255 : 0;
    ctx.fillStyle = `rgba(${shade},${shade},${shade},${0.03 + Math.random() * 0.05})`;
    const size = 2 + Math.random() * 3;
    ctx.fillRect(Math.random() * width, Math.random() * height, size, size);
  }

  const texture = new THREE.CanvasTexture(canvas);
  texture.wrapS = THREE.RepeatWrapping;
  texture.wrapT = THREE.RepeatWrapping;
  texture.repeat.set(1, 3);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

/** ケーキの断面: スポンジ層(ピンク/黄/白)+クリーム層+スプリンクルの粒。 */
function createCakeSideTexture() {
  const width = 128;
  const height = 128;
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext('2d');

  const spongeColors = ['#ffd6ec', '#fff3b0', '#ffe9f5'];
  const sprinkleColors = [CANDY_ACCENT.red, CANDY_ACCENT.mint, '#4c9dff', CANDY_ACCENT.yellow];
  let y = 0;
  let i = 0;
  while (y < height) {
    const spongeHeight = 13 + Math.random() * 9;
    ctx.fillStyle = spongeColors[i % spongeColors.length];
    ctx.fillRect(0, y, width, spongeHeight);
    y += spongeHeight;

    const creamHeight = 5 + Math.random() * 3;
    ctx.fillStyle = CANDY_ACCENT.white;
    ctx.fillRect(0, y, width, creamHeight);
    for (let n = 0; n < 5; n++) {
      ctx.fillStyle = sprinkleColors[Math.floor(Math.random() * sprinkleColors.length)];
      ctx.fillRect(Math.random() * width, y + Math.random() * creamHeight, 3, 1.5);
    }
    y += creamHeight;
    i++;
  }

  const texture = new THREE.CanvasTexture(canvas);
  texture.wrapS = THREE.RepeatWrapping;
  texture.wrapT = THREE.RepeatWrapping;
  texture.repeat.set(1, 3);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

const cliffSideMaterialCache = new Map();
function getCliffSideMaterial(style) {
  if (cliffSideMaterialCache.has(style)) return cliffSideMaterialCache.get(style);
  const texture = style === 'cake' ? createCakeSideTexture() : createCliffSideTexture();
  const material = new THREE.MeshStandardMaterial({
    map: texture,
    roughness: style === 'cake' ? 0.6 : 0.95,
    metalness: 0,
  });
  cliffSideMaterialCache.set(style, material);
  return material;
}

/** セグメント用の2枠マテリアル配列(0=側面/底面/端面、1=上面の種別テクスチャ)。テーマ単位で切り替わる。 */
function getSegmentMaterials(theme, type) {
  const themeConfig = THEMES[theme];
  return [getCliffSideMaterial(themeConfig.cliffStyle), getSegmentMaterial(theme, type)];
}

/**
 * 始端と終端で幅が異なる台形の箱ジオメトリを作る。
 * セグメント種別が変わって幅が変化する箇所(例: 通常路→狭道)で、中心線は必ず連続する一方
 * 縁は幅差の半分だけズレて隙間/段差ができてしまう問題を、縁を滑らかにテーパーさせて解消する。
 * ローカル座標系: X=幅方向, Y=厚み(上が+), Z=長さ(+が始端側, -が終端側。quaternion側の定義に合わせる)。
 * マテリアルは2枠([0]=側面・底面・端面の岩肌, [1]=上面の種別テクスチャ)。
 */
function createTaperedBoxGeometry(startWidth, endWidth, thickness, length) {
  const hT = thickness / 2;
  const hL = length / 2;
  const sW = startWidth / 2;
  const eW = endWidth / 2;

  const bls = [-sW, -hT, hL];
  const brs = [sW, -hT, hL];
  const trs = [sW, hT, hL];
  const tls = [-sW, hT, hL];
  const ble = [-eW, -hT, -hL];
  const bre = [eW, -hT, -hL];
  const tre = [eW, hT, -hL];
  const tle = [-eW, hT, -hL];

  const quads = [
    { verts: [tls, trs, tre, tle], normal: [0, 1, 0], materialIndex: 1 }, // 上面
    { verts: [ble, bre, brs, bls], normal: [0, -1, 0], materialIndex: 0 }, // 底面
    { verts: [brs, bre, tre, trs], normal: [1, 0, 0], materialIndex: 0 }, // 右側面
    { verts: [tls, tle, ble, bls], normal: [-1, 0, 0], materialIndex: 0 }, // 左側面
    { verts: [bls, brs, trs, tls], normal: [0, 0, 1], materialIndex: 0 }, // 始端の切り口
    { verts: [ble, tle, tre, bre], normal: [0, 0, -1], materialIndex: 0 }, // 終端の切り口
  ];
  const uvCoords = [
    [0, 0],
    [1, 0],
    [1, 1],
    [0, 1],
  ];

  const positions = [];
  const normals = [];
  const uvs = [];
  const indices = [];

  quads.forEach((quad, qi) => {
    const base = qi * 4;
    quad.verts.forEach((v, i) => {
      positions.push(v[0], v[1], v[2]);
      normals.push(quad.normal[0], quad.normal[1], quad.normal[2]);
      uvs.push(uvCoords[i][0], uvCoords[i][1]);
    });
    indices.push(base, base + 1, base + 2, base, base + 2, base + 3);
  });

  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geometry.setAttribute('normal', new THREE.Float32BufferAttribute(normals, 3));
  geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
  geometry.setIndex(indices);
  quads.forEach((quad, qi) => geometry.addGroup(qi * 6, 6, quad.materialIndex));
  // 台形テーパーで面がわずかに非平面になる箇所があるため、法線は面ごとに固定値を使う
  // (computeVertexNormalsは使わない。頂点共有していないので平坦なままでよい)。
  return geometry;
}

let coinGeometry = null;
/** コインらしい薄い円盤。円柱を90度倒し、進行方向から見て丸い面が見えるようにする。 */
function getCoinGeometry() {
  if (!coinGeometry) {
    coinGeometry = new THREE.CylinderGeometry(0.3, 0.3, 0.09, 20);
    coinGeometry.rotateX(Math.PI / 2);
  }
  return coinGeometry;
}

let coinMaterial = null;
function getCoinMaterial() {
  if (!coinMaterial) {
    coinMaterial = new THREE.MeshStandardMaterial({
      color: COIN_COLOR,
      emissive: 0x8a6200,
      emissiveIntensity: 0.4,
      roughness: 0.25,
      metalness: 0.7,
    });
  }
  return coinMaterial;
}

// --- お菓子の国テーマ: 外部モデルに頼らずThree.jsのプリミティブでキャンディ装飾を作る ---
// (cloneModel()が読み込むKenney製GLBの代わり。asset_libraryに適したお菓子アセットが無かったため、
// 本セッションで確立したプロシージャル生成の手法(タペリング地形/コイン円盤と同様)で自作する)

/** 渦巻き模様(ロリポップの頭)。 */
function createSwirlTexture(colorA, colorB) {
  const size = 128;
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = colorA;
  ctx.fillRect(0, 0, size, size);
  ctx.strokeStyle = colorB;
  ctx.lineWidth = size * 0.14;
  ctx.lineCap = 'round';
  const cx = size / 2;
  const cy = size / 2;
  ctx.beginPath();
  for (let a = 0; a < Math.PI * 5; a += 0.1) {
    const r = a * (size * 0.075);
    const x = cx + Math.cos(a) * r;
    const y = cy + Math.sin(a) * r;
    if (a === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  }
  ctx.stroke();
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

/** キャンディケインの斜めストライプ(チューブに巻き付ける)。 */
function createCandyCaneTubeTexture() {
  const size = 64;
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = CANDY_ACCENT.white;
  ctx.fillRect(0, 0, size, size);
  ctx.fillStyle = CANDY_ACCENT.red;
  const stripe = size / 3;
  for (let x = -size; x < size * 2; x += stripe * 2) {
    ctx.save();
    ctx.translate(x, 0);
    ctx.rotate(Math.PI / 4);
    ctx.fillRect(-size, 0, stripe, size * 3);
    ctx.restore();
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.wrapS = THREE.RepeatWrapping;
  texture.wrapT = THREE.RepeatWrapping;
  texture.repeat.set(4, 1);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

/** ドーナツ表面のスプリンクル(カラフルな粒)。 */
function createDonutTexture(glazeColor) {
  const size = 128;
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = glazeColor;
  ctx.fillRect(0, 0, size, size);
  const sprinkleColors = [CANDY_ACCENT.red, '#4c9dff', CANDY_ACCENT.yellow, '#4cd77b', CANDY_ACCENT.white];
  for (let i = 0; i < 70; i++) {
    ctx.save();
    ctx.translate(Math.random() * size, Math.random() * size);
    ctx.rotate(Math.random() * Math.PI * 2);
    ctx.fillStyle = sprinkleColors[i % sprinkleColors.length];
    ctx.fillRect(-4, -1.2, 8, 2.4);
    ctx.restore();
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

function createCandyCaneGroup() {
  const group = new THREE.Group();
  const curve = new THREE.CatmullRomCurve3([
    new THREE.Vector3(0, 0, 0),
    new THREE.Vector3(0, 0.5, 0),
    new THREE.Vector3(0, 0.8, 0),
    new THREE.Vector3(0.1, 0.95, 0),
    new THREE.Vector3(0.24, 0.88, 0),
  ]);
  const geometry = new THREE.TubeGeometry(curve, 28, 0.045, 10, false);
  const material = new THREE.MeshStandardMaterial({ map: createCandyCaneTubeTexture(), roughness: 0.35 });
  const mesh = new THREE.Mesh(geometry, material);
  group.add(mesh);
  return group;
}

function createLollipopGroup(headColorA, headColorB) {
  const group = new THREE.Group();
  const stickGeometry = new THREE.CylinderGeometry(0.02, 0.02, 0.5, 8);
  const stickMaterial = new THREE.MeshStandardMaterial({ color: 0xfffaf5, roughness: 0.5 });
  applyGrainIfFlat(stickMaterial);
  const stick = new THREE.Mesh(stickGeometry, stickMaterial);
  stick.position.y = 0.25;
  group.add(stick);

  const headGeometry = new THREE.CylinderGeometry(0.22, 0.22, 0.055, 24);
  const headMaterial = new THREE.MeshStandardMaterial({
    map: createSwirlTexture(headColorA, headColorB),
    roughness: 0.3,
  });
  const head = new THREE.Mesh(headGeometry, headMaterial);
  head.rotation.x = Math.PI / 2;
  head.position.y = 0.52;
  group.add(head);
  return group;
}

function createGumdropGroup(colorHex) {
  const group = new THREE.Group();
  const geometry = new THREE.SphereGeometry(0.18, 16, 12);
  const material = new THREE.MeshStandardMaterial({ color: colorHex, roughness: 0.25, metalness: 0.05 });
  applyGrainIfFlat(material);
  const mesh = new THREE.Mesh(geometry, material);
  mesh.scale.set(1, 0.8, 1);
  mesh.position.y = 0.14;
  group.add(mesh);
  return group;
}

function createDonutGroup() {
  const group = new THREE.Group();
  const geometry = new THREE.TorusGeometry(0.16, 0.075, 12, 24);
  const material = new THREE.MeshStandardMaterial({ map: createDonutTexture(CANDY_ACCENT.pink), roughness: 0.4 });
  const mesh = new THREE.Mesh(geometry, material);
  mesh.rotation.x = Math.PI / 2;
  mesh.position.y = 0.1;
  group.add(mesh);
  return group;
}

/** クリームだまり(お菓子テーマの地面パッチ代わり)。潰した球で表現する。 */
function createFrostingPatchGroup() {
  const group = new THREE.Group();
  const geometry = new THREE.SphereGeometry(0.5, 16, 8);
  const material = new THREE.MeshStandardMaterial({ color: 0xfff6ea, roughness: 0.5 });
  applyGrainIfFlat(material);
  const mesh = new THREE.Mesh(geometry, material);
  mesh.scale.set(1, 0.22, 1);
  group.add(mesh);
  return group;
}

const candyTemplates = new Map();

/** キャンディ装飾のテンプレートをキャッシュし、cloneModel()と同じ要領でclone(true)して返す。 */
function cloneCandyProp(kind) {
  if (!candyTemplates.has(kind)) {
    let template;
    switch (kind) {
      case 'candyCane':
        template = createCandyCaneGroup();
        break;
      case 'lollipopPink':
        template = createLollipopGroup(CANDY_ACCENT.pink, CANDY_ACCENT.white);
        break;
      case 'lollipopMint':
        template = createLollipopGroup(CANDY_ACCENT.mint, CANDY_ACCENT.white);
        break;
      case 'gumdropRed':
        template = createGumdropGroup(CANDY_ACCENT.red);
        break;
      case 'gumdropYellow':
        template = createGumdropGroup(CANDY_ACCENT.yellow);
        break;
      case 'donut':
        template = createDonutGroup();
        break;
      default:
        template = createGumdropGroup(CANDY_ACCENT.red);
    }
    template.traverse((obj) => {
      if (obj.isMesh) {
        obj.castShadow = false;
        obj.receiveShadow = false;
      }
    });
    candyTemplates.set(kind, template);
  }
  return candyTemplates.get(kind).clone(true);
}

let frostingPatchTemplate = null;
function cloneFrostingPatch() {
  if (!frostingPatchTemplate) {
    frostingPatchTemplate = createFrostingPatchGroup();
    frostingPatchTemplate.traverse((obj) => {
      if (obj.isMesh) {
        obj.castShadow = false;
        obj.receiveShadow = false;
      }
    });
  }
  return frostingPatchTemplate.clone(true);
}

/**
 * タイトル画面のテーマ選択カード用に、そのテーマの見た目(路面テクスチャ・崖の質感・
 * 装飾)を凝縮した小さなジオラマを作る。main.js側でオフスクリーンレンダリングして
 * 実際の見た目そのままのサムネイル画像を生成するために使う(色見本ではなく実写)。
 */
export function buildThemePreviewScene(theme) {
  const cfg = THEMES[theme];
  const scene = new THREE.Scene();

  const geometry = new THREE.BoxGeometry(4.4, PLATFORM_THICKNESS, 4.6);
  const materials = getSegmentMaterials(theme, 'straight');
  // BoxGeometryは6面グループ([+x,-x,+y,-y,+z,-z])だがgetSegmentMaterialsは
  // テーパー形状用の2枠配列([0]=側面,[1]=上面)なので、6面ぶんに展開する。
  const mesh = new THREE.Mesh(geometry, [materials[0], materials[0], materials[1], materials[0], materials[0], materials[0]]);
  mesh.position.y = -PLATFORM_THICKNESS / 2;
  scene.add(mesh);

  const isCandy = theme === 'candy';
  const propNames = cfg.decorations;
  const offsets = [
    [-1.35, -0.6],
    [1.3, 0.5],
  ];
  offsets.forEach(([x, z], i) => {
    const name = propNames[i % propNames.length];
    const prop = isCandy ? cloneCandyProp(name) : cloneModel(name);
    const patch = isCandy ? cloneFrostingPatch() : cloneModel(cfg.patch);
    if (!prop || !patch) return;
    patch.position.set(x, 0, z);
    patch.scale.setScalar(1.1);
    prop.position.set(x, 0, z);
    prop.scale.setScalar(1.15);
    prop.rotation.y = i * 1.4;
    scene.add(patch);
    scene.add(prop);
  });

  return scene;
}

function pickWeighted(entries, rand) {
  const total = entries.reduce((sum, e) => sum + e.weight, 0);
  let r = rand() * total;
  for (const e of entries) {
    if (r < e.weight) return e.type;
    r -= e.weight;
  }
  return entries[entries.length - 1].type;
}

export class CourseGenerator {
  constructor({ scene, world, groundMaterial, rand = Math.random, theme = DEFAULT_THEME }) {
    this.scene = scene;
    this.world = world;
    this.groundMaterial = groundMaterial;
    this.rand = rand;
    this.setTheme(theme);

    this.segments = [];
    this.coins = [];
    this.movingSegments = [];

    this.cursorPos = new THREE.Vector3();
    this.cursorHeading = 0;
    this.cursorDist = 0;
    this.cursorWidth = 0;
    this._lastForkEndDist = -Infinity;
  }

  /** テーマ切り替え。次回のreset()から反映される(既存セグメントは差し替えない)。 */
  setTheme(theme) {
    this.theme = THEMES[theme] ? theme : DEFAULT_THEME;
  }

  reset() {
    for (const seg of this.segments) this._disposeSegment(seg);
    for (const coin of this.coins) this._disposeCoin(coin);
    this.segments = [];
    this.coins = [];
    this.movingSegments = [];

    this.cursorPos.set(0, 0, 0);
    this.cursorHeading = 0;
    this.cursorDist = 0;
    this.cursorWidth = 0;
    this._lastForkEndDist = -Infinity;

    // 開始地点は必ず平らで緩やかな安全地帯にする。
    this._appendSegment(
      { type: 'straight', length: 10, width: 5.5, slopeDeg: 4, yawDelta: 0 },
      true,
    );
  }

  get spawnPosition() {
    const first = this.segments[0];
    // 端(start)ちょうどだとボールの半径が箱の縁からはみ出し、角に接触して
    // 想定外の横方向の初速がつくことがあるため、少し内側にスポーンさせる。
    const p = first.start.clone().lerp(first.end, 0.12);
    p.y += PLATFORM_THICKNESS / 2 + 0.9;
    return { x: p.x, y: p.y, z: p.z };
  }

  difficultyAt(dist) {
    return Math.max(0, Math.min(1, dist / 900));
  }

  /**
   * 900m以降もdifficultyAt()は1で頭打ちになる(セグメント形状の乱数レンジが破綻しないようにするため)が、
   * それだけだと長く走るほど緊張感が薄れて「作業感」につながる。傾斜だけは上限なくじわじわ急にして、
   * 上手いプレイヤーほど際限なく速く・怖くなっていく感覚を保つ(伸びはsqrtで逓減させ、無理ゲー化を防ぐ)。
   */
  speedFactorAt(dist) {
    const over = Math.max(0, dist - 900);
    return 1 + Math.min(0.6, Math.sqrt(over) * 0.02);
  }

  _pickSpec(diff) {
    const weights = [
      { type: 'straight', weight: lerp(55, 22, diff) },
      { type: 'curveLeft', weight: lerp(12, 20, diff) },
      { type: 'curveRight', weight: lerp(12, 20, diff) },
      { type: 'narrow', weight: lerp(10, 20, diff) },
      { type: 'moving', weight: lerp(4, 15, diff) },
      { type: 'boost', weight: lerp(3, 10, diff) },
    ];
    const forkReady =
      this.cursorDist > FORK_MIN_START_DIST && this.cursorDist - this._lastForkEndDist > FORK_COOLDOWN;
    if (forkReady) weights.push({ type: 'fork', weight: lerp(3, 8, diff) });
    const type = pickWeighted(weights, this.rand);
    const slopeDeg = (lerp(9, 15, diff) + this.rand() * lerp(4, 7, diff)) * this.speedFactorAt(this.cursorDist);

    switch (type) {
      case 'fork':
        return { type, slopeDeg };
      case 'curveLeft':
        return {
          type,
          length: 7 + this.rand() * 3,
          width: 5.0,
          slopeDeg,
          yawDelta: -(lerp(16, 32, diff) + this.rand() * 10),
        };
      case 'curveRight':
        return {
          type,
          length: 7 + this.rand() * 3,
          width: 5.0,
          slopeDeg,
          yawDelta: lerp(16, 32, diff) + this.rand() * 10,
        };
      case 'narrow':
        return { type, length: 8 + this.rand() * 4, width: 2.3, slopeDeg, yawDelta: 0 };
      case 'moving':
        return {
          type,
          length: 6 + this.rand() * 2,
          width: 3.4,
          slopeDeg: slopeDeg * 0.6,
          yawDelta: 0,
          moveAmplitude: lerp(1.2, 2.6, diff),
          moveSpeed: lerp(0.9, 1.7, diff),
        };
      case 'boost':
        return { type, length: 6 + this.rand() * 2, width: 3.6, slopeDeg: slopeDeg * 0.5, yawDelta: 0 };
      default:
        return { type: 'straight', length: 9 + this.rand() * 4, width: 5.2, slopeDeg, yawDelta: 0 };
    }
  }

  ensureAheadOf(distanceTraveled) {
    while (this.cursorDist - distanceTraveled < LOOKAHEAD) {
      const diff = this.difficultyAt(this.cursorDist);
      const spec = this._pickSpec(diff);
      if (spec.type === 'fork') {
        this._appendForkSegment(spec);
      } else {
        this._appendSegment(spec, false);
      }
    }
    while (this.segments.length > 0 && this.segments[0].endDist < distanceTraveled - BEHIND_CULL) {
      this._disposeSegment(this.segments.shift());
    }
    this.coins = this.coins.filter((coin) => {
      if (coin.dist < distanceTraveled - BEHIND_CULL) {
        this._disposeCoin(coin);
        return false;
      }
      return true;
    });
  }

  _appendSegment(spec, isFirst) {
    const start = this.cursorPos.clone();
    const startHeading = this.cursorHeading;
    const yawDeltaRad = (spec.yawDelta || 0) * DEG;
    const endHeading = startHeading + yawDeltaRad;
    const avgHeading = startHeading + yawDeltaRad / 2;

    const forwardHoriz = new THREE.Vector3(Math.sin(avgHeading), 0, -Math.cos(avgHeading));
    const drop = spec.length * Math.tan(spec.slopeDeg * DEG);
    const end = start.clone().add(forwardHoriz.multiplyScalar(spec.length));
    end.y -= drop;

    const direction3D = end.clone().sub(start).normalize();
    const segLength3D = start.distanceTo(end);
    const center = start.clone().lerp(end, 0.5);

    // 進行方向は heading=0 のとき (0,0,-1) 基準。setFromUnitVectors の基準ベクトルを
    // (0,0,1) にすると通常の緩斜面でほぼ180度回転になり、setFromUnitVectorsが
    // 回転軸を一意に決められず"上面"がひっくり返って下り坂の向きが逆転するバグを踏む。
    // 基準を (0,0,-1) にして常に小さい回転で済むようにする。
    const quaternion = new THREE.Quaternion().setFromUnitVectors(
      new THREE.Vector3(0, 0, -1),
      direction3D,
    );

    // 前のセグメントの終端幅から自セグメントの幅へ滑らかにテーパーさせ、縁の隙間/段差を防ぐ
    // (中心線は常に連続するが、幅が変わる境界では縁だけが幅差の半分だけズレてしまうため)。
    const startWidth = isFirst ? spec.width : this.cursorWidth;
    // 当たり判定はテーパーしない単純な直方体なので、始端/終端の狭い方に合わせると
    // 見た目には道の上なのに当たり判定が無く落下する帯ができてしまう。広い方に合わせ、
    // 狭い方の外側にわずかな見えない安全マージンができる側に倒す。
    const physicsWidth = Math.max(startWidth, spec.width);
    const halfExtents = { x: physicsWidth / 2, y: PLATFORM_THICKNESS / 2, z: segLength3D / 2 };
    const isMoving = spec.type === 'moving';

    const geometry = createTaperedBoxGeometry(startWidth, spec.width, PLATFORM_THICKNESS, segLength3D);
    const mesh = new THREE.Mesh(geometry, getSegmentMaterials(this.theme, spec.type));
    mesh.position.copy(center);
    mesh.quaternion.copy(quaternion);
    mesh.receiveShadow = true;
    this.scene.add(mesh);

    const body = createPlatformBody({
      material: this.groundMaterial,
      halfExtents,
      position: center,
      quaternion,
      kinematic: isMoving,
    });
    this.world.addBody(body);
    this.cursorWidth = spec.width;

    const rightAxis = direction3D.clone().cross(new THREE.Vector3(0, 1, 0)).normalize();

    const segment = {
      type: spec.type,
      mesh,
      body,
      start: start.clone(),
      end: end.clone(),
      startDist: this.cursorDist,
      endDist: this.cursorDist + segLength3D,
      startY: start.y,
      endY: end.y,
      boosted: false,
      moving: isMoving
        ? { rightAxis, amplitude: spec.moveAmplitude, speed: spec.moveSpeed, basePos: center.clone() }
        : null,
      decorations: [],
    };
    this.segments.push(segment);
    if (isMoving) this.movingSegments.push(segment);

    if (!isFirst && spec.type !== 'moving' && this.rand() < 0.7) {
      this._placeCoins(start, end, this.cursorDist);
    }
    // 開始地点(isFirst)にもコインは置かない(安全地帯にする)が、装飾は置く。
    // タイトル画面で最初に映るのがこの区間なので、殺風景にならないようにする。
    if (!isMoving) {
      this._placeDecorations(segment, start, end, rightAxis, spec.width / 2);
    }

    this.cursorPos.copy(end);
    this.cursorHeading = endHeading;
    this.cursorDist = segment.endDist;
  }

  _placeCoins(start, end, baseDist) {
    this._placeCoinsCount(start, end, baseDist, 1 + Math.floor(this.rand() * 3));
  }

  _placeCoinsCount(start, end, baseDist, count) {
    for (let i = 0; i < count; i++) {
      const t = (i + 1) / (count + 1);
      const pos = start.clone().lerp(end, t);
      pos.y += PLATFORM_THICKNESS / 2 + 0.55;

      const mesh = new THREE.Mesh(getCoinGeometry(), getCoinMaterial());
      mesh.position.copy(pos);
      this.scene.add(mesh);

      this.coins.push({
        mesh,
        position: pos,
        baseY: pos.y,
        bobPhase: this.rand() * Math.PI * 2,
        dist: baseDist,
        collected: false,
      });
    }
  }

  /**
   * 分岐(fork)区間を作る。中心の1本道を、右へ「安全で広いが報酬の少ない道」、
   * 左へ「狭くて危険だがコインが多い道」の2枚の足場に分ける。2段階(A→B)に分けて
   * 間隔を徐々に広げることで、分岐した瞬間にどちらの道の上にいるか曖昧なまま
   * 落下してしまう理不尽を避ける。両道は最後に中心へ戻し、直後の通常セグメントが
   * (cursorWidthを外側の縁まで広げておくことで)テーパーしながら1本道へ合流する。
   */
  _appendForkSegment(spec) {
    const start = this.cursorPos.clone();
    const heading = this.cursorHeading;
    const forward = new THREE.Vector3(Math.sin(heading), 0, -Math.cos(heading));
    const rightAxis = forward.clone().cross(new THREE.Vector3(0, 1, 0)).normalize();

    const stageA = this._appendForkStage({
      start,
      forward,
      rightAxis,
      baseDist: this.cursorDist,
      length: FORK_STAGE_A_LENGTH,
      slopeDeg: spec.slopeDeg,
      safeOffset: FORK_OFFSET_A,
      riskOffset: -FORK_OFFSET_A,
      riskCoinCount: 2 + Math.floor(this.rand() * 2),
      safeCoinChance: 0.5,
    });

    const stageB = this._appendForkStage({
      start: stageA.end,
      forward,
      rightAxis,
      baseDist: stageA.endDist,
      length: FORK_STAGE_B_LENGTH,
      slopeDeg: spec.slopeDeg,
      safeOffset: FORK_OFFSET_B,
      riskOffset: -FORK_OFFSET_B,
      riskCoinCount: 4 + Math.floor(this.rand() * 3),
      safeCoinChance: 0.3,
    });

    this.cursorPos.copy(stageB.end);
    this.cursorHeading = heading;
    this.cursorDist = stageB.endDist;
    // 次の通常セグメントが合流するテーパーの開始幅。安全レーンの方が幅広なので、
    // その外縁までを覆えば両レーンとも隙間なく1本道へ収束する。
    this.cursorWidth = FORK_OFFSET_B * 2 + FORK_SAFE_WIDTH;
    this._lastForkEndDist = stageB.endDist;
  }

  /** fork区間の1段階分(安全レーン+危険レーンのペア)を生成し、中心線の終点/距離を返す。 */
  _appendForkStage(opts) {
    const { start, forward, rightAxis, baseDist, length, slopeDeg, safeOffset, riskOffset, riskCoinCount, safeCoinChance } =
      opts;
    const drop = length * Math.tan(slopeDeg * DEG);
    const centerEnd = start.clone().add(forward.clone().multiplyScalar(length));
    centerEnd.y -= drop;
    const direction3D = centerEnd.clone().sub(start).normalize();
    // _appendSegment同様、基準ベクトルを(0,0,-1)にして大回転による上面反転バグを避ける。
    const quaternion = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 0, -1), direction3D);
    const segLength3D = start.distanceTo(centerEnd);

    const makeLane = (offset, width, materialType, laneKind, coinCount) => {
      const laneStart = start.clone().add(rightAxis.clone().multiplyScalar(offset));
      const laneEnd = centerEnd.clone().add(rightAxis.clone().multiplyScalar(offset));
      const laneCenter = laneStart.clone().lerp(laneEnd, 0.5);
      const halfExtents = { x: width / 2, y: PLATFORM_THICKNESS / 2, z: segLength3D / 2 };

      const geometry = createTaperedBoxGeometry(width, width, PLATFORM_THICKNESS, segLength3D);
      const mesh = new THREE.Mesh(geometry, getSegmentMaterials(this.theme, materialType));
      mesh.position.copy(laneCenter);
      mesh.quaternion.copy(quaternion);
      mesh.receiveShadow = true;
      this.scene.add(mesh);

      const body = createPlatformBody({
        material: this.groundMaterial,
        halfExtents,
        position: laneCenter,
        quaternion,
        kinematic: false,
      });
      this.world.addBody(body);

      const segment = {
        type: laneKind,
        mesh,
        body,
        start: laneStart.clone(),
        end: laneEnd.clone(),
        startDist: baseDist,
        endDist: baseDist + segLength3D,
        startY: laneStart.y,
        endY: laneEnd.y,
        boosted: false,
        moving: null,
        decorations: [],
      };
      this.segments.push(segment);

      if (coinCount > 0) this._placeCoinsCount(laneStart, laneEnd, baseDist, coinCount);
      this._placeDecorations(segment, laneStart, laneEnd, rightAxis, width / 2);
      return segment;
    };

    makeLane(
      safeOffset,
      FORK_SAFE_WIDTH,
      'straight',
      'fork-safe',
      this.rand() < safeCoinChance ? 1 + Math.floor(this.rand() * 2) : 0,
    );
    makeLane(riskOffset, FORK_RISK_WIDTH, 'narrow', 'fork-risk', riskCoinCount);

    return { end: centerEnd, endDist: baseDist + segLength3D };
  }

  /** 硬貨らしい回転+上下のふわふわ揺れ演出。elapsed: 秒単位の累積時間、dt: 前フレームからの経過秒。 */
  updateCoins(elapsed, dt) {
    for (const coin of this.coins) {
      coin.mesh.rotation.y += COIN_SPIN_SPEED * dt;
      coin.mesh.position.y = coin.baseY + Math.sin(elapsed * COIN_BOB_SPEED + coin.bobPhase) * COIN_BOB_AMPLITUDE;
    }
  }

  /**
   * ボールが現在いるboostセグメントを1度だけ「消費」する。
   * 同じセグメントに留まっている間に何度も加速しないよう、消費済みフラグで防ぐ。
   * 該当セグメントが見つかればそれを返し、呼び出し側(main.js)が速度への加算を行う。
   */
  consumeBoost(distanceTraveled) {
    const seg = this.segments.find(
      (s) => s.type === 'boost' && !s.boosted && distanceTraveled >= s.startDist && distanceTraveled <= s.endDist,
    );
    if (!seg) return null;
    seg.boosted = true;
    return seg;
  }

  /**
   * コース脇に木・岩などの装飾(当たり判定なし)をランダムに配置する。
   * 足場の外(空中)に置くと支えるものが何もなく浮いて見えるため、必ず足場の岩の上
   * (縁寄りだが内側)に留める。土台として「地面パッチ」をテーマに応じて敷き、
   * その上に木/岩を乗せる。
   */
  _placeDecorations(segment, start, end, rightAxis, halfWidth) {
    const { decorations, patch: patchName } = THEMES[this.theme];
    // お菓子の国はcloneModel()の代わりにプロシージャル生成(cloneCandyProp/cloneFrostingPatch)を使う。
    const isCandy = this.theme === 'candy';
    for (const side of [-1, 1]) {
      if (this.rand() > 0.4) continue;
      const propName = decorations[Math.floor(this.rand() * decorations.length)];
      const prop = isCandy ? cloneCandyProp(propName) : cloneModel(propName);
      const patch = isCandy ? cloneFrostingPatch() : cloneModel(patchName);
      if (!prop || !patch) continue;

      const t = 0.25 + this.rand() * 0.5;
      // 足場の外(空中)にはみ出させない。縁ぎりぎりだが必ず足場の岩の上に乗る位置に置く。
      const lateral = halfWidth * (0.55 + this.rand() * 0.35);
      const pos = start.clone().lerp(end, t).add(rightAxis.clone().multiplyScalar(side * lateral));
      pos.y += PLATFORM_THICKNESS / 2; // 足場の上面高さに合わせる(start/endは中心線)。

      const rotationY = this.rand() * Math.PI * 2;

      patch.position.copy(pos);
      patch.rotation.y = rotationY;
      patch.scale.setScalar(0.9 + this.rand() * 0.5);
      this.scene.add(patch);
      segment.decorations.push(patch);

      prop.position.copy(pos);
      prop.rotation.y = this.rand() * Math.PI * 2;
      prop.scale.setScalar(0.8 + this.rand() * 0.6);
      this.scene.add(prop);
      segment.decorations.push(prop);
    }
  }

  /** elapsed: 秒単位の累積時間 */
  updateMovingPlatforms(elapsed) {
    for (const seg of this.movingSegments) {
      const { rightAxis, amplitude, speed, basePos } = seg.moving;
      const offset = Math.sin(elapsed * speed) * amplitude;
      const velocityScalar = Math.cos(elapsed * speed) * amplitude * speed;
      const newPos = basePos.clone().add(rightAxis.clone().multiplyScalar(offset));
      seg.body.velocity.set(
        rightAxis.x * velocityScalar,
        rightAxis.y * velocityScalar,
        rightAxis.z * velocityScalar,
      );
      seg.body.position.set(newPos.x, newPos.y, newPos.z);
      seg.mesh.position.copy(seg.body.position);
    }
  }

  /** ボール位置とコインの当たり判定。取得したコイン数を返す。 */
  collectCoins(ballPosition, radius = 0.9) {
    let collected = 0;
    for (const coin of this.coins) {
      if (coin.collected) continue;
      const dx = coin.position.x - ballPosition.x;
      const dy = coin.position.y - ballPosition.y;
      const dz = coin.position.z - ballPosition.z;
      if (dx * dx + dy * dy + dz * dz < radius * radius) {
        coin.collected = true;
        this.scene.remove(coin.mesh);
        // geometry/materialは全コインで共有(getCoinGeometry/getCoinMaterial)しているためdisposeしない。
        collected++;
      }
    }
    if (collected > 0) this.coins = this.coins.filter((c) => !c.collected);
    return collected;
  }

  _disposeSegment(seg) {
    this.scene.remove(seg.mesh);
    seg.mesh.geometry.dispose();
    // materialはセグメント種別ごとにgetSegmentMaterial()で共有しているため、
    // ここではdisposeしない(他の生存中セグメントが同じマテリアルを参照している)。
    this.world.removeBody(seg.body);
    if (seg.moving) {
      const idx = this.movingSegments.indexOf(seg);
      if (idx >= 0) this.movingSegments.splice(idx, 1);
    }
    // 装飾のgeometry/materialはモデルテンプレートを複数インスタンスで共有しているため
    // disposeしない(他の装飾から参照されているGPUリソースを壊してしまうため)。
    for (const decoration of seg.decorations) {
      this.scene.remove(decoration);
    }
  }

  _disposeCoin(coin) {
    this.scene.remove(coin.mesh);
    // geometry/materialは全コインで共有(getCoinGeometry/getCoinMaterial)しているためdisposeしない。
  }
}
