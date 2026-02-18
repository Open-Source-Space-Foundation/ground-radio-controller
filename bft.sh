#!/usr/bin/env bash

## `bft` means "build flash test"

set -euo pipefail

fprime-util build

# PENDING DEBUG PROBE CONNECTOR ON NEXT FCB REVISION (and changes on `rpi-add-ocd` branch)
# fprime-util build --target program-board

## REMOVE BEGINNING HERE
echo "Waiting for BOOTSEL (remove once we get the debug probe connector on the next FCB revision)"

DEV="/dev/disk/by-label/RP2350"
until [ -e "$DEV" ]; do :; done
until MOUNTPOINT=$(findmnt --json "$DEV" | jq -r '.filesystems.[0].target'); do :; done

echo "Got it!"

cp ./build-artifacts/zephyr.uf2 "$MOUNTPOINT"
## REMOVE ENDING HERE

trap "echo 'Timed out waiting for USB serial port after flash' 1>&2" EXIT

timeout 5 sh -c 'until [ -e /dev/serial/by-id/usb-F_Prime_Pomona_Ground_Station-if00 ]; do :; done'

trap - EXIT

fprime-gds --uart-device $(realpath /dev/serial/by-id/usb-F_Prime_Pomona_Ground_Station-if00) --gui none &>/dev/null &

# Kill children on exit to clean up GDS
# Also zero out SIGTERM handler to avoid "Terminated" message after trap handler sends bash SIGTERM
# Source - https://stackoverflow.com/a/2173421
TRAP_MSG="Timed out launching GDS\n"
trap "printf \"\$TRAP_MSG\" 1>&2 && trap '' SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

timeout 5 sh -c "until lsof -U 2>/dev/null | grep -q /tmp/fprime-server-out; do :; done"

# Unset TRAP_MSG as timeout has passed, but keep trap killing children on exit.
TRAP_MSG=

pytest test/int/one_board_test.py

