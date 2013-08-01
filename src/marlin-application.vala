private Marlin.Application singleton = null;

public class Marlin.Application : Granite.Application {
    
    private VolumeMonitor volume_monitor;
    private Marlin.Progress.UIHandler progress_handler;
    private Marlin.Clipboard.Manager clipboard;
    private Marlin.Thumbnailer thumbnailer;
    private bool debug;
    private bool open_intab;
    
    private static int MARLIN_ACCEL_MAP_SAVE_DELAY = 15;
    private bool save_of_accel_map_requested = false;
    
    public Application () {
        base ();
        singleton = this;
        this.program_name = "Files";
    }
    
    public static new Application get () {
        if (singleton == null)
            singleton = new Marlin.Application ();
            
        return singleton;
    }
    
    public void create_window (File location, Gdk.Screen screen) {
        this.open_window (location, screen);
    }
    
    public new void quit () {
        foreach (var window in this.get_windows ())
            window.destroy ();
    }
    
    public bool is_first_window (Gtk.Window window) {
        return false;
    }
    
    public override int command_line (ApplicationCommandLine command_line) {
        bool version = false;
        bool kill_shell = false;
        string[] remaining = null;
        
        OptionEntry[] options = {};
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
        
        var context = new OptionContext (_("\n\nBrowse the file system with the file manager"));
        context.add_main_entries (options, null);
        context.add_group (Gtk.get_option_group (true));
        
        string[] args = command_line.get_arguments ();
        // We need to store args in an unowned variable for context.parse .
        unowned string[] args_aux = args;
        
        try {
            context.parse (ref args_aux);
        } catch (OptionError error) {
            printerr ("Could not parse arguments: %s\n", error.message);
            return Posix.EXIT_FAILURE;
        }
        
        if (version) {
            command_line.print ("Files " + Config.VERSION + "\n");
            return Posix.EXIT_SUCCESS;
        }
        
        if (kill_shell) {
            if (remaining != null) {
                command_line.printerr ("%s\n",
                                       _("--quit cannot be used with URIs."));
                return Posix.EXIT_FAILURE;
            } else {
                this.quit ();
                return Posix.EXIT_SUCCESS;
            }
        }

        File[] files = {};
        
        if (remaining != null) {
            foreach (string filepath in remaining) {
                var file = File.new_for_commandline_arg (filepath);
                if (file != null)
                    files += (file);
            }
        }
        
        this.open_location (files);
        
        return Posix.EXIT_SUCCESS;
    }
    
    public override void startup () {
        Granite.Services.Logger.initialize ("pantheon-files");
        Granite.Services.Logger.DisplayLevel = Granite.Services.LogLevel.INFO;
        
        message ("Welcome to Pantheon Files");
        message ("Version: %s", Config.VERSION);
        message ("Report any issues/bugs you might find to http://bugs.launchpad.net/pantheon-files");
        
        if (this.debug)
            Granite.Services.Logger.DisplayLevel = Granite.Services.LogLevel.DEBUG;
            
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
    }
    
    private void mount_removed_callback (VolumeMonitor monitor, Mount mount) {
        /* Check and see if any of the open windows are displaying contents from the unmounted mount */
        unowned List<Gtk.Window> window_list = this.get_windows ();
        File root = mount.get_root ();
        
        /* We browse each slot from each windows, loading home for current tabs and closing the rest */
        foreach (Gtk.Window window in window_list) {
            var marlin_window = window as Marlin.View.Window;
            List<Gtk.Widget> pages = marlin_window.tabs.get_children ();
            
            foreach (var page in pages) {
                var view_container = page as Marlin.View.ViewContainer;
                var slot = view_container.slot;
                var location = slot.location;
                if (location == null || location.has_prefix (root) ||
                        location.equal (root)) {
                    if (view_container == marlin_window.current_tab)
                        Signal.emit_by_name (view_container, "path-changed",
                                             File.new_for_path (Environment.get_home_dir ()));
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
    
    private void init_gtk_accels () {
        /* Load accelerator map, and register save callback */
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
        
        return true;
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
        Marlin.View.Window window;
        
        unowned List<Gtk.Window> windows = this.get_windows ();
        
        if (windows != null && windows.data != null)
            window = windows.data as Marlin.View.Window;
        else {
            window = new Marlin.View.Window (this, screen);
            this.add_window (window as Gtk.Window);
            plugins.interface_loaded (window as Gtk.Widget);
        }
        
        if (files == null) {
            var location = File.new_for_path (Environment.get_home_dir ());
            window.add_tab (location);
        } else {
            foreach (var file in files)
                window.add_tab (file);
        }
    }
    
    private void open_location (File[] files) {
        //TODO:
        /*if (this.debug)
            Granite.Services.Logger.DisplayLevel (Granite.Services.LogLevel.DEBUG);*/
        
        /* Create windows */
        if (this.open_intab)
            this.open_tabs (files, Gdk.Screen.get_default ());
        else
            this.open_windows (files, Gdk.Screen.get_default ());
        
        this.open_intab = false;
    }
    

}
