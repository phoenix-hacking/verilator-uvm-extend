// DESCRIPTION: Verilator: Hold mkdir pending while another native caller enters
//
// This program is free software; you can redistribute it and/or modify it
// under the terms of either the GNU Lesser General Public License Version 3
// or the Perl Artistic License Version 2.0.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

#include "V3File.h"
#include "V3FileLine.h"
#include "V3Global.h"

#include <chrono>
#include <condition_variable>
#include <cstdlib>
#include <future>
#include <iostream>
#include <mutex>
#include <thread>

#include <sys/stat.h>

namespace {
std::mutex s_mutex;
std::condition_variable s_changed;
bool s_entered = false;
bool s_released = false;
unsigned s_calls = 0;
unsigned s_pauseCall = 1;
}  // namespace

extern "C" int __real_mkdir(const char*, mode_t);
extern "C" int __wrap_mkdir(const char* path, mode_t mode) {
    {
        std::unique_lock<std::mutex> lock{s_mutex};
        if (++s_calls == s_pauseCall) {
            s_entered = true;
            s_changed.notify_all();
            s_changed.wait(lock, [] { return s_released; });
        }
    }
    return __real_mkdir(path, mode);
}

int main(int argc, char** argv) {
    if (argc != 2) return 2;
    const std::string mode{argv[1]};
    const bool hierarchical = mode == "hierarchical" || mode == "stream_hierarchical";
    const bool streams = mode == "stream" || mode == "stream_hierarchical";
    V3MutexConfig::s().configure(true);
    if (hierarchical) {
        // Exercise waiting for the second directory, after the main directory exists.
        FileLine fl{FileLine::commandLineFilename()};
        char blockFlag[] = "--hierarchical-block";
        char block[] = "child,child";
        char prefixFlag[] = "--prefix";
        char prefix[] = "Vt";
        char* args[] = {blockFlag, block, prefixFlag, prefix};
        v3Global.opt.parseOptsList(&fl, ".", 4, args);
        s_pauseCall = 2;
    }
    const std::string dirname = v3Global.opt.hierTopDataDir();
    const auto create = [&dirname, streams](const char* filename) {
        if (!streams) {
            V3File::createMakeDir();
            return true;
        }
        const std::unique_ptr<std::ofstream> ofp{V3File::new_ofstream(dirname + '/' + filename)};
        return static_cast<bool>(*ofp);
    };
    bool firstOk = false;
    std::thread first{[&] { firstOk = create("first.txt"); }};
    {
        std::unique_lock<std::mutex> lock{s_mutex};
        if (!s_changed.wait_for(lock, std::chrono::seconds{10}, [] { return s_entered; }))
            std::abort();
    }
    std::promise<void> started;
    std::future<void> start = started.get_future();
    std::future<bool> second = std::async(std::launch::async, [&] {
        started.set_value();
        return create("second.txt");
    });
    start.wait();
    const bool premature = second.wait_for(std::chrono::seconds{2}) == std::future_status::ready;
    struct stat info;
    const bool existedBeforeRelease = stat(dirname.c_str(), &info) == 0;
    {
        const std::lock_guard<std::mutex> lock{s_mutex};
        s_released = true;
    }
    s_changed.notify_all();
    first.join();
    const bool secondOk = second.get();
    V3File::createMakeDir();
    const bool existsAfterRelease = stat(dirname.c_str(), &info) == 0 && S_ISDIR(info.st_mode);
    std::cout << "premature=" << premature << " existedBeforeRelease=" << existedBeforeRelease
              << " existsAfterRelease=" << existsAfterRelease << " mkdirCalls=" << s_calls
              << " firstOk=" << firstOk << " secondOk=" << secondOk << '\n';
    return premature || existedBeforeRelease || !existsAfterRelease || s_calls != s_pauseCall
           || !firstOk || !secondOk;
}
