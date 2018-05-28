/***
    Copyright (c) Lucas Baudin 2011 <xapantu@gmail.com>

    Marlin is free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the
    Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Marlin is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
    See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program.  If not, see <http://www.gnu.org/licenses/>.
***/

public class Marlin.Plugins.Trash : Marlin.Plugins.Base {
    private unowned TrashMonitor trash_monitor;
    private Gee.HashMap<unowned GOF.AbstractSlot,Gtk.ActionBar> actionbars = new Gee.HashMap<unowned GOF.AbstractSlot, Gtk.ActionBar>();

    private Gtk.Button delete_button;
    private Gtk.Button restore_button;

    public Trash () {
        trash_monitor = TrashMonitor.get_default ();
        trash_monitor.notify["is-empty"].connect (() => {
            var state = trash_monitor.is_empty;
            var to_remove = new Gee.ArrayList<Gee.Map.Entry<GOF.AbstractSlot,Gtk.ActionBar>> ();
            foreach (var entry in actionbars.entries) {
                var actionbar = entry.value;
                if (actionbar.get_parent () != null) {
                    restore_button.sensitive = !state;
                    delete_button.sensitive = !state;
                    actionbar.set_visible (!state);
                } else {
                    to_remove.add (entry);
                }
            }
            foreach (var closed in to_remove) {
                closed.value.destroy ();
                actionbars.unset (closed.key);
            }
        });
    }

    public override void directory_loaded (void* user_data) {
        unowned GOF.File file = ((Object[]) user_data)[2] as GOF.File;
        assert (((Object[]) user_data)[1] is GOF.AbstractSlot);
        unowned GOF.AbstractSlot slot = ((Object[]) user_data)[1] as GOF.AbstractSlot;
        Gtk.ActionBar? actionbar = actionbars.@get (slot);
        /* Ignore directories other than trash and ignore reloading trash */
        if (file.location.get_uri_scheme () == "trash") {
            /* Only add actionbar once */
            if (actionbar == null) {
                actionbar = new Gtk.ActionBar ();
                restore_button = new Gtk.Button.with_label (_("Restore All"));
                delete_button = new Gtk.Button.with_label (_("Empty the Trash"));

                actionbar.pack_end (delete_button);
                actionbar.pack_end (restore_button);

                restore_button.clicked.connect (() => {
                    slot.set_all_selected (true);
                    unowned GLib.List<GOF.File> selection = slot.get_selected_files ();
                    PF.FileUtils.restore_files_from_trash (selection, window);
                });

                delete_button.clicked.connect (() => {
                    Marlin.FileOperations.empty_trash (delete_button);
                });

                slot.add_extra_widget (actionbar);
                actionbars.@set (slot, actionbar);
            }

            restore_button.sensitive = !trash_monitor.is_empty && file.basename == "/";
            restore_button.sensitive = !trash_monitor.is_empty && file.basename == "/";

            actionbar.show_all ();
            actionbar.set_visible (!trash_monitor.is_empty);
        } else if (actionbar != null) {
            actionbar.destroy ();
            actionbars.unset (slot);
        }
    }
}


public Marlin.Plugins.Base module_init () {
    return new Marlin.Plugins.Trash ();
}
