// -*- mode: C++; c-file-style: "cc-mode" -*-
// DESCRIPTION: Verilator: Stateful C reference model for the UVM DPI scoreboard
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

#include "svdpi.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// Keep the model C-compatible; the regression build links it as C++.
typedef struct {
    uint32_t checksum;
    char name[64];
} ReferenceModel;

static int live_models = 0;

#ifdef __cplusplus
extern "C" {
#endif

void* dpi_reference_new(const char* name) {
    ReferenceModel* model;
    if (!name || strlen(name) >= sizeof(model->name)) return NULL;
    model = (ReferenceModel*)calloc(1, sizeof(ReferenceModel));
    if (!model) return NULL;
    memcpy(model->name, name, strlen(name) + 1);
    ++live_models;
    return model;
}

const char* dpi_reference_name(void* handle) {
    const ReferenceModel* model = (const ReferenceModel*)handle;
    return model ? model->name : "";
}

int dpi_reference_reset(void* handle) {
    ReferenceModel* model = (ReferenceModel*)handle;
    if (!model) return -1;
    model->checksum = 0;
    return 0;
}

int dpi_reference_step(void* handle, int count, const svOpenArrayHandle bytes,
                       const svOpenArrayHandle expected) {
    ReferenceModel* model = (ReferenceModel*)handle;
    int offset;
    int byte_step;
    int expected_step;
    if (!model || !bytes || !expected) return -1;
    if (svDimensions(bytes) != 1 || svDimensions(expected) != 1) return -2;
    if (count < 0 || count > svSize(bytes, 1) || count > svSize(expected, 1)) return -3;
    byte_step = svLeft(bytes, 1) <= svRight(bytes, 1) ? 1 : -1;
    expected_step = svLeft(expected, 1) <= svRight(expected, 1) ? 1 : -1;
    for (offset = 0; offset < count; ++offset) {
        const unsigned char* byte
            = (const unsigned char*)svGetArrElemPtr1(bytes, svLeft(bytes, 1) + offset * byte_step);
        unsigned int* result = (unsigned int*)svGetArrElemPtr1(
            expected, svLeft(expected, 1) + offset * expected_step);
        if (!byte || !result) return -4;
        // Protocol contract: h[n+1] = (33*h[n] + byte[n]) modulo 2**31.
        model->checksum = (33U * model->checksum + *byte) & UINT32_C(0x7fffffff);
        *result = model->checksum;
    }
    return count;
}

int dpi_reference_delete(void* handle) {
    if (!handle) return -1;
    free(handle);
    --live_models;
    return 0;
}

int dpi_reference_live(void) { return live_models; }

#ifdef __cplusplus
}
#endif
