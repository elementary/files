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

namespace Files {
    public Settings app_settings;
    public Settings icon_view_settings;
    public Settings list_view_settings;
    public Settings column_view_settings;
}

public class Files.Application : Gtk.Application {

    private VolumeMonitor volume_monitor;
    private Progress.UIHandler progress_handler;
    private ClipboardManager clipboard;
    private Gtk.RecentManager recent;

    private const int MARLIN_ACCEL_MAP_SAVE_DELAY = 15;
    private const uint MAX_WINDOWS = 25;

    public Settings gnome_interface_settings { get; construct; }
    public Settings gnome_privacy_settings { get; construct; }
    public Settings gtk_file_chooser_settings { get; construct; }

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
        this.application_id = APP_ID; //Ensures an unique instance.
        this.flags |= ApplicationFlags.HANDLES_COMMAND_LINE;

        set_option_context_parameter_string (_("\n\nBrowse the file system with the file manager"));
        add_main_option ("version", '\0', NONE, NONE, _("Show the version of the program"), null);

        /* The -t option is redundant but is retained for backward compatability
         * Locations are always opened in tabs unless -n option specified,
         * in the active window, if present, or after opening a window if not.
         */
        add_main_option ("tab", 't', NONE, NONE, _("Open one or more URIs, each in their own tab"), null );
        add_main_option ("new-window", 'n', NONE, NONE, _("New Window"), null );
        add_main_option ("quit", 'q', NONE, NONE, _("Quit Files"), null );
        add_main_option ("debug", 'd', NONE, NONE, _("Enable debug logging"), null );

        // GLib.OPTION_REMAINING: Catches the remaining arguments
        add_main_option (GLib.OPTION_REMAINING, '\0', NONE, STRING_ARRAY, "\0", _("[URI…]") );
    }

    protected override int handle_local_options (GLib.VariantDict options) {
        if ("version" in options) {
            stdout.printf ("io.elementary.files %s\n", Config.VERSION);
            return Posix.EXIT_SUCCESS;
        }

        // Only allow running with root privileges using pkexec, not using sudo */
        if (Files.is_admin () && GLib.Environment.get_variable ("PKEXEC_UID") == null) {
            stderr.printf (
                _("Error: Running Files as root using sudo is not possible.") + " " +
                _("Please use the command: io.elementary.files-pkexec [folder]")
            );

            return Posix.EXIT_FAILURE;
        }

        try {
            register (); // register early so we can handle the quit flag locally
        } catch (Error e) {
            stderr.printf ("Error: failed to register application: %s", e.message);
            return Posix.EXIT_FAILURE;
        }

        var remote = is_remote;

        if ("quit" in options) {
            if (GLib.OPTION_REMAINING in options) {
                stderr.printf (_("--quit cannot be used with URIs.") + "\n");
                return Posix.EXIT_FAILURE;
            }

            if (remote) {
                activate_action ("quit", null);
            }

            return Posix.EXIT_SUCCESS;
        }

        // Only handle --debug if not remote
        // FIXME: GLib.Environment.set_variable() is not thread-safe, use a custom GLib.LogFuncWriter for this
        if (!remote && "debug" in options) {
            GLib.Environment.set_variable ("G_MESSAGES_DEBUG", "all", false);
            options.remove ("debug");
        }

        return -1;
    }

    public override void startup () {
        base.startup ();

        init_schemas ();

        Gtk.IconTheme.get_default ().changed.connect (() => {
            Files.IconInfo.clear_caches ();
        });

        progress_handler = new Progress.UIHandler ();

        this.clipboard = ClipboardManager.get_for_display ();
        this.recent = new Gtk.RecentManager ();

        /* Global static variable "plugins" declared in PluginManager.vala */
        plugins = new PluginManager (Config.PLUGIN_DIR, (uint)(Posix.getuid ()));

        /**TODO** move the volume manager here? */
        /**TODO** gio: This should be using the UNMOUNTED feature of GFileMonitor instead */

        this.volume_monitor = VolumeMonitor.get ();
        this.volume_monitor.mount_removed.connect (mount_removed_callback);

#if HAVE_UNITY
        QuicklistHandler.get_singleton ();
#endif

        var granite_settings = Granite.Settings.get_default ();
        var gtk_settings = Gtk.Settings.get_default ();

        gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;

        granite_settings.notify["prefers-color-scheme"].connect (() => {
            gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
            Files.EmblemRenderer.clear_cache ();
        });

        var quit_action = new SimpleAction ("quit", null);
        quit_action.activate.connect (quit);
        add_action (quit_action);

        set_accels_for_action ("app.quit", { "<Ctrl>Q" });
    }

    public unowned ClipboardManager get_clipboard_manager () {
        return this.clipboard;
    }

    public unowned Gtk.RecentManager get_recent_manager () {
        return this.recent;
    }

    public override int command_line (GLib.ApplicationCommandLine cmd) {
        unowned var options = cmd.get_options_dict ();

        var window = (View.Window) active_window;
        bool new_window = false;

        if (window == null || options.lookup ("new-window", "b", out new_window) && new_window) {
            if (get_windows ().length () >= MAX_WINDOWS) { // Can be assumed to be limited in length
                cmd.printerr_literal ("Error: failed to create new window, maximum limit reached.");
                return Posix.EXIT_FAILURE;
            }

            window = new View.Window (this);
            new_window = true;
        }

        // Convert remaining arguments to GLib.Files
        (unowned string)[] uris;

        if (options.lookup (GLib.OPTION_REMAINING, "^a&s", out uris)) {
            var working_directory = cmd.get_cwd () ?? GLib.Environment.get_current_dir ();
            GLib.File[] files = new GLib.File[GLib.strv_length (uris)];

            for (var i = 0; uris[i] != null; ++i) {
                var uri = FileUtils.sanitize_path (uris[i], working_directory);
                files[i] = GLib.File.new_for_uri (FileUtils.escape_uri (uri));
            }

            window.open_tabs.begin (files, PREFERRED, !new_window); // Ignore duplicates tabs in a existing window
        } else if (window.tab_view.n_pages == 0) {
            window.open_tabs.begin (null, PREFERRED, false);
        }

        window.present ();
        return Posix.EXIT_SUCCESS;
    }

    protected override void window_added (Gtk.Window window) {
        plugins.interface_loaded (window);
        base.window_added (window);
    }

    public override void quit_mainloop () {
        warning ("Quitting mainloop");
        Files.IconInfo.clear_caches ();

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
            ((View.Window)window).quit ();
        });

        base.quit ();
    }

    public void folder_deleted (GLib.File file) {
        unowned List<Gtk.Window> window_list = this.get_windows ();
        window_list.@foreach ((window) => {
            ((View.Window)window).folder_deleted (file);
        });
    }

    private void mount_removed_callback (VolumeMonitor monitor, Mount mount) {
        /* Notify each window */
        foreach (var window in this.get_windows ()) {
            ((View.Window)window).mount_removed (mount);
        }
    }

    private void init_schemas () {
        /* Bind settings with GOFPreferences */
        var prefs = Files.Preferences.get_default ();
        if (app_settings.settings_schema.has_key ("singleclick-select")) {
            app_settings.bind ("singleclick-select", prefs, "singleclick-select", GLib.SettingsBindFlags.DEFAULT);
        }

        Files.app_settings.bind ("show-hiddenfiles", prefs, "show-hidden-files", GLib.SettingsBindFlags.DEFAULT);

        Files.app_settings.bind ("show-remote-thumbnails",
                                   prefs, "show-remote-thumbnails", GLib.SettingsBindFlags.DEFAULT);
        Files.app_settings.bind ("show-local-thumbnails",
                                   prefs, "show-local-thumbnails", GLib.SettingsBindFlags.DEFAULT);

        Files.app_settings.bind ("date-format", prefs, "date-format", GLib.SettingsBindFlags.DEFAULT);

        gnome_interface_settings.bind ("clock-format",
                                       Files.Preferences.get_default (), "clock-format", GLib.SettingsBindFlags.GET);
        gnome_privacy_settings.bind ("remember-recent-files",
                                     Files.Preferences.get_default (), "remember-history", GLib.SettingsBindFlags.GET);
        gtk_file_chooser_settings.bind ("sort-directories-first",
                                        prefs, "sort-directories-first", GLib.SettingsBindFlags.DEFAULT);
    }
}
