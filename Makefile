# Ground Radio Controller — Makefile (layout inspired by proves-core-reference)
# https://github.com/Open-Source-Space-Foundation/proves-core-reference/blob/main/Makefile

export VIRTUAL_ENV ?= $(abspath fprime-venv)

UV ?= uv
UVX ?= uvx
UV_RUN ?= $(UV) run --active

# uv runs west with the active virtual environment (see proves makelib/zephyr.mk)
WEST ?= $(UV_RUN) west
WESTX ?= $(UVX) west

ZEPHYR_PATH ?= lib/zephyr-workspace/zephyr
ifeq ($(origin SDK_VERSION), undefined)
SDK_VERSION := $(strip $(shell test -f "$(ZEPHYR_PATH)/SDK_VERSION" && cat "$(ZEPHYR_PATH)/SDK_VERSION"))
endif
ZEPHYR_SDK_PATH ?= $(HOME)/zephyr-sdk-$(SDK_VERSION)

CMAKE_PACKAGES ?= $(HOME)/.cmake/packages

BUILD_DIR ?= $(abspath build-fprime-automatic-zephyr)
DEPLOY_DIR ?= $(abspath build-artifacts/zephyr/fprime-zephyr-deployment)

.PHONY: all
all: submodules fprime-venv zephyr generate-if-needed build ## Submodules, venv, Zephyr env, generate if needed, build

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Dependencies

.PHONY: uv
uv: ## Require uv on PATH (install: https://docs.astral.sh/uv/)
	@command -v $(UV) >/dev/null 2>&1 || { echo "error: uv not found"; exit 1; }

.PHONY: submodules
submodules: ## Initialize and update git submodules
	git submodule update --init --recursive
	@if [ -f patches/fprime-gds-version.patch ]; then \
		echo "Applying fprime-gds version patch..."; \
		cd lib/fprime && \
		if git apply --check ../../patches/fprime-gds-version.patch 2>/dev/null; then \
			git apply ../../patches/fprime-gds-version.patch && echo "✓ Applied fprime-gds version patch"; \
		elif git apply --reverse --check ../../patches/fprime-gds-version.patch 2>/dev/null; then \
			echo "⚠ Patch already applied"; \
		else \
			echo "❌ Unable to apply patches/fprime-gds-version.patch"; exit 1; \
		fi; \
	fi
	@if [ -f patches/zephyr-uart-tx-fix.patch ]; then \
		echo "Applying zephyr-uart-tx-fix patch..."; \
		cd lib/fprime-zephyr && \
		if git apply --check ../../patches/zephyr-uart-tx-fix.patch 2>/dev/null; then \
			git apply ../../patches/zephyr-uart-tx-fix.patch && echo "✓ Applied zephyr-uart-tx-fix patch"; \
		elif git apply --reverse --check ../../patches/zephyr-uart-tx-fix.patch 2>/dev/null; then \
			echo "⚠ Patch already applied"; \
		else \
			echo "❌ Unable to apply patches/zephyr-uart-tx-fix.patch"; exit 1; \
		fi; \
	fi

.PHONY: fprime-venv
fprime-venv: uv ## Create the Python virtual environment and install requirements
	@$(UV) venv $(VIRTUAL_ENV) --allow-existing
	@$(UV) pip install --python $(VIRTUAL_ENV)/bin/python --prerelease=allow -r requirements.txt

##@ Zephyr

.PHONY: zephyr
zephyr: zephyr-config zephyr-workspace zephyr-export zephyr-python-deps zephyr-sdk ## Full Zephyr workspace + SDK setup

.PHONY: clean-zephyr
clean-zephyr: clean-zephyr-workspace clean-zephyr-export clean-zephyr-sdk ## Remove west modules, SDK, and CMake exports

.PHONY: zephyr-config
zephyr-config: fprime-venv ## Configure west (local manifest)
	@test -f .west/config || { $(WEST) init --local .; }

.PHONY: zephyr-workspace
zephyr-workspace: fprime-venv ## Fetch Zephyr modules via west update
	@$(WESTX) update

.PHONY: clean-zephyr-workspace
clean-zephyr-workspace: ## Remove nested submodule checkouts (destructive)
	git submodule deinit --all -f

.PHONY: zephyr-export
zephyr-export: fprime-venv ## Export Zephyr CMake package metadata
	@test -d $(CMAKE_PACKAGES)/Zephyr/ || \
	test -d $(CMAKE_PACKAGES)/ZephyrUnittest/ || \
	{ $(WESTX) zephyr-export; }

.PHONY: clean-zephyr-export
clean-zephyr-export: ## Remove Zephyr CMake export markers from ~/.cmake/packages
	rm -rf $(CMAKE_PACKAGES)/Zephyr $(CMAKE_PACKAGES)/ZephyrUnittest/

.PHONY: zephyr-sdk
zephyr-sdk: fprime-venv ## Install Zephyr SDK (arm-zephyr-eabi) if missing
	@test -d $(ZEPHYR_SDK_PATH) || { $(WEST) sdk install --toolchains arm-zephyr-eabi; }

.PHONY: clean-zephyr-sdk
clean-zephyr-sdk: ## Remove Zephyr SDK install directory (see ZEPHYR_SDK_PATH)
	rm -rf $(ZEPHYR_SDK_PATH)

.PHONY: zephyr-python-deps
zephyr-python-deps: fprime-venv ## Install Zephyr/module pip requirements via west (venv pip, not west uv)
	@$(VIRTUAL_ENV)/bin/west packages pip --install -- --pre --quiet

##@ Build

.PHONY: generate
generate: submodules fprime-venv zephyr ## Regenerate the F Prime / Zephyr build (CMake)
	@$(UV_RUN) fprime-util generate --force

.PHONY: generate-if-needed
generate-if-needed: ## Run generate only when the CMake build directory is missing
	@test -d $(BUILD_DIR) || $(MAKE) generate

.PHONY: generate-force
generate-force: submodules fprime-venv zephyr ## Clean regenerate (fixes stale codegen cache)
	@$(UV_RUN) fprime-util generate -f

.PHONY: build
build: submodules zephyr fprime-venv generate-if-needed ## Build firmware (zephyr.uf2 in build-artifacts)
	@$(UV_RUN) fprime-util build

.PHONY: menuconfig zephyr-menuconfig
# Same as README "Zephyr Menuconfig": merges prj.conf + board defconfig; writes $(BUILD_DIR)/zephyr/.config
menuconfig: fprime-venv generate-if-needed ## Zephyr menuconfig (fprime-util build --target menuconfig)
	@$(UV_RUN) fprime-util build --target menuconfig

##@ Tests & GDS

.PHONY: test-hw
test-hw: fprime-venv ## Build, flash, and run on-device tests (usage: make test-hw ARGS="1 main")
	PATH="$(VIRTUAL_ENV)/bin:$$PATH" ./bft.sh $(ARGS)

.PHONY: pytest
pytest: fprime-venv ## Run pytest against test/ (often needs hardware + GDS — see test-hw)
	@$(UV_RUN) pytest $(PYTEST_ARGS)

.PHONY: gds
gds: fprime-venv ## Run F Prime GDS (optional: UART_DEVICE=/dev/ttyXXX)
	@if [ -n "$(UART_DEVICE)" ]; then \
		echo "Using UART_DEVICE=$(UART_DEVICE)"; \
		$(UV_RUN) fprime-gds --uart-device $(UART_DEVICE); \
	else \
		$(UV_RUN) fprime-gds; \
	fi

##@ Maintenance

.PHONY: fmt
fmt: fprime-venv ## Run Ruff linter/formatter
	@$(UV_RUN) ruff check --fix .
	@$(UV_RUN) ruff format .

.PHONY: clean
clean: ## Remove gitignored build artifacts (git clean -dfX)
	git clean -dfX
