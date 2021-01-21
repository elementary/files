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

namespace Marlin {
    public Settings app_settings;
    public Settings icon_view_settings;
    public Settings list_view_settings;
    public Settings column_view_settings;
}

public class Marlin.Application : Gtk.Application {

    private VolumeMonitor volume_monitor;
    private Marlin.Progress.UIHandler progress_handler;
    private Marlin.ClipboardManager clipboard;
    private Gtk.RecentManager recent;

    private const int MARLIN_ACCEL_MAP_SAVE_DELAY = 15;
    private const uint MAX_WINDOWS = 25;

    public Settings gnome_interface_settings { get; construct; }
    public Settings gnome_privacy_settings { get; construct; }
    public Settings gtk_file_chooser_settings { get; construct; }


    public int window_count { get; private set; }

    bool quitting = false;

    static construct {
        /* GSettings parameters */
        app_settings = new Settings ("io.elementary.files.preferences");
        icon_view_settings = new Settings ("io.elementary.files.icon-view");
        list_view_settings = new Settings ("io.elementary.files.list-view");
        column_view_settings = new Settings ("io.elementary.files.column-view");
    }

    construct {
        gnome_interface_settings = new Settings ("org.gnome.desktop.interface");
        gnome_privacy_settings = new Settings ("org.gnome.desktop.privacy");
        gtk_file_chooser_settings = new Settings ("org.gtk.Settings.FileChooser");

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
            warning ("Running Files as root using sudo is not possible. " +
                     "Please use the command: io.elementary.files-pkexec [folder]");
            quit ();
        };

        init_schemas ();

        Gtk.IconTheme.get_default ().changed.connect (() => {
            Marlin.IconInfo.clear_caches ();
        });

        progress_handler = new Marlin.Progress.UIHandler ();

        this.clipboard = Marlin.ClipboardManager.get_for_display ();
        this.recent = new Gtk.RecentManager ();

        /* Global static variable "plugins" declared in PluginManager.vala */
        plugins = new Marlin.PluginManager (Config.PLUGIN_DIR, (uint)(Posix.getuid ()));

        /**TODO** move the volume manager here? */
        /**TODO** gio: This should be using the UNMOUNTED feature of GFileMonitor instead */

        this.volume_monitor = VolumeMonitor.get ();
        this.volume_monitor.mount_removed.connect (mount_removed_callback);
        this.volume_monitor.drive_connected.connect (drive_connected_callback);

#if HAVE_UNITY
        QuicklistHandler.get_singleton ();
#endif

        window_count = 0;
        this.window_added.connect_after (() => {window_count++;});
        this.window_removed.connect (() => {
            window_count--;
        });

        var granite_settings = Granite.Settings.get_default ();
        var gtk_settings = Gtk.Settings.get_default ();

        gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;

        granite_settings.notify["prefers-color-scheme"].connect (() => {
            gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
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
        /* The -t option is redundant but is retained for backward compatability
         * Locations are always opened in tabs unless -n option specified,
         * in the active window, if present, or after opening a window if not.
         */
        bool open_in_tab = true;
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
        if (files != null) {
            if (create_new_window || window_count == 0) {
                /* Open window with tabs at each requested location. */
                create_window_with_tabs (files);
            } else {
                var win = (Marlin.View.Window)(get_active_window ());
                win.open_tabs (files, Marlin.ViewMode.PREFERRED, true); /* Ignore if duplicate tab in existing window */
            }
        } else if (create_new_window || window_count == 0) {
            create_window_with_tabs ();
        }

        if (window_count > 0) {
            get_active_window ().present ();
            return Posix.EXIT_SUCCESS;
        } else {
            return Posix.EXIT_FAILURE;
        }
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

    private void drive_connected_callback (Drive drive) {
        debug ("Drive: %s".printf (drive.get_name ()));
        debug ("Volume(s): %u".printf (drive.get_volumes ().length ()));
        debug ("Icon string name: %s".printf (drive.get_icon ().to_string ()));

        var notification = new Notification (_("%s connected").printf (drive.get_name ()));
        notification.set_icon (drive.get_icon ());

        var n_volumes = drive.get_volumes ().length ();

        if (n_volumes > 0) {
            notification.set_body (_("With %u %s").printf (n_volumes, ngettext ("volume", "volumes", n_volumes)));
        }

        this.send_notification (this.application_id, notification);
    }

    private void init_schemas () {
        /* Bind settings with GOFPreferences */
        var prefs = GOF.Preferences.get_default ();
        Marlin.app_settings.bind ("show-hiddenfiles", prefs, "show-hidden-files", GLib.SettingsBindFlags.DEFAULT);
        Marlin.app_settings.bind ("show-remote-thumbnails",
                                   prefs, "show-remote-thumbnails", GLib.SettingsBindFlags.DEFAULT);
        Marlin.app_settings.bind ("hide-local-thumbnails",
                                   prefs, "hide-local-thumbnails", GLib.SettingsBindFlags.DEFAULT);
        Marlin.app_settings.bind ("date-format", prefs, "date-format", GLib.SettingsBindFlags.DEFAULT);
        gnome_interface_settings.bind ("clock-format",
                                   GOF.Preferences.get_default (), "clock-format", GLib.SettingsBindFlags.GET);
        gnome_privacy_settings.bind ("remember-recent-files",
                                   GOF.Preferences.get_default (), "remember-history", GLib.SettingsBindFlags.GET);
        gtk_file_chooser_settings.bind ("sort-directories-first",
                                   prefs, "sort-directories-first", GLib.SettingsBindFlags.DEFAULT);
    }

    public Marlin.View.Window? create_window (File? location = null,
                                              Marlin.ViewMode viewmode = Marlin.ViewMode.PREFERRED) {

        return create_window_with_tabs ({location}, viewmode);
    }

    /* All window creation should be done via this function */
    private Marlin.View.Window? create_window_with_tabs (File[] locations = {},
                                                         Marlin.ViewMode viewmode = Marlin.ViewMode.PREFERRED) {

        if (this.get_windows ().length () >= MAX_WINDOWS) { //Can be assumed to be limited in length
            return null;
        }

        var win = new Marlin.View.Window (this);
        add_window (win as Gtk.Window);
        plugins.interface_loaded (win as Gtk.Widget);
        win.open_tabs (locations, viewmode);

        return win;
    }
}
