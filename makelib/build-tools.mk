##@ Build Tools

TOOLS_DIR ?= $(shell pwd)/bin
$(TOOLS_DIR):
	mkdir -p $(TOOLS_DIR)

### Tool Versions
UV_VERSION ?= 0.11.25

### uv & uvx
UV_ARCH ?= $(shell gcc -dumpmachine | cut -d- -f1)
UV_PLATFORM ?= $(UV_ARCH)-unknown-linux-gnu
UV_DIR ?= $(TOOLS_DIR)/uv-$(UV_VERSION)
UV ?= $(UV_DIR)/uv
UVX ?= $(UV_DIR)/uvx

.PHONY: download-bin
download-bin: $(UV) $(UVX)
$(UV) $(UVX) &: | $(TOOLS_DIR)
	mkdir -p "$(UV_DIR)"
	curl -LsSf "https://releases.astral.sh/github/uv/releases/download/$(UV_VERSION)/uv-$(UV_PLATFORM).tar.gz" | tar -xzf - -C "$(UV_DIR)" --strip-components=1 "uv-$(UV_PLATFORM)/uv" "uv-$(UV_PLATFORM)/uvx"

IN_VENV ?= VIRTUAL_ENV=$(shell pwd)/fprime-venv PATH=$(shell pwd)/fprime-venv/bin:$$PATH
