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

public class Files.Plugins.Trash : Files.Plugins.Base {
    private const string RESTORE_ALL = N_("Restore All");
    private const string DELETE_ALL = N_("Empty the Trash");
    private const string RESTORE_SELECTED = N_("Restore Selected");
    private const string DELETE_SELECTED = N_("Delete Selected");

    private unowned TrashMonitor trash_monitor;
    private bool trash_is_empty = false;

    private Gee.HashMap<Files.SlotContainerInterface,Gtk.ActionBar> actionbars;

    private Gtk.Button delete_button;
    private Gtk.Button restore_button;

    public Trash () {
        actionbars = new Gee.HashMap<Files.SlotContainerInterface, Gtk.ActionBar> ();
        trash_monitor = TrashMonitor.get_default ();
        trash_monitor.notify["is-empty"].connect (() => {
            trash_is_empty = trash_monitor.is_empty;
            var to_remove = new Gee.ArrayList<Gee.Map.Entry<Files.SlotContainerInterface,Gtk.ActionBar>> ();
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

    public override void directory_loaded (
        Files.SlotContainerInterface multi_slot, Files.File directory
    ) {
        Gtk.ActionBar? actionbar = actionbars.@get (multi_slot);
        var slot = multi_slot.get_slot ();
        var window = (Gtk.ApplicationWindow)multi_slot.get_ancestor (
            typeof (Gtk.ApplicationWindow)
        );
        /* Ignore directories other than trash and ignore reloading trash */
        if (directory.location.get_uri () == "trash:///") {
            /* Only add actionbar once */
            if (actionbar == null) {
                actionbar = new Gtk.ActionBar ();
                //TODO Add suitable Gtk4 style class

                restore_button = new Gtk.Button.with_label (_(RESTORE_ALL)) {
                    valign = Gtk.Align.CENTER
                };

                delete_button = new Gtk.Button.with_label (_(DELETE_ALL)) {
                    margin_start = 0,
                    margin_end = 6,
                    margin_top = 6,
                    margin_bottom = 6
                };
                delete_button.add_css_class (Granite.STYLE_CLASS_DESTRUCTIVE_ACTION);

                var size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
                size_group.add_widget (restore_button);
                size_group.add_widget (delete_button);

                actionbar.pack_end (delete_button);
                actionbar.pack_end (restore_button);

                restore_button.clicked.connect (() => {
                    if (restore_button.label == _(RESTORE_ALL)) {
                        slot.set_all_selected (true);
                    }

                    GLib.List<Files.File> selection = slot.get_selected_files ();
                    FileUtils.restore_files_from_trash (selection, window);
                });

                delete_button.clicked.connect (() => {
                    if (delete_button.label == _(DELETE_ALL)) {
                        var job = new Files.FileOperations.EmptyTrashJob (window);
                        job.empty_trash.begin ();
                    } else {
                        GLib.List<GLib.File> to_delete = null;
                        foreach (Files.File gof in slot.get_selected_files ()) {
                            to_delete.prepend (gof.location);
                        }

                        if (to_delete != null) {
                            Files.FileOperations.@delete.begin (to_delete, window, false);
                        }
                    }
                });

                slot.selection_changed.connect_after ((files) => {
                    if (files == null) {
                        restore_button.label = _(RESTORE_ALL);
                        delete_button.label = _(DELETE_ALL);
                    } else {
                        restore_button.label = _(RESTORE_SELECTED);
                        delete_button.label = _(DELETE_SELECTED);
                    }
                });

                multi_slot.add_extra_action_widget (actionbar);
                actionbars.@set (multi_slot, actionbar);
            }

            set_actionbar (actionbar);
        } else if (actionbar != null) {  /* not showing trash directory */
            actionbar.unparent ();
            actionbars.unset (multi_slot);
            actionbar.destroy ();
        }
    }

    private void set_actionbar (Gtk.Widget bar) {
        restore_button.sensitive = !trash_is_empty;
        delete_button.sensitive = !trash_is_empty;
        bar.set_visible (!trash_is_empty);
    }
}


public Files.Plugins.Base module_init () {
    return new Files.Plugins.Trash ();
}
