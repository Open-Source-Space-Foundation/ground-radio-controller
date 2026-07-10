SHELL := /bin/bash
.SHELLFLAGS = -euo pipefail -c

# Parallelize 2-board flash
MAKEFLAGS := --jobs=2

-include testconfig

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

include makelib/zephyr.mk

export VIRTUAL_ENV ?= $(shell pwd)/fprime-venv
IN_VENV ?= VIRTUAL_ENV=$(shell pwd)/fprime-venv PATH=$(shell pwd)/fprime-venv/bin:$$PATH

.PHONY: clean
clean: ## Remove all gitignored files except testconfig
	git clean -dfX -e '!testconfig'

##@ Development

.PHONY: pre-commit-install
pre-commit-install: ## Install pre-commit hooks
	@uvx pre-commit install > /dev/null

.PHONY: fmt
fmt: pre-commit-install ## Lint and format files
	@uvx pre-commit run --all-files

.PHONY: submodules
submodules: ## Initialize and update git submodules
	@git submodule update --init --recursive

.PHONY: fprime-venv
fprime-venv: submodules ## Create a virtual environment
	@uv venv fprime-venv --python 3.10 --allow-existing
	uv pip install --prerelease=allow --requirement requirements.txt

.PHONY: generate
generate: submodules fprime-venv zephyr ## Generate FPrime project
	@$(IN_VENV) fprime-util generate --force

BUILD_DIR ?= $(shell pwd)/build-fprime-automatic-zephyr
BUILD_NINJA ?= $(BUILD_DIR)/build.ninja
$(BUILD_NINJA): | submodules fprime-venv zephyr
	@$(IN_VENV) fprime-util generate --force

.PHONY: build
build: $(BUILD_NINJA) ## Build FPrime project
	@$(IN_VENV) fprime-util build

.PHONY: check-no-gds
check-no-gds:
	@if pgrep -f '[f]prime-gds|[f]prime_gds' 2>/dev/null 1>&2; then \
		echo 'There are running GDS processes which will interfere with tests.' \
			'Please kill with `pkill -f "[f]prime-gds|[f]prime_gds"`' 1>&2; \
		exit 1; \
	fi

.PHONY: gds
gds: check-no-gds fprime-venv
	$(IN_VENV) fprime-gds \
		--uart-device "$(BOARD_ONE_CONTROL_PORT)" \
		--uart-skip-port-check

.PHONY: menuconfig
menuconfig: fprime-venv
	$(IN_VENV) fprime-util build --target menuconfig

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

ONE_BOARD_TEST_TARGETS := bft1 bft1-main test1 test1-main
TWO_BOARD_TEST_TARGETS := bft2 bft2-main bft2-long test2 test2-main test2-long
BFT_TARGETS := bft1 bft1-main bft2 bft2-main bft2-long
TEST_TARGETS := test1 test1-main test2 test2-main test2-long

$(ONE_BOARD_TEST_TARGETS): PYTEST_CFG_ARGS := $(PYTEST_ONE_BOARD_CFG_ARGS)
$(TWO_BOARD_TEST_TARGETS): PYTEST_CFG_ARGS := $(PYTEST_TWO_BOARD_CFG_ARGS)
bft1 test1: PYTEST_TESTS := test/one-board
bft1-main test1-main: PYTEST_TESTS := test/one-board/main_test.py
bft2 test2: PYTEST_TESTS := test/two-board/
bft2-main test2-main: PYTEST_TESTS := test/two-board/main_test.py
bft2-long test2-long: PYTEST_TESTS := test/two-board/long_test.py

bft1 bft1-main: check-no-gds flash1
bft2 bft2-main bft2-long: check-no-gds flash2

.PHONY: $(BFT_TARGETS)
$(BFT_TARGETS): fprime-venv
	# Serial port symlinks seem to appear and disappear briefly after device is first
	# flashed. Can't find a good event to block on to be sure they're stable.
	# `udevadm settle` and `udevadm wait` don't seem to work as advertised. Just
	# `sleep 1` and forget about it.

	setsid env $(IN_VENV) fprime-gds $(GDS_ARGS) 2>&1 & \
	GDS_PID=$$!; \
	trap 'kill -SIGTERM -$$GDS_PID 2>/dev/null || true' EXIT; \
	sleep 1; \
	$(IN_VENV) pytest $(PYTEST_CFG_ARGS) $(PT_ARGS) $(PYTEST_TESTS)

.PHONY: $(TEST_TARGETS)
$(TEST_TARGETS): fprime-venv
	$(IN_VENV) pytest $(PYTEST_CFG_ARGS) $(PT_ARGS) $(PYTEST_TESTS)

gdb1 attach1 flash1: ACTIVE_PROBE := $(PROBE_ONE)
gdb2 attach2 flash2only: ACTIVE_PROBE := $(PROBE_TWO)

.PHONY: flash1 flash2only
flash1 flash2only: build
	probe-rs download --probe "$(PROBE_USB_ID):$(ACTIVE_PROBE)" ./build-artifacts/zephyr.elf
	probe-rs reset --probe "$(PROBE_USB_ID):$(ACTIVE_PROBE)"

.PHONY: flash2
flash2: flash1 flash2only

.PHONY: gdb1 gdb2
gdb1 gdb2:
	probe-rs gdb --gdb gdb --probe $(PROBE_USB_ID):$(ACTIVE_PROBE) build-artifacts/zephyr.elf

.PHONY: attach1 attach2
attach1 attach2:
	probe-rs attach --probe $(PROBE_USB_ID):$(ACTIVE_PROBE) build-artifacts/zephyr.elf
