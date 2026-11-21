#!/usr/bin/env bash
# Reflash a running RP2350 GRC with no button presses.
#
#   scripts/remote-flash.sh --serial E9114582E1094947 --uf2 build-artifacts/zephyr.uf2
#
# 1. Sends CdhCore.fatalHandler.ARM_BOOTLOADER then ENTER_BOOTLOADER through the
#    GDS that holds the stick's control port (its REST API, --gds).
# 2. Waits for the stick to show up in BOOTSEL with the same serial number.
# 3. Flashes the UF2 with picotool, verifies it, and boots it.
# 4. Waits for the control port to come back.
#
# --enter-only stops after step 2 and leaves the stick in BOOTSEL.
# `picotool reboot --ser <serial>` boots the old image again from there.
# Needs curl and picotool on the host that the stick is plugged into.
set -euo pipefail

GDS_URL="http://127.0.0.1:5000"
SERIAL=""
UF2=""
ENTER_ONLY=0
TIMEOUT_S=30
BOOTLOADER_KEY="0xB007B007"
GDS_KEY="0xfeedcafe"

usage() {
    sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
    echo
    echo "Options: --serial SN (required)  --uf2 FILE  --gds URL (default $GDS_URL)"
    echo "         --enter-only  --timeout SECONDS (default $TIMEOUT_S)"
    exit "${1:-0}"
}

while [ $# -gt 0 ]; do
    case "$1" in
    --serial) SERIAL="$2"; shift 2 ;;
    --uf2) UF2="$2"; shift 2 ;;
    --gds) GDS_URL="$2"; shift 2 ;;
    --enter-only) ENTER_ONLY=1; shift ;;
    --timeout) TIMEOUT_S="$2"; shift 2 ;;
    -h | --help) usage 0 ;;
    *) echo "unknown option: $1" >&2; usage 2 ;;
    esac
done

[ -n "$SERIAL" ] || { echo "--serial is required" >&2; usage 2; }
if [ "$ENTER_ONLY" -eq 0 ]; then
    [ -f "$UF2" ] || { echo "--uf2 must name an existing file" >&2; usage 2; }
fi
for tool in curl picotool; do
    command -v "$tool" >/dev/null || { echo "$tool not found on PATH" >&2; exit 1; }
done

send() {
    curl --fail-with-body -sS -X PUT \
        -H 'Content-Type: application/json' \
        -d "{\"key\": \"$GDS_KEY\", \"arguments\": [\"$BOOTLOADER_KEY\"]}" \
        "$GDS_URL/commands/CdhCore.fatalHandler.$1"
}

in_bootsel() {
    picotool info --ser "$SERIAL" >/dev/null 2>&1
}

wait_for() {
    local what="$1"
    shift
    local deadline=$((SECONDS + TIMEOUT_S))
    until "$@"; do
        if [ "$SECONDS" -ge "$deadline" ]; then
            echo "timed out after ${TIMEOUT_S}s waiting for $what" >&2
            return 1
        fi
        sleep 1
    done
}

if in_bootsel; then
    echo "$SERIAL is already in BOOTSEL"
else
    echo "arming bootloader entry on $SERIAL via $GDS_URL"
    send ARM_BOOTLOADER
    send ENTER_BOOTLOADER
    wait_for "$SERIAL in BOOTSEL" in_bootsel
    echo "$SERIAL is in BOOTSEL"
fi

if [ "$ENTER_ONLY" -eq 1 ]; then
    echo "left in BOOTSEL; boot the old image with: picotool reboot --ser $SERIAL"
    exit 0
fi

picotool load -v -x --ser "$SERIAL" "$UF2"

control_port_back() {
    # macOS has no /dev/serial/by-id; there the USB serial is part of the cu.* name.
    compgen -G "/dev/serial/by-id/*$SERIAL-if00" >/dev/null ||
        compgen -G "/dev/cu.usbmodem*$SERIAL*" >/dev/null
}
wait_for "the control port to return" control_port_back
echo "$SERIAL is running the new image"
