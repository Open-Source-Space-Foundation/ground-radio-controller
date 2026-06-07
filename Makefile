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

clean:
	fprime-util purge -f

build-fprime-automatic-zephyr:
	fprime-util generate

generate-force:
	fprime-util generate -f

build: build-fprime-automatic-zephyr
	fprime-util build

flash1: build
	probe-rs download --probe "$(PROBE_USB_ID):$(PROBE_ONE)" ./build-artifacts/zephyr.elf
	probe-rs reset --probe "$(PROBE_USB_ID):$(PROBE_ONE)"

flash2: build
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

gds: check-no-gds
	fprime-gds \
		--uart-device "$(BOARD_ONE_CONTROL_PORT)" \
		--uart-skip-port-check

ONE_BOARD_TEST_TARGETS := bft1 bft1-main bft1-fs test1 test1-main test1-fs
TWO_BOARD_TEST_TARGETS := bft2 test2
BFT_TARGETS := bft1 bft1-main bft1-fs bft2
TEST_TARGETS := test1 test1-main test1-fs test2

$(ONE_BOARD_TEST_TARGETS): PYTEST_CFG_ARGS := $(PYTEST_ONE_BOARD_CFG_ARGS)
$(TWO_BOARD_TEST_TARGETS): PYTEST_CFG_ARGS := $(PYTEST_TWO_BOARD_CFG_ARGS)
bft1 test1: PYTEST_TESTS := test/one-board
bft1-main test1-main: PYTEST_TESTS := test/one-board/main_test.py
bft1-fs test1-fs: PYTEST_TESTS := test/one-board/fs_test.py
bft2 test2: PYTEST_TESTS := test/two-board/two_board_test.py

bft1 bft1-main bft1-fs: check-no-gds flash1
bft2: check-no-gds flash2

$(BFT_TARGETS):
	# Serial port symlinks seem to appear and disappear briefly after device is first
	# flashed. Can't find a good event to block on to be sure they're stable.
	# `udevadm settle` and `udevadm wait` don't seem to work as advertised. Just
	# `sleep 1` and forget about it.

	setsid fprime-gds $(GDS_ARGS) 2>&1 & \
	GDS_PID=$$!; \
	trap 'kill -SIGTERM -$$GDS_PID 2>/dev/null || true' EXIT; \
	sleep 1; \
	pytest $(PYTEST_CFG_ARGS) $(PT_ARGS) $(PYTEST_TESTS)

$(TEST_TARGETS):
	pytest $(PYTEST_CFG_ARGS) $(PT_ARGS) $(PYTEST_TESTS)

gdb1 attach1: ACTIVE_PROBE := $(PROBE_ONE)
gdb2 attach2: ACTIVE_PROBE := $(PROBE_TWO)

gdb1 gdb2:
	probe-rs gdb --gdb gdb-multiarch --probe $(PROBE_USB_ID):$(ACTIVE_PROBE) build-artifacts/zephyr.elf

attach1 attach2:
	probe-rs attach --probe $(PROBE_USB_ID):$(ACTIVE_PROBE) build-artifacts/zephyr.elf


.PHONY: clean generate-force build flash1 flash2 gds gdb1 gdb2 attach1 attach2 $(BFT_TARGETS) $(TEST_TARGETS) check-no-gds
