private Marlin.Application application_singleton = null;

public class Marlin.Application : Granite.Application {

    private VolumeMonitor volume_monitor;
    private Marlin.Progress.UIHandler progress_handler;
    private Marlin.Clipboard.Manager clipboard;
    private Marlin.Thumbnailer thumbnailer;
    private bool debug;
    private bool open_intab;

    private int MARLIN_ACCEL_MAP_SAVE_DELAY = 15;
    private bool save_of_accel_map_requested = false;

    construct {
        program_name = "Files";
        build_version = Config.VERSION;

        flags = ApplicationFlags.HANDLES_COMMAND_LINE;

        application_singleton = this;
    }

    public static new Application get () {
        if (application_singleton == null)
            application_singleton = new Marlin.Application ();

        return application_singleton;
    }

    ~Application () {
        Notify.uninit ();
    }

    public override void startup () {
        base.startup ();

        Granite.Services.Logger.initialize ("pantheon-files");
        if (this.debug)
            Granite.Services.Logger.DisplayLevel = Granite.Services.LogLevel.DEBUG;
        else
            Granite.Services.Logger.DisplayLevel = Granite.Services.LogLevel.INFO;
        message ("Report any issues/bugs you might find to http://bugs.launchpad.net/pantheon-files");

        init_schemas ();
        init_gtk_accels ();

        Gtk.IconTheme.get_default ().notify["changed"].connect (() => {
            Marlin.IconInfo.clear_caches ();
        });

        Notify.init (Config.GETTEXT_PACKAGE);
        this.progress_handler = new Marlin.Progress.UIHandler ();
        this.clipboard = new Marlin.Clipboard.Manager.get_for_display (Gdk.Display.get_default ());
        this.thumbnailer = Marlin.Thumbnailer.get ();

        tags = new Marlin.View.Tags ();

        plugins = new Marlin.PluginManager (Config.PLUGIN_DIR);
        plugins.load_plugins ();

        /* TODO move the volume manager here? */
        /* TODO-gio: This should be using the UNMOUNTED feature of GFileMonitor instead */
        this.volume_monitor = VolumeMonitor.get ();
        this.volume_monitor.mount_removed.connect (mount_removed_callback);

#if HAVE_UNITY
        Unity.QuicklistHandler.singleton = Unity.QuicklistHandler.get_singleton ();
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
        bool version = false;
        bool kill_shell = false;

        OptionEntry[] options = new OptionEntry [6];
        options [0] = { "version", '\0', 0, OptionArg.NONE, ref version,
                        N_("Show the version of the program."), null };
        options [1] = { "tab", 't', 0, OptionArg.NONE, ref this.open_intab,
                        N_("Open uri(s) in new tab"), null };
        options [2] = { "quit", 'q', 0, OptionArg.NONE, ref kill_shell,
                        N_("Quit Files."), null };
        options [3] = { "debug", 'd', 0, OptionArg.NONE, ref this.debug,
                        N_("Enable debug logging"), null };
        // "" = G_OPTION_REMAINING
        options [4] = { "", 0, 0, OptionArg.STRING_ARRAY, ref remaining,
                        null, N_("[URI...]") };
        options [5] = { null };

        var context = new OptionContext (_("\n\nBrowse the file system with the file manager"));
        context.add_main_entries (options, null);
        context.add_group (Gtk.get_option_group (true));

        string[] args = cmd.get_arguments ();
        /* We need to store args in an unowned variable for context.parse */
        unowned string[] args_aux = args;

        try {
            context.parse (ref args_aux);
        } catch (OptionError error) {
            printerr ("Could not parse arguments: %s\n", error.message);
            return Posix.EXIT_FAILURE;
        }

        if (version) {
            cmd.print ("Files " + Config.VERSION + "\n");
            return Posix.EXIT_SUCCESS;
        }

        if (kill_shell) {
            if (remaining != null) {
                cmd.printerr ("%s\n",
                                       _("--quit cannot be used with URIs."));
                return Posix.EXIT_FAILURE;
            } else {
                this.quit ();
                return Posix.EXIT_SUCCESS;
            }
        }

        File[] files = null;
        
        /* Convert remaining args to GFiles */
        if (remaining != null) {
            foreach (string filepath in remaining) {
                var file = File.new_for_commandline_arg (filepath);
                if (file != null)
                    files += (file);
            }
        }

        /* Open application */
        this.open_locations (files);

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
        this.open_window (location, screen);
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
                var slot = view_container.slot;
                var location = slot.location;
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

        Gtk.AccelMap.get ().notify["changed"].connect (() => {
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


    private void open_window (File location, Gdk.Screen screen) {
        var window = new Marlin.View.Window (this, screen);
        plugins.interface_loaded (window as Gtk.Widget);
        this.add_window (window as Gtk.Window);
        window.set_size_request (300, 250);
        window.add_tab (location);
    }

    private void open_windows (File[]? files, Gdk.Screen screen) {
        if (files == null) {
            /* Open a window pointing at the default location. */
            var location = File.new_for_path (Environment.get_home_dir ());
            open_window (location, screen);
        } else {
            /* Open windows at each requested location. */
            foreach (var file in files)
                open_window (file, screen);
        }
    }

    private void open_tabs (File[]? files, Gdk.Screen screen) {
        Marlin.View.Window window = null;

        unowned List<Gtk.Window> windows = this.get_windows ();

        /* Get the first windows if any */
        if (windows != null && windows.data != null)
            window = windows.data as Marlin.View.Window;
        else {
            window = new Marlin.View.Window (this, screen);
            this.add_window (window as Gtk.Window);
            plugins.interface_loaded (window as Gtk.Widget);
        }

        if (files == null) {
            /* Open a tab pointing at the default location */
            var location = File.new_for_path (Environment.get_home_dir ());
            window.add_tab (location);
        } else {
            /* Open tabs at each requested location */
            foreach (var file in files)
                window.add_tab (file);
        }
    }

    private void open_locations (File[] files) {
        if (this.open_intab)
            this.open_tabs (files, Gdk.Screen.get_default ());
        else
            this.open_windows (files, Gdk.Screen.get_default ());

        this.open_intab = false;
    }
    
    public bool is_first_window (Gtk.Window window) {
        unowned List<Gtk.Window> list = this.get_windows ();
        list = list.last ();

        return (window == list.data);
    }
}
