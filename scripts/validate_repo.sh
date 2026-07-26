#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

ios_bundle_ids() {
  for project in $(find "$repo_root/apps" -path '*/ios/Runner.xcodeproj/project.pbxproj' -type f); do
    sed -n 's/.*PRODUCT_BUNDLE_IDENTIFIER = \([^;]*\);/\1/p' "$project" |
      sed 's/[[:space:]]//g' |
      grep -v -e '\$(PRODUCT_BUNDLE_IDENTIFIER)' -e '\.RunnerTests$' |
      sort -u
  done
}

android_application_ids() {
  for gradle in $(find "$repo_root/apps" -path '*/android/app/build.gradle.kts' -type f); do
    sed -n 's/.*applicationId = "\([^"]*\)".*/\1/p' "$gradle" | sort -u
  done
}

if [ "${1:-}" = "--contains-bundle-id" ]; then
  [ "$#" -eq 2 ] || exit 2
  {
    ios_bundle_ids
    android_application_ids
  } | grep -Fxq "$2"
  exit $?
fi

failed=0

duplicate_package_names=$(
  find "$repo_root/apps" -mindepth 2 -maxdepth 2 -name pubspec.yaml -type f -print0 |
    xargs -0 sed -n 's/^name:[[:space:]]*//p' |
    sort |
    uniq -d
)

if [ -n "$duplicate_package_names" ]; then
  echo "Duplicate Dart package names:" >&2
  echo "$duplicate_package_names" >&2
  failed=1
fi

duplicate_bundle_ids=$(
  ios_bundle_ids |
    sort |
    uniq -d
)

if [ -n "$duplicate_bundle_ids" ]; then
  echo "Duplicate iOS Bundle IDs:" >&2
  echo "$duplicate_bundle_ids" >&2
  failed=1
fi

duplicate_android_ids=$(android_application_ids | sort | uniq -d)

if [ -n "$duplicate_android_ids" ]; then
  echo "Duplicate Android application IDs:" >&2
  echo "$duplicate_android_ids" >&2
  failed=1
fi

if [ "$failed" -ne 0 ]; then
  exit 1
fi

app_count=$(find "$repo_root/apps" -mindepth 2 -maxdepth 2 -name pubspec.yaml -type f | wc -l | tr -d ' ')
echo "Repository structure is valid ($app_count app(s))."
