#!/bin/sh
# Zip each QA plugin folder (plugin.json at the zip root) into $1 (default below).
set -eu
out="${1:-/tmp/kanaru-translation-ai/fixtures}"
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$out"
for n in ai_translate_sample ai_translate_custom_model translate_plain; do
  rm -f "$out/$n.zip"
  (cd "$here/$n" && zip -qrD "$out/$n.zip" plugin.json src)
done
echo "zips in $out"
