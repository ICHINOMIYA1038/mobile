// esbuildが生成した dist/game.js (+ .map) に、静的な index.html / style.css / フォント / 音声を合流させる。
//
// 注意: このスクリプトはesbuildの後に実行される想定。dist/game.js(.map)には触れず、
// このスクリプトが管理するファイル/ディレクトリだけを毎回削除してからコピーし直す
// (コピー対象を変更した際に古いファイルが残り続けるのを防ぐため)。
import { copyFileSync, cpSync, mkdirSync, rmSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const staticDir = join(here, 'static');
const distDir = join(here, 'dist');

mkdirSync(distDir, { recursive: true });

const MANAGED_ENTRIES = ['index.html', 'style.css', 'fonts', 'audio', 'models'];
for (const entry of MANAGED_ENTRIES) {
  rmSync(join(distDir, entry), { recursive: true, force: true });
}

for (const file of ['index.html', 'style.css']) {
  copyFileSync(join(staticDir, file), join(distDir, file));
}

for (const dir of ['fonts', 'audio']) {
  cpSync(join(staticDir, dir), join(distDir, dir), { recursive: true });
}

// モデル本体(.glb)はgenerate_model_data.jsでBase64化してgame.jsに埋め込み済みなので、
// ここではGLTFLoaderが相対パス解決で参照するテクスチャだけをコピーすればよい。
// 雪原テーマ(Holiday Kit)は森テーマと同名の"colormap.png"だが中身が別物のため、
// models/snow/Textures/ に分離して衝突を避けている(models.jsのRESOURCE_PATH参照)。
cpSync(join(staticDir, 'models', 'Textures'), join(distDir, 'models', 'Textures'), { recursive: true });
cpSync(join(staticDir, 'models', 'snow', 'Textures'), join(distDir, 'models', 'snow', 'Textures'), { recursive: true });

console.log('[copy_static] copied index.html / style.css / fonts/ / audio/ / models/Textures/ into dist/');
