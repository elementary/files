/*
 * Copyright (C) Lucas Baudin 2011 <xapantu@gmail.com>
 *
 * Marlin is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Marlin is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public class Marlin.Plugins.Trash : Marlin.Plugins.Base {
    private TrashMonitor trash_monitor;
    private Gee.HashMap<GOF.AbstractSlot,Gtk.InfoBar> infobars = new Gee.HashMap<GOF.AbstractSlot, Gtk.InfoBar>();

    public Trash () {
        trash_monitor = TrashMonitor.get ();
        trash_monitor.trash_state_changed.connect ((state) => {
            /* state true = empty trash */
            var to_remove = new Gee.ArrayList<Gee.Map.Entry<GOF.AbstractSlot,Gtk.InfoBar>> ();
            foreach (var entry in infobars.entries) {
                var infobar = entry.value;
                if (infobar.get_parent () != null) {
                    infobar.set_response_sensitive (0, !state);
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
        GOF.File file = ((Object[]) user_data)[2] as GOF.File;
        assert (((Object[]) user_data)[1] is GOF.AbstractSlot);
        GOF.AbstractSlot slot = ((Object[]) user_data)[1] as GOF.AbstractSlot;

        /* Ignore directories other than trash and ignore reloading trash */
        if (file.location.get_uri_scheme () == "trash") {
            /* Only add infobar once */
            if (!infobars.has_key (slot)) {

                var infobar = new Gtk.InfoBar ();
                (infobar.get_content_area () as Gtk.Box).add (new Gtk.Label (_("These items may be deleted by emptying the trash.")));
                infobar.add_button (_("Empty the Trash"), 0);
                infobar.response.connect ((self, response) => {
                    Marlin.FileOperations.empty_trash (self);
                });
                infobar.set_message_type (Gtk.MessageType.INFO);
                infobar.set_response_sensitive (0, !TrashMonitor.is_empty ());
                slot.add_extra_widget (infobar);
                infobar.show_all ();
                infobar.set_visible (!TrashMonitor.is_empty ());
                infobars.@set (slot, infobar);
            }
        } else {
            var infobar = infobars.@get (slot);
            if (infobar != null) {
                infobar.destroy ();
                infobars.unset (slot);
            }
        }
    }
}


public Marlin.Plugins.Base module_init () {
    return new Marlin.Plugins.Trash ();
}
