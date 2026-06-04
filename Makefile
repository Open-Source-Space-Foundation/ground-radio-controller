SHELL := /bin/bash
.SHELLFLAGS = -euo pipefail -c

include testconfig

BOARD_ONE_CONTROL_PORT := /dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_$(BOARD_ONE)-if00
BOARD_ONE_DATA_PORT := /dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_$(BOARD_ONE)-if02
BOARD_TWO_DATA_PORT := /dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_$(BOARD_TWO)-if02

PYTEST_ONE_BOARD_CFG_ARGS := \
	--probe-usb-id="$(PROBE_USB_ID)" \
	--probe-one="$(PROBE_ONE)" \
	--data-port-one="$(BOARD_ONE_DATA_PORT)"

PYTEST_TWO_BOARD_CFG_ARGS := \
	$(PYTEST_ONE_BOARD_CFG_ARGS) \
	--probe-two="$(PROBE_TWO)" \
	--data-port-two="$(BOARD_TWO_DATA_PORT)"

GDS_ARGS := \
	--uart-device "$(BOARD_ONE_CONTROL_PORT)" \
	--uart-skip-port-check \
	--output-unframed-data unframed-data.log \
	--gui none

flash1:
	probe-rs download --probe "$(PROBE_USB_ID):$(PROBE_ONE)" ./build-artifacts/zephyr.elf
	probe-rs reset --probe "$(PROBE_USB_ID):$(PROBE_ONE)"

flash2:
	probe-rs download --probe "$(PROBE_USB_ID):$(PROBE_ONE)" ./build-artifacts/zephyr.elf & \
	probe-rs download --probe "$(PROBE_USB_ID):$(PROBE_TWO)" ./build-artifacts/zephyr.elf & \
	wait; \
	probe-rs reset --probe "$(PROBE_USB_ID):$(PROBE_ONE)"; \
	probe-rs reset --probe "$(PROBE_USB_ID):$(PROBE_TWO)"

check-no-gds:
	@if pgrep -f '[f]prime-gds|[f]prime_gds' 2>/dev/null 1>&2; then \
		echo 'There are running GDS processes which will interfere with tests.' \
			'Please kill with `pkill -f "[f]prime-gds|[f]prime_gds"`' 1>&2; \
		exit 1; \
	fi

bft1 bft1-main bft1-fs: PYTEST_CFG_ARGS := $(PYTEST_ONE_BOARD_CFG_ARGS)
bft1: PYTEST_TESTS := test/one-board
bft1-main: PYTEST_TESTS := test/one-board/main_test.py
bft1-fs: PYTEST_TESTS := test/one-board/fs_test.py
bft2: PYTEST_CFG_ARGS := $(PYTEST_TWO_BOARD_CFG_ARGS)
bft2: PYTEST_TESTS := test/two-board/two_board_test.py

bft1 bft1-main bft1-fs: check-no-gds flash1
bft2: check-no-gds flash2

bft1 bft1-main bft1-fs bft2:
	# Serial port symlinks seem to appear and disappear briefly after device is first
	# flashed. Can't find a good event to block on to be sure they're stable.
	# `udevadm settle` and `udevadm wait` don't seem to work as advertised. Just
	# `sleep 1` and forget about it.

	setsid fprime-gds $(GDS_ARGS) 2>&1 & \
	GDS_PID=$$!; \
	trap 'kill -SIGTERM -$$GDS_PID 2>/dev/null || true' EXIT; \
	sleep 1; \
	pytest $(PYTEST_CFG_ARGS) $(PT_ARGS) $(PYTEST_TESTS)

.PHONY: flash1 flash2 bft1 bft1-main bft1-fs bft2 check-no-gds
