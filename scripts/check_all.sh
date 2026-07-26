#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

"$repo_root/scripts/validate_repo.sh"

for pubspec in "$repo_root"/apps/*/pubspec.yaml; do
  app_dir=$(dirname "$pubspec")
  echo "==> Checking ${app_dir#"$repo_root"/}"
  (
    cd "$app_dir"
    flutter pub get
    flutter analyze
    flutter test
  )
done
