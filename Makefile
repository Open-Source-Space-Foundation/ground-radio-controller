.ONESHELL:
SHELL := /bin/bash
.SHELLFLAGS = -euo pipefail -c

include testconfig

BOARD_ONE_CONTROL_PORT := /dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_$(BOARD_ONE)-if00
BOARD_ONE_DATA_PORT := /dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_$(BOARD_ONE)-if02
BOARD_TWO_DATA_PORT := /dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_$(BOARD_TWO)-if02

PYTEST_CFG_ARGS := \
	--probe-usb-id="$(PROBE_USB_ID)" \
	--probe-one="$(PROBE_ONE)" \
	--data-port-one="$(BOARD_ONE_DATA_PORT)" \
	--probe-two="$(PROBE_TWO)" \
	--data-port-two="$(BOARD_TWO_DATA_PORT)"

GDS_ARGS := \
	--uart-device "$(BOARD_ONE_CONTROL_PORT)" \
	--uart-skip-port-check \
	--output-unframed-data unframed-data.log \
	--gui none

check-no-gds:
	@if pgrep -f '[f]prime-gds|[f]prime_gds' 2>/dev/null 1>&2; then
		echo 'There are running GDS processes which will interfere with tests.' \
			'Please kill with `pkill -f "[f]prime-gds|[f]prime_gds"`' 1>&2
		exit 1
	fi

bft: check-no-gds
	setsid fprime-gds $(GDS_ARGS) 2>&1 &
	GDS_PID=$$!
	trap 'kill -SIGTERM -$$GDS_PID 2>/dev/null || true' EXIT
	pytest $(PYTEST_CFG_ARGS) $(PT_ARGS)

.PHONY: bft check-no-gds
