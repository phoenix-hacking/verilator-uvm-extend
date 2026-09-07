// DESCRIPTION: Verilator: Link unchanged UVM DPI sources with the Verilator HDL backend
//
// This program is free software; you can redistribute it and/or modify it
// under the terms of either the GNU Lesser General Public License Version 3
// or the Perl Artistic License Version 2.0.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

// Accellera 2020.3.1 permits compiling its DPI components individually, but
// uvm_dpi.cc selects HDL backends only for VCS, Questa, and Xcelium. The include
// path selects the explicit upstream source tree for every common component.
// Only the simulator-specific HDL backend comes from the Verilator checkout.
#include <cstdlib>

extern "C" {
// Components share declarations and must retain Accellera's inclusion order.
// clang-format off
#include <uvm_dpi.h>
#include <uvm_common.c>
#include <uvm_regex.cc>
#include "uvm/v2020_3_1/dpi/uvm_hdl_verilator.c"
#include <uvm_svcmd_dpi.c>
#include <uvm_hdl_polling.c>
// clang-format on
}
