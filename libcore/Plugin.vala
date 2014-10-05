public abstract class Marlin.Plugins.Base {
    public virtual void directory_loaded (void* data) { }
    public virtual void context_menu (Gtk.Widget? widget, List<GOF.File> files) { }
    public virtual void ui (Gtk.UIManager? widget) { }
    public virtual void update_sidebar (Gtk.Widget widget) { }
    public virtual void update_file_info (GOF.File file) { }

    public Gtk.Widget window;

    public void interface_loaded (Gtk.Widget? widget) {
        window = widget;
    }
}
