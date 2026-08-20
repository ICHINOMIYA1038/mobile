// Android WebView は file:// スキームでの fetch() をブロックするため
// (フォント/音声のような <link>/<audio> 経由のネイティブ読み込みは通る一方、
// three.jsのFileLoaderはfetch()決め打ちで読み込むため失敗する)、
// GLBモデルはネットワーク経由で読み込ませず、Base64文字列としてJSバンドルに直接埋め込み、
// GLTFLoader.parse() でメモリから読み込む。このファイルはビルド時に一度だけ実行し、
// src/generated/model-data.js を生成する。
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const modelsDir = join(here, 'static', 'models');
const outDir = join(here, 'src', 'generated');
const outFile = join(outDir, 'model-data.js');

const MODEL_NAMES = [
  // 森テーマ (Kenney "Mini Forest")
  'tree', 'tree-high', 'rocks-high', 'rocks-low', 'rocks-ramp', 'stones', 'plant', 'patch-grass',
  // 岩場テーマ (Kenney "Nature Kit")
  'rock-tall-a', 'rock-tall-d', 'rock-large-b', 'rock-large-e', 'stone-tall-c', 'cactus-tall', 'mushroom-tan-tall', 'rock-flat-a',
  // 雪原テーマ (Kenney "Holiday Kit")
  'tree-snow-a', 'tree-snow-b', 'tree-snow-c', 'snow-rocks-large', 'snow-rocks-medium', 'snowman', 'snowflake-a', 'snow-flat',
];

mkdirSync(outDir, { recursive: true });

const entries = MODEL_NAMES.map((name) => {
  const buffer = readFileSync(join(modelsDir, `${name}.glb`));
  return `  ${JSON.stringify(name)}: ${JSON.stringify(buffer.toString('base64'))},`;
});

const content =
  '// このファイルは generate_model_data.js が自動生成する。手で編集しないこと。\n' +
  'export const MODEL_DATA = {\n' +
  entries.join('\n') +
  '\n};\n';

writeFileSync(outFile, content);
console.log(`[generate_model_data] wrote ${outFile} (${MODEL_NAMES.length} models)`);
