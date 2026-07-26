#!/bin/sh
set -eu

usage() {
  echo "Usage: $0 <snake_case_name> <bundle_id>"
  echo "Example: $0 takken_mock_exam jp.pairof.takken.mockexam"
}

if [ "$#" -ne 2 ]; then
  usage
  exit 2
fi

app_name=$1
bundle_id=$2
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app_dir="$repo_root/apps/$app_name"

case "$app_name" in
  *[!a-z0-9_]* | "" | [0-9]*)
    echo "App name must be lower_snake_case and must not start with a number: $app_name" >&2
    exit 2
    ;;
esac

case "$bundle_id" in
  jp.pairof.* | com.gikyokutosyokan.*) ;;
  *)
    echo "Bundle ID must start with jp.pairof. or com.gikyokutosyokan.: $bundle_id" >&2
    exit 2
    ;;
esac

if [ -e "$app_dir" ]; then
  echo "App directory already exists: $app_dir" >&2
  exit 1
fi

if "$repo_root/scripts/validate_repo.sh" --contains-bundle-id "$bundle_id"; then
  echo "Bundle ID is already used: $bundle_id" >&2
  exit 1
fi

org=$(echo "$bundle_id" | awk -F. '{ print $1 "." $2 }')

flutter create \
  --org "$org" \
  --project-name "$app_name" \
  --platforms ios,android,macos,web \
  "$app_dir"

echo "Created apps/$app_name"
echo "Requested Bundle ID: $bundle_id"
echo "Flutter derives platform identifiers from the project name. Before release, replace them with the requested Bundle ID and run scripts/validate_repo.sh."
echo "Next: set the final display name, icons, privacy files, signing, and store metadata."
