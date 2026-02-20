#!/usr/bin/env bash

## `bft` means "build flash test"

set -euo pipefail

source testconfig
BOARD_ONE_CONTROL_PORT="/dev/serial/by-id/usb-F_Prime_Pomona_Ground_Station_$BOARD_ONE-if00"
BOARD_TWO_CONTROL_PORT="/dev/serial/by-id/usb-F_Prime_Pomona_Ground_Station_$BOARD_TWO-if00"

fprime-util build

function flash () {
	BOARD_ID="$1"

	# PENDING DEBUG PROBE CONNECTOR ON NEXT FCB REVISION (and changes on `rpi-add-ocd` branch)
	# fprime-util build --target program-board

	## REMOVE BEGINNING HERE
	echo "Waiting for BOOTSEL on $BOARD_ID (remove once we get the debug probe connector on the next FCB revision)"

	DEV="/dev/disk/by-label/RP2350"
	until [ -e "$DEV" ]; do :; done
	until MOUNTPOINT=$(findmnt --json "$DEV" | jq -r '.filesystems.[0].target'); do :; done

	echo "Got it!"

	cp ./build-artifacts/zephyr.uf2 "$MOUNTPOINT"
	## REMOVE ENDING HERE
}

# flash "$BOARD_ONE"
# trap "echo 'Timed out waiting for USB serial port on $BOARD_ONE after flash' 1>&2" EXIT
# timeout 5 sh -c "until [ -e $BOARD_ONE_CONTROL_PORT ]; do :; done"
#
# flash "$BOARD_TWO"
# trap "echo 'Timed out waiting for USB serial port on $BOARD_TWO after flash' 1>&2" EXIT
# timeout 5 sh -c "until [ -e $BOARD_TWO_CONTROL_PORT ]; do :; done"
#
# trap - EXIT

fprime-gds --uart-device $(realpath "$BOARD_ONE_CONTROL_PORT") --gui none &>/dev/null &

# Kill children on exit to clean up GDS
# Also zero out SIGTERM handler to avoid "Terminated" message after trap handler sends bash SIGTERM
# Source - https://stackoverflow.com/a/2173421
TRAP_MSG="Timed out launching GDS\n"
trap "printf \"\$TRAP_MSG\" 1>&2 && trap '' SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

timeout 5 sh -c "until lsof -U 2>/dev/null | grep -q /tmp/fprime-server-out; do :; done"

# Unset TRAP_MSG as timeout has passed, but keep trap killing children on exit.
TRAP_MSG=

pytest --data-port-one="$BOARD_ONE_CONTROL_PORT" --data-port-two="$BOARD_TWO_CONTROL_PORT" test/int/two_board_test.py

