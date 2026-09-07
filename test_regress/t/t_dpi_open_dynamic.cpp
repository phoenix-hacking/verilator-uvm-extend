// DESCRIPTION: Verilator: Dynamic and queue actual arguments to DPI open arrays
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

#include "svdpi.h"

#include <cassert>
#include <cstdint>
#include <cstdio>
#include <cstring>

// Include the generated ABI declarations after the DPI header.
#ifdef T_DPI_OPEN_DYNAMIC_PROTECT_IDS
#include "Vt_dpi_open_dynamic_protect_ids__Dpi.h"
#else
#include "Vt_dpi_open_dynamic__Dpi.h"
#endif

static void check_bounds(const svOpenArrayHandle values, int count) {
    assert(svDimensions(values) == 1);
    assert(svLeft(values, 1) == 0);
    assert(svRight(values, 1) == count - 1);
    assert(svLow(values, 1) == 0);
    assert(svHigh(values, 1) == count - 1);
    assert(svIncrement(values, 1) == -1);
    assert(svSize(values, 1) == count);
    // Noncontiguous storage must not be advertised as a contiguous C array.
    if (!svGetArrayPtr(values)) assert(svSizeOfArray(values) == 0);
}

int dpi_dynamic_read(int count, const svOpenArrayHandle values) {
    check_bounds(values, count);
    for (int i = 0; i < count; ++i) {
        const auto* const p = static_cast<const unsigned char*>(svGetArrElemPtr1(values, i));
        assert(p);
        assert(*p == static_cast<unsigned char>(13 * i + 7));
        assert(p == svGetArrElemPtr(values, i));
    }
    return count;
}

void dpi_dynamic_write(const svOpenArrayHandle values) {
    for (int i = 0; i < svSize(values, 1); ++i) {
        auto* const p = static_cast<unsigned char*>(svGetArrElemPtr1(values, i));
        assert(p);
        ++*p;
    }
}

void dpi_dynamic_wide(const svOpenArrayHandle values) {
    assert(svSize(values, 0) == 65);
    for (int i = 0; i < svSize(values, 1); ++i) {
        svBitVecVal bits[3] = {};
        svGetBitArrElem1VecVal(bits, values, i);
        assert(bits[0] == 0xabcdef00U + i);
        assert(bits[1] == 0x12345678U);
        assert(bits[2] == 1);
        bits[0] ^= 0x80000000U;
        bits[1] ^= 1;
        bits[2] ^= 1;
        svPutBitArrElem1VecVal(values, bits, i);
    }
}

void dpi_dynamic_rows(const svOpenArrayHandle values) {
    assert(svDimensions(values) == 2);
    assert(svSize(values, 1) == 3);
    assert(svLeft(values, 2) == 3);
    assert(svRight(values, 2) == 1);
    for (int i = 0; i < 3; ++i) {
        for (int j = 1; j <= 3; ++j) {
            const auto* const p = static_cast<const int*>(svGetArrElemPtr2(values, i, j));
            assert(p && *p == i * 100 + j);
            assert(p == svGetArrElemPtr(values, i, j));
        }
    }
}

void dpi_dynamic_columns(const svOpenArrayHandle values) {
    assert(svDimensions(values) == 2);
    assert(svLeft(values, 1) == 2);
    assert(svRight(values, 1) == 4);
    // Inner dynamic-dimension queries are illegal (IEEE 1800-2017 20.7.1).
    for (int i = 2; i <= 4; ++i) {
        for (int j = 0; j < i - 1; ++j) {
            const auto* const p = static_cast<const int*>(svGetArrElemPtr2(values, i, j));
            assert(p && *p == i * 100 + j);
        }
    }
}

void dpi_dynamic_sized_outer(const svOpenArrayHandle values) { dpi_dynamic_rows(values); }

void dpi_dynamic_sized_inner(const svOpenArrayHandle values) {
    for (int i = 2; i <= 4; ++i) {
        for (int j = 0; j < 3; ++j) {
            auto* const p = static_cast<int*>(svGetArrElemPtr2(values, i, j));
            assert(p && *p == i * 100 + j);
            ++*p;
        }
    }
}

void dpi_dynamic_equivalent(const svOpenArrayHandle values) {
    check_bounds(values, 3);
    for (int i = 0; i < 3; ++i) {
        svBitVecVal bits = 0;
        svGetBitArrElem1VecVal(&bits, values, i);
        assert(bits == static_cast<svBitVecVal>(i));
    }
}

void dpi_dynamic_real(const svOpenArrayHandle values) {
    check_bounds(values, 7);
    for (int i = 0; i < 7; ++i) {
        auto* const p = static_cast<double*>(svGetArrElemPtr1(values, i));
        assert(p && *p == i + 0.5);
        *p += 1.0;
    }
}

void* dpi_dynamic_handle(int index) {
    static const int objects[2] = {};
    assert(index == 0 || index == 1);
    return const_cast<int*>(&objects[index]);
}

void dpi_dynamic_handles(const svOpenArrayHandle values) {
    check_bounds(values, 7);
    for (int i = 0; i < 7; ++i) {
        auto* const p = static_cast<void**>(svGetArrElemPtr1(values, i));
        assert(p && *p == (i == 0 ? nullptr : dpi_dynamic_handle(i % 2)));
        *p = dpi_dynamic_handle((i + 1) % 2);
    }
}

void dpi_dynamic_strings(const svOpenArrayHandle values) {
    assert(svSize(values, 1) == 3);
    const char** slots[3];
    const char* originals[3];
    for (int i = 0; i < 3; ++i) {
        slots[i] = static_cast<const char**>(svGetArrElemPtr1(values, svLow(values, 1) + i));
        assert(slots[i]);
        originals[i] = *slots[i];
        char expected[32];
        std::snprintf(expected, sizeof(expected), "value_%d", i);
        assert(std::strcmp(originals[i], expected) == 0);
    }
    for (int i = 0; i < 3; ++i) *slots[i] = originals[(i + 1) % 3];
}
