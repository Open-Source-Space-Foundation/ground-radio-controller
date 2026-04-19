#!/usr/bin/env bash

## `bft` means "build flash test"

set -euo pipefail

if [[ $# -lt 1 ]] || [[ $# -gt 2 ]] || [[ ! "$1" =~ ^[12]$ ]]; then
    echo "Usage: $0 {1|2} [all|main|fs]" >&2
    exit 1
fi

NUM_BOARDS="$1"
SUITE="${2:-all}"

if [[ "$NUM_BOARDS" -eq 2 ]] && [[ $# -eq 2 ]]; then
    echo "Usage: $0 2" >&2
    exit 1
fi

if [[ "$NUM_BOARDS" -eq 1 ]] && [[ ! "$SUITE" =~ ^(all|main|fs)$ ]]; then
    echo "Usage: $0 1 [all|main|fs]" >&2
    exit 1
fi

source ./testconfig
BOARD_ONE_CONTROL_PORT="/dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_$BOARD_ONE-if00"
BOARD_ONE_DATA_PORT="/dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_$BOARD_ONE-if02"
PROBE_ONE="${PROBE_ONE:-}"

if [[ "$NUM_BOARDS" -eq 2 ]]; then
    BOARD_TWO_CONTROL_PORT="/dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_$BOARD_TWO-if00"
    BOARD_TWO_DATA_PORT="/dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_$BOARD_TWO-if02"
    PROBE_TWO="${PROBE_TWO:-}"
fi

# Build everything so zephyr.uf2 is up to date
fprime-util build

function flash() {
    local BOARD_ID="$1"
    local DEBUG_PROBE_SERIAL="$2"

    if [[ -n "$DEBUG_PROBE_SERIAL" ]]; then
        echo "Flashing $BOARD_ID via debug probe $DEBUG_PROBE_SERIAL"
        OPENOCD_ADAPTER_SERIAL="$DEBUG_PROBE_SERIAL" fprime-util build --target program-board
        return
    fi

    echo "Waiting for BOOTSEL on $BOARD_ID"

    DEV="/dev/disk/by-label/RP2350"
    until [ -e "$DEV" ]; do :; done
    until MOUNTPOINT=$(findmnt --json "$DEV" | jq -r '.filesystems.[0].target'); do :; done

    echo "Got a BOOTSEL!"

    cp ./build-artifacts/zephyr.uf2 "$MOUNTPOINT"
}

function reap_old_gds() {
    pkill -f fprime-gds || true
    rm -f /tmp/fprime-server-in /tmp/fprime-server-out

    timeout 5 bash -c "until ! lsof $BOARD_ONE_CONTROL_PORT >/dev/null 2>&1; do sleep 0.1; done"
}

function print_gds_startup_log() {
    local LOG_PATH="$1"

    if [[ -s "$LOG_PATH" ]]; then
        echo "GDS startup output:" >&2
        cat "$LOG_PATH" >&2
    fi
}

flash "$BOARD_ONE" "$PROBE_ONE"
trap "echo 'Timed out waiting for USB serial port after flash $BOARD_ONE' 1>&2" EXIT
timeout 5 bash -c "until [[ -e $BOARD_ONE_CONTROL_PORT && -e $BOARD_ONE_DATA_PORT ]]; do sleep 0.1; done"

if [[ "$NUM_BOARDS" -eq 2 ]]; then
    flash "$BOARD_TWO" "$PROBE_TWO"
    trap "echo 'Timed out waiting for USB serial port after flash $BOARD_TWO' 1>&2" EXIT
    timeout 5 bash -c "until [[ -e $BOARD_TWO_CONTROL_PORT && -e $BOARD_TWO_DATA_PORT ]]; do sleep 0.1; done"
fi

trap - EXIT

reap_old_gds

# Serial port symlinks seem to appear and disappear briefly after device is first
# flashed. Can't find a good event to block on to be sure they're stable.
# `udevadm settle` and `udevadm wait` don't seem to work as advertised. Just
# `sleep 1` and forget about it.

sleep 1

GDS_LOG=$(mktemp)

fprime-gds \
    --uart-device "$BOARD_ONE_CONTROL_PORT" \
    --uart-skip-port-check \
    --gui none \
    >"$GDS_LOG" 2>&1 &

# Kill children on exit to clean up GDS
# Also zero out SIGTERM handler to avoid "Terminated" message after trap handler sends bash SIGTERM
# Source - https://stackoverflow.com/a/2173421
trap "echo 'Timed out launching GDS' 1>&2; print_gds_startup_log \"$GDS_LOG\"; rm -f \"$GDS_LOG\"; trap '' SIGTERM; kill -- -$$" SIGINT SIGTERM EXIT

timeout 5 bash -c 'until [ -e /tmp/fprime-server-out ]; do sleep 0.1; done'

trap "rm -f \"$GDS_LOG\"; trap '' SIGTERM; kill -- -$$ 2>/dev/null;" SIGINT SIGTERM EXIT


# Run appropriate test based on board configuration
if [[ "$NUM_BOARDS" -eq 1 ]]; then
    case "$SUITE" in
        main)
            pytest --data-port-one="$BOARD_ONE_DATA_PORT" test/one-board/main_test.py
            ;;
        fs)
            pytest --data-port-one="$BOARD_ONE_DATA_PORT" test/one-board/fs_test.py
            ;;
        all)
            pytest --data-port-one="$BOARD_ONE_DATA_PORT" test/one-board
            ;;
    esac
else
    pytest --data-port-one="$BOARD_ONE_DATA_PORT" --data-port-two="$BOARD_TWO_DATA_PORT" test/two-board/two_board_test.py
fi
