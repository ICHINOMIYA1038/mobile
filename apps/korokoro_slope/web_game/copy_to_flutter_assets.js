// dist/ の成果物を Flutter 側の assets/web/ にコピーする。
// assets/web/ は WebViewController.loadFlutterAsset() で読み込まれるバンドル資産。
import { cpSync, mkdirSync, rmSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const distDir = join(here, 'dist');
const targetDir = join(here, '..', 'assets', 'web');

if (existsSync(targetDir)) {
  rmSync(targetDir, { recursive: true, force: true });
}
mkdirSync(targetDir, { recursive: true });
cpSync(distDir, targetDir, { recursive: true });

console.log(`[copy_to_flutter_assets] copied dist/ -> ${targetDir}`);
