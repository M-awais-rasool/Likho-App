#!/usr/bin/env bash
# Builds the Likho app for the web into admin/public/preview: the admin
# panel's phone preview runs the real app (app/lib/preview/preview_main.dart)
# with the level being edited. Run it once, and again after app changes.
#
#   admin/scripts/build-preview.sh
set -euo pipefail
admin="$(cd "$(dirname "$0")/.." && pwd)"
app="$admin/../app"
out="$admin/public/preview"

command -v flutter >/dev/null || export PATH="$HOME/development/flutter/bin:$PATH"

cd "$app"
flutter build web -t lib/preview/preview_main.dart --release \
  --base-href /admin/preview/ --no-web-resources-cdn --no-wasm-dry-run --no-source-maps

rm -rf "$out"
cp -R build/web "$out"

# (the pictures and recordings come from the API's media folder: /v1/media)

echo "Phone preview built: $out"
