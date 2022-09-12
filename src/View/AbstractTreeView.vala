/***
    Copyright (c) 2015-2022 elementary LLC <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/

/* Implement common features of ColumnView and ListView */
public abstract class Files.AbstractTreeView : Files.AbstractDirectoryView {
    protected TreeView tree;
    protected Files.IconRenderer icon_renderer;
    protected Files.TextRenderer? name_renderer = null;
    protected Files.File? active_file = null;

    public Files.ListModel model { get; construct; }
    protected Gtk.TreeViewColumn name_column;

    protected AbstractTreeView (View.Slot _slot) {
        base (_slot);
    }

    construct {
        model = new Files.ListModel ();
        model.sort_column_changed.connect (() => {
            model.get_sort_column_id (out sort_column_id, out sort_order);
            on_sort_column_changed ();
        });

        model.set_should_sort_directories_first (Files.Preferences.get_default ().sort_directories_first);
        model.row_deleted.connect (on_row_deleted);
        // /* Sort order of model is set after loading */

        tree = new TreeView () {
            model = model,
            headers_visible = false,
            activate_on_single_click = true
        };

        var selection = tree.get_selection ();
        selection.set_mode (Gtk.SelectionMode.MULTIPLE);
        // selection.changed.connect (() => {
        // warning ("selection changed - %u selected", selection.get_selected_rows (null).length ());
        // });

        // Does not currently work due to upstream issue
        // https://gitlab.gnome.org/GNOME/gtk/-/issues/3985
        tree.set_rubber_banding (true);

        tree.row_activated.connect ((path, column) => {
            Gtk.TreeIter? iter;
            model.get_iter (out iter, path);
            model.@get (iter, Files.ColumnID.FILE_COLUMN, out active_file, -1);
            // Active directories with single click on name column
            if (active_file.is_directory && column == name_column) {
                activate_file (active_file);
                active_file = null;
            }
        });

        name_renderer = new Files.TextRenderer (ViewMode.LIST);
        name_renderer.editable = false;
        name_renderer.edited.connect (on_name_edited);
        name_renderer.editing_canceled.connect (on_name_editing_canceled);
        name_renderer.editing_started.connect (on_name_editing_started);
        name_renderer.@set ("wrap-width", -1);
        name_renderer.@set ("zoom-level", ZoomLevel.NORMAL);
        name_renderer.@set ("ellipsize-set", true);
        name_renderer.@set ("ellipsize", Pango.EllipsizeMode.END);
        name_renderer.xalign = 0.0f;
        name_renderer.yalign = 0.5f;

        icon_renderer = new IconRenderer () {
            show_emblems = false
        };

        var emblem_renderer = new Files.EmblemRenderer () {
            yalign = 0.5f
        };

        name_column = new Gtk.TreeViewColumn () {
            sort_column_id = Files.ColumnID.FILENAME,
            expand = true,
            resizable = true
        };
        name_column.pack_start (icon_renderer, false);
        name_column.set_attributes (icon_renderer,
                                    "file", Files.ColumnID.FILE_COLUMN);

        name_column.pack_start (name_renderer, true);
        name_column.set_attributes (name_renderer,
                                    "text", Files.ColumnID.FILENAME,
                                    "file", Files.ColumnID.FILE_COLUMN,
                                    "background", Files.ColumnID.COLOR);

        name_column.pack_start (emblem_renderer, false);
        name_column.set_attributes (emblem_renderer,
                                    "file", Files.ColumnID.FILE_COLUMN);

        tree.append_column (name_column);

        connect_tree_signals ();
        tree.realize.connect ((w) => {
            tree.grab_focus ();
            tree.columns_autosize ();
        });

        view = tree;

        /* Set up eventcontrollers for view widget */
        var view_primary_click_controller = new Gtk.GestureClick ();
        view_primary_click_controller.set_propagation_phase (Gtk.PropagationPhase.TARGET);
        view_primary_click_controller.set_button (Gdk.BUTTON_PRIMARY);
        view_primary_click_controller.pressed.connect (on_view_press);
        view.add_controller (view_primary_click_controller);
    }

    ~AbstractTreeView () {
        debug ("ATV destruct");
    }

    protected virtual void on_view_press (Gtk.GestureClick controller, int n_press, double x, double y) {
        // Activate non-directory files on double click (directories already activated natively)
        if (n_press == 2 && active_file != null) {
            activate_file (active_file);
            active_file = null;
        }
    }

    protected override void add_file (
        Files.File file, Directory dir, bool select = true, bool sorted = false
    ) {
        model.add_file (file, dir);

        if (select) { /* This true once view finished loading */
            Gtk.TreeIter iter;
            if (!model.get_first_iter_for_file (file, out iter)) {
                return; /* file not in model */
            }

            var path = model.get_path (iter);
            select_path (path); /* Cursor does not follow */
        }
    }

    protected override void clear () {
        model.row_deleted.disconnect (on_row_deleted);
        model.clear ();
        all_selected = false;
        model.row_deleted.connect (on_row_deleted);
    }

    protected void connect_tree_signals () {
        tree.get_selection ().changed.connect (on_view_selection_changed);
    }
    protected void disconnect_tree_signals () {
        tree.get_selection ().changed.disconnect (on_view_selection_changed);
    }


    public override void change_zoom_level () {
        model.icon_size = icon_size;
        icon_renderer.zoom_level = zoom_level;
        name_renderer.zoom_level = zoom_level;
        tree.columns_autosize ();
    }

    public void highlight_path (Gtk.TreePath? path) {
        tree.set_drag_dest_row (path, Gtk.TreeViewDropPosition.INTO_OR_AFTER);
    }

    public Gtk.TreePath? get_path_at_pos (int x, int y) {
        Gtk.TreePath? path = null;

        if (x >= 0 && y >= 0 && tree.get_dest_row_at_pos (x, y, out path, null)) {
            return path;
        } else {
            return null;
        }
    }

    public override void tree_select_all () {
        tree.get_selection ().select_all ();
    }

    public override void tree_unselect_all () {
        tree.get_selection ().unselect_all ();
    }

    /* Avoid using this function with "cursor_follows = true" to select large numbers of files one by one
     * It would take an exponentially long time. Use "select_files" function in parent class.
     */
    public void select_path (Gtk.TreePath? path, bool cursor_follows = false) {
        if (path != null) {
            var selection = tree.get_selection ();
            selection.select_path (path);
            if (cursor_follows) {
                /* Unlike for IconView, set_view_cursor unselects previously selected paths (Gtk bug?),
                 * so we have to remember them and reselect afterwards */
                GLib.List<Gtk.TreePath> selected_paths = null;
                selection.selected_foreach ((m, p, i) => {
                    selected_paths.prepend (p);
                });
                /* Ensure cursor follows last selection */
                tree.set_cursor (path, null, false); /* This selects path but unselects rest! */

                selected_paths.@foreach ((p) => {
                   selection.select_path (p);
                });
            }
        }
    }
    public void unselect_path (Gtk.TreePath? path) {
// warning ("UNSELECT PATH");
        if (path != null) {
            tree.get_selection ().unselect_path (path);
        }
    }

    public bool path_is_selected (Gtk.TreePath? path) {
        if (path != null) {
            return tree.get_selection ().path_is_selected (path);
        } else {
            return false;
        }
    }

    public GLib.List<Gtk.TreePath> get_selected_paths () {
        return tree.get_selection ().get_selected_rows (null);
    }

    protected override void invert_selection () {
        GLib.List<Gtk.TreeRowReference> selected_row_refs = null;
        foreach (Gtk.TreePath p in get_selected_paths ()) {
            selected_row_refs.prepend (new Gtk.TreeRowReference (model, p));
        }

        select_all ();
        if (selected_row_refs != null) {
            foreach (Gtk.TreeRowReference r in selected_row_refs) {
                var p = r.get_path ();
                if (p != null) {
                    unselect_path (p);
                }
            }
        }
    }

    public bool get_visible_range (out Gtk.TreePath? start_path,
                                            out Gtk.TreePath? end_path) {
        start_path = null;
        end_path = null;
        return tree.get_visible_range (out start_path, out end_path);
    }

    protected override uint select_gof_files (
        Gee.LinkedList<Files.File> files_to_select, GLib.File? focus_file
    ) {
        Gtk.TreeIter? iter;
        var count = 0;
        foreach (Files.File f in files_to_select) {
            /* Not all files selected in previous view  (e.g. expanded tree view) may appear in this one. */
            if (model.get_first_iter_for_file (f, out iter)) {
                count++;
                var path = model.get_path (iter);
                /* Cursor follows if matches focus location*/
                select_path (path, focus_file != null && focus_file.equal (f.location));
            }
        }

        return count;
    }

    public override void focus_first_for_empty_selection (bool select) {
        if (selected_files == null) {
            set_cursor_timeout_id = Idle.add_full (GLib.Priority.LOW, () => {
                if (!tree_frozen) {
                    set_cursor_timeout_id = 0;
                    set_view_cursor (new Gtk.TreePath.from_indices (0), false, select, true);
                    return GLib.Source.REMOVE;
                } else {
                    return GLib.Source.CONTINUE;
                }
            });
        }
    }

    protected override uint get_selected_files_from_model (out GLib.List<Files.File> selected_files) {
        uint count = 0;

        GLib.List<Files.File> list = null;
        tree.get_selection ().selected_foreach ((model, path, iter) => {
            Files.File? file; /* can be null if click on blank row in list view */
            model.@get (iter, Files.ColumnID.FILE_COLUMN, out file, -1);
            if (file != null) {
                list.prepend ((owned) file);
                count++;
            }
        });

        selected_files = (owned)list;
        return count;
    }

    protected override bool view_has_focus () {
        return tree.has_focus;
    }

    protected override uint get_event_position_info (double x, double y) {
        Gtk.TreePath? p = null;
        unowned Gtk.TreeViewColumn? c = null;
        uint zone;
        int cx, cy, depth;
        // Gtk.TreePath? path = null;

        /* Determine whether there whitespace at this point.  Note: this function returns false when the
         * position is on the edge of the cell, even though this appears to be blank. We
         * deal with this below. */
        var is_blank = tree.is_blank_at_pos ((int)x, (int)y, null, null, null, null);

        tree.get_path_at_pos ((int)x, (int)y, out p, out c, out cx, out cy);
        click_path = p;
        depth = p != null ? p.get_depth () : 0;

        /* Determine whether on edge of cell and designate as blank */
        Gdk.Rectangle rect;
        tree.get_cell_area (p, c, out rect);
        int height = rect.height;

        is_blank = is_blank || cy < 5 || cy > height - 5;

        /* Do not allow rubberbanding to start except on a row in tree view */
        zone = (p != null && is_blank ? ClickZone.BLANK_PATH : ClickZone.INVALID);

        if (p != null && c != null && c == name_column) {
            Files.File? file = model.file_for_path (p);

            if (file == null) {
                zone = ClickZone.INVALID;
            } else {
                var rtl = (get_direction () == Gtk.TextDirection.RTL);
                if (rtl ? (x > rect.x + rect.width - icon_size) : (x < rect.x + icon_size)) {
                    /* cannot be on name */
                    bool on_helper = false;
                    bool on_icon = is_on_icon ((int)x, (int)y, ref on_helper);

                    if (on_helper) {
                        zone = ClickZone.HELPER;
                    } else if (on_icon) {
                        zone = ClickZone.ICON;
                    } else {
                        zone = ClickZone.EXPANDER;
                    }
                } else if (!is_blank) {
                    zone = ClickZone.NAME;
                }
            }
        } else if (c != name_column) {
            /* Cause unselect all to occur on other columns and allow rubberbanding */
            zone = ClickZone.BLANK_NO_PATH;
        }

        return zone;
    }

    protected void scroll_to_cell (Gtk.TreePath? path, bool scroll_to_top) {
        /* slot && directory should not be null but see lp:1595438  & https://github.com/elementary/files/issues/1699 */
        if (tree == null || path == null || slot == null || slot.directory == null ||
            slot.directory.permission_denied || slot.directory.is_empty ()) {

            return;
        }

        tree.scroll_to_cell (path, name_column, scroll_to_top, 0.5f, 0.5f);
    }

    protected void set_cursor_on_cell (Gtk.TreePath path,
                                                Gtk.CellRenderer renderer,
                                                bool start_editing,
                                                bool scroll_to_top) {
        scroll_to_cell (path, scroll_to_top);
        tree.set_cursor_on_cell (path, name_column, renderer, start_editing);
    }

    public void set_view_cursor (Gtk.TreePath? path,
                                     bool start_editing,
                                     bool select,
                                     bool scroll_to_top) {
        if (path == null) {
            return;
        }

        Gtk.TreeSelection selection = tree.get_selection ();
        bool no_selection = selected_files == null;

        if (!select) {
            selection.changed.disconnect (on_view_selection_changed);
        } else {
            select_path (path);
        }

        set_cursor_on_cell (path, name_renderer, start_editing, scroll_to_top);

        if (!select) {
            /* When just focusing first for empty selection we do not want the row selected.
             * This makes behaviour consistent with Icon View */
            if (no_selection) {
                unselect_path (path); /* Reverse automatic selection by set_cursor_on_cell for TreeView */
            }

            selection.changed.connect (on_view_selection_changed);
        }
    }

    public Gtk.TreePath? get_path_at_cursor () {
        Gtk.TreePath? path;
        tree.get_cursor (out path, null);
        return path;
    }


    //Moved from AbstractDirectoryView - only relevant to TreeView, not GridView

    /* Support for keeping cursor position after delete */
    // private Gtk.TreePath deleted_path;
    protected Gtk.TreePath? click_path = null;
    private Gtk.TreePath? hover_path = null;

    protected bool is_on_icon (int x, int y, ref bool on_helper) {
        /* x and y must be in same coordinate system as used by the IconRenderer */
        Gdk.Rectangle pointer_rect = {x - 2, y - 2, 4, 4}; /* Allow slight inaccuracy */
        bool on_icon = pointer_rect.intersect (icon_renderer.hover_rect, null);
        on_helper = pointer_rect.intersect (icon_renderer.hover_helper_rect, null);
        return on_icon;
    }


    /* Multi-select could be by rubberbanding or modified clicking. Returning false
     * invokes the default widget handler.  IconView requires special handler */
    protected virtual bool handle_multi_select (Gtk.TreePath path) { return false; }

    protected override void select_and_scroll_to_gof_file (Files.File file) {
        Gtk.TreeIter iter;
        if (!model.get_first_iter_for_file (file, out iter)) {
            return; /* file not in model */
        }

        var path = model.get_path (iter);
        set_view_cursor (path, false, true, true);
    }

    public override void select_gof_file (Files.File file) {
        Gtk.TreeIter? iter;
        if (!model.get_first_iter_for_file (file, out iter)) {
            return; /* file not in model */
        }

        var path = model.get_path (iter);
        set_view_cursor (path, false, true, false);
    }

    protected override List<Files.File> get_visible_files () {
        Gtk.TreePath start_path, end_path, path;
        Gtk.TreePath sp, ep;
        Gtk.TreeIter iter;
        bool iter_is_valid;
        Files.File? file;
        GLib.List<Files.File> visible_files = null;
        // uint actually_visible = 0;

        if (get_visible_range (out start_path, out end_path)) {
            sp = start_path;
            ep = end_path;

            /* To improve performance for large folders we thumbnail files on either side of visible region
             * as well.  The delay is mainly in redrawing the view and this reduces the number of updates and
             * redraws necessary when scrolling */
            int count = 50;
            while (start_path.prev () && count > 0) {
                count--;
            }

            count = 50;
            while (count > 0) {
                end_path.next ();
                count--;
            }

            /* iterate over the range to collect all files */
            iter_is_valid = model.get_iter (out iter, start_path);
            while (iter_is_valid && thumbnail_source_id > 0) {
                file = model.file_for_iter (iter); // Maybe null if dummy row or file being deleted
                path = model.get_path (iter);
                visible_files.prepend (file);
                /* check if we've reached the end of the visible range */
                if (path.compare (end_path) != 0) {
                    iter_is_valid = model.iter_next (ref iter);
                } else {
                    iter_is_valid = false;
                }
            }
        }

        return visible_files;
    }

    protected override void add_gof_file_to_selection (Files.File file) {}
    protected override void remove_gof_file (Files.File file) {}
    protected override void scroll_to_file (Files.File file, bool scroll_to_top) {}
    protected override void resort () {}

    /* These two functions accelerate the loading of Views especially for large folders
     * Views are not displayed until fully loaded
     * May not be need for Gtk4 widgets */
    // protected override void freeze_tree () {
    //     tree.freeze_child_notify ();
    //     tree_frozen = true;
    // }

    // protected override void thaw_tree () {
    //     if (tree_frozen) {
    //         tree.thaw_child_notify ();
    //         tree_frozen = false;
    //     }
    // }

    // protected override void freeze_child_notify () {
    //     tree.freeze_child_notify ();
    // }

    // protected override void thaw_child_notify () {
    //     tree.thaw_child_notify ();
    // }

    // protected abstract void freeze_tree ();
    // protected abstract void thaw_tree ();
    // protected new abstract void freeze_child_notify ();
    // protected new abstract void thaw_child_notify ();
    // protected abstract void connect_tree_signals ();
    // protected abstract void disconnect_tree_signals ();


    protected class TreeView : Gtk.TreeView { // Not a final class
        // private ZoomLevel _zoom_level = ZoomLevel.INVALID;
        // public ZoomLevel zoom_level {
        //     set {
        //         if (_zoom_level == value || !get_realized ()) {
        //             return;
        //         } else {
        //             _zoom_level = value;
        //         }
        //     }

        //     get {
        //         return _zoom_level;
        //     }
        // }

        //TODO Use EventControllers
        // /* Override base class in order to disable the Gtk.TreeView local search functionality */
        // public override bool key_press_event (Gdk.EventKey event) {
        //     /* We still need the base class to handle cursor keys first */
        //     uint keyval;
        //     event.get_keyval (out keyval);
        //     switch (keyval) {
        //         case Gdk.Key.Up:
        //         case Gdk.Key.Down:
        //         case Gdk.Key.KP_Up:
        //         case Gdk.Key.KP_Down:
        //         case Gdk.Key.Page_Up:
        //         case Gdk.Key.Page_Down:
        //         case Gdk.Key.KP_Page_Up:
        //         case Gdk.Key.KP_Page_Down:
        //         case Gdk.Key.Home:
        //         case Gdk.Key.End:

        //             return base.key_press_event (event);

        //         default:

        //             return false; // Pass event to Window handler.
        //     }
        // }
    }
}
