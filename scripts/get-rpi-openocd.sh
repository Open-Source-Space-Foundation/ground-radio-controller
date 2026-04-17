#!/usr/bin/env bash
set -euo pipefail

dest="${1:?usage: $0 <dest-dir>}"
mkdir -p "$dest"
cd "$dest"

# Optional: skip if already extracted (no stamp files)
if [ -x "./openocd" ]; then
  echo "rpi-openocd already present in: $dest"
  exit 0
fi

repo="raspberrypi/pico-sdk-tools"
pattern='^openocd-.*-x86_64-lin\.tar\.gz$'

json="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest")"
url="$(jq -r --arg re "$pattern" '.assets[] | select(.name|test($re)) | .browser_download_url' <<<"$json" | head -n1)"

wget -q -O "openocd.tar.gz" "$url"
tar xzf "openocd.tar.gz"
rm "openocd.tar.gz"
