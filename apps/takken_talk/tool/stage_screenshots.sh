#!/usr/bin/env bash
# 撮影した素材を fastlane が読む場所へ並べる。
# 掲載に使う順番はここで決める（ファイル名の先頭の数字がストアの並び順になる）。
set -euo pipefail

cd "$(dirname "$0")/.."
SRC_PHONE="${1:-build/shots}"
SRC_IPAD="${2:-build/shots_ipad}"
DEST="ios/fastlane/screenshots/ja"

mkdir -p "$DEST"
# 前回の素材だけ消す。枠を付けた *_framed.png は消さない（frameit が作り直す）
find "$DEST" -maxdepth 1 -name '*.png' ! -name '*_framed*' -delete

# 掲載順: 図解 → ホーム → 出題 → 地図 → ライブラリ → はじめの画面
copy() {
  local src="$1" name="$2" suffix="${3:-}"
  [ -f "$src" ] || { echo "見つかりません: $src" >&2; return; }
  cp "$src" "$DEST/${name}${suffix}.png"
}

copy "$SRC_PHONE/06_chat_figure.png"     "01_figure"
copy "$SRC_PHONE/02_home.png"            "02_home"
copy "$SRC_PHONE/04_chat_question.png"   "03_question"
copy "$SRC_PHONE/09_map_topics.png"      "04_map"
copy "$SRC_PHONE/10_library.png"         "05_library"
copy "$SRC_PHONE/01_onboarding.png"      "06_start"

copy "$SRC_IPAD/06_chat_figure.png"      "01_figure" "_ipad"
copy "$SRC_IPAD/02_home.png"             "02_home"   "_ipad"
copy "$SRC_IPAD/04_chat_question.png"    "03_question" "_ipad"
copy "$SRC_IPAD/09_map_topics.png"       "04_map"    "_ipad"

echo "== $DEST =="
ls -la "$DEST"/*.png 2>/dev/null | grep -v framed || echo "素材がありません"
