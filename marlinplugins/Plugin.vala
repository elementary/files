public abstract class Marlin.Plugins.Base
{    
    public virtual void interface_loaded(Gtk.Widget? widget) { }
    public virtual void directory_loaded(void* data) { }
    public virtual void context_menu(Gtk.Widget? widget) { }
    public virtual void ui(Gtk.UIManager? widget) { }
    public virtual void update_sidebar(Gtk.Widget sidebar) { }
    public virtual void file(List<Object> files) { }
}
