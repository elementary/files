namespace Marlin.View.Chrome {
    public interface Locatable : Gtk.Box {
        public signal void path_change_request (string path, Marlin.OpenFlag flag = Marlin.OpenFlag.DEFAULT);

        public abstract void set_display_path (string path);
        public abstract bool set_focussed ();
    }
}