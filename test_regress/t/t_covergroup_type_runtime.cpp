// -*- mode: C++; c-file-style: "cc-mode" -*-
// DESCRIPTION: Verilator: Covergroup type storage and aggregation runtime test
//
// This file ONLY is placed under the Creative Commons Public Domain
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

#include "verilated.h"
#include "verilated_cov.h"
#include "verilated_covergroup.h"

#include <cmath>
#include <cstdio>
#include <memory>

// These require the above. Comment prevents clang-format moving them
#include "TestCheck.h"

int errors = 0;

struct RuntimeOptions final {
    uint32_t weight = 1;
    std::string comment;
};

static void initItem(VlCoverpoint& item, const char* hier, uint32_t atLeast = 1) {
    item.init(hier, atLeast, 3);
    item.addSingleNamer(VlCovBinKind::KIND_NORMAL, "lo", __FILE__, 20, 1);
    item.addSingleNamer(VlCovBinKind::KIND_NORMAL, "hi", __FILE__, 21, 1);
    item.addSingleNamer(VlCovBinKind::KIND_IGNORE, "ignored", __FILE__, 22, 1);
}

int main() {
    VerilatedContext context;
    uint32_t coveredBins = 0;
    uint32_t totalBins = 0;
    VlCovergroupType type{2};
    std::shared_ptr<VlCovergroupData> firstp = type.create();
    const RuntimeOptions prototype;
    RuntimeOptions& owned = firstp->options(prototype, -1);
    owned.comment = "retained";
    firstp->bindWeight(-1, owned.weight);
    RuntimeOptions replacement;
    replacement.weight = 5;
    replacement.comment = "retained";
    owned = replacement;
    TEST_CHECK_EQ(firstp->weight(), 5);
    firstp->weight() = 1;
    initItem(firstp->item(0), "first.cp");
    initItem(firstp->item(1), "first.cross");
    firstp->item(0).registerBins(context.coveragep(), "v_covergroup/type_runtime");
    firstp->item(0).incrementBin(0);
    firstp->item(1).incrementBin(0);
    firstp->item(1).incrementBin(1);
    firstp->itemWeight(1) = 3;
    TEST_CHECK_EQ(firstp->coverage(), 87.5);
    TEST_CHECK_EQ(type.coverage(), 87.5);
    TEST_CHECK_EQ(firstp->coverage(coveredBins, totalBins), 87.5);
    TEST_CHECK_EQ(coveredBins, 3);
    TEST_CHECK_EQ(totalBins, 4);

    std::shared_ptr<VlCovergroupData> secondp = type.create();
    initItem(secondp->item(0), "second.cp");
    initItem(secondp->item(1), "second.cross");
    secondp->item(0).incrementBin(1);
    secondp->weight() = 3;
    TEST_CHECK_EQ(secondp->coverage(), 25.0);
    TEST_CHECK_EQ(type.coverage(), 40.625);
    TEST_CHECK_EQ(type.coverage(coveredBins, totalBins), 40.625);
    TEST_CHECK_EQ(coveredBins, 4);
    TEST_CHECK_EQ(totalBins, 8);
    secondp->weight() = 0;
    TEST_CHECK_EQ(type.coverage(), 87.5);
    secondp->weight() = 3;

    // Type weights apply to the union, independently of instance weights.
    type.mergeInstances() = true;
    TEST_CHECK_EQ(type.coverage(), 100.0);
    TEST_CHECK_EQ(type.coverage(coveredBins, totalBins), 100.0);
    TEST_CHECK_EQ(coveredBins, 4);
    TEST_CHECK_EQ(totalBins, 4);
    TEST_CHECK_EQ(firstp->coverage(coveredBins, coveredBins), 87.5);
    TEST_CHECK_EQ(coveredBins, 4);
    const std::weak_ptr<VlCovergroupData> retainedp = firstp;
    firstp.reset();
    TEST_CHECK_EQ(retainedp.expired(), false);
    TEST_CHECK_EQ(retainedp.lock()->options(prototype, -1).comment, "retained");
    TEST_CHECK_EQ(type.coverage(), 100.0);
    context.coveragep()->write(VL_STRINGIFY(TEST_OBJ_DIR) "/coverage.dat");
    type.mergeInstances() = false;
    TEST_CHECK_EQ(type.coverage(), 40.625);
    std::shared_ptr<VlCovergroupData> thirdp = type.create();
    initItem(thirdp->item(0), "third.cp");
    initItem(thirdp->item(1), "third.cross");
    TEST_CHECK_EQ(type.coverage(), 32.5);

    // Names, rather than positional indices, identify overlapping bins. Counts
    // near the storage limit must not wrap during the type-only summation.
    VlCovergroupType overlap{1};
    overlap.mergeInstances() = true;
    overlap.itemAtLeast(0) = 2;
    const std::shared_ptr<VlCovergroupData> ap = overlap.create();
    const std::shared_ptr<VlCovergroupData> bp = overlap.create();
    ap->item(0).init("a", 2, 2);
    bp->item(0).init("b", 2, 2);
    ap->item(0).addSingleNamer(VlCovBinKind::KIND_NORMAL, "x", __FILE__, 1, 0);
    ap->item(0).addSingleNamer(VlCovBinKind::KIND_NORMAL, "y", __FILE__, 1, 0);
    bp->item(0).addSingleNamer(VlCovBinKind::KIND_NORMAL, "y", __FILE__, 1, 0);
    bp->item(0).addSingleNamer(VlCovBinKind::KIND_NORMAL, "z", __FILE__, 1, 0);
    ap->item(0).binHitsRef(1) = UINT32_MAX;
    bp->item(0).binHitsRef(0) = UINT32_MAX;
    TEST_CHECK_EQ(std::abs(overlap.coverage() - 100.0 / 3.0) < 1e-12, true);
    TEST_CHECK_EQ(ap->item(0).binHits(1), UINT32_MAX);
    TEST_CHECK_EQ(bp->item(0).binHits(0), UINT32_MAX);

    // A separate model/type starts with separate storage. Counts must be summed
    // before at_least is tested, even when no individual instance covers a bin.
    VlCovergroupType merged{2};
    merged.mergeInstances() = true;
    merged.itemAtLeast(0) = 2;
    merged.itemAtLeast(1) = 2;
    std::shared_ptr<VlCovergroupData> leftp = merged.create();
    std::shared_ptr<VlCovergroupData> rightp = merged.create();
    for (const std::shared_ptr<VlCovergroupData>& instancep : {leftp, rightp}) {
        initItem(instancep->item(0), "merge.cp", 2);
        initItem(instancep->item(1), "merge.cross", 2);
        instancep->item(0).incrementBin(0);
        instancep->item(0).recordHit(2);
        TEST_CHECK_EQ(instancep->coverage(), 0.0);
    }
    TEST_CHECK_EQ(merged.coverage(), 25.0);
    merged.itemWeight(0) = 3;
    TEST_CHECK_EQ(merged.coverage(), 37.5);
    merged.itemWeight(0) = 0;
    TEST_CHECK_EQ(merged.coverage(), 0.0);
    TEST_CHECK_EQ(type.coverage(), 32.5);

    // Empty and excluded instances do not dilute the contributing instances.
    VlCovergroupType empty{0};
    TEST_CHECK_EQ(empty.coverage(), 0.0);
    const std::shared_ptr<VlCovergroupData> emptyp = empty.create();
    TEST_CHECK_EQ(emptyp->coverage(), 0.0);
    emptyp->weight() = 0;
    empty.weight() = 0;
    TEST_CHECK_EQ(emptyp->coverage(), 100.0);
    TEST_CHECK_EQ(empty.coverage(), 100.0);
    TEST_CHECK_EQ(empty.coverage(coveredBins, totalBins), 100.0);
    TEST_CHECK_EQ(coveredBins, 0);
    TEST_CHECK_EQ(totalBins, 0);
    thirdp->itemWeight(0) = 0;
    thirdp->itemWeight(1) = 0;
    TEST_CHECK_EQ(type.coverage(), 40.625);

    // Destroying the registry releases its retained data. A surviving handle
    // owns its data independently and does not retain a pointer to the registry.
    std::weak_ptr<VlCovergroupData> expiredp;
    std::shared_ptr<VlCovergroupData> survivor;
    {
        VlCovergroupType temporary{1};
        expiredp = temporary.create();
        survivor = temporary.create();
        initItem(survivor->item(0), "survivor.cp");
        survivor->item(0).incrementBin(0);
    }
    TEST_CHECK_EQ(expiredp.expired(), true);
    TEST_CHECK_EQ(survivor->coverage(), 50.0);
    if (errors) return 1;
    std::puts("*-* All Finished *-*");
}
