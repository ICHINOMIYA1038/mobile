// Kenney "Mini Forest" (CC0) の3Dモデルを起動時にプリロードし、装飾配置(course.js)で
// クローンして使い回す。詳細は web_game/MODEL_CREDITS.md を参照。
//
// Android WebViewは file:// スキームでの fetch() をブロックするため、three.jsの
// FileLoader(fetch決め打ち)経由のURL読み込みは失敗する。そのためモデルは
// generate_model_data.js がビルド時に生成したBase64文字列としてJSバンドルに直接
// 埋め込み、ネットワークI/Oなしで GLTFLoader.parse() から読み込む。
// テクスチャ(models/Textures/colormap.png)は<img>要素ベースの読み込みで file:// でも
// 問題なく動くため、そちらは通常どおり相対パス解決に任せる。
import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { MODEL_DATA } from './generated/model-data.js';

const MODEL_NAMES = Object.keys(MODEL_DATA);
const RESOURCE_PATH = 'models/';

// 雪原テーマ(Holiday Kit)は外部テクスチャ"Textures/colormap.png"を参照するが、
// 森テーマ(Mini Forest)の同名テクスチャと中身が異なるため、models/snow/ に
// 分離して配置している(copy_static.js参照)。GLTFLoader.parse()の第2引数(path)を
// モデルごとに切り替えて衝突を避ける。岩場テーマ(Nature Kit)はテクスチャ埋め込み済みで
// 外部参照を持たないため影響しない。
const SNOW_MODEL_NAMES = new Set([
  'tree-snow-a', 'tree-snow-b', 'tree-snow-c',
  'snow-rocks-large', 'snow-rocks-medium', 'snowman', 'snowflake-a', 'snow-flat',
]);

function resourcePathFor(name) {
  return SNOW_MODEL_NAMES.has(name) ? `${RESOURCE_PATH}snow/` : RESOURCE_PATH;
}

const loader = new GLTFLoader();
const templates = new Map();

function base64ToArrayBuffer(base64) {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

/**
 * 表面に粒状の明暗ムラを与える小さなノイズテクスチャ。色そのものは変えず、
 * のっぺりした単色塗りに質感を足すためだけに使う(1枚だけ生成して全体で共有)。
 */
let grainTexture = null;
function getGrainTexture() {
  if (grainTexture) return grainTexture;
  const size = 128;
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, size, size);
  // 大きめのムラ(岩肌のシミのような塊)を先に敷き、その上に細かい粒を重ねる。
  // 単なる微弱ノイズだとレンダリング後にほぼ見えなくなるため、コントラストを強めに取る。
  for (let i = 0; i < 40; i++) {
    const shade = 150 + Math.random() * 110;
    ctx.fillStyle = `rgba(${shade},${shade},${shade},${0.18 + Math.random() * 0.22})`;
    const r = 10 + Math.random() * 26;
    ctx.beginPath();
    ctx.arc(Math.random() * size, Math.random() * size, r, 0, Math.PI * 2);
    ctx.fill();
  }
  for (let i = 0; i < 900; i++) {
    const shade = 130 + Math.random() * 130;
    ctx.fillStyle = `rgba(${shade},${shade},${shade},${0.15 + Math.random() * 0.3})`;
    const s = 1 + Math.random() * 3;
    ctx.fillRect(Math.random() * size, Math.random() * size, s, s);
  }
  grainTexture = new THREE.CanvasTexture(canvas);
  grainTexture.wrapS = THREE.RepeatWrapping;
  grainTexture.wrapT = THREE.RepeatWrapping;
  grainTexture.repeat.set(3, 3);
  grainTexture.colorSpace = THREE.SRGBColorSpace;
  return grainTexture;
}

/**
 * mapを持たないマテリアルに粒状ノイズを足す。色(material.color / baseColorFactor)は
 * そのまま活かしつつ、表面が完全な単色べた塗りに見えるのを防ぐ。素材パックによっては
 * (例: Kenney "Nature Kit")テクスチャ画像を一切持たずbaseColorFactorだけで
 * 書き出されているものがあり、これが「マテリアルがついていない」ように見える主因のひとつ。
 * お菓子テーマの自作プロシージャル装飾(グミ等、mapなしで単色のみ)にも同じ処理を使う。
 */
export function applyGrainIfFlat(material) {
  if (!material || material.map) return;
  material.map = getGrainTexture();
  material.needsUpdate = true;
}

/**
 * 一部の素材パック(Kenney "Nature Kit"の岩場テーマ)はmetallicFactor:1で書き出されている。
 * このシーンは環境マップ(IBL)を持たないため、metallic=1のマテリアルは鏡面反射する光源が
 * ほとんどなく、baseColorがあってもほぼ真っ黒〜灰色に潰れて見える(=「マテリアルが
 * ついていない」ように見える)。ローポリのカートゥーン調アセットなので金属反射は不要と
 * 判断し、読み込んだ全モデルで一律metalness=0を強制する(テンプレートに一度だけ適用すれば
 * clone()先はマテリアルを共有するので全クローンに効く)。あわせてmapを持たないマテリアルには
 * 粒状ノイズも足す。
 */
function normalizeMaterials(scene) {
  scene.traverse((obj) => {
    if (obj.isMesh && obj.material) {
      const materials = Array.isArray(obj.material) ? obj.material : [obj.material];
      for (const material of materials) {
        if ('metalness' in material) material.metalness = 0;
        applyGrainIfFlat(material);
      }
    }
  });
}

function loadOne(name) {
  return new Promise((resolve) => {
    const base64 = MODEL_DATA[name];
    if (!base64) {
      resolve();
      return;
    }
    const buffer = base64ToArrayBuffer(base64);
    loader.parse(
      buffer,
      resourcePathFor(name),
      (gltf) => {
        normalizeMaterials(gltf.scene);
        templates.set(name, gltf.scene);
        resolve();
      },
      (error) => {
        console.error(`[models] failed to parse ${name}`, error);
        resolve(); // 1つ失敗しても他のロードは続行し、ゲーム自体は起動できるようにする。
      },
    );
  });
}

/** 全モデルの読み込みを待つ。main.jsの起動シーケンスから一度だけ呼ぶ。 */
export function preloadModels() {
  return Promise.all(MODEL_NAMES.map(loadOne));
}

/** ロード済みモデルのクローンを返す。未ロード/失敗時は null。 */
export function cloneModel(name) {
  const template = templates.get(name);
  if (!template) return null;
  const clone = template.clone(true);
  clone.traverse((obj) => {
    if (obj.isMesh) {
      obj.castShadow = false;
      obj.receiveShadow = false;
    }
  });
  return clone;
}
