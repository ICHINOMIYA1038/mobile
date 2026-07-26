#!/usr/bin/env bash
# 実画面のスクリーンショットに、App Storeで強みを伝える短いコピーを合成する。
# 元画像は変更せず、store_screenshots*/ に同じ提出解像度で書き出す。
set -euo pipefail

font_candidates=(/System/Library/Fonts/*W6.ttc)
body_font_candidates=(/System/Library/Fonts/*W3.ttc)
FONT="${font_candidates[0]}"
BODY_FONT="${body_font_candidates[0]}"
BG="#FFF9F5"
INK="#3D342F"
ACCENT="#FF8438"

titles=(
  "配点の高い分野から\n自動で5問"
  "○×だけだから\nすきま時間に進む"
  "全問に解説と\n根拠条文つき"
  "予想得点で\n合格まであと何点"
  "本試験の配点が\nひと目でわかる"
)

subtitles=(
  "忘れかけた問題も自動で復習"
  "迷わず、すぐに学習開始"
  "その場で理由まで理解できる"
  "未学習を含めて現実的に計算"
  "広い科目ほど合格に効く"
)

files=(01_home 02_quiz 03_explanation 04_pass_gauge 05_pass_graph)

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
