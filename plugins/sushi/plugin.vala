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
    public abstract void show_file (string uri, int32 windowHandle, bool closeIfAlreadyShown) throws GLib.Error; //vala-lint=naming-convention

    [DBus (name = "Close")]
    public abstract void close () throws GLib.Error;

    [DBus (name = "Visible")]
    public abstract bool visible { get; }

    [DBus (name = "SelectionEvent")]
    public signal void selection_event (uint direction);
}

public class Marlin.Plugins.Sushi : Marlin.Plugins.Base {

    const string SUSHI_ACCEL = "<Ctrl>space";
    const string SUSHI_SHOW_FILE_TARGET = "SushiShowFile";
    const string SUSHI_SELECT_NEXT_TARGET = "SushiShowNext";
    NautilusPreviewer nautilus_previewer;
    unowned List<GOF.File> selected_files = null;
    unowned List<GOF.File> selected_index;

    public Sushi () {
        try {
            nautilus_previewer = Bus.get_proxy_sync (BusType.SESSION, "org.gnome.NautilusPreviewer", "/org/gnome/NautilusPreviewer");

            var app = (Gtk.Application)(Application.get_default ());
            var action = "app." + Marlin.PluginManager.MESSAGE_PLUGIN_ACTION + "::" + SUSHI_SHOW_FILE_TARGET;
            app.set_accels_for_action (action, {SUSHI_ACCEL});

            nautilus_previewer.selection_event.connect ((direction) => {
                switch (direction) {
                    case Gtk.DirectionType.LEFT:
                            unowned List<GOF.File> prev = selected_index.prev;
                            if (prev != null) {
                                selected_index = prev;
                                show_file (selected_index);
                            }
                        break;
                    case Gtk.DirectionType.RIGHT:
                            unowned List<GOF.File> next = selected_index.next;
                            if (next != null) {
                                selected_index = next;
                                show_file (selected_index);
                            }
                        break;
                    default:
                        break;
                }
            });

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
            SUSHI_ACCEL
        ));

        preview_menu_item.activate.connect (() => {
            var app = (Gtk.Application)(Application.get_default ());
            app.activate_action ("message-plugin", new Variant ("s", SUSHI_SHOW_FILE_TARGET));
        });

        plugins.menuitem_references.add (preview_menu_item);

        add_menuitem (menu, new Gtk.SeparatorMenuItem ());
        add_menuitem (menu, preview_menu_item);
    }

    private void add_menuitem (Gtk.Menu menu, Gtk.MenuItem menu_item) {
        menu.append (menu_item);
        menu_item.show ();
    }

    public override void message_plugin (string data, List<GOF.File> selected) {
        if (data == SUSHI_SHOW_FILE_TARGET && selected != null) {
            selected_files = selected;
            selected_index = selected_files.first ();
            show_file (selected_index);
        }
    }

    private void show_file (List<GOF.File> selected) {
        GOF.File gof = selected.data;
        try {
            nautilus_previewer.show_file (gof.uri, 0, true);
        } catch (Error e) {
            warning ("Error previewing: %s", e.message);
        }
    }
}

public Marlin.Plugins.Base module_init () {
    return new Marlin.Plugins.Sushi ();
}
