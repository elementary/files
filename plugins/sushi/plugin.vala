/***
Copyright (c) 2020 elementary LLC <https://elementary.io>

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License version 3, as published
by the Free Software Foundation.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranties of
MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program. If not, see <http://www.gnu.org/licenses/>.

Authors : Marco Betschart <elementary@marco.betschart.name>
***/

[DBus (name = "org.gnome.NautilusPreviewer", timeout = 120000)]
public interface NautilusPreviewer : GLib.Object {

    [DBus (name = "ShowFile")]
    public abstract void show_file(string uri, int32 windowHandle, bool closeIfAlreadyShown) throws GLib.Error;

    [DBus (name = "Close")]
    public abstract void close() throws GLib.Error;

    [DBus (name = "Visible")]
    public abstract bool visible { get; }

    [DBus (name = "SelectionEvent")]
    public signal void selection_event(uint direction);
}

public class Marlin.Plugins.Sushi : Marlin.Plugins.Base {

    const GLib.ActionEntry [] SUSHI_ENTRIES = {
        {"show_file", on_sushi_action_show_file_executable}
    };

    NautilusPreviewer nautilus_previewer;

    public Sushi () {
        try {
            nautilus_previewer = Bus.get_proxy_sync (BusType.SESSION, "org.gnome.NautilusPreviewer", "/org/gnome/NautilusPreviewer");
        } catch (IOError e) {
            stderr.printf ("%s\n", e.message);
        }
    }

    public override void context_menu (Gtk.Widget? widget, List<GOF.File> selected_files) {
        unowned GOF.File? selected_file = selected_files.nth_data (0);
        if (selected_file == null || widget == null) {
            return;
        }

        var menu = widget as Gtk.Menu;
        var preview_menu_item = new Gtk.MenuItem ();
        preview_menu_item.add (new Granite.AccelLabel (
            _("Preview"),
            "<Alt>space"
        ));
        preview_menu_item.action_name = "sushi.show_file";

        add_menuitem (menu, new Gtk.SeparatorMenuItem ());
        add_menuitem (menu, preview_menu_item);
    }

    private void add_menuitem (Gtk.Menu menu, Gtk.MenuItem menu_item) {
        menu.append (menu_item);
        menu_item.show ();
    }

    private void on_sushi_action_show_file_executable (GLib.SimpleAction action, GLib.Variant? param) {
        debug (@">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> on_sushi_action_show_file_executable");
    }
}

public Marlin.Plugins.Base module_init () {
    return new Marlin.Plugins.Sushi ();
}

