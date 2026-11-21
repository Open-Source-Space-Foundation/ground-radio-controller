#!/usr/bin/env bash
# Reflash a running RP2350 GRC with no button presses, on Linux or macOS.
#
#   scripts/remote-flash.sh --serial 291E95CA969699F2 --gds http://127.0.0.1:5051 \
#       --uf2 build-artifacts/zephyr.uf2
#
# 1. Refuses if anything holds the stick's data port open (a pass may be on).
# 2. Sends CdhCore.fatalHandler.ARM_BOOTLOADER then ENTER_BOOTLOADER through the
#    GDS on the stick's control port (--gds, its web address). The key is the
#    serial's last 8 hex digits, so a GDS on another stick rejects both.
# 3. Waits for the stick to show up in BOOTSEL with the same serial number.
# 4. Flashes the UF2 with picotool, verifies it, boots it, and waits for the
#    control port to come back.
#
# --enter-only stops after step 3; `picotool reboot --ser <serial>` boots the
# old image again from there. --force skips the data port and image checks.
# Needs curl, picotool and python3.
set -euo pipefail

export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH

GDS_URL=""
SERIAL=""
UF2=""
ENTER_ONLY=0
FORCE=0
TIMEOUT_S=30
GDS_KEY="0xfeedcafe"
# Text of the EnteringBootloader event; an image without it cannot be reflashed remotely.
ENTRY_MARKER="Rebooting into the ROM USB bootloader"

usage() {
    sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
    echo
    echo "Options: --serial SN --gds URL (both required)  --uf2 FILE"
    echo "         --enter-only  --force  --timeout SECONDS (default $TIMEOUT_S)"
    exit "${1:-0}"
}

while [ $# -gt 0 ]; do
    case "$1" in
    --serial) SERIAL="${2:?--serial needs a value}"; shift 2 ;;
    --uf2) UF2="${2:?--uf2 needs a value}"; shift 2 ;;
    --gds) GDS_URL="${2:?--gds needs a value}"; shift 2 ;;
    --timeout) TIMEOUT_S="${2:?--timeout needs a value}"; shift 2 ;;
    --enter-only) ENTER_ONLY=1; shift ;;
    --force) FORCE=1; shift ;;
    -h | --help) usage 0 ;;
    *) echo "unknown option: $1" >&2; usage 2 ;;
    esac
done

die() { echo "$*" >&2; exit 1; }

[[ $SERIAL =~ ^[0-9A-F]{16}$ ]] || die "--serial must be the stick's 16 hex digit USB serial"
[ -n "$GDS_URL" ] || die "--gds is required (the GDS on this stick's control port)"
[[ $TIMEOUT_S =~ ^[0-9]+$ ]] || die "--timeout must be whole seconds"
if [ "$ENTER_ONLY" -eq 0 ]; then
    [ -f "$UF2" ] || die "--uf2 must name an existing file"
fi
for tool in curl picotool python3; do
    command -v "$tool" >/dev/null || die "$tool not found on PATH"
done
KEY="0x${SERIAL: -8}"

# Serial ports of the USB device with this serial number, control port first.
# macOS names cu.* ports by USB location, so look them up in ioreg there.
ports_of() {
    if [ "$(uname)" = Darwin ]; then
        ioreg -r -c IOUSBHostDevice -l -w0 | awk -v s="\"$SERIAL\"" '
            /<class IOUSBHostDevice/ { cur = 0 }
            /"USB Serial Number"/ { cur = index($0, s) > 0 }
            cur && /"IOCalloutDevice"/ { gsub(/.*= "|"/, ""); print }' | sort -u
    else
        compgen -G "/dev/serial/by-id/*_$SERIAL-if0[02]" | sort || true
    fi
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

send() {
    curl --fail -sS -X PUT \
        -H 'Content-Type: application/json' \
        -d "{\"key\": \"$GDS_KEY\", \"arguments\": [\"$KEY\"]}" \
        "$GDS_URL/commands/CdhCore.fatalHandler.$1" >/dev/null
}

if [ "$(uname)" != Darwin ] && [ "$(id -u)" -ne 0 ] &&
    ! grep -qrs 2e8a /etc/udev/rules.d /lib/udev/rules.d /usr/lib/udev/rules.d; then
    die "no udev rule for Raspberry Pi USB (2e8a): picotool could not reach the stick in BOOTSEL"
fi

if [ "$ENTER_ONLY" -eq 0 ] && [ "$FORCE" -eq 0 ]; then
    python3 - "$UF2" "$ENTRY_MARKER" <<'EOF' ||
import struct, sys
data = open(sys.argv[1], "rb").read()
payload = b"".join(
    data[i + 32 : i + 32 + struct.unpack_from("<I", data, i + 16)[0]]
    for i in range(0, len(data) - 511, 512)
    if data[i : i + 8] == b"UF2\n\x57\x51\x5d\x9e"
)
sys.exit(sys.argv[2].encode() not in payload)
EOF
        die "$UF2 lacks the remote bootloader entry; flashing it would need hands on the stick next time (--force to flash anyway)"
fi

if in_bootsel; then
    echo "$SERIAL is already in BOOTSEL"
else
    ports=$(ports_of)
    [ "$(wc -l <<<"$ports")" -eq 2 ] || die "$SERIAL is neither running (control and data port) nor in BOOTSEL"
    data_port=$(tail -1 <<<"$ports")
    data_dev=$(realpath "$data_port" 2>/dev/null || echo "$data_port")
    if [ "$FORCE" -eq 0 ] && holders=$(lsof -t "$data_dev" 2>/dev/null); then
        die "data port $data_port is open (pid $holders); a pass may be running (--force to go ahead)"
    fi
    echo "entering BOOTSEL on $SERIAL via $GDS_URL"
    send ARM_BOOTLOADER
    send ENTER_BOOTLOADER
    if ! wait_for "$SERIAL in BOOTSEL" in_bootsel; then
        picotool info --ser "$SERIAL" || true
        die "$SERIAL never reached BOOTSEL; check the GDS events for BootloaderKeyRejected or BootloaderNotArmed"
    fi
    echo "$SERIAL is in BOOTSEL"
fi

if [ "$ENTER_ONLY" -eq 1 ]; then
    echo "left in BOOTSEL; boot the old image with: picotool reboot --ser $SERIAL"
    exit 0
fi

picotool load -v -x --ser "$SERIAL" "$UF2"

control_port_back() {
    [ -n "$(ports_of)" ]
}
wait_for "the control port to return" control_port_back
echo "$SERIAL control port is back at $(ports_of | head -1)"
