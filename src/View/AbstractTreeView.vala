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
public abstract class Files.AbstractTreeView : AbstractDirectoryView {
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
            rubber_banding = true,
            activate_on_single_click = true
        };

        tree.get_selection ().set_mode (Gtk.SelectionMode.MULTIPLE);

        tree.row_activated.connect ((path, column) => {
            Gtk.TreeIter? iter;
            model.get_iter (out iter, path);
            model.@get (iter, Files.ColumnID.FILE_COLUMN, out active_file, -1);
            if (active_file.is_directory) {
            warning ("directory");
                activate_file (active_file);
                active_file = null;
            } else {
            warning ("other");
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
            tree.zoom_level = zoom_level;
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
        if (tree != null) {
            icon_renderer.zoom_level = zoom_level;
            name_renderer.zoom_level = zoom_level;
            tree.columns_autosize ();
            tree.set_property ("zoom-level", zoom_level);
        }
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

        // var ewindow = event.get_window ();
        // if (ewindow != tree.get_bin_window ()) {
        //     return ClickZone.INVALID;
        // }

        // double x, y;
        // event.get_coords (out x, out y);

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

    /* These two functions accelerate the loading of Views especially for large folders
     * Views are not displayed until fully loaded */
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

    //TODO Use EventControllers
    // protected virtual bool on_view_button_press_event (Gdk.EventButton event) {
    //     if (renaming) {
    //         /* Commit any change if renaming (https://github.com/elementary/files/issues/641) */
    //         name_renderer.end_editing (false);
    //     }

    //     cancel_hover (); /* cancel overlay statusbar cancellables */

    //     /* Ignore if second button pressed before first released - not permitted during rubberbanding.
    //      * Multiple click produces an event without corresponding release event so do not block that.
    //      */
    //     var type = event.get_event_type ();
    //     if (dnd_disabled && type == Gdk.EventType.BUTTON_PRESS) {
    //         return true;
    //     }

    //     grab_focus ();

    //     Gtk.TreePath? path = null;
    //     /* Remember position of click for detecting drag motion*/
    //     event.get_coords (out drag_x, out drag_y);
    //     uint button;
    //     event.get_button (out button);
    //     //Only rubberband with primary button
    //     click_zone = get_event_position_info (event, out path, button == Gdk.BUTTON_PRIMARY);
    //     click_path = path;

    //     Gdk.ModifierType state;
    //     event.get_state (out state);
    //     var mods = state & Gtk.accelerator_get_default_mod_mask ();
    //     bool no_mods = (mods == 0);
    //     bool control_pressed = ((mods & Gdk.ModifierType.CONTROL_MASK) != 0);
    //     bool shift_pressed = ((mods & Gdk.ModifierType.SHIFT_MASK) != 0);
    //     bool other_mod_pressed = (((mods & ~Gdk.ModifierType.SHIFT_MASK) & ~Gdk.ModifierType.CONTROL_MASK) != 0);
    //     bool only_control_pressed = control_pressed && !other_mod_pressed; /* Shift can be pressed */
    //     bool only_shift_pressed = shift_pressed && !control_pressed && !other_mod_pressed;
    //     bool path_selected = (path != null ? path_is_selected (path) : false);
    //     bool on_blank = (click_zone == ClickZone.BLANK_NO_PATH || click_zone == ClickZone.BLANK_PATH);
    //     bool double_click_event = (type == Gdk.EventType.@2BUTTON_PRESS);
    //     /* Block drag and drop to allow rubberbanding and prevent unwanted effects of
    //      * dragging on blank areas
    //      */
    //     block_drag_and_drop ();

    //     /* Handle un-modified clicks or control-clicks here else pass on. */
    //     if (!will_handle_button_press (no_mods, only_control_pressed, only_shift_pressed)) {
    //         return false;
    //     }

    //     bool result = false; // default false so events get passed to Window
    //     should_activate = false;
    //     should_deselect = false;
    //     should_select = false;
    //     should_scroll = true;

    //     /* Handle all selection and deselection explicitly in the following switch statement */
    //     switch (button) {
    //         case Gdk.BUTTON_PRIMARY: // button 1
    //             switch (click_zone) {
    //                 case ClickZone.BLANK_NO_PATH:
    //                 case ClickZone.INVALID:
    //                     // Maintain existing selection by holding down modifier so we can multi-select
    //                     // separate groups with rubberbanding.
    //                     if (no_mods) {
    //                         unselect_all ();
    //                     }

    //                     break;

    //                 case ClickZone.BLANK_PATH:
    //                 case ClickZone.ICON:
    //                 case ClickZone.NAME:
    //                     /* Control-click on selected item should deselect it on key release (unless
    //                      * pointer moves) */
    //                     should_deselect = only_control_pressed && path_selected;

    //                     /* Determine whether should activate on key release (unless pointer moved)*/
    //                     /* Only activate single files with unmodified button when not on blank unless double-clicked */
    //                     if (no_mods && one_or_less) {
    //                         should_activate = (on_directory && !on_blank) || double_click_event;
    //                     }

    //                     /* We need to decide whether to rubberband or drag&drop.
    //                      * Rubberband if modifer pressed or if not on the icon and either
    //                      * the item is unselected. */
    //                     if (!no_mods || (on_blank && !path_selected)) {
    //                         result = only_shift_pressed && handle_multi_select (path);
    //                         // Have to select on button release because IconView, unlike TreeView,
    //                         // will not both select and rubberband
    //                         should_select = true;
    //                     } else {
    //                         if (no_mods && !path_selected) {
    //                             unselect_all ();
    //                         }

    //                         select_path (path, true);
    //                         unblock_drag_and_drop ();
    //                         result = handle_primary_button_click (event, path);
    //                     }

    //                     update_selected_files_and_menu ();
    //                     break;

    //                 case ClickZone.HELPER:
    //                     if (only_control_pressed || only_shift_pressed) { /* Treat like modified click on icon */
    //                         result = only_shift_pressed && handle_multi_select (path);
    //                     } else {
    //                         if (path_selected) {
    //                             /* Don't deselect yet, may drag */
    //                             should_deselect = true;
    //                         } else {
    //                             select_path (path, true); /* Cursor follow and selection preserved */
    //                         }

    //                         unblock_drag_and_drop ();
    //                         result = true; /* Prevent rubberbanding and deselection of other paths */
    //                     }
    //                     break;

    //                 case ClickZone.EXPANDER:
    //                     /* on expanders (if any) or xpad. Handle ourselves so that clicking
    //                      * on xpad also expands/collapses row (accessibility). */
    //                     result = expand_collapse (path);
    //                     break;

    //                 default:
    //                     break;
    //             }

    //             break;

    //         case Gdk.BUTTON_MIDDLE: // button 2
    //             if (!path_is_selected (path)) {
    //                 select_path (path, true);
    //             }

    //             should_activate = true;
    //             unblock_drag_and_drop ();
    //             result = true;

    //             break;

    //         case Gdk.BUTTON_SECONDARY: // button 3
    //             switch (click_zone) {
    //                 case ClickZone.BLANK_NO_PATH:
    //                 case ClickZone.INVALID:
    //                     unselect_all ();
    //                     break;

    //                 case ClickZone.BLANK_PATH:
    //                     if (!path_selected && no_mods) {
    //                         unselect_all (); // Show the background menu on unselected blank areas
    //                     }

    //                     break;

    //                 case ClickZone.NAME:
    //                 case ClickZone.ICON:
    //                 case ClickZone.HELPER:
    //                     if (!path_selected && no_mods) {
    //                         unselect_all ();
    //                     }

    //                     select_path (path); /* Note: secondary click does not toggle selection */
    //                     break;

    //                 default:
    //                     break;
    //             }

    //             /* Ensure selected files list and menu actions are updated before context menu shown */
    //             update_selected_files_and_menu ();
    //             unblock_drag_and_drop ();
    //             start_drag_timer (event);

    //             result = handle_secondary_button_click (event);
    //             break;

    //         default:
    //             result = handle_default_button_click (event);
    //             break;
    //     }

    //     return result;
    // }

    // protected virtual bool on_view_button_release_event (Gdk.EventButton event) {
    //     unblock_drag_and_drop ();
    //     /* Ignore button release from click that started renaming.
    //      * View may lose focus during a drag if another tab is hovered, in which case
    //      * we do not want to refocus this view.
    //      * Under both these circumstances, 'should_activate' will be false */
    //     if (renaming || !view_has_focus ()) {
    //         return true;
    //     }

    //     slot.active (should_scroll);

    //     // Gtk.Widget widget = ;
    //     double x, y;
    //     uint button;
    //     event.get_coords (out x, out y);
    //     event.get_button (out button);
    //     update_selected_files_and_menu ();
    //     /* Only take action if pointer has not moved */
    //     if (!Gtk.drag_check_threshold (get_child (), (int)drag_x, (int)drag_y, (int)x, (int)y)) {
    //         if (should_activate) {
    //             /* Need Idle else can crash with rapid clicking (avoid nested signals) */
    //             Idle.add (() => {
    //                 var flag = button == Gdk.BUTTON_MIDDLE ? Files.OpenFlag.NEW_TAB : Files.OpenFlag.DEFAULT;
    //                 activate_selected_items (flag);
    //                 return GLib.Source.REMOVE;
    //             });
    //         } else if (should_deselect && click_path != null) {
    //             unselect_path (click_path);
    //             /* Only need to update selected files if changed by this handler */
    //             Idle.add (() => {
    //                 update_selected_files_and_menu ();
    //                 return GLib.Source.REMOVE;
    //             });
    //         } else if (should_select && click_path != null) {
    //             select_path (click_path);
    //             /* Only need to update selected files if changed by this handler */
    //             Idle.add (() => {
    //                 update_selected_files_and_menu ();
    //                 return GLib.Source.REMOVE;
    //             });
    //         } else if (button == Gdk.BUTTON_SECONDARY) {
    //             show_context_menu (event);
    //         }
    //     }

    //     should_activate = false;
    //     should_deselect = false;
    //     should_select = false;
    //     click_path = null;
    //     return false;
    // }

    // protected override ZoomLevel get_normal_zoom_level () {}

    protected override void remove_gof_file (Files.File file) {}
    protected override void scroll_to_file (Files.File file, bool scroll_to_top) {}

    protected override void resort () {}

    // protected abstract void freeze_tree ();
    // protected abstract void thaw_tree ();
    // protected new abstract void freeze_child_notify ();
    // protected new abstract void thaw_child_notify ();
    // protected abstract void connect_tree_signals ();
    // protected abstract void disconnect_tree_signals ();

    // protected virtual void set_up_icon_renderer () {}


    protected class TreeView : Gtk.TreeView { // Not a final class
        private ZoomLevel _zoom_level = ZoomLevel.INVALID;
        public ZoomLevel zoom_level {
            set {
                if (_zoom_level == value || !get_realized ()) {
                    return;
                } else {
                    _zoom_level = value;
                }
            }

            get {
                return _zoom_level;
            }
        }

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


