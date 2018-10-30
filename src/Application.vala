/***
    Copyright (c) 1999, 2000 Red Hat, Inc.
    Copyright (c) 2000, 2001 Eazel, Inc.
    Copyright (c) 2013 Julián Unrrein <junrrein@gmail.com>
    Copyright (c) 2015-2018 elementary LLC <https://elementary.io>

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
public class Marlin.Application : Gtk.Application {

    private VolumeMonitor volume_monitor;
    private Marlin.Progress.UIHandler progress_handler;
    private Marlin.ClipboardManager clipboard;
    private Gtk.RecentManager recent;

    private const int MARLIN_ACCEL_MAP_SAVE_DELAY = 15;
    private const uint MAX_WINDOWS = 25;

    public int window_count { get; private set; }

    bool quitting = false;

    construct {
        /* Needed by Glib.Application */
        this.application_id = Marlin.APP_ID; //Ensures an unique instance.
        this.flags |= ApplicationFlags.HANDLES_COMMAND_LINE;
    }

    public override void startup () {
        base.startup ();

        if (Granite.Services.Logger.DisplayLevel != Granite.Services.LogLevel.DEBUG) {
            Granite.Services.Logger.DisplayLevel = Granite.Services.LogLevel.INFO;
        }

        message ("Report any issues/bugs you might find to https://github.com/elementary/files/issues");

        /* Only allow running with root privileges using pkexec, not using sudo */
        if (Posix.getuid () == 0 && GLib.Environment.get_variable ("PKEXEC_UID") == null) {
            warning ("Running Files as root using sudo is not possible. Please use the command: io.elementary.files-pkexec [folder]");
            quit ();
        };

        init_schemas ();

        Gtk.IconTheme.get_default ().changed.connect (() => {
            Marlin.IconInfo.clear_caches ();
        });

        progress_handler = new Marlin.Progress.UIHandler (this);

        this.clipboard = Marlin.ClipboardManager.get_for_display ();
        this.recent = new Gtk.RecentManager ();

        /* Global static variable "plugins" declared in PluginManager.vala */
        plugins = new Marlin.PluginManager (Config.PLUGIN_DIR, (uint)(Posix.getuid ()));

        /**TODO** move the volume manager here? */
        /**TODO** gio: This should be using the UNMOUNTED feature of GFileMonitor instead */

        this.volume_monitor = VolumeMonitor.get ();
        this.volume_monitor.mount_removed.connect (mount_removed_callback);

#if HAVE_UNITY
        QuicklistHandler.get_singleton ();
#endif

        window_count = 0;
        this.window_added.connect_after (() => {window_count++;});
        this.window_removed.connect (() => {
            window_count--;
        });
    }

    public unowned Marlin.ClipboardManager get_clipboard_manager () {
        return this.clipboard;
    }

    public unowned Gtk.RecentManager get_recent_manager () {
        return this.recent;
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
                        N_("Show the version of the program"), null };
        options [1] = { "tab", 't', 0, OptionArg.NONE, ref open_in_tab,
                        N_("Open one or more URIs, each in their own tab"), null };
        options [2] = { "new-window", 'n', 0, OptionArg.NONE, out create_new_window,
                        N_("New Window"), null };
        options [3] = { "quit", 'q', 0, OptionArg.NONE, ref kill_shell,
                        N_("Quit Files"), null };
        options [4] = { "debug", 'd', 0, OptionArg.NONE, ref debug,
                        N_("Enable debug logging"), null };
        /* "" = G_OPTION_REMAINING: Catches the remaining arguments */
        options [5] = { "", 0, 0, OptionArg.STRING_ARRAY, ref remaining,
                        null, N_("[URI…]") };
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
        if (debug) {
            Granite.Services.Logger.DisplayLevel = Granite.Services.LogLevel.DEBUG;
        }

        if (version) {
            cmd.print ("io.elementary.files %s\n", Config.VERSION);
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
            string path = PF.FileUtils.sanitize_path (filepath, GLib.Environment.get_current_dir ());
            GLib.File? file = null;

            if (path.length > 0) {
                file = File.new_for_uri (PF.FileUtils.escape_uri (path));
            }

            if (file != null) {
                files += (file);
            }
        }

        /* Open application */
        if (open_in_tab || files == null) {
             create_windows (files);
        } else {
            /* Open windows with tab at each requested location. */
            foreach (var file in files) {
                create_window (file);
            }
        }

        return get_windows ().length () > 0 ? Posix.EXIT_SUCCESS : Posix.EXIT_FAILURE;
    }

    public override void quit_mainloop () {
        warning ("Quitting mainloop");
        Marlin.IconInfo.clear_caches ();

        base.quit_mainloop ();
    }

    public new void quit () {
        /* Protect against holding Ctrl-Q down */
        if (quitting) {
            return;
        }

        quitting = true;
        unowned List<Gtk.Window> window_list = this.get_windows ();
        window_list.@foreach ((window) => {
            ((Marlin.View.Window)window).quit ();
        });

        base.quit ();
    }

    public void folder_deleted (GLib.File file) {
        unowned List<Gtk.Window> window_list = this.get_windows ();
        window_list.@foreach ((window) => {
            ((Marlin.View.Window)window).folder_deleted (file);
        });
    }

    private void mount_removed_callback (VolumeMonitor monitor, Mount mount) {
        /* Notify each window */
        foreach (var window in this.get_windows ()) {
            ((Marlin.View.Window)window).mount_removed (mount);
        }
    }

    private void init_schemas () {
        /* GSettings parameters */
        Preferences.settings = new Settings ("io.elementary.files.preferences");
        Preferences.marlin_icon_view_settings = new Settings ("io.elementary.files.icon-view");
        Preferences.marlin_list_view_settings = new Settings ("io.elementary.files.list-view");
        Preferences.marlin_column_view_settings = new Settings ("io.elementary.files.column-view");
        Preferences.gnome_interface_settings = new Settings ("org.gnome.desktop.interface");
        Preferences.gtk_file_chooser_settings = new Settings ("org.gtk.Settings.FileChooser");

        /* Bind settings with GOFPreferences */
        Preferences.settings.bind ("show-hiddenfiles",
                                   GOF.Preferences.get_default (), "show-hidden-files", GLib.SettingsBindFlags.DEFAULT);
        Preferences.settings.bind ("show-remote-thumbnails",
                                   GOF.Preferences.get_default (), "show-remote-thumbnails", GLib.SettingsBindFlags.DEFAULT);
        Preferences.settings.bind ("confirm-trash",
                                   GOF.Preferences.get_default (), "confirm-trash", GLib.SettingsBindFlags.DEFAULT);
        Preferences.settings.bind ("date-format",
                                   GOF.Preferences.get_default (), "date-format", GLib.SettingsBindFlags.DEFAULT);
        Preferences.gnome_interface_settings.bind ("clock-format",
                                   GOF.Preferences.get_default (), "clock-format", GLib.SettingsBindFlags.GET);
        Preferences.gtk_file_chooser_settings.bind ("sort-directories-first",
                                   GOF.Preferences.get_default (), "sort-directories-first", GLib.SettingsBindFlags.DEFAULT);
    }

    public Marlin.View.Window? create_window (File? location = null,
                                              Marlin.ViewMode viewmode = Marlin.ViewMode.PREFERRED,
                                              int x = -1, int y = -1) {

        return create_windows ({location}, viewmode, x, y);
    }

    /* All window creation should be done via this function */
    public Marlin.View.Window? create_windows (File[] locations = {},
                                               Marlin.ViewMode viewmode = Marlin.ViewMode.PREFERRED,
                                               int x = -1, int y = -1) {
        if (this.get_windows ().length () >= MAX_WINDOWS) {
            return null;
        }

        var win = new Marlin.View.Window (this);
        add_window (win as Gtk.Window);
        plugins.interface_loaded (win as Gtk.Widget);
        win.open_tabs (locations, viewmode);

        return win;
    }
}
