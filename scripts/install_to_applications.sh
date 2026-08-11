#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -d build/Art.app ]]; then
    echo "Run scripts/build_app.sh first." >&2
    exit 1
fi

echo "Installing Art to /Applications…"
rm -rf "/Applications/Art.app"
cp -R build/Art.app "/Applications/Art.app"
open "/Applications/Art.app"
echo "✅ Installed and launched Art."
