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
/// \brief Verilated functional-coverage collection runtime
///
/// VlCoverpoint owns per-instance bin-count storage for one coverpoint,
/// computes coverage, builds bin names on demand, and registers bins with the
/// coverage database.  It implements the VlCoverpointIf read interface.
///
/// Generated covergroup code holds one VlCoverpoint per coverpoint, configures
/// it in the constructor (init + add*Namer), increments bins from sample(),
/// and registers via registerBins().
///
//=============================================================================

#ifndef VERILATOR_VERILATED_COVERGROUP_H_
#define VERILATOR_VERILATED_COVERGROUP_H_

#include "verilatedos.h"

#include "verilated_cov_model.h"

#include <cstdint>
#include <memory>
#include <string>
#include <vector>

class VerilatedCovContext;

// How a namer builds the names of the bins it covers.
enum class VlCovBinNaming : uint8_t {
    Single,  // "<name>"      one bin
    Array,  // "<name>[i]"   bins b[N] value array
};

// Specifies the naming scheme for a range of bins, allowing the
// specific name to be computed on-demand.
// All name strings are borrowed literals from the generated code.
class VlCovNamer final {
    // MEMBERS
    VlCovBinKind m_set;  // which set the bins belong to
    int m_count;  // bins this namer covers (1 for Single)
    int m_base;  // first bin index (declaration order), assigned on append
    VlCovBinNaming m_naming;  // how bin names are built
    const char* m_name;  // bin name (Single) or array base name (Array)
    const char* m_file;  // declaration file
    int m_line;  // declaration line
    int m_col;  // declaration column

public:
    // CONSTRUCTORS
    VlCovNamer(VlCovBinKind set, int count, int base, VlCovBinNaming naming, const char* name,
               const char* file, int line, int col)
        : m_set{set}
        , m_count{count}
        , m_base{base}
        , m_naming{naming}
        , m_name{name}
        , m_file{file}
        , m_line{line}
        , m_col{col} {}

    // METHODS
    VlCovBinKind set() const { return m_set; }
    int count() const { return m_count; }
    int base() const { return m_base; }
    VlCovBinNaming naming() const { return m_naming; }
    const char* name() const { return m_name; }
    const char* file() const { return m_file; }
    int line() const { return m_line; }
    int col() const { return m_col; }
};

//=============================================================================
// VlCoverpoint
/// Per-instance coverpoint runtime.  Bins are stored in declaration order; a
/// bin's set/name come from the owning namer.  coverage() is computed on demand
/// by scanning bin counts, keeping the sample() hot path a plain counter bump.

class VlCoverpoint final : public VlCoverpointIf {
    // MEMBERS
    std::string m_hier;  // "covergroup.coverpoint"
    uint32_t m_atLeast = 1;  // option.at_least (coverpoint-wide)
    int m_total = 0;  // bins across all sets
    int m_normal = 0;  // Normal bins (coverage denominator)
    int m_nextBase = 0;  // running append cursor
    std::vector<uint32_t> m_counts;  // [m_total], one per bin
    std::vector<VlCovNamer> m_namers;  // appended in declaration order

    // PRIVATE METHODS
    const VlCovNamer& namerFor(int i) const;  // obtain the bin-specific name producer
    void addNamer(VlCovBinKind set, int count, VlCovBinNaming naming, const char* name,
                  const char* file, int line, int col);

public:
    // CONSTRUCTORS
    VlCoverpoint() = default;

    // METHODS
    // ---- configuration (from generated constructor) ----
    void init(const char* hier, uint32_t atLeast, int nBins);
    /// Elaborated hit threshold used for both instance and merged type coverage.
    uint32_t atLeast() const { return m_atLeast; }
    void addSingleNamer(VlCovBinKind set, const char* name, const char* file, int line, int col) {
        addNamer(set, 1, VlCovBinNaming::Single, name, file, line, col);
    }
    void addArrayNamer(VlCovBinKind set, int count, const char* name, const char* file, int line,
                       int col) {
        addNamer(set, count, VlCovBinNaming::Array, name, file, line, col);
    }
    void registerBins(VerilatedCovContext* covcontextp, const char* page);

    // ---- hot path (from generated sample()) ----
    void incrementBin(int i) { ++m_counts[i]; }  // Normal bin: count only
    void recordHit(int i) { ++m_counts[i]; }  // Ignore/Illegal/Default: count only

    // ---- VlCoverpointIf ----
    int binCount() const override { return m_total; }
    /// Current hit count, including ignored, illegal, and default bins.
    uint32_t binHits(int i) const { return m_counts[i]; }
    /// Mutable counter for generated transition and cross sampling expressions.
    uint32_t& binHitsRef(int i) { return m_counts[i]; }
    std::string binName(int i) const override;
    VlCovBinKind binKind(int i) const override { return namerFor(i).set(); }
    void coverageParts(double& covered, double& total) const override {
        // Count Normal bins that reached option.at_least on demand, so the hot
        // path (incrementBin) stays a plain counter bump.
        int numCovered = 0;
        for (const VlCovNamer& nm : m_namers) {
            if (nm.set() != VlCovBinKind::KIND_NORMAL) continue;
            for (int i = nm.base(); i < nm.base() + nm.count(); ++i) {
                if (m_counts[i] >= m_atLeast) ++numCovered;
            }
        }
        covered = numCovered;
        total = m_normal;
    }
};

//=============================================================================
// VlCovergroupData
/// Coverage-only state for one instance. The type retains this state after the
/// SystemVerilog handle is released, without retaining sample arguments or UVM objects.
/// Items are allocated before bin registration, so their counter addresses remain stable.

class VlCovergroupData final {
    uint32_t m_weight = 1;
    std::vector<VlCoverpoint> m_items;
    std::vector<uint32_t> m_weights;
    uint32_t* m_boundWeightp = nullptr;
    std::vector<uint32_t*> m_boundWeights;
    std::vector<std::shared_ptr<void>> m_options;

public:
    explicit VlCovergroupData(int items)
        : m_items(items)
        , m_weights(items, 1)
        , m_boundWeights(items, nullptr)
        , m_options(items + 1) {}
    /// Instance option.weight; also used by type coverage in average mode.
    uint32_t& weight() { return m_boundWeightp ? *m_boundWeightp : m_weight; }
    uint32_t weight() const { return m_boundWeightp ? *m_boundWeightp : m_weight; }
    /// Coverpoint or cross storage, indexed in declaration order.
    VlCoverpoint& item(int i) { return m_items[i]; }
    const VlCoverpoint& item(int i) const { return m_items[i]; }
    /// Instance option.weight of a coverpoint or cross.
    uint32_t& itemWeight(int i) { return m_boundWeights[i] ? *m_boundWeights[i] : m_weights[i]; }
    uint32_t itemWeight(int i) const {
        return m_boundWeights[i] ? *m_boundWeights[i] : m_weights[i];
    }
    /// Own the complete generated option structure, including strings and fields
    /// accessed through whole-struct assignment or by reference. The prototype
    /// supplies only its type; its value is never read.
    template <typename T>
    T& options(const T&, int item) {
        std::shared_ptr<void>& storage = m_options[item + 1];
        if (!storage) storage = std::make_shared<T>();
        return *static_cast<T*>(storage.get());
    }
    /// Bind a weight inside owned option storage. Whole-struct assignment keeps
    /// this address stable, and the option object's lifetime matches this data.
    void bindWeight(int item, uint32_t& value) {
        if (item < 0)
            m_boundWeightp = &value;
        else
            m_boundWeights[item] = &value;
    }
    /// Weighted sum of item bin ratios and sum of contributing item weights.
    void coverageParts(double& covered, double& total, uint32_t& coveredBins,
                       uint32_t& totalBins) const;
    /// Instance percentage under IEEE 1800-2023 19.11, including empty groups.
    double coverage() const;
    /// Return the percentage and unweighted constituent bin counts (IEEE 19.8).
    double coverage(uint32_t& coveredBins, uint32_t& totalBins) const;
};

//=============================================================================
// VlCovergroupType
/// Model-owned registry of coverage-only instance state. Generated code serializes
/// construction, sampling, option changes, and queries as it does class accesses.
/// There is no process-global registry and no extra work on the bin increment path.

class VlCovergroupType final {
    struct ItemOptions final {
        uint32_t weight = 1;
        uint32_t atLeast = 1;
    };
    uint32_t m_weight = 1;
    bool m_mergeInstances = false;
    std::vector<ItemOptions> m_items;
    std::vector<std::shared_ptr<VlCovergroupData>> m_instances;

    void mergedCoverageParts(double& covered, double& total, uint32_t& coveredBins,
                             uint32_t& totalBins) const;

public:
    /// Configure the type before constructing instances. Thresholds and type
    /// weights are supplied from the elaborated coverage item declarations.
    explicit VlCovergroupType(int items = 0)
        : m_items(items) {}
    /// Allocate and retain only the coverage data of a new instance.
    std::shared_ptr<VlCovergroupData> create();
    /// Lazily configure a generated type before its first instance is created.
    std::shared_ptr<VlCovergroupData> create(int items);
    /// Type options, independent of the corresponding instance options.
    uint32_t& weight() { return m_weight; }
    bool& mergeInstances() { return m_mergeInstances; }
    uint32_t& itemWeight(int i) { return m_items[i].weight; }
    uint32_t& itemAtLeast(int i) { return m_items[i].atLeast; }
    /// Type percentage, using either instance weights or merged bin counts.
    double coverage() const;
    /// Return the type percentage and aggregated bin counts (IEEE 19.8).
    double coverage(uint32_t& coveredBins, uint32_t& totalBins) const;
    /// Query using the current generated static type options.
    double coverage(uint32_t weight, bool mergeInstances, uint32_t& coveredBins,
                    uint32_t& totalBins) const;
};

#endif  // Guard
