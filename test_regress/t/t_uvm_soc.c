// -*- mode: C; c-file-style: "cc-mode" -*-
// DESCRIPTION: Verilator: Independent C memory-copy reference for the synthetic SoC
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

#include <stdint.h>
#include <string.h>

#ifdef __cplusplus
#error "Compile the SoC reference as C."
#endif

int soc_reference_copy(int source, int destination, int length, int index, int corrupt) {
    uint8_t memory[512];
    int i;
    if (source < 0 || destination < 0 || length < 0 || source + length > 512
        || destination + length > 512 || index < 0 || index >= 512)
        return -1;
    for (i = 0; i < 512; ++i)
        memory[i] = (uint8_t)((37U * (unsigned)i) ^ ((unsigned)i >> 2) ^ 90U);
    memmove(memory + destination, memory + source, (unsigned)length);
    return memory[index] ^ (corrupt != 0);
}
