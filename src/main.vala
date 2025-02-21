/***
    Copyright (c) 2013 Julián Unrrein <junrrein@gmail.com>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.
***/
public static int main (string[] args) {
    /* Initiliaze gettext support */
    Intl.setlocale (LocaleCategory.ALL, "");
    Intl.textdomain (Config.GETTEXT_PACKAGE);
    Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALE_DIR);
    Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");

    Environment.set_application_name (Config.APP_NAME);
    Environment.set_prgname (Config.APP_NAME);

    var application = new Files.Application ();

// By default, profile whole app when profiling is enabled in meson_options.txt
// These conditional statements can be moved to profile sections of code
// The gperftools library must be installed (libgoogle-perftools-dev)
// Amend the profile report paths as required
#if PROFILING
            // The output path will have the suffix '.prof' appended
            // Visualize the cpu profile with e.g. google-pprof --functions --gv /usr/bin/io.elementary.code <profile_path>
            // Use --focus=<regexp> and --ignore=<regexp> to filter/prune nodes displayed
            var profile_path = Path.build_filename (Environment.get_home_dir (), "Application");
            // Start CPU profiling
            Profiler.start (profile_path);
            warning ("start cpu profiling - output to %s", profile_path);
#endif
#if HEAP_PROFILING
            // NOTE: Heap profiling at this point slows the program down **a lot** It will take tens of seconds to load.
            // The output path will have the suffix '.NNNN.heap' appended
            // Visualize the profile with e.g. google-pprof --gv /usr/bin/io.elementary.code <profile_path>
            // Use --focus=<regexp> and --ignore=<regexp> to filter/prune nodes displayed
            var heap_profile_path = Path.build_filename (Environment.get_home_dir (), "Application");
            // Start heap profiling
            HeapProfiler.start (heap_profile_path);
            warning ("start heap profiling - output to %s", heap_profile_path);
#endif

    return application.run (args);

#if PROFILING
            Profiler.stop ();
            warning ("stop cpu profiling");
#endif
#if HEAP_PROFILING
            HeapProfiler.stop ();
            warning ("stop heap profiling");
#endif
}
