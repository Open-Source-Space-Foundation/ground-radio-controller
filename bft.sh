#!/usr/bin/env bash

## `bft` means "build flash test"

set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: $0 {1|2} [all|main|fs]" >&2
    exit 1
fi

NUM_BOARDS="$1"
SUITE="${2:-all}"

case "$NUM_BOARDS" in
    1|2)
        ;;
    *)
        echo "Usage: $0 {1|2} [all|main|fs]" >&2
        exit 1
        ;;
esac

if [ "$NUM_BOARDS" -eq 2 ] && [ $# -eq 2 ]; then
    echo "Usage: $0 2" >&2
    exit 1
fi

if [ "$NUM_BOARDS" -eq 1 ]; then
    case "$SUITE" in
        all|main|fs)
            ;;
        *)
            echo "Usage: $0 1 [all|main|fs]" >&2
            exit 1
            ;;
    esac
fi

source ./testconfig
BOARD_ONE_CONTROL_PORT="/dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_$BOARD_ONE-if00"
BOARD_ONE_DATA_PORT="/dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_$BOARD_ONE-if02"
PROBE_USB_ID="${PROBE_USB_ID:-}"
PROBE_ONE="${PROBE_ONE:-}"
PROBE_TWO="${PROBE_TWO:-}"

if [ "$NUM_BOARDS" -eq 2 ]; then
    BOARD_TWO_DATA_PORT="/dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_$BOARD_TWO-if02"
fi

if [ -z "$PROBE_USB_ID" ] || [ -z "$PROBE_ONE" ] || { [ "$NUM_BOARDS" -eq 2 ] && [ -z "$PROBE_TWO" ]; }; then
    echo "bft.sh requires PROBE_USB_ID, PROBE_ONE, and PROBE_TWO for two-board tests" >&2
    exit 1
fi

if ! command -v probe-rs >/dev/null 2>&1; then
    echo "probe-rs is required to run bft.sh." >&2
    echo "Install it with: cargo install probe-rs-tools --locked" >&2
    exit 1
fi

echo "Resetting board hardware via probe-rs before each test"

# Build everything so zephyr.elf is up to date
fprime-util build

function flash_with_probe() {
    local board_id="$1"
    local debug_probe_serial="$2"

    echo "Flashing $board_id via debug probe $debug_probe_serial"
    probe-rs download --probe "$PROBE_USB_ID:$debug_probe_serial" ./build-artifacts/zephyr.elf
    probe-rs reset --probe "$PROBE_USB_ID:$debug_probe_serial"
}

function flash_both_with_probe() {
    echo "Flashing both boards..."
    probe-rs download --probe "$PROBE_USB_ID:$PROBE_ONE" ./build-artifacts/zephyr.elf &
    probe-rs download --probe "$PROBE_USB_ID:$PROBE_TWO" ./build-artifacts/zephyr.elf &

    wait

    probe-rs reset --probe "$PROBE_USB_ID:$PROBE_ONE"
    probe-rs reset --probe "$PROBE_USB_ID:$PROBE_TWO"
}

function reap_old_gds() {
    pkill -f 'fprime-gds|fprime_gds' || true
    rm -f /tmp/fprime-server-in /tmp/fprime-server-out

    prev_trap=$(trap -p EXIT)
    trap "echo 'Timed out waiting for no readers on $BOARD_ONE_CONTROL_PORT' 1>&2" EXIT
    timeout 5 bash -c "until ! lsof $BOARD_ONE_CONTROL_PORT >/dev/null 2>&1; do sleep 0.1; done"
    trap "$prev_trap" EXIT
}

function print_gds_startup_log() {
    local LOG_PATH="$1"

    if [ -s "$LOG_PATH" ]; then
        echo "GDS startup output:" >&2
        cat "$LOG_PATH" >&2
    fi
}

function wait_for_control_port() {
    trap "echo 'Timed out waiting for board one USB control port after flash' 1>&2" EXIT
    timeout 5 bash -c 'until [ -e "$1" ]; do sleep 0.1; done' bash "$BOARD_ONE_CONTROL_PORT"
    trap - EXIT

    # Serial port symlinks seem to appear and disappear briefly after device is first
    # flashed. Can't find a good event to block on to be sure they're stable.
    # `udevadm settle` and `udevadm wait` don't seem to work as advertised. Just
    # `sleep 1` and forget about it.
    sleep 1
}

if [ "$NUM_BOARDS" = 2 ]; then
    flash_both_with_probe
else
    flash_with_probe "$BOARD_ONE" "$PROBE_ONE"
fi

wait_for_control_port

reap_old_gds

GDS_LOG=$(mktemp)

fprime-gds \
    --uart-device "$BOARD_ONE_CONTROL_PORT" \
    --uart-skip-port-check \
    --output-unframed-data unframed-data.log \
    --gui none \
    >"$GDS_LOG" 2>&1 &

# Kill children on exit to clean up GDS
# Also zero out SIGTERM handler to avoid "Terminated" message after trap handler sends bash SIGTERM
# Source - https://stackoverflow.com/a/2173421
trap "echo 'Timed out launching GDS' 1>&2; print_gds_startup_log \"$GDS_LOG\"; rm -f \"$GDS_LOG\"; trap '' SIGTERM; kill -- -$$" SIGINT SIGTERM EXIT

timeout 5 bash -c 'until [ -e /tmp/fprime-server-out ]; do sleep 0.1; done'

trap "rm -f \"$GDS_LOG\"; trap '' SIGTERM; kill -- -$$ 2>/dev/null;" SIGINT SIGTERM EXIT


# Run appropriate test based on board configuration
if [ "$NUM_BOARDS" -eq 1 ]; then
    case "$SUITE" in
        main)
            pytest \
                --probe-usb-id="$PROBE_USB_ID" \
                --probe-one="$PROBE_ONE" \
                --data-port-one="$BOARD_ONE_DATA_PORT" \
                test/one-board/main_test.py
            ;;
        fs)
            pytest \
                --probe-usb-id="$PROBE_USB_ID" \
                --probe-one="$PROBE_ONE" \
                --data-port-one="$BOARD_ONE_DATA_PORT" \
                test/one-board/fs_test.py
            ;;
        all)
            pytest \
                --probe-usb-id="$PROBE_USB_ID" \
                --probe-one="$PROBE_ONE" \
                --data-port-one="$BOARD_ONE_DATA_PORT" \
                test/one-board
            ;;
    esac
else
    pytest \
        --probe-usb-id="$PROBE_USB_ID" \
        --probe-one="$PROBE_ONE" \
        --probe-two="$PROBE_TWO" \
        --data-port-one="$BOARD_ONE_DATA_PORT" \
        --data-port-two="$BOARD_TWO_DATA_PORT" \
        test/two-board/two_board_test.py
fi
