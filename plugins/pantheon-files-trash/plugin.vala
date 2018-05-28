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
    private const string RESTORE_ALL = _("Restore All");
    private const string DELETE_ALL = _("Empty the Trash");
    private const string RESTORE_SELECTED = (_("Restore Selected"));
    private const string DELETE_SELECTED = (_("Delete Selected"));

    private unowned TrashMonitor trash_monitor;
    private bool trash_is_empty = false;

    private Gee.HashMap<unowned GOF.AbstractSlot,Gtk.ActionBar> actionbars = new Gee.HashMap<unowned GOF.AbstractSlot, Gtk.ActionBar>();

    private Gtk.Button delete_button;
    private Gtk.Button restore_button;

    public Trash () {
        trash_monitor = TrashMonitor.get_default ();
        trash_monitor.notify["is-empty"].connect (() => {
            trash_is_empty = trash_monitor.is_empty;
            var to_remove = new Gee.ArrayList<Gee.Map.Entry<GOF.AbstractSlot,Gtk.ActionBar>> ();
            foreach (var entry in actionbars.entries) {
                var actionbar = entry.value;
                if (actionbar.get_parent () != null) {
                    set_actionbar (actionbar);
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
                actionbar.get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);

                restore_button = new Gtk.Button.with_label (RESTORE_ALL);
                restore_button.valign = Gtk.Align.CENTER;

                delete_button = new Gtk.Button.with_label (DELETE_ALL);
                delete_button.margin = 6;
                delete_button.margin_start = 0;
                delete_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

                var size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
                size_group.add_widget (restore_button);
                size_group.add_widget (delete_button);

                actionbar.pack_end (delete_button);
                actionbar.pack_end (restore_button);

                restore_button.clicked.connect (() => {
                    if (restore_button.label == RESTORE_ALL) {
                        slot.set_all_selected (true);
                    }

                    unowned GLib.List<GOF.File> selection = slot.get_selected_files ();
                    PF.FileUtils.restore_files_from_trash (selection, window);
                });

                delete_button.clicked.connect (() => {
                    if (delete_button.label == DELETE_ALL) {
                        Marlin.FileOperations.empty_trash (delete_button);
                    } else {
                        GLib.List<GLib.File> to_delete = null;
                        foreach (GOF.File gof in slot.get_selected_files ()) {
                            to_delete.prepend (gof.location);
                        }

                        if (to_delete != null) {
                            Gtk.Window window = (Gtk.Window)(delete_button.get_ancestor (typeof (Gtk.Window)));
                            Marlin.FileOperations.@delete (to_delete, window);
                        }
                    }
                });

                slot.selection_changed.connect_after ((files) => {
                    if (files == null) {
                        restore_button.label = RESTORE_ALL;
                        delete_button.label = DELETE_ALL;
                    } else {
                        restore_button.label = RESTORE_SELECTED;
                        delete_button.label = DELETE_SELECTED;
                    }
                });

                slot.add_extra_widget (actionbar);
                actionbars.@set (slot, actionbar);
            }

            set_actionbar (actionbar);
        } else if (actionbar != null) {  /* not showing trash directory */
            actionbar.destroy ();
            actionbars.unset (slot);
        }
    }

    private void set_actionbar (Gtk.Widget bar) {
        restore_button.sensitive = !trash_is_empty;
        delete_button.sensitive = !trash_is_empty;

        bar.set_visible (!trash_is_empty);
        bar.no_show_all = trash_is_empty;
        bar.show_all ();
    }
}


public Marlin.Plugins.Base module_init () {
    return new Marlin.Plugins.Trash ();
}
