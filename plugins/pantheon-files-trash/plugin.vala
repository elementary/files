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
    const GLib.ActionEntry [] TRASH_ENTRIES = {
        {"delete-all", action_delete_all},
    };

    private SimpleActionGroup trash_actions;
    private Files.SidebarInterface? sidebar;
    private uint32 trash_item_ref = 0;

    private const string RESTORE_ALL = N_("Restore All");
    private const string DELETE_ALL = N_("Empty the Trash");
    private const string RESTORE_SELECTED = N_("Restore Selected");
    private const string DELETE_SELECTED = N_("Delete Selected");

    private unowned TrashMonitor trash_monitor;
    private bool trash_is_empty = false;

    private Gee.HashMap<Files.AbstractSlot,Gtk.ActionBar> actionbars;

    private Gtk.Button delete_button;
    private Gtk.Button restore_button;

    public Trash () {
        trash_actions = new SimpleActionGroup ();
        trash_actions.add_action_entries (TRASH_ENTRIES, this);
        var delete_all_action = (GLib.SimpleAction? )(trash_actions.lookup_action ("delete-all"));

        actionbars = new Gee.HashMap<Files.AbstractSlot, Gtk.ActionBar> ();
        trash_monitor = TrashMonitor.get_default ();
        trash_monitor.notify["is-empty"].connect (() => {
            trash_is_empty = trash_monitor.is_empty;
            var to_remove = new Gee.ArrayList<Gee.Map.Entry<Files.AbstractSlot,Gtk.ActionBar>> ();
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

            delete_all_action.set_enabled (!trash_is_empty);

            var item = new Files.SidebarPluginItem () {
                icon = trash_monitor.get_icon ()
            };

            sidebar.update_plugin_item (item, trash_item_ref);
        });

        delete_all_action.set_enabled (!trash_monitor.is_empty);
    }

    public override void sidebar_loaded (Gtk.Widget widget) {
        sidebar = (Files.SidebarInterface)widget;
        var trash_model = new Menu ();
        trash_model.append (_("Permanently Delete All Trash"), "trash.delete-all");
        var item = new Files.SidebarPluginItem () {
            name = _("Trash"),
            tooltip =  Granite.markup_accel_tooltip ({"<Alt>T"}, _("Open the Trash")),
            uri = _(Files.TRASH_URI),
            icon = trash_monitor.get_icon (),
            show_spinner = false,
            action_group = trash_actions,
            action_group_namespace = "trash",
            menu_model = trash_model
        };

        trash_item_ref = sidebar.add_plugin_item (item, Files.PlaceType.BOOKMARKS_CATEGORY);
    }

    public override void update_sidebar (Gtk.Widget widget) {
        sidebar_loaded (widget);
    }

    public override void directory_loaded (Gtk.ApplicationWindow window, Files.AbstractSlot view, Files.File directory) {
        Gtk.ActionBar? actionbar = actionbars.@get (view);
        /* Ignore directories other than trash and ignore reloading trash */
        if (directory.location.get_uri_scheme () == "trash") {
            /* Only add actionbar once */
            if (actionbar == null) {
                actionbar = new Gtk.ActionBar ();
                actionbar.get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);

                restore_button = new Gtk.Button.with_label (_(RESTORE_ALL)) {
                    valign = Gtk.Align.CENTER
                };

                delete_button = new Gtk.Button.with_label (_(DELETE_ALL)) {
                    margin = 6,
                    margin_start = 0
                };

                delete_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

                var size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
                size_group.add_widget (restore_button);
                size_group.add_widget (delete_button);

                actionbar.pack_end (delete_button);
                actionbar.pack_end (restore_button);

                restore_button.clicked.connect (() => {
                    if (restore_button.label == _(RESTORE_ALL)) {
                        view.set_all_selected (true);
                    }

                    unowned GLib.List<Files.File> selection = view.get_selected_files ();
                    FileUtils.restore_files_from_trash (selection, window);
                });

                delete_button.clicked.connect (() => {
                    if (delete_button.label == _(DELETE_ALL)) {
                        var job = new Files.FileOperations.EmptyTrashJob (window);
                        job.empty_trash.begin (false);
                    } else {
                        GLib.List<GLib.File> to_delete = null;
                        foreach (Files.File gof in view.get_selected_files ()) {
                            to_delete.prepend (gof.location);
                        }

                        if (to_delete != null) {
                            Files.FileOperations.@delete.begin (to_delete, window, false);
                        }
                    }
                });

                view.selection_changed.connect_after ((files) => {
                    if (files == null) {
                        restore_button.label = _(RESTORE_ALL);
                        delete_button.label = _(DELETE_ALL);
                    } else {
                        restore_button.label = _(RESTORE_SELECTED);
                        delete_button.label = _(DELETE_SELECTED);
                    }
                });

                view.add_extra_action_widget (actionbar);
                actionbars.@set (view, actionbar);
            }

            set_actionbar (actionbar);
        } else if (actionbar != null) {  /* not showing trash directory */
            actionbar.destroy ();
            actionbars.unset (view);
        }
    }

    private void set_actionbar (Gtk.Widget bar) {
        restore_button.sensitive = !trash_is_empty;
        delete_button.sensitive = !trash_is_empty;

        bar.set_visible (!trash_is_empty);
        bar.no_show_all = trash_is_empty;
        bar.show_all ();
    }

    public void action_delete_all () {
        var parent = (Gtk.Window)(sidebar.get_ancestor (typeof (Gtk.Window)));
        var job = new Files.FileOperations.EmptyTrashJob (parent);
        job.empty_trash.begin (true); // Always confirm when enptying trash "blind" from context menu
    }
}


public Files.Plugins.Base module_init () {
    return new Files.Plugins.Trash ();
}
