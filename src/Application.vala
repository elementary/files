/***
    Copyright (c) 1999, 2000 Red Hat, Inc.
    Copyright (c) 2000, 2001 Eazel, Inc.
    Copyright (c) 2013 Julián Unrrein <junrrein@gmail.com>
    Copyright (c) 2015-2017 elementary LLC (http://launchpad.net/elementary)  

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
    private Marlin.ClipboardManager clipboard;
    private Gtk.RecentManager recent;

    private const int MARLIN_ACCEL_MAP_SAVE_DELAY = 15;
    private const uint MAX_WINDOWS = 25;

    public int window_count { get; private set; }

    bool quitting = false;

    construct {
        /* Needed by Glib.Application */
        this.application_id = Marlin.APP_ID;  //Ensures an unique instance.
        this.flags = ApplicationFlags.HANDLES_COMMAND_LINE;

        /* Needed by Granite.Application */
        this.program_name = _(Marlin.APP_TITLE);
        this.exec_name = APP_NAME;
        this.build_version = Config.VERSION;

        this.app_copyright = Marlin.COPYRIGHT;
        this.app_years = Marlin.APP_YEARS;
        this.about_license_type = Gtk.License.GPL_3_0;
        this.app_icon = Marlin.ICON_APP_LOGO;

        this.main_url = Marlin.LAUNCHPAD_URL;
        this.bug_url = Marlin.BUG_URL;
        this.help_url = Marlin.HELP_URL;
        this.translate_url = Marlin.TRANSLATE_URL;

        this.about_authors = Marlin.AUTHORS;
        this.about_documenters = { null };
        this.about_artists = Marlin.ARTISTS;
        this.about_comments = _(Marlin.COMMENTS);
        this.about_translators = Marlin.TRANSLATORS;

        application_singleton = this;
    }

    public static new unowned Application get () {
        if (application_singleton == null)
            application_singleton = new Marlin.Application ();

        return application_singleton;
    }

    public override void startup () {
        base.startup ();

        if (Granite.Services.Logger.DisplayLevel != Granite.Services.LogLevel.DEBUG)
            Granite.Services.Logger.DisplayLevel = Granite.Services.LogLevel.INFO;

        message ("Report any issues/bugs you might find to http://bugs.launchpad.net/pantheon-files");

        init_schemas ();

        Gtk.IconTheme.get_default ().changed.connect (() => {
            Marlin.IconInfo.clear_caches ();
        });

        progress_handler = new Marlin.Progress.UIHandler (this);

        this.clipboard = Marlin.ClipboardManager.get_for_display ();
        this.recent = new Gtk.RecentManager ();

        plugins = new Marlin.PluginManager (Config.PLUGIN_DIR);

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
        if (create_new_window) {
            var win = create_window (null);
            win.add_tab (); /* Default tab */
        } else if (open_in_tab) {
            open_tabs (files);
        } else {
            open_windows (files);
        }
        return Posix.EXIT_SUCCESS;
    }

    public override void quit_mainloop () {
        warning ("Quitting mainloop");
        Marlin.IconInfo.clear_caches ();

        base.quit_mainloop ();
    }

    public new void quit () {
        /* Protect against holding Ctrl-Q down */
        if (quitting)
            return;

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
        Preferences.settings = new Settings ("org.pantheon.files.preferences");
        Preferences.marlin_icon_view_settings = new Settings ("org.pantheon.files.icon-view");
        Preferences.marlin_list_view_settings = new Settings ("org.pantheon.files.list-view");
        Preferences.marlin_column_view_settings = new Settings ("org.pantheon.files.column-view");

        /* Bind settings with GOFPreferences */
        Preferences.settings.bind ("show-hiddenfiles",
                                   GOF.Preferences.get_default (), "show-hidden-files", GLib.SettingsBindFlags.DEFAULT);
        Preferences.settings.bind ("show-remote-thumbnails",
                                   GOF.Preferences.get_default (), "show-remote-thumbnails", GLib.SettingsBindFlags.DEFAULT);
        Preferences.settings.bind ("confirm-trash",
                                   GOF.Preferences.get_default (), "confirm-trash", GLib.SettingsBindFlags.DEFAULT);
        Preferences.settings.bind ("date-format",
                                   GOF.Preferences.get_default (), "date-format", GLib.SettingsBindFlags.DEFAULT);
        Preferences.settings.bind ("force-icon-size",
                                   GOF.Preferences.get_default (), "force-icon-size", GLib.SettingsBindFlags.DEFAULT);
    }

    private void open_windows (File[]? files) {
        if (files == null)
            open_tabs (null); /* open_tabs () will restore saved tabs or default tab depending on preference */ 
        else {
            /* Open windows with tab at each requested location. */
            foreach (var file in files) {
                create_window (file);
            }
        }
    }

    /* All window creation should be done via this function */
    public Marlin.View.Window? create_window (File? location,
                                             Marlin.ViewMode viewmode = Marlin.ViewMode.PREFERRED,
                                             int x = -1, int y = -1) {
        if (this.get_windows ().length () >= MAX_WINDOWS) {
            return null;
        }

        Marlin.View.Window win;
        Gdk.Rectangle? new_win_rect = null;
        Gdk.Screen screen = Gdk.Screen.get_default ();
        var aw = this.get_active_window ();
        if (aw != null) {
            /* This is not the first window - determine size and position of new window */            
            int w, h;
            aw.get_size (out w, out h);
            /* Calculate difference between the visible width of the window and the width returned by Gtk+,
             * which might include client side decorations (shadow) in some versions (bug 756618).
             * Assumes top_menu stretches full visible width. */
            var tm_aw = ((Marlin.View.Window)aw).top_menu.get_allocated_width ();
            int shadow_width = (w - tm_aw) / 2;
            shadow_width -= 10; //Allow a small gap between adjacent windows
            screen = aw.get_screen ();
            if (x <= 0 || y <= 0) {
                /* Place holder for auto-tiling code. If missing then new window will be placed
                 * at the default position (centre of screen) */
            } else { /* New window is a dropped tab */
                /* Move new window so that centre of upper edge just inside the window is at mouse
                 * cursor position. This makes it easier for used to readjust window position with mouse if required.
                 */
                x -= (shadow_width + w / 2);
                y -= (shadow_width + 6);
                new_win_rect = {x, y, w, h};
            }
        } 

        /* New window will not size or show itself if new_win_rect is not null */
        win = new Marlin.View.Window (this, screen, new_win_rect == null);
        this.add_window (win as Gtk.Window);
        plugins.interface_loaded (win as Gtk.Widget);

        if (location != null) {
            win.add_tab (location, viewmode);
        }

        if (new_win_rect != null) {
            move_resize_window (win, new_win_rect);
            win.show ();
        }

        return win;
    }

    private void open_tabs (File[]? files, Gdk.Screen screen = Gdk.Screen.get_default ()) {
        Marlin.View.Window window = null;

        /* Get the first window, if any, else create a new window */
        if (windows_exist ()) {
            window = (this.get_windows ()).data as Marlin.View.Window;
        } else {
            window = create_window (null); /* Do not add a tab on creation */
            if (window == null) { /* Maximum number of windows reached */
                return;
            }
        }
        if (files == null) {
            /* Restore session if settings allow */
            if (!Preferences.settings.get_boolean ("restore-tabs") || window.restore_tabs () < 1) {
                /* Open a tab pointing at the default location if no tabs restored*/
                var location = File.new_for_path (Environment.get_home_dir ());
                window.add_tab (location, Marlin.ViewMode.PREFERRED);
            }
        } else {
            /* Open tabs at each requested location */
            foreach (var file in files)
                window.add_tab (file, Marlin.ViewMode.PREFERRED);
        }
    }

    private bool windows_exist () {
        unowned List<weak Gtk.Window> windows = this.get_windows ();
        return (windows != null && windows.data != null);
    }

    private void move_resize_window (Gtk.Window win, Gdk.Rectangle? rect) {
        if (rect == null) {
            return;
        }

        if (rect.x > 0 && rect.y > 0) {
            win.move (rect.x, rect.y);
        }
        if (rect.width > 0 && rect.height > 0) {
            win.resize (rect.width, rect.height);
        }
        win.show ();
    }
}
