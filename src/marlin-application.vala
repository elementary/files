Marlin.Application singleton = null;

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
    }
    
    public static new Application get () {
        return new Application ();
    }
    
    public void create_window (File location, Gdk.Screen screen) {
    }
    
    public new void quit () {
    }
    
    public bool is_first_window (Gtk.Window window) {
        return false;
    }
}
