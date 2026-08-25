#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

"$repo_root/scripts/validate_repo.sh"

for cmd in dart melos; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd (dart pub global activate melos)" >&2
    exit 1
  fi
done

cd "$repo_root"

# workspace全体(apps/* と packages/*)の依存解決・analyze・testをmelos経由で行う。
# 個別に見たい場合は `melos run analyze --scope=<package>` のように絞り込める。
melos bootstrap
melos run analyze
melos run test
