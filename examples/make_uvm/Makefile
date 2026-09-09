######################################################################
# DESCRIPTION: Verilator Example: Explicit external UVM source selection
# This file ONLY is placed under the Creative Commons Public Domain.
# SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
# SPDX-License-Identifier: CC0-1.0
######################################################################

.DEFAULT_GOAL := run
.PHONY: run build clean help check-source

ifeq ($(VERILATOR_ROOT),)
  VERILATOR ?= verilator
else
  export VERILATOR_ROOT
  VERILATOR ?= $(VERILATOR_ROOT)/bin/verilator
endif

UVM_SOURCE_ROOT ?=
UVM_DPI ?= 1
BUILD_JOBS ?= 1
MODEL_CFLAGS ?= -O0
RUN_ARGS ?= +UVM_NO_RELNOTES

# Keep build products for the two modes separate. Rebuild when selecting a
# source tree, so switching libraries never reuses the previous package.
OBJ_DIR = obj_dir/dpi$(UVM_DPI)
UVM_SRC = $(abspath $(UVM_SOURCE_ROOT))/src
UVM_FLAGS = $(addprefix +incdir+,$(UVM_SRC)) $(UVM_SRC)/uvm_pkg.sv
ifeq ($(UVM_DPI),1)
  UVM_FLAGS += --vpi -CFLAGS -I$(UVM_SRC)/dpi uvm_dpi.cpp
else
  UVM_FLAGS += +define+UVM_NO_DPI
endif

help:
	@echo "make UVM_SOURCE_ROOT=/path/to/uvm-core UVM_DPI=1"
	@echo "Use UVM_DPI=0 for no-DPI; BUILD_JOBS defaults to 1."
	@echo "The qualified reference is unmodified Accellera UVM 2020.3.1."

check-source:
	@test "$(UVM_DPI)" = 0 -o "$(UVM_DPI)" = 1 || { echo "UVM_DPI must be 0 or 1"; exit 1; }
	@test -n "$(UVM_SOURCE_ROOT)" || { echo "Set UVM_SOURCE_ROOT to an external uvm-core checkout; see make help"; exit 1; }
	@test "$(words $(CURDIR) $(UVM_SOURCE_ROOT))" = 2 || { echo "Build and UVM source paths must not contain spaces"; exit 1; }
	@test "$(BUILD_JOBS)" -gt 0 2>/dev/null || { echo "BUILD_JOBS must be a positive integer"; exit 1; }
	@case "$(BUILD_JOBS)" in ''|*[!0-9]*|0) echo "BUILD_JOBS must be a positive integer"; exit 1;; esac
	@for file in uvm_pkg.sv uvm_macros.svh; do \
		test -f "$(UVM_SRC)/$$file" || { echo "Missing UVM source: $(UVM_SRC)/$$file"; exit 1; }; \
	done
	@if test "$(UVM_DPI)" = 1; then \
		for file in uvm_dpi.h uvm_common.c uvm_regex.cc uvm_svcmd_dpi.c; do \
			test -f "$(UVM_SRC)/dpi/$$file" || { echo "Missing UVM DPI source: $(UVM_SRC)/dpi/$$file"; exit 1; }; \
		done; \
	fi

build: check-source
	mkdir -p $(OBJ_DIR)
	$(VERILATOR) --binary --build-jobs $(BUILD_JOBS) --output-groups 6 \
		--Mdir $(OBJ_DIR) --top-module top --prefix Vtop --assert \
		-Wall -Wno-DECLFILENAME -CFLAGS "$(MODEL_CFLAGS)" $(UVM_FLAGS) top.v

run: build
	$(OBJ_DIR)/Vtop $(RUN_ARGS)

clean:
	rm -rf obj_dir
