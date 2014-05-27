/***
  Copyright (C) 1999, 2000 Red Hat, Inc.
  Copyright (C) 2000, 2001 Eazel, Inc.
  Copyright (C) 2013 Julián Unrrein <junrrein@gmail.com>

  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE. See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program. If not, see <http://www.gnu.org/licenses/>.

  Authors: Elliot Lee <sopwith@redhat.com>,
           Darin Adler <darin@bentspoon.com>,
           Julián Unrrein <junrrein@gmail.com>
***/

private Marlin.Application application_singleton = null;

public class Marlin.Application : Granite.Application {

    private VolumeMonitor volume_monitor;
    private Marlin.Progress.UIHandler progress_handler;
    private Marlin.Clipboard.Manager clipboard;
    private Marlin.Thumbnailer thumbnailer;

    private const int MARLIN_ACCEL_MAP_SAVE_DELAY = 15;
    private bool save_of_accel_map_requested = false;

    construct {
        /* Needed by Glib.Application */
        this.application_id = "org.pantheon.files";  //Ensures an unique instance.
        this.flags = ApplicationFlags.HANDLES_COMMAND_LINE;

        /* Needed by Granite.Application */
        this.program_name = Marlin.APP_TITLE;
        this.exec_name = Marlin.APP_TITLE.down ().replace (" ", "-");
        this.build_version = Config.VERSION;

        this.app_copyright = Marlin.COPYRIGHT;
        this.app_years = Marlin.APP_YEARS;
        this.about_license_type = Gtk.License.GPL_3_0;
        this.app_icon = Marlin.ICON_ABOUT_LOGO;

        this.main_url = Marlin.LAUNCHPAD_URL;
        this.bug_url = Marlin.BUG_URL;
        this.help_url = Marlin.HELP_URL;
        this.translate_url = Marlin.TRANSLATE_URL;

        this.about_authors = Marlin.AUTHORS;
        this.about_documenters = { null };
        this.about_artists = Marlin.ARTISTS;
        this.about_comments = Marlin.COMMENTS;
        this.about_translators = Marlin.TRANSLATORS;

        application_singleton = this;
    }

    public static new unowned Application get () {
        if (application_singleton == null)
            application_singleton = new Marlin.Application ();

        return application_singleton;
    }

    ~Application () {
        Notify.uninit ();
    }

    public override void startup () {
        base.startup ();

        if (Granite.Services.Logger.DisplayLevel != Granite.Services.LogLevel.DEBUG)
            Granite.Services.Logger.DisplayLevel = Granite.Services.LogLevel.INFO;

        message ("Report any issues/bugs you might find to http://bugs.launchpad.net/pantheon-files");

        init_schemas ();
        init_gtk_accels ();

        Gtk.IconTheme.get_default ().changed.connect (() => {
            Marlin.IconInfo.clear_caches ();
        });

        Notify.init (Config.GETTEXT_PACKAGE);
        this.progress_handler = new Marlin.Progress.UIHandler ();
        this.clipboard = new Marlin.Clipboard.Manager.get_for_display (Gdk.Display.get_default ());
        this.thumbnailer = Marlin.Thumbnailer.get ();

        tags = new Marlin.View.Tags ();

        plugins = new Marlin.PluginManager (Config.PLUGIN_DIR);

        /* TODO move the volume manager here? */
        /* TODO-gio: This should be using the UNMOUNTED feature of GFileMonitor instead */
        this.volume_monitor = VolumeMonitor.get ();
        this.volume_monitor.mount_removed.connect (mount_removed_callback);

#if HAVE_UNITY
        QuicklistHandler.get_singleton ();
#endif
    }

    public override int command_line (ApplicationCommandLine cmd) {
        this.hold ();
        int result = _command_line (cmd);
        this.release ();
        return result;
    }

    /* The array that holds the file commandline arguments
       needs some boilerplate so its size gets updated. */
    [CCode (array_length = false, array_null_terminated = true)]
    private string[]? remaining = null;

    private int _command_line (ApplicationCommandLine cmd) {
        /* Setup the argument parser */
        bool version = false;
        bool open_in_tab = false;
        bool create_new_window = false;
        bool kill_shell = false;
        bool debug = false;

        OptionEntry[] options = new OptionEntry [7];
        options [0] = { "version", '\0', 0, OptionArg.NONE, ref version,
                        N_("Show the version of the program."), null };
        options [1] = { "tab", 't', 0, OptionArg.NONE, ref open_in_tab,
                        N_("Open uri(s) in new tab"), null };
        options [2] = { "new-window", 'n', 0, OptionArg.NONE, out create_new_window,
                        N_("New Window"), null };
        options [3] = { "quit", 'q', 0, OptionArg.NONE, ref kill_shell,
                        N_("Quit Files."), null };
        options [4] = { "debug", 'd', 0, OptionArg.NONE, ref debug,
                        N_("Enable debug logging"), null };
        /* "" = G_OPTION_REMAINING: Catches the remaining arguments */
        options [5] = { "", 0, 0, OptionArg.STRING_ARRAY, ref remaining,
                        null, N_("[URI...]") };
        options [6] = { null };

        var context = new OptionContext (_("\n\nBrowse the file system with the file manager"));
        context.add_main_entries (options, null);
        context.add_group (Gtk.get_option_group (true));

        string[] args = cmd.get_arguments ();
        /* We need to store arguments in an unowned variable for context.parse */
        unowned string[] args_aux = args;

        /* Parse arguments */
        try {
            context.parse (ref args_aux);
        } catch (OptionError error) {
            cmd.printerr ("Could not parse arguments: %s\n", error.message);
            return Posix.EXIT_FAILURE;
        }

        /* Handle arguments */
        if (debug)
            Granite.Services.Logger.DisplayLevel = Granite.Services.LogLevel.DEBUG;

        if (version) {
            cmd.print ("pantheon-files %s\n", Config.VERSION);
            return Posix.EXIT_SUCCESS;
        }

        if (kill_shell) {
            if (remaining != null) {
                cmd.printerr ("%s\n", _("--quit cannot be used with URIs."));
                return Posix.EXIT_FAILURE;
            } else {
                this.quit ();
                return Posix.EXIT_SUCCESS;
            }
        }

        File[] files = null;

        /* Convert remaining arguments to GFiles */
        foreach (string filepath in remaining) {
            var file = File.new_for_commandline_arg (filepath);

            if (file != null)
                files += (file);
        }

        /* Open application */
        if (create_new_window)
            create_window (File.new_for_path (Environment.get_home_dir ()), Gdk.Screen.get_default ());
        else if (open_in_tab)
            open_tabs (files);
        else
            open_windows (files);

        return Posix.EXIT_SUCCESS;
    }

    public override void quit_mainloop () {
        print ("Quitting mainloop");
        Marlin.IconInfo.clear_caches ();

        base.quit_mainloop ();
    }

    public new void quit () {
        foreach (var window in this.get_windows ())
            window.destroy ();
    }

    public void create_window (File location, Gdk.Screen screen) {
        open_window (location, screen);
    }

    private void mount_removed_callback (VolumeMonitor monitor, Mount mount) {
        /* Check and see if any of the open windows are displaying contents from the unmounted mount */
        unowned List<Gtk.Window> window_list = this.get_windows ();
        File root = mount.get_root ();

        /* Check each slot from each window, loading home for current tabs and closing the rest */
        foreach (Gtk.Window window in window_list) {
            var marlin_window = window as Marlin.View.Window;
            List<Gtk.Widget> pages = marlin_window.tabs.get_children ();

            foreach (var page in pages) {
                var view_container = page as Marlin.View.ViewContainer;
                File location = view_container.slot.location;
                if (location == null || location.has_prefix (root) || location.equal (root)) {
                    if (view_container == marlin_window.current_tab)
                        view_container.path_changed (File.new_for_path (Environment.get_home_dir ()));
                    else
                        marlin_window.remove_tab (view_container);
                }
            }
        }
    }

    private void init_schemas () {
        /* GSettings parameters */
        Preferences.settings = new Settings ("org.pantheon.files.preferences");
        Preferences.marlin_icon_view_settings = new Settings ("org.pantheon.files.icon-view");
        Preferences.marlin_list_view_settings = new Settings ("org.pantheon.files.list-view");
        Preferences.marlin_column_view_settings = new Settings ("org.pantheon.files.column-view");

        /* Bind settings with GOFPreferences */
        Preferences.settings.bind ("show-hiddenfiles",
                                   GOF.Preferences.get_default (), "show-hidden-files", 0);
        Preferences.settings.bind ("confirm-trash",
                                   GOF.Preferences.get_default (), "confirm-trash", 0);
        Preferences.settings.bind ("date-format",
                                   GOF.Preferences.get_default (), "date-format", 0);
        Preferences.settings.bind ("interpret-desktop-files",
                                   GOF.Preferences.get_default (), "interpret-desktop-files", 0);
    }

    /* Load accelerator map, and register save callback */
    private void init_gtk_accels () {
        string accel_map_filename = Marlin.get_accel_map_file ();
        if (accel_map_filename != null) {
            Gtk.AccelMap.load (accel_map_filename);
        }

        Gtk.AccelMap.get ().changed.connect (() => {
            if (!save_of_accel_map_requested) {
                save_of_accel_map_requested = true;
                Timeout.add_seconds (MARLIN_ACCEL_MAP_SAVE_DELAY,
                                     save_accel_map);
            }
        });
    }

    private bool save_accel_map () {
        if (save_of_accel_map_requested) {
            string accel_map_filename = Marlin.get_accel_map_file ();
            if (accel_map_filename != null)
                Gtk.AccelMap.save (accel_map_filename);
            save_of_accel_map_requested = false;
        }

        return false;
    }

    private void open_window (File location, Gdk.Screen screen = Gdk.Screen.get_default ()) {
        var window = new Marlin.View.Window (this, screen, !windows_exist ());
        plugins.interface_loaded (window as Gtk.Widget);
        this.add_window (window as Gtk.Window);
        window.set_size_request (300, 250);
        window.add_tab (location);
    }

    private void open_windows (File[]? files) {
        if (files == null)
            open_tabs (files);
        else {
            /* Open windows at each requested location. */
            foreach (var file in files)
                open_window (file);
        }
    }

    private void open_tabs (File[]? files, Gdk.Screen screen = Gdk.Screen.get_default ()) {
        Marlin.View.Window window = null;

        /* Get the first window, if any, else create a new window */
        if (windows_exist ())
            window = (this.get_windows ()).data as Marlin.View.Window;
        else {
            window = new Marlin.View.Window (this, screen, true);
            this.add_window (window as Gtk.Window);
            plugins.interface_loaded (window as Gtk.Widget);
        }

        if (files == null) {
            /* Restore session if settings allow */
            if (!Preferences.settings.get_boolean ("restore-tabs") || window.restore_tabs () < 1) {
                /* Open a tab pointing at the default location if no tabs restored*/
                var location = File.new_for_path (Environment.get_home_dir ());
                window.add_tab (location);
            }
        } else {
            /* Open tabs at each requested location */
            foreach (var file in files)
                window.add_tab (file);
        }
    }

    private bool windows_exist () {
        unowned List<Gtk.Window> windows = this.get_windows ();
        return (windows != null && windows.data != null);
    }
}
