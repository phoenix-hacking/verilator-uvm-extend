// DESCRIPTION: Verilator: Exercise concurrent debug IDs and JSON snapshots
//
// This program is free software; you can redistribute it and/or modify it
// under the terms of either the GNU Lesser General Public License Version 3
// or the Perl Artistic License Version 2.0.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

#include "V3Global.h"

#include <atomic>
#include <iostream>
#include <sstream>
#include <thread>
#include <vector>

int main() {
    V3MutexConfig::s().configure(true);
    V3GlobalDebug ids;
    constexpr unsigned COUNT = 2048;
    std::vector<unsigned> keys(COUNT);
    std::vector<std::string> expected(COUNT);
    std::vector<const std::string*> references(COUNT);
    std::atomic<unsigned> ready{0};
    std::atomic<bool> start{false};
    std::atomic<bool> failed{false};
    if (ids.ptrToId(nullptr) != "0") return 1;
    const auto wait = [&] {
        ready.fetch_add(1);
        while (!start.load()) std::this_thread::yield();
    };
    const auto writer = [&](unsigned parity) {
        wait();
        for (unsigned round = 0; round < 4; ++round) {
            for (unsigned i = parity; i < COUNT; i += 2) {
                const std::string& id = ids.ptrToId(&keys[i]);
                if (!round) {
                    expected[i] = id;
                    references[i] = &id;
                } else if (expected[i] != id || references[i] != &id) {
                    failed.store(true);
                }
                ids.saveJsonPtrFieldName("field" + std::to_string(i % 16));
            }
        }
    };
    std::thread first{writer, 0};
    std::thread second{writer, 1};
    std::thread reader{[&] {
        wait();
        for (unsigned i = 0; i < 128; ++i) {
            std::ostringstream snapshot;
            ids.idPtrMapDumpJson(snapshot);
            ids.ptrNamesDumpJson(snapshot);
        }
    }};
    while (ready.load() != 3) std::this_thread::yield();
    start.store(true);
    first.join();
    second.join();
    reader.join();
    for (unsigned i = 0; i < COUNT; ++i) {
        if (ids.ptrToId(&keys[i]) != expected[i] || *references[i] != expected[i]) return 1;
    }
    std::cout << "{\n";
    ids.idPtrMapDumpJson(std::cout);
    std::cout << ",\n";
    ids.ptrNamesDumpJson(std::cout);
    std::cout << ",\n\"expected\": {";
    for (unsigned i = 0; i < COUNT; ++i) {
        std::cout << (i ? "," : "") << '"' << expected[i] << "\": \"" << &keys[i] << '"';
    }
    std::cout << "}\n}\n";
    return failed.load() ? 1 : 0;
}
