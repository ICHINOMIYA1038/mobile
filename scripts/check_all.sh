#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

"$repo_root/scripts/validate_repo.sh"

# 共有パッケージを先に見る。壊れているとアプリ側の失敗として現れて原因が分かりにくい。
for pubspec in "$repo_root"/packages/*/pubspec.yaml "$repo_root"/apps/*/pubspec.yaml; do
  [ -f "$pubspec" ] || continue
  target_dir=$(dirname "$pubspec")
  echo "==> Checking ${target_dir#"$repo_root"/}"
  (
    cd "$target_dir"
    flutter pub get
    flutter analyze
    flutter test
  )
done
