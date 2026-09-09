// DESCRIPTION: Verilator: Invalid element indices into dynamic DPI open arrays
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

#include "Vt_dpi_open_dynamic_oob_bad__Dpi.h"
#include "svdpi.h"

#include <cassert>

void dpi_dynamic_oob(const svOpenArrayHandle values, const svOpenArrayHandle empty_values) {
    assert(svGetArrElemPtr2(values, 1, 0) == nullptr);
    assert(svGetArrElemPtr2(values, 2, 1) == nullptr);
    assert(svGetArrElemPtr2(values, 3, -1) == nullptr);
    assert(svGetArrElemPtr2(values, 4, 3) == nullptr);
    assert(svGetArrElemPtr1(empty_values, 0) == nullptr);
    assert(svGetArrElemPtr1(empty_values, -1) == nullptr);
}
