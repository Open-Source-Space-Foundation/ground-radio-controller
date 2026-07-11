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

.PHONY: submodules
submodules: ## Initialize/update git submodules and apply carried lib/fprime patches (issue #432 class)
	@git submodule update --init --recursive
	@echo "Applying fprime ComAggregator bounded-timeout patch (issue #432)..."
	@cd lib/fprime && \
		if git apply --check ../../patches/fprime-com-aggregator-bounded-timeout.patch 2>/dev/null; then \
			git apply ../../patches/fprime-com-aggregator-bounded-timeout.patch && \
			echo "Applied ComAggregator bounded-timeout patch"; \
		elif git apply --reverse --check ../../patches/fprime-com-aggregator-bounded-timeout.patch 2>/dev/null; then \
			echo "Already applied: ComAggregator bounded-timeout patch"; \
		else \
			echo "Error: unable to apply ComAggregator patch. Run 'cd lib/fprime && git status' to check."; \
			exit 1; \
		fi
	@echo "Applying fprime sched-tick drop patch (issue #432 class)..."
	@cd lib/fprime && \
		if git apply --check ../../patches/fprime-sched-tick-drop.patch 2>/dev/null; then \
			git apply ../../patches/fprime-sched-tick-drop.patch && \
			echo "Applied sched-tick drop patch"; \
		elif git apply --reverse --check ../../patches/fprime-sched-tick-drop.patch 2>/dev/null; then \
			echo "Already applied: sched-tick drop patch"; \
		else \
			echo "Error: unable to apply sched-tick drop patch (TlmPacketizer.fpp hunk may need hand-reconciling on a lib/fprime version bump -- see patches/README.md). Run 'cd lib/fprime && git status' to check."; \
			exit 1; \
		fi

USP_ZEPHYR_DIR ?= $(shell pwd)/lib/zephyr-workspace/modules/lib/usp_zephyr

.PHONY: usp-patches
usp-patches: ## Apply usp_zephyr patches (RF-switch GPIO + Zephyr 4.3 compat + wakeup-busy race fix)
	@if [ ! -d "$(USP_ZEPHYR_DIR)" ]; then \
		echo "usp_zephyr not found at $(USP_ZEPHYR_DIR) -- run 'west update usp_zephyr usp' first"; \
		exit 1; \
	fi
	@echo "Applying usp_zephyr patches..."
	@cd "$(USP_ZEPHYR_DIR)" && \
	for p in $(shell pwd)/patches/0001-feat-sx126x-add-external-RF-switch-GPIO-support-tx-r.patch \
	          $(shell pwd)/patches/0002-fix-zephyr-4.3-remove-select-ZEPHYR_LORA_BASICS_MODE.patch \
	          $(shell pwd)/patches/0003-fix-usp-main-2025-fix-LR_FHSS_SRC_PATH-for-flattened.patch \
	          $(shell pwd)/patches/0006-fix-sx126x-wakeup-busy-race-add-t_woff-settle-delay.patch \
	          $(shell pwd)/patches/0008-fix-smtc-modem-hal-implement-rac-api-mutex.patch; do \
		name=$$(basename $$p); \
		if git apply --check "$$p" 2>/dev/null; then \
			git apply "$$p" && echo "Applied $$name"; \
		elif git apply --reverse --check "$$p" 2>/dev/null; then \
			echo "Already applied: $$name"; \
		else \
			echo "Cannot apply $$name -- check usp_zephyr revision"; exit 1; \
		fi; \
	done


# USP_DIR: the Semtech smtc_rac_lib west module (radio planner lives here).
USP_DIR ?= $(shell pwd)/lib/zephyr-workspace/modules/lib/usp

.PHONY: usp-core-patches
usp-core-patches: ## Apply usp (smtc_rac_lib) patches (radio-planner failsafe unlock exemption)
	@cd "$(USP_DIR)" && \
	for p in $(shell pwd)/patches/0009-fix-radio-planner-failsafe-exempt-unlock-radio-access.patch; do \
		name=$$(basename $$p); \
		if git apply --check "$$p" 2>/dev/null; then \
			git apply "$$p" && echo "OK Applied $$name"; \
		elif git apply --reverse --check "$$p" 2>/dev/null; then \
			echo "Already applied: $$name"; \
		else \
			echo "Cannot apply $$name - check usp revision"; exit 1; \
		fi; \
	done

ZEPHYR_DIR ?= $(shell pwd)/lib/zephyr-workspace/zephyr

.PHONY: zephyr-patches
zephyr-patches: ## Apply Zephyr tree patches (CDC-ACM TX fixes; 0004-equivalent poll-mode drain is already baked into this submodule's pinned commit, so only 0005+0007 are carried here)
	@if [ ! -d "$(ZEPHYR_DIR)" ]; then \
		echo "zephyr not found at $(ZEPHYR_DIR) -- run 'west update' first"; \
		exit 1; \
	fi
	@echo "Applying Zephyr patches..."
	@cd "$(ZEPHYR_DIR)" && \
	for p in \
		$(shell pwd)/patches/0005-fix-usbd-cdc-acm-stuck-tx-fifo-busy-on-disable-and-retry.patch \
		$(shell pwd)/patches/0007-fix-usbd-cdc-acm-bound-poll-out-backpressure-wait.patch; do \
		name=$$(basename $$p); \
		if git apply --check "$$p" 2>/dev/null; then \
			git apply "$$p" && echo "Applied $$name"; \
		elif git apply --reverse --check "$$p" 2>/dev/null; then \
			echo "Already applied: $$name"; \
		else \
			echo "Cannot apply $$name -- check Zephyr revision"; exit 1; \
		fi; \
	done

clean:
	fprime-util purge -f

build-fprime-automatic-zephyr:
	fprime-util generate

generate-force:
	fprime-util generate -f

build: build-fprime-automatic-zephyr
	fprime-util build

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

menuconfig:
	fprime-util build --target menuconfig

ONE_BOARD_TEST_TARGETS := bft1 bft1-main bft1-fs test1 test1-main test1-fs
TWO_BOARD_TEST_TARGETS := bft2 bft2-main bft2-long test2 test2-main test2-long
BFT_TARGETS := bft1 bft1-main bft1-fs bft2 bft2-main bft2-long
TEST_TARGETS := test1 test1-main test1-fs test2 test2-main test2-long

$(ONE_BOARD_TEST_TARGETS): PYTEST_CFG_ARGS := $(PYTEST_ONE_BOARD_CFG_ARGS)
$(TWO_BOARD_TEST_TARGETS): PYTEST_CFG_ARGS := $(PYTEST_TWO_BOARD_CFG_ARGS)
bft1 test1: PYTEST_TESTS := test/one-board
bft1-main test1-main: PYTEST_TESTS := test/one-board/main_test.py
bft1-fs test1-fs: PYTEST_TESTS := test/one-board/fs_test.py
bft2 test2: PYTEST_TESTS := test/two-board/
bft2-main test2-main: PYTEST_TESTS := test/two-board/main_test.py
bft2-long test2-long: PYTEST_TESTS := test/two-board/long_test.py

bft1 bft1-main bft1-fs: check-no-gds flash1
bft2 bft2-main bft2-long: check-no-gds flash2

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

gdb1 attach1 flash1: ACTIVE_PROBE := $(PROBE_ONE)
gdb2 attach2 flash2only: ACTIVE_PROBE := $(PROBE_TWO)

flash1 flash2only: build
	probe-rs download --probe "$(PROBE_USB_ID):$(ACTIVE_PROBE)" ./build-artifacts/zephyr.elf
	probe-rs reset --probe "$(PROBE_USB_ID):$(ACTIVE_PROBE)"

flash2: flash1 flash2only

gdb1 gdb2:
	probe-rs gdb --gdb gdb-multiarch --probe $(PROBE_USB_ID):$(ACTIVE_PROBE) build-artifacts/zephyr.elf

attach1 attach2:
	probe-rs attach --probe $(PROBE_USB_ID):$(ACTIVE_PROBE) build-artifacts/zephyr.elf


.PHONY: clean generate-force build flash1 flash2 gds gdb1 gdb2 attach1 attach2 $(BFT_TARGETS) $(TEST_TARGETS) check-no-gds menuconfig
