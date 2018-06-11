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
    private Gee.HashMap<unowned GOF.AbstractSlot,Gtk.InfoBar> infobars = new Gee.HashMap<unowned GOF.AbstractSlot, Gtk.InfoBar>();

    public Trash () {
        trash_monitor = TrashMonitor.get_default ();
        trash_monitor.notify["is-empty"].connect (() => {
            var state = trash_monitor.is_empty;
            var to_remove = new Gee.ArrayList<Gee.Map.Entry<GOF.AbstractSlot,Gtk.InfoBar>> ();
            foreach (var entry in infobars.entries) {
                var infobar = entry.value;
                if (infobar.get_parent () != null) {
                    infobar.set_response_sensitive (0, !state);
                    infobar.set_response_sensitive (1, !state);
                    infobar.set_visible (!state);
                } else {
                    to_remove.add (entry);
                }
            }
            foreach (var closed in to_remove) {
                closed.value.destroy ();
                infobars.unset (closed.key);
            }
        });
    }

    public override void directory_loaded (void* user_data) {
        unowned GOF.File file = ((Object[]) user_data)[2] as GOF.File;
        assert (((Object[]) user_data)[1] is GOF.AbstractSlot);
        unowned GOF.AbstractSlot slot = ((Object[]) user_data)[1] as GOF.AbstractSlot;
        Gtk.InfoBar? infobar = infobars.@get (slot);
        /* Ignore directories other than trash and ignore reloading trash */
        if (file.location.get_uri_scheme () == "trash") {
            /* Only add infobar once */
            if (infobar == null) {
                infobar = new Gtk.InfoBar ();
                (infobar.get_content_area () as Gtk.Box).add (new Gtk.Label (null));
                infobar.add_button (_("Restore All"), 0);
                infobar.add_button (_("Empty the Trash"), 1);

                infobar.response.connect ((self, response) => {
                    switch (response) {
                        case 0:
                            slot.set_all_selected (true);
                            unowned GLib.List<GOF.File> selection = slot.get_selected_files ();
                            PF.FileUtils.restore_files_from_trash (selection, window);
                            break;
                        case 1:
                            Marlin.FileOperations.empty_trash (self);
                            break;
                    }
                });

                slot.add_extra_widget (infobar);
                infobars.@set (slot, infobar);
            }
            infobar.set_message_type (file.basename == "/" ? Gtk.MessageType.INFO : Gtk.MessageType.WARNING);
            string msg;
            if (file.basename == "/")
                msg = _("These items may be restored or deleted from the trash.");
            else
                msg = _("Cannot restore or delete unless in root folder");

            foreach (Gtk.Widget w in (infobar.get_content_area ()).get_children ()) {
                if (w is Gtk.Label)
                    (w as Gtk.Label).set_text (msg);
            }

            infobar.set_response_sensitive (0, !trash_monitor.is_empty && file.basename == "/");
            infobar.set_response_sensitive (1, !trash_monitor.is_empty && file.basename == "/");
            infobar.show_all ();
            infobar.set_visible (!trash_monitor.is_empty);
        } else if (infobar != null) {
            infobar.destroy ();
            infobars.unset (slot);
        }
    }
}


public Marlin.Plugins.Base module_init () {
    return new Marlin.Plugins.Trash ();
}
