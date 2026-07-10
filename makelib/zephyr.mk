##@ Zephyr

# WEST runs with the active virtual environment
WEST ?= $(IN_VENV) west

# UVX runs west without the active virtual environment
WESTX ?= uvx west

ZEPHYR_PATH ?= lib/zephyr-workspace/zephyr
WEST_CONFIG ?= .west/config
ZEPHYR_WORKSPACE_DIRS ?= lib/zephyr-workspace/bootloader lib/zephyr-workspace/modules
CMAKE_PACKAGES ?= $(HOME)/.cmake/packages
ZEPHYR_EXPORT_DIRS ?= $(CMAKE_PACKAGES)/Zephyr $(CMAKE_PACKAGES)/ZephyrUnittest
ZEPHYR_SDK_PACKAGE ?= $(CMAKE_PACKAGES)/Zephyr-sdk
ifeq ($(origin SDK_VERSION), undefined)
# Recursive (=) so it is evaluated after west update populates $(ZEPHYR_PATH)
# on a fresh checkout, rather than at parse time.
SDK_VERSION = $(strip $(shell test -f "$(ZEPHYR_PATH)/SDK_VERSION" && cat "$(ZEPHYR_PATH)/SDK_VERSION"))
endif
ZEPHYR_SDK_PATH ?= $(HOME)/zephyr-sdk-$(SDK_VERSION)

.PHONY: zephyr
zephyr: $(ZEPHYR_EXPORT_DIRS) $(ZEPHYR_SDK_PACKAGE) zephyr-python-deps ## Set up Zephyr dependencies

.PHONY: clean-zephyr
clean-zephyr: clean-zephyr-workspace clean-zephyr-export clean-zephyr-sdk

$(WEST_CONFIG): | fprime-venv
	$(WEST) init --local .

$(ZEPHYR_WORKSPACE_DIRS) &: | $(WEST_CONFIG)
	$(WESTX) update

.PHONY: clean-zephyr-workspace
clean-zephyr-workspace: ## Remove Zephyr bootloader and modules directories
	rm -rf lib/zephyr-workspace/bootloader lib/zephyr-workspace/modules

$(CMAKE_PACKAGES):
	mkdir -p "$@"

$(ZEPHYR_EXPORT_DIRS) &: | $(ZEPHYR_WORKSPACE_DIRS) $(CMAKE_PACKAGES)
	$(WESTX) zephyr-export

.PHONY: clean-zephyr-export
clean-zephyr-export: ## Remove Zephyr exported files
	rm -rf $(CMAKE_PACKAGES)/Zephyr $(CMAKE_PACKAGES)/ZephyrUnittest/

$(ZEPHYR_SDK_PACKAGE): | $(ZEPHYR_WORKSPACE_DIRS) fprime-venv $(CMAKE_PACKAGES)
	$(WEST) sdk install --toolchains arm-zephyr-eabi

.PHONY: clean-zephyr-sdk
clean-zephyr-sdk: ## Remove Zephyr SDK
	rm -rf $(ZEPHYR_SDK_PATH) $(ZEPHYR_SDK_PACKAGE)

.PHONY: zephyr-python-deps
zephyr-python-deps: $(ZEPHYR_WORKSPACE_DIRS) fprime-venv ## Install Zephyr Python dependencies
	@$(WEST) uv pip --install -- --prerelease=allow --quiet
