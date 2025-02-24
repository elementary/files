/* Copyright (c) 2018 elementary LLC (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, Inc.,; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

// To use profiling utils enable one or both option in meson_options.txt
// Do not start cpu and heap profiling simultaneously as they will profile each other
// The gperftools library must be installed (libgoogle-perftools-dev)
// Visualize the cpu profile with e.g. google-pprof --functions --gv /usr/bin/io.elementary.files <profile_path>
// Use --focus=<regexp> and --ignore=<regexp> to filter/prune nodes displayed
namespace CPUProfiler {
    static bool on (string name = "", string dir = Environment.get_home_dir ()) {
#if PROFILING
        var  profile_name = name == "" ? Files.APP_ID : name;
        var profile_path = Path.build_filename (dir, profile_name + ".prof");
        Profiler.start (profile_path);
        warning ("started cpu profiling - output to %s", profile_path);
        return true;
#else
        return false;
#endif
    }

    static bool off () {
#if PROFILING
        Profiler.stop ();
        warning ("stopped cpu profiling");
        return true;
#else
        return false;
#endif
    }

    static bool flush () {
#if PROFILING
        Profiler.flush ();
        return true;
#else
        return false;
#endif
    }
}

namespace HeapProfiler {
// NOTE: Heap profiling slows the program down **a lot** 
// The output path will have the suffix '.NNNN.heap' appended
// Visualize the profile with e.g. google-pprof --gv /usr/bin/io.elementary.files <profile_path>
// Use --focus=<regexp> and --ignore=<regexp> to filter/prune nodes displayed

    static bool on (string name = "", string dir = Environment.get_home_dir ()) {
#if HEAP_PROFILING
    var  profile_name = name == "" ? Files.APP_ID : name;
    var profile_path = Path.build_filename (dir, profile_name);
    HeapProfiler.start (profile_path);
    warning ("started heap profiling - output to %s", heap_profile_path);
    return true;
#else
    return false;
#endif
    }

    static bool off () {
#if HEAP_PROFILING
    HeapProfiler.stop ();
    warning ("stopped heap profiling");
    return true;
#else
    return false;
#endif
    }
}
