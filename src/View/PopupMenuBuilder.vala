
public class PopupMenuBuilder : Object {
    public delegate void MenuitemCallback (Gtk.MenuItem item);
    Gtk.MenuItem[] itens = {};

    public Gtk.Menu build () {
        var popupmenu = new Gtk.Menu ();
        foreach (var item in itens) {
            popupmenu.append (item);
        }

        return popupmenu;
    }

    public PopupMenuBuilder add_open (MenuitemCallback open_cb) {
        add_item (new Gtk.MenuItem.with_mnemonic (_("Open")), open_cb);
        return this;
    }

    public PopupMenuBuilder add_open_tab (MenuitemCallback open_in_new_tab_cb) {
        add_item (new Gtk.MenuItem.with_mnemonic (_("Open in New _Tab")), open_in_new_tab_cb);
        return this;
    }

    public PopupMenuBuilder add_open_window (MenuitemCallback open_in_new_window_cb) {
        add_item (new Gtk.MenuItem.with_mnemonic (_("Open in New _Window")), open_in_new_window_cb);
        return this;
    }

    public PopupMenuBuilder add_remove (MenuitemCallback remove_cb) {
        add_item (new Gtk.MenuItem.with_label (_("Remove")), remove_cb);
        return this;
    }

    public PopupMenuBuilder add_rename (MenuitemCallback rename_cb) {
        add_item (new Gtk.MenuItem.with_label (_("Rename")), rename_cb);
        return this;
    }

    public PopupMenuBuilder add_mount (MenuitemCallback mount_selected) {
        add_item (new Gtk.MenuItem.with_mnemonic (_("_Mount")), mount_selected);
        return this;
    }

    public PopupMenuBuilder add_unmount (MenuitemCallback unmount_cb) {
        add_item (new Gtk.MenuItem.with_mnemonic (_("_Unmount")), unmount_cb);
        return this;
    }

    public PopupMenuBuilder add_eject (MenuitemCallback eject_cb) {
        add_item (new Gtk.MenuItem.with_mnemonic (_("_Eject")), eject_cb);
        return this;
    }

    public PopupMenuBuilder add_property (MenuitemCallback show_drive_info_cb) {
        add_item (new Gtk.MenuItem.with_mnemonic (_("Properties")), show_drive_info_cb);
        return this;
    }

    public PopupMenuBuilder add_separator () {
        add_item (new Gtk.SeparatorMenuItem ());
        return this;
    }

    public PopupMenuBuilder add_item (Gtk.MenuItem item, MenuitemCallback? callback = null) {
        if (callback != null) {
            item.activate.connect (callback);
        }

        item.show ();
        itens += item;
        return this;
    }
}