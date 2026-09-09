// -*- mode: C++; c-file-style: "cc-mode" -*-
//=============================================================================
//
// Code available from: https://verilator.org
//
// This program is free software; you can redistribute it and/or modify it
// under the terms of either the GNU Lesser General Public License Version 3
// or the Perl Artistic License Version 2.0.
// SPDX-FileCopyrightText: 2024-2026 Wilson Snyder
// SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0
//
//=============================================================================
///
/// \file
/// \brief Verilated functional-coverage collection runtime implementation
///
/// Linked when covergroups are present.  The coverage-database registration
/// is compiled only with "verilator --coverage".
///
//=============================================================================

#include "verilatedos.h"

#include "verilated_covergroup.h"

#include <algorithm>
#include <cassert>
#include <map>

#if VM_COVERAGE
#include "verilated_cov.h"
#endif

void VlCoverpoint::init(const char* hier, uint32_t atLeast, int nBins) {
    m_hier = hier;
    m_atLeast = atLeast;
    m_total = nBins;
    m_counts.assign(nBins, 0);
}

void VlCoverpoint::addNamer(VlCovBinKind set, int count, VlCovBinNaming naming, const char* name,
                            const char* file, int line, int col) {
    m_namers.emplace_back(set, count, m_nextBase, naming, name, file, line, col);
    m_nextBase += count;
    if (set == VlCovBinKind::KIND_NORMAL) m_normal += count;
}

const VlCovNamer& VlCoverpoint::namerFor(int i) const {
    // Namers are appended in ascending, contiguous index order. Use binary
    // search so querying every bin does not scan the complete namer list per bin.
    assert(i >= 0 && i < m_total);
    const auto it = std::upper_bound(
        m_namers.begin(), m_namers.end(), i,
        [](int index, const VlCovNamer& namer) { return index < namer.base(); });
    return *(it - 1);
}

std::string VlCoverpoint::binName(int i) const {
    const VlCovNamer& nm = namerFor(i);
    std::string name = nm.name();
    if (nm.naming() == VlCovBinNaming::Array) name += '[' + std::to_string(i - nm.base()) + ']';
    return name;
}

#if VM_COVERAGE
void VlCoverpoint::registerBins(VerilatedCovContext* covcontextp, const char* page) {
    for (int i = 0; i < binCount(); ++i) {
        const VlCovNamer& nm = namerFor(i);
        const VlCovBinKind kind = binKind(i);
        const std::string binp = binName(i);
        const std::string full = m_hier + "." + binp;
        const std::string lineStr = std::to_string(nm.line());
        const std::string colStr = std::to_string(nm.col());
        if (kind == VlCovBinKind::KIND_NORMAL) {
            VL_COVER_INSERT(covcontextp, full.c_str(), &m_counts[i], "page", page, "filename",
                            nm.file(), "lineno", lineStr.c_str(), "column", colStr.c_str(), "bin",
                            binp.c_str());
        } else {
            const char* const binType = kind == VlCovBinKind::KIND_IGNORE    ? "ignore"
                                        : kind == VlCovBinKind::KIND_ILLEGAL ? "illegal"
                                                                             : "default";
            VL_COVER_INSERT(covcontextp, full.c_str(), &m_counts[i], "page", page, "filename",
                            nm.file(), "lineno", lineStr.c_str(), "column", colStr.c_str(), "bin",
                            binp.c_str(), "bin_type", binType);
        }
    }
}
#endif  // VM_COVERAGE

void VlCovergroupData::coverageParts(double& covered, double& total, uint32_t& coveredBins,
                                     uint32_t& totalBins) const {
    covered = 0.0;
    total = 0.0;
    coveredBins = 0;
    totalBins = 0;
    for (size_t i = 0; i < m_items.size(); ++i) {
        double itemCovered = 0.0;
        double itemTotal = 0.0;
        m_items[i].coverageParts(itemCovered, itemTotal);
        if (itemTotal == 0.0) continue;
        covered += itemWeight(static_cast<int>(i)) * itemCovered / itemTotal;
        total += itemWeight(static_cast<int>(i));
        coveredBins += static_cast<uint32_t>(itemCovered);
        totalBins += static_cast<uint32_t>(itemTotal);
    }
    if (total == 0.0) coveredBins = totalBins = 0;
}

double VlCovergroupData::coverage() const {
    uint32_t coveredBins = 0;
    uint32_t totalBins = 0;
    return coverage(coveredBins, totalBins);
}

double VlCovergroupData::coverage(uint32_t& coveredBins, uint32_t& totalBins) const {
    double covered = 0.0;
    double total = 0.0;
    uint32_t binCovered = 0;
    uint32_t binTotal = 0;
    coverageParts(covered, total, binCovered, binTotal);
    // Assign after computing both results, including when the ref arguments alias.
    coveredBins = binCovered;
    totalBins = binTotal;
    return total != 0.0 ? 100.0 * covered / total : (weight() ? 0.0 : 100.0);
}

std::shared_ptr<VlCovergroupData> VlCovergroupType::create() {
    const std::shared_ptr<VlCovergroupData> instancep
        = std::make_shared<VlCovergroupData>(static_cast<int>(m_items.size()));
    m_instances.emplace_back(instancep);
    return instancep;
}

std::shared_ptr<VlCovergroupData> VlCovergroupType::create(int items) {
    if (m_instances.empty()) m_items.resize(items);
    assert(static_cast<int>(m_items.size()) == items);
    return create();
}

void VlCovergroupType::mergedCoverageParts(double& covered, double& total, uint32_t& coveredBins,
                                           uint32_t& totalBins) const {
    // IEEE 1800-2023 19.11.3: overlap is determined by bin name within each
    // item. Add hit counts before comparing against the elaborated threshold.
    covered = 0.0;
    total = 0.0;
    coveredBins = 0;
    totalBins = 0;
    for (size_t i = 0; i < m_items.size(); ++i) {
        std::map<std::string, uint32_t> counts;
        const uint32_t atLeast = m_items[i].atLeast;
        for (const std::shared_ptr<VlCovergroupData>& instancep : m_instances) {
            const VlCoverpoint& item = instancep->item(static_cast<int>(i));
            for (int bin = 0; bin < item.binCount(); ++bin) {
                if (item.binKind(bin) != VlCovBinKind::KIND_NORMAL) continue;
                uint32_t& count = counts[item.binName(bin)];
                // Saturate at the threshold: avoid overflow without changing
                // the per-instance counters or database contents.
                const uint32_t hits = item.binHits(bin);
                count = hits >= atLeast - count ? atLeast : count + hits;
            }
        }
        if (counts.empty()) continue;
        double itemCovered = 0.0;
        for (const auto& entry : counts) {
            if (entry.second >= atLeast) ++itemCovered;
        }
        covered += m_items[i].weight * itemCovered / counts.size();
        total += m_items[i].weight;
        coveredBins += static_cast<uint32_t>(itemCovered);
        totalBins += static_cast<uint32_t>(counts.size());
    }
}

double VlCovergroupType::coverage() const {
    uint32_t coveredBins = 0;
    uint32_t totalBins = 0;
    return coverage(coveredBins, totalBins);
}

double VlCovergroupType::coverage(uint32_t& coveredBins, uint32_t& totalBins) const {
    return coverage(m_weight, m_mergeInstances, coveredBins, totalBins);
}

double VlCovergroupType::coverage(uint32_t weight, bool mergeInstances, uint32_t& coveredBins,
                                  uint32_t& totalBins) const {
    double covered = 0.0;
    double total = 0.0;
    uint32_t binCovered = 0;
    uint32_t binTotal = 0;
    if (mergeInstances) {
        mergedCoverageParts(covered, total, binCovered, binTotal);
    } else {
        // Excluded groups contribute to neither side of the weighted average.
        for (const std::shared_ptr<VlCovergroupData>& instancep : m_instances) {
            double instanceCovered = 0.0;
            double instanceTotal = 0.0;
            uint32_t instanceBinsCovered = 0;
            uint32_t instanceBinsTotal = 0;
            instancep->coverageParts(instanceCovered, instanceTotal, instanceBinsCovered,
                                     instanceBinsTotal);
            if (instanceTotal == 0.0) continue;
            covered += instancep->weight() * instanceCovered / instanceTotal;
            total += instancep->weight();
            binCovered += instanceBinsCovered;
            binTotal += instanceBinsTotal;
        }
    }
    coveredBins = total != 0.0 ? binCovered : 0;
    totalBins = total != 0.0 ? binTotal : 0;
    return total != 0.0 ? 100.0 * covered / total : (weight ? 0.0 : 100.0);
}
