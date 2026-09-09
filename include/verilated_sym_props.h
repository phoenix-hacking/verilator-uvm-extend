// -*- mode: C++; c-file-style: "cc-mode" -*-
//*************************************************************************
//
// Code available from: https://verilator.org
//
// This program is free software; you can redistribute it and/or modify it
// under the terms of either the GNU Lesser General Public License Version 3
// or the Perl Artistic License Version 2.0.
// SPDX-FileCopyrightText: 2003-2026 Wilson Snyder
// SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0
//
//*************************************************************************
///
/// \file
/// \brief Verilated symbol inspection header
///
/// This file is for inclusion by internal files that need to inspect
/// specific symbols.  Applications typically use the VPI instead.
///
/// User wrapper code wanting to inspect the symbol table should use
/// verilated_syms.h instead.
///
//*************************************************************************
// These classes are thread safe, and read only.

#ifndef VERILATOR_VERILATED_SYM_PROPS_H_
#define VERILATOR_VERILATED_SYM_PROPS_H_

#include "verilatedos.h"

#include "verilated.h"

#include <initializer_list>
#include <unordered_map>
#include <vector>

//===========================================================================
// Verilator range
// Thread safety: Assume is constructed only with model, then any number of readers

// See also V3Ast::VNumRange
class VerilatedRange final {
    int m_left = 0;
    int m_right = 0;

protected:
    friend class VerilatedVarProps;
    friend class VerilatedScope;
    VerilatedRange() = default;
    void init(int left, int right) {
        m_left = left;
        m_right = right;
    }

public:
    VerilatedRange(int left, int right)
        : m_left{left}
        , m_right{right} {}
    ~VerilatedRange() = default;
    int left() const VL_PURE { return m_left; }
    int right() const VL_PURE { return m_right; }
    int low() const VL_PURE { return (m_left < m_right) ? m_left : m_right; }
    int high() const VL_PURE { return (m_left > m_right) ? m_left : m_right; }
    int elements() const VL_PURE {
        return (VL_LIKELY(m_left >= m_right) ? (m_left - m_right + 1) : (m_right - m_left + 1));
    }
    int increment() const VL_PURE { return (m_left >= m_right) ? 1 : -1; }
};

//===========================================================================
// Verilator variable
// Thread safety: Assume is constructed only with model, then any number of readers

class VerilatedVarProps VL_NOT_FINAL {
    // TYPES
    static constexpr uint32_t MAGIC = 0xddc4f829UL;
    // MEMBERS
    const uint32_t m_magic;  // Magic number
    const VerilatedVarType m_vltype;  // Data type
    const VerilatedVarFlags m_vlflags;  // Direction
    const uint32_t m_entSize;  // Element size in bytes, or 0 to derive from type
    std::vector<VerilatedRange> m_unpacked;  // Unpacked array ranges
    std::vector<VerilatedRange> m_packed;  // Packed array ranges
    VerilatedRange m_packedDpi;  // Flattened packed array range
    void initUnpacked(int udims, const int* ulims) {
        for (int i = 0; i < udims; ++i) {
            const int uleft = ulims ? ulims[2 * i + 0] : 0;
            const int uright = ulims ? ulims[2 * i + 1] : 0;
            m_unpacked.emplace_back(uleft, uright);
        }
    }
    void initPacked(int pdims, const int* plims) {
        int packedSize = 1;
        for (int i = 0; i < pdims; ++i) {
            const int pleft = plims ? plims[2 * i + 0] : 0;
            const int pright = plims ? plims[2 * i + 1] : 0;
            m_packed.emplace_back(pleft, pright);
            packedSize *= abs(pleft - pright) + 1;
        }
        if (pdims == 1) {
            // Preserve packed array range if the packed component is 1-D
            m_packedDpi = m_packed.front();
        } else {
            m_packedDpi = VerilatedRange{packedSize - 1, 0};
        }
    }
    // CONSTRUCTORS
protected:
    friend class VerilatedScope;
    VerilatedVarProps(VerilatedVarType vltype, VerilatedVarFlags vlflags, int udims, int pdims,
                      uint32_t entSize = 0)
        : m_magic{MAGIC}
        , m_vltype{vltype}
        , m_vlflags{vlflags}
        , m_entSize{entSize} {
        // Only preallocate the ranges
        initUnpacked(udims, nullptr);
        initPacked(pdims, nullptr);
    }

public:
    class Unpacked {};
    // Without packed
    VerilatedVarProps(VerilatedVarType vltype, int vlflags)
        : m_magic{MAGIC}
        , m_vltype{vltype}
        , m_vlflags(VerilatedVarFlags(vlflags))  // Need () or GCC 4.8 false warning
        , m_entSize{0} {}

    VerilatedVarProps(VerilatedVarType vltype, int vlflags, Unpacked, int udims, const int* ulims)
        : m_magic{MAGIC}
        , m_vltype{vltype}
        , m_vlflags(VerilatedVarFlags(vlflags))  // Need () or GCC 4.8 false warning
        , m_entSize{0} {
        initUnpacked(udims, ulims);
    }
    // With packed
    class Packed {};
    VerilatedVarProps(VerilatedVarType vltype, int vlflags, Packed, int pdims, const int* plims)
        : m_magic{MAGIC}
        , m_vltype{vltype}
        , m_vlflags(VerilatedVarFlags(vlflags))  // Need () or GCC 4.8 false warning
        , m_entSize{0} {
        initPacked(pdims, plims);
    }
    VerilatedVarProps(VerilatedVarType vltype, int vlflags, Unpacked, int udims, const int* ulims,
                      Packed, int pdims, const int* plims)
        : m_magic{MAGIC}
        , m_vltype{vltype}
        , m_vlflags(VerilatedVarFlags(vlflags))  // Need () or GCC 4.8 false warning
        , m_entSize{0} {
        initUnpacked(udims, ulims);
        initPacked(pdims, plims);
    }

    ~VerilatedVarProps() = default;
    // METHODS
    bool magicOk() const { return m_magic == MAGIC; }
    VerilatedVarType vltype() const VL_MT_SAFE { return m_vltype; }
    VerilatedVarFlags vldir() const {
        return static_cast<VerilatedVarFlags>(static_cast<int>(m_vlflags) & VLVF_MASK_DIR);
    }
    uint32_t entSize() const VL_MT_SAFE;
    uint32_t entBits() const VL_MT_SAFE {
        uint32_t bits = 1;
        for (auto it : m_packed) bits *= it.elements();
        return bits;
    }
    bool isPublicRW() const { return ((m_vlflags & VLVF_PUB_RW) != 0); }
    bool isForceable() const { return ((m_vlflags & VLVF_FORCEABLE) != 0); }
    bool isContinuously() const { return ((m_vlflags & VLVF_CONTINUOUSLY) != 0); }
    // DPI compatible C standard layout
    bool isDpiCLayout() const { return ((m_vlflags & VLVF_DPI_CLAY) != 0); }
    bool isSigned() const { return ((m_vlflags & VLVF_SIGNED) != 0); }
    bool isBitVar() const { return ((m_vlflags & VLVF_BITVAR) != 0); }
    bool isNet() const { return ((m_vlflags & VLVF_NET) != 0); }
    int udims() const VL_MT_SAFE { return m_unpacked.size(); }
    int pdims() const VL_MT_SAFE { return m_packed.size(); }
    int dims() const VL_MT_SAFE { return pdims() + udims(); }
    const std::vector<VerilatedRange>& packedRanges() const VL_MT_SAFE { return m_packed; }
    const std::vector<VerilatedRange>& unpackedRanges() const VL_MT_SAFE { return m_unpacked; }
    const VerilatedRange* range(int dim) const VL_MT_SAFE {
        if (dim < udims()) return &m_unpacked[dim];
        if (dim < dims()) return &m_packed[dim - udims()];
        return nullptr;
    }
    // DPI accessors (with packed dimensions flattened!)
    int left(int dim) const VL_MT_SAFE {
        return dim == 0                                ? m_packedDpi.left()
               : VL_LIKELY(dim >= 1 && dim <= udims()) ? m_unpacked[dim - 1].left()
                                                       : 0;
    }
    int right(int dim) const VL_MT_SAFE {
        return dim == 0                                ? m_packedDpi.right()
               : VL_LIKELY(dim >= 1 && dim <= udims()) ? m_unpacked[dim - 1].right()
                                                       : 0;
    }
    int low(int dim) const VL_MT_SAFE {
        return dim == 0                                ? m_packedDpi.low()
               : VL_LIKELY(dim >= 1 && dim <= udims()) ? m_unpacked[dim - 1].low()
                                                       : 0;
    }
    int high(int dim) const VL_MT_SAFE {
        return dim == 0                                ? m_packedDpi.high()
               : VL_LIKELY(dim >= 1 && dim <= udims()) ? m_unpacked[dim - 1].high()
                                                       : 0;
    }
    int increment(int dim) const {
        return dim == 0                                ? m_packedDpi.increment()
               : VL_LIKELY(dim >= 1 && dim <= udims()) ? m_unpacked[dim - 1].increment()
                                                       : 0;
    }
    int elements(int dim) const VL_MT_SAFE {
        return dim == 0                                ? m_packedDpi.elements()
               : VL_LIKELY(dim >= 1 && dim <= udims()) ? m_unpacked[dim - 1].elements()
                                                       : 0;
    }
    // Total size in bytes (note DPI limited to 4GB)
    size_t totalSize() const;
    // Adjust a data pointer to access a given array element, NULL if something goes bad
    void* datapAdjustIndex(void* datap, int dim, int indx) const VL_MT_SAFE;
};

//===========================================================================
// Verilator DPI open array variable

/// Select elements in an open array containing queues or dynamic dimensions.
template <typename T_Value>
struct VlDpiArrayAccess final {
    /// Stop at the element type; there are no more unpacked dimensions.
    static void* select(void*, int, int, int) VL_MT_SAFE { return nullptr; }
    /// A scalar has no dynamic dimension.
    static bool dynamic(int) VL_PURE { return false; }
    /// A scalar has no unpacked extent.
    static int size(const void*, int) VL_MT_SAFE { return 0; }
    /// Scalar elements terminate a dimension-size check.
    static bool checkSizes(const void*, const int* beginp, const int* endp) VL_MT_SAFE {
        return beginp == endp;
    }
};

/// Access a fixed dimension, including fixed dimensions containing dynamic arrays.
template <typename T_Value, std::size_t N_Depth>
struct VlDpiArrayAccess<VlUnpacked<T_Value, N_Depth>> final {
    /// Select the requested dimension from the already selected parent element.
    static void* select(void* datap, int dim, int index, int low) VL_MT_SAFE {
        if (dim != 1) return VlDpiArrayAccess<T_Value>::select(datap, dim - 1, index, low);
        const int64_t offset = static_cast<int64_t>(index) - low;
        if (VL_UNLIKELY(offset < 0 || offset >= static_cast<int64_t>(N_Depth))) return nullptr;
        auto* const arrayp = static_cast<VlUnpacked<T_Value, N_Depth>*>(datap);
        return &(*arrayp)[offset];
    }
    /// Identify dynamic dimensions below this fixed dimension.
    static bool dynamic(int dim) VL_PURE {
        return dim > 1 && VlDpiArrayAccess<T_Value>::dynamic(dim - 1);
    }
    /// Return the extent of the selected parent array.
    static int size(const void* datap, int dim) VL_MT_SAFE {
        return dim == 1 ? N_Depth : VlDpiArrayAccess<T_Value>::size(datap, dim - 1);
    }
    /// Check only the prefix of dimensions constrained by the formal argument.
    static bool checkSizes(const void* datap, const int* beginp, const int* endp) VL_MT_SAFE {
        if (beginp == endp) return true;
        if (*beginp && static_cast<std::size_t>(*beginp) != N_Depth) return false;
        if (beginp + 1 == endp) return true;
        const auto* const arrayp = static_cast<const VlUnpacked<T_Value, N_Depth>*>(datap);
        for (std::size_t index = 0; index < N_Depth; ++index) {
            if (!VlDpiArrayAccess<T_Value>::checkSizes(&(*arrayp)[index], beginp + 1, endp)) {
                return false;
            }
        }
        return true;
    }
};

/// Access a deque-backed dynamic array or queue without copying its elements.
template <typename T_Value, std::size_t N_MaxSize>
struct VlDpiArrayAccess<VlQueue<T_Value, N_MaxSize>> final {
    /// Select an existing element; DPI cannot resize an actual argument.
    static void* select(void* datap, int dim, int index, int low) VL_MT_SAFE {
        if (dim != 1) return VlDpiArrayAccess<T_Value>::select(datap, dim - 1, index, low);
        const auto* const arrayp = static_cast<const VlQueue<T_Value, N_MaxSize>*>(datap);
        if (VL_UNLIKELY(index < 0 || index >= arrayp->size())) return nullptr;
        return const_cast<T_Value*>(&arrayp->at(index));
    }
    /// Identify this dynamic dimension and any nested dynamic dimensions.
    static bool dynamic(int dim) VL_PURE {
        return dim == 1 || (dim > 1 && VlDpiArrayAccess<T_Value>::dynamic(dim - 1));
    }
    /// Return the extent of the selected parent array.
    static int size(const void* datap, int dim) VL_MT_SAFE {
        if (dim != 1) return VlDpiArrayAccess<T_Value>::size(datap, dim - 1);
        return static_cast<const VlQueue<T_Value, N_MaxSize>*>(datap)->size();
    }
    /// Validate sized formal dimensions before the foreign function can access the array.
    static bool checkSizes(const void* datap, const int* beginp, const int* endp) VL_MT_SAFE {
        if (beginp == endp) return true;
        const auto* const arrayp = static_cast<const VlQueue<T_Value, N_MaxSize>*>(datap);
        if (*beginp && *beginp != arrayp->size()) return false;
        if (beginp + 1 == endp) return true;
        for (const T_Value& element : *arrayp) {
            if (!VlDpiArrayAccess<T_Value>::checkSizes(&element, beginp + 1, endp)) return false;
        }
        return true;
    }
};

/// Check sized formal dimensions on the bound argument before calling the foreign function.
template <typename T_Array>
void VL_DPI_CHECK_OPEN_ARRAY(const T_Array& array, std::initializer_list<int> sizes) VL_MT_SAFE {
    if (VL_UNLIKELY(!VlDpiArrayAccess<T_Array>::checkSizes(&array, sizes.begin(), sizes.end()))) {
        VL_FATAL_MT(__FILE__, __LINE__, "",
                    "DPI open-array actual does not match a sized dimension");
    }
}

class VerilatedDpiOpenVar final {
    using HandleRefs = std::unordered_map<QData*, void*>;
    using StringRefs = std::unordered_map<std::string*, const char*>;
    // MEMBERS - Callback contracts match the assigned VlDpiArrayAccess functions.
    const VerilatedVarProps* const m_propsp;  // Variable properties
    void* const m_datap;  // Location of data (local to thread always, so safe)
    void* (*m_select)(void*, int, int, int)VL_MT_SAFE = nullptr;  // Noncontiguous element access
    bool (*m_dynamic)(int) VL_PURE = nullptr;  // Which dimensions have a variable extent
    int (*m_size)(const void*, int) VL_MT_SAFE = nullptr;  // Extent of a selected parent array
    int m_outerSize = 0;  // First-dimension extent at entry to the DPI call
    mutable std::unique_ptr<StringRefs> m_strings;  // C string pointer slots, allocated on demand
    mutable std::unique_ptr<HandleRefs> m_handles;  // Native pointer slots for model QData handles

    int dynamicSize(int dim) const VL_MT_SAFE {
        // IEEE 1800-2017 20.7.1 prohibits queries of inner variable dimensions.
        if (VL_UNLIKELY(dim != 1)) {
            VL_FATAL_MT(__FILE__, __LINE__, "", "DPI query of an inner dynamic array dimension");
        }
        return m_outerSize;
    }
    bool dynamic(int dim) const VL_MT_SAFE { return m_dynamic && m_dynamic(dim); }

public:
    /// Select typed access for noncontiguous storage or converted element representations.
    struct Typed final {};
    // CONSTRUCTORS
    VerilatedDpiOpenVar(const VerilatedVarProps* propsp, void* datap)
        : m_propsp{propsp}
        , m_datap{datap} {}
    VerilatedDpiOpenVar(const VerilatedVarProps* propsp, const void* datap)
        : m_propsp{propsp}
        , m_datap{const_cast<void*>(datap)} {}
    /// Wrap dynamic storage for the lifetime of a single DPI call.
    template <typename T_Array>
    VerilatedDpiOpenVar(const VerilatedVarProps* propsp, const T_Array* datap, Typed)
        : m_propsp{propsp}
        , m_datap{const_cast<T_Array*>(datap)}
        , m_select{&VlDpiArrayAccess<T_Array>::select}
        , m_dynamic{&VlDpiArrayAccess<T_Array>::dynamic}
        , m_size{&VlDpiArrayAccess<T_Array>::size}
        , m_outerSize{VlDpiArrayAccess<T_Array>::size(datap, 1)} {}
    /// Commit writable C string and handle slots after the imported function returns.
    ~VerilatedDpiOpenVar() {
        if (m_propsp->vldir() == VLVD_IN) return;
        if (m_handles) {
            for (const auto& entry : *m_handles) *entry.first = VL_CVT_VP_Q(entry.second);
        }
        if (!m_strings) return;
        // Copy every source first: a C string pointer may refer to another array element.
        std::vector<std::pair<std::string*, std::string>> values;
        values.reserve(m_strings->size());
        for (const auto& entry : *m_strings) {
            values.emplace_back(entry.first, entry.second ? entry.second : "");
        }
        for (auto& entry : values) *entry.first = std::move(entry.second);
    }
    // METHODS
    void* datap() const VL_MT_SAFE { return m_datap; }
    // METHODS - from VerilatedVarProps
    bool magicOk() const { return m_propsp->magicOk(); }
    VerilatedVarType vltype() const VL_MT_SAFE { return m_propsp->vltype(); }
    bool isDpiStdLayout() const {
        return m_propsp->isDpiCLayout() || m_propsp->vltype() == VLVT_STRING;
    }
    /// Whole-array pointers require contiguous storage as well as C-compatible elements.
    bool isContiguous() const VL_MT_SAFE { return !m_select && m_propsp->vltype() != VLVT_STRING; }
    int entBits() const { return m_propsp->entBits(); }
    int udims() const VL_MT_SAFE { return m_propsp->udims(); }
    int left(int dim) const VL_MT_SAFE {
        if (!dynamic(dim)) return m_propsp->left(dim);
        (void)dynamicSize(dim);
        return 0;
    }
    int right(int dim) const VL_MT_SAFE {
        return dynamic(dim) ? dynamicSize(dim) - 1 : m_propsp->right(dim);
    }
    int low(int dim) const { return dynamic(dim) ? left(dim) : m_propsp->low(dim); }
    int high(int dim) const { return dynamic(dim) ? right(dim) : m_propsp->high(dim); }
    int increment(int dim) const {
        if (!dynamic(dim)) return m_propsp->increment(dim);
        (void)dynamicSize(dim);
        return -1;
    }
    int elements(int dim) const {
        return dynamic(dim) ? dynamicSize(dim) : m_propsp->elements(dim);
    }
    size_t totalSize() const { return m_propsp->totalSize(); }
    /// Bounds for diagnostics after selecting a parent, including inner dynamic dimensions.
    int indexLeft(int dim) const VL_MT_SAFE { return dynamic(dim) ? 0 : m_propsp->left(dim); }
    /// Unlike an array-wide query, the selected parent determines an inner dynamic extent.
    int indexRight(const void* parentp, int dim) const VL_MT_SAFE {
        return dynamic(dim) ? m_size(parentp, dim) - 1 : m_propsp->right(dim);
    }
    void* datapAdjustIndex(void* datap, int dim, int indx) const VL_MT_SAFE {
        void* const resultp = m_select ? m_select(datap, dim, indx, m_propsp->low(dim))
                                       : m_propsp->datapAdjustIndex(datap, dim, indx);
        if (!resultp || dim != udims()) return resultp;
        if (vltype() == VLVT_PTR) {
            if (!m_handles) m_handles.reset(new HandleRefs);
            auto* const handlep = static_cast<QData*>(resultp);
            const auto entry = m_handles->emplace(handlep, VL_CVT_Q_VP(*handlep));
            return &entry.first->second;
        }
        if (vltype() != VLVT_STRING) return resultp;
        if (!m_strings) m_strings.reset(new StringRefs);
        auto* const stringp = static_cast<std::string*>(resultp);
        const auto entry = m_strings->emplace(stringp, stringp->c_str());
        return &entry.first->second;
    }
};

//===========================================================================
// Verilator variable
// Thread safety: Assume is constructed only with model, then any number of readers

struct VerilatedForceControlSignals;
class VerilatedVar final : public VerilatedVarProps {
    // MEMBERS
    void* const m_datap;  // Location of data
    const char* const m_namep;  // Name - slowpath
    std::unique_ptr<const VerilatedForceControlSignals>
        m_forceControlSignals;  // Force control signals

protected:
    const bool m_isParam;
    friend class VerilatedScope;
    // CONSTRUCTORS
    VerilatedVar(const char* namep, void* datap, VerilatedVarType vltype,
                 VerilatedVarFlags vlflags, int udims, int pdims, bool isParam);
    VerilatedVar(const char* namep, void* datap, VerilatedVarType vltype,
                 VerilatedVarFlags vlflags, int udims, int pdims, bool isParam, uint32_t entSize);
    VerilatedVar(const char* namep, void* datap, VerilatedVarType vltype,
                 VerilatedVarFlags vlflags, int udims, int pdims, bool isParam,
                 std::unique_ptr<const VerilatedForceControlSignals> forceControlSignals);

public:
    ~VerilatedVar();
    VerilatedVar(VerilatedVar&&);
    // ACCESSORS
    void* datap() const { return m_datap; }
    const char* name() const { return m_namep; }
    bool isParam() const { return m_isParam; }
    const VerilatedForceControlSignals* forceControlSignals() const {
        return m_forceControlSignals.get();
    }
};

//===========================================================================
// Force control signals of a VerilatedVar

struct VerilatedForceControlSignals final {
    const VerilatedVar* forceEnableSignalp{nullptr};  // __VforceEn signal
    const VerilatedVar* forceValueSignalp{nullptr};  // __VforceVal signal
    const VerilatedVar forceReadSignal;  // __VforceRd signal
};

inline VerilatedVar::VerilatedVar(const char* namep, void* datap, VerilatedVarType vltype,
                                  VerilatedVarFlags vlflags, int udims, int pdims, bool isParam)
    : VerilatedVarProps{vltype, vlflags, udims, pdims}
    , m_datap{datap}
    , m_namep{namep}
    , m_isParam{isParam} {}
inline VerilatedVar::VerilatedVar(const char* namep, void* datap, VerilatedVarType vltype,
                                  VerilatedVarFlags vlflags, int udims, int pdims, bool isParam,
                                  uint32_t entSize)
    : VerilatedVarProps{vltype, vlflags, udims, pdims, entSize}
    , m_datap{datap}
    , m_namep{namep}
    , m_isParam{isParam} {}
inline VerilatedVar::VerilatedVar(
    const char* namep, void* datap, VerilatedVarType vltype, VerilatedVarFlags vlflags, int udims,
    int pdims, bool isParam,
    std::unique_ptr<const VerilatedForceControlSignals> forceControlSignals)
    : VerilatedVarProps{vltype, vlflags, udims, pdims}
    , m_datap{datap}
    , m_namep{namep}
    , m_forceControlSignals{std::move(forceControlSignals)}
    , m_isParam{isParam} {}
inline VerilatedVar::~VerilatedVar() = default;
inline VerilatedVar::VerilatedVar(VerilatedVar&&) = default;

#endif  // Guard
