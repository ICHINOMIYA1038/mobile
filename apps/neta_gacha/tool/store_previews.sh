#!/usr/bin/env bash
# 実画面のスクリーンショットに、App Storeで強みを伝える短いコピーを合成する。
# 元画像は変更せず、store_screenshots/ に同じ提出解像度で書き出す。
# パターンは docs/screenshot-guidelines.md 参照(見出し・配色を全カットに入れる)。
set -euo pipefail

font_candidates=(/System/Library/Fonts/*W6.ttc)
body_font_candidates=(/System/Library/Fonts/*W3.ttc)
FONT="${font_candidates[0]}"
BODY_FONT="${body_font_candidates[0]}"
# lib/ui/theme.dart のブランドカラーに合わせる。
BG="#FFF6E9"     # warmCream
INK="#2A2438"    # inkNavy
ACCENT="#FF6B4A" # gachaOrange

titles=(
  "シチュエーション別に\nお題が出てくる"
  "ガチャを回すだけ"
  "かわいいカードで\nネタが届く"
  "気に入ったネタは\n保存できる"
  "自分のネタも\n追加できる"
)

subtitles=(
  "配信の流れを止めない"
  "迷わずすぐ使える"
  "そのまま読み上げOK"
  "配信の定番ネタ帳に"
  "オリジナルのお題帳に育てる"
)

files=(01_home 02_roulette 03_result 04_favorites 05_custom)

make_set() {
  local src_dir="$1"
  local out_dir="$2"
  local width="$3"
  local height="$4"
  local header="$5"
  local shot_width="$6"
  local title_size="$7"
  local subtitle_size="$8"

  mkdir -p "$out_dir"

  for i in "${!files[@]}"; do
    local src="$src_dir/${files[$i]}.png"
    local out="$out_dir/${files[$i]}.png"
    local shot_height=$((height - header + 80))

    magick -size "${width}x${height}" "xc:$BG" \
      -font "$FONT" -fill "$INK" -gravity north \
      -pointsize "$title_size" -interline-spacing 8 \
      -annotate "+0+$((header / 8))" "${titles[$i]}" \
      -font "$BODY_FONT" -fill "$ACCENT" -pointsize "$subtitle_size" \
      -annotate "+0+$((header * 2 / 3))" "${subtitles[$i]}" \
      \( "$src" -resize "${shot_width}x${shot_height}^" \
         -gravity north -crop "${shot_width}x${shot_height}+0+0" +repage \
         -bordercolor white -border 2 \
         -alpha set -channel A -evaluate set 96% +channel \) \
      -gravity south -geometry "+0-0" -composite \
      "$out"
  done
}

make_set screenshots store_screenshots 1320 2868 560 1160 64 30
make_set screenshots_ipad store_screenshots_ipad 2064 2752 430 1880 68 30

echo "生成完了: store_screenshots/ store_screenshots_ipad/"
