#!/usr/bin/env bash

set -euo pipefail

set -x

mkdir -p rpi-openocd
cd rpi-openocd

repo="raspberrypi/pico-sdk-tools"
pattern='^openocd-.*-x86_64-lin\.tar\.gz$'

json="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest")"
tag="$(echo "$json" | jq -r '.tag_name')"
url="$(echo "$json" | jq -r --arg re "$pattern" '.assets[] | select(.name|test($re)) | .browser_download_url' | head -n1)"
final_name="$(basename "$url")"

echo "Latest release: $tag"
wget -q -O "openocd.tar.gz" --show-progress "$url"

tar xzf "openocd.tar.gz"

rm "openocd.tar.gz"
