#!/usr/bin/env bash
# 撮影した素材を fastlane が読む場所へ並べる。
# 掲載に使う順番はここで決める（ファイル名の先頭の数字がストアの並び順になる）。
set -euo pipefail

cd "$(dirname "$0")/.."
SRC_PHONE="${1:-build/shots}"
SRC_IPAD="${2:-build/shots_ipad}"
DEST="ios/fastlane/screenshots/ja"

mkdir -p "$DEST"
# 前回の素材と枠付きを消す（名前を変えたので、古い枠付きが残るとそれも上がってしまう）
find "$DEST" -maxdepth 1 -name '*.png' -delete

# 掲載順: 会話で○× → 過去問の AIに聞く → 過去問の一覧 → 図解 → ホーム → 選択肢で確かめる
# 素材は tool/store_shots.sh（integration_test/store_shots_test.dart、本番・本物の AI）で撮る。
# 価格（「無料」を含む）が写る画面は載せない（Guideline 2.3.7 で却下された）。Pro の画面・はじめの画面は撮らない。
# 本物の AI なので、会話の画面は撮るたびに中身が変わる。撮ったら目で見て選び直す。
copy() {
  local src="$1" name="$2" suffix="${3:-}"
  [ -f "$src" ] || { echo "見つかりません: $src" >&2; return; }
  cp "$src" "$DEST/${name}${suffix}.png"
}

copy "$SRC_PHONE/01_chat_figure.png"     "01_question"
copy "$SRC_PHONE/06_explain.png"         "02_explain"
copy "$SRC_PHONE/04_kakomon.png"         "03_kakomon"
copy "$SRC_PHONE/07_library.png"         "04_figure"
copy "$SRC_PHONE/03_home.png"            "05_home"
copy "$SRC_PHONE/02_chat_question.png"   "06_choice"

copy "$SRC_IPAD/02_chat_question.png"    "01_question" "_ipad"
copy "$SRC_IPAD/06_explain.png"          "02_explain"  "_ipad"
copy "$SRC_IPAD/04_kakomon.png"          "03_kakomon"  "_ipad"
copy "$SRC_IPAD/01_chat_figure.png"      "04_figure"   "_ipad"
copy "$SRC_IPAD/03_home.png"             "05_home"     "_ipad"

echo "== $DEST =="
ls -la "$DEST"/*.png 2>/dev/null | grep -v framed || echo "素材がありません"
