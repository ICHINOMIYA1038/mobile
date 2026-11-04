#!/bin/zsh
# ストアの画像の素材を撮る: tool/store_shots.sh <シミュレーターの UDID> <出力先（例 build/store_raw/iphone）> [flutter test に渡す引数…]
# integration_test/store_shots_test.dart が「SHOT 名前」を出したところで simctl で撮る。時計などは揃える。
set -u
UDID=$1; OUT=$2; shift 2
cd "$(dirname "$0")/.."
mkdir -p "$OUT"
xcrun simctl boot "$UDID" 2>/dev/null
xcrun simctl status_bar "$UDID" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
flutter test ${TEST:-integration_test/store_shots_test.dart} -d "$UDID" "$@" 2>&1 | while IFS= read -r line; do
  echo "$line"
  case "$line" in *"SHOT "*) n=${line##*SHOT }; xcrun simctl io "$UDID" screenshot "$OUT/$n.png" >/dev/null 2>&1;; esac
done
