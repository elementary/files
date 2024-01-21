/***
    Copyright (c) 2015-2020 elementary LLC <https://elementary.io>

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

namespace Files {
    /* Implement common features of ColumnView and ListView */
    public abstract class AbstractTreeView : AbstractDirectoryView {
        protected Files.TreeView tree;
        protected Gtk.TreeViewColumn name_column;

        protected AbstractTreeView (View.Slot _slot) {
            base (_slot);
        }

        ~AbstractTreeView () {
            debug ("ATV destruct");
        }

        protected abstract void set_up_icon_renderer ();

        protected override void connect_tree_signals () {
            tree.get_selection ().changed.connect (on_view_selection_changed);
        }

        protected override void disconnect_tree_signals () {
            tree.get_selection ().changed.disconnect (on_view_selection_changed);
        }

        protected override Gtk.Widget? create_view () {
            tree = new Files.TreeView () {
                model = model,
                headers_visible = false,
                rubber_banding = true
            };

            tree.get_selection ().set_mode (Gtk.SelectionMode.MULTIPLE);

            name_column = new Gtk.TreeViewColumn () {
                sort_column_id = Files.ListModel.ColumnID.FILENAME,
                expand = true,
                resizable = true
            };

            name_renderer = new Files.TextRenderer (ViewMode.LIST) {
                wrap_width = -1,
                zoom_level = ZoomLevel.NORMAL,
                ellipsize_set = true,
                ellipsize = Pango.EllipsizeMode.END,
                xalign = 0.0f,
                yalign = 0.5f
            };
            set_up_name_renderer ();


            set_up_icon_renderer ();
            var emblem_renderer = new Files.EmblemRenderer ();
            emblem_renderer.yalign = 0.5f;

            name_column.pack_start (icon_renderer, false);
            name_column.set_attributes (icon_renderer,
                                        "file", Files.ListModel.ColumnID.FILE_COLUMN);

            name_column.pack_start (name_renderer, true);
            name_column.set_attributes (name_renderer,
                                        "text", Files.ListModel.ColumnID.FILENAME,
                                        "file", Files.ListModel.ColumnID.FILE_COLUMN,
                                        "background", Files.ListModel.ColumnID.COLOR);

            name_column.pack_start (emblem_renderer, false);
            name_column.set_attributes (emblem_renderer,
                                        "file", Files.ListModel.ColumnID.FILE_COLUMN);

            tree.append_column (name_column);
            connect_tree_signals ();
            tree.realize.connect ((w) => {
                tree.grab_focus ();
                tree.columns_autosize ();
                tree.zoom_level = zoom_level;
            });

            return tree as Gtk.Widget;
        }

        public override void change_zoom_level () {
            if (tree != null) {
                base.change_zoom_level ();
                tree.columns_autosize ();
                tree.set_property ("zoom-level", zoom_level);
            }
        }

        public override GLib.List<Gtk.TreePath> get_selected_paths () {
            return tree.get_selection ().get_selected_rows (null);
        }

        public override void highlight_path (Gtk.TreePath? path) {
            tree.set_drag_dest_row (path, Gtk.TreeViewDropPosition.INTO_OR_AFTER);
        }

        public override Gtk.TreePath? get_path_at_pos (int x, int y) {
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
        public override void select_path (Gtk.TreePath? path, bool cursor_follows = false) {
            if (path != null) {
                var selection = tree.get_selection ();
                selection.select_path (path);
                if (cursor_follows) {
                    /* Unlike for IconView, set_cursor unselects previously selected paths (Gtk bug?),
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
        public override void unselect_path (Gtk.TreePath? path) {
            if (path != null) {
                tree.get_selection ().unselect_path (path);
            }
        }

        public override bool path_is_selected (Gtk.TreePath? path) {
            if (path != null) {
                return tree.get_selection ().path_is_selected (path);
            } else {
                return false;
            }
        }

        public override bool get_visible_range (out Gtk.TreePath? start_path,
                                                out Gtk.TreePath? end_path) {
            start_path = null;
            end_path = null;
            return tree.get_visible_range (out start_path, out end_path);
        }

        protected override uint get_event_position_info (Gdk.Event event,
                                                         out Gtk.TreePath? path,
                                                         bool rubberband = false) {
            Gtk.TreePath? p = null;
            unowned Gtk.TreeViewColumn? c = null;
            uint zone;
            int cx, cy, depth;
            path = null;

            var ewindow = event.get_window ();
            if (ewindow != tree.get_bin_window ()) {
                return ClickZone.INVALID;
            }

            double x, y;
            event.get_coords (out x, out y);
            tree.get_path_at_pos ((int)x, (int)y, out p, out c, out cx, out cy);
            path = p;
            depth = p != null ? p.get_depth () : 0;
            /* Get rect for whole column; no simple way to get individual renderer sizes? */
            Gdk.Rectangle rect;
            tree.get_cell_area (p, c, out rect);
            int height = rect.height;
             /* Note: is_blank_at_pos () returns "true" on the whitespace below and
             * above text pixels, which we do not want. We deal with this later.*/
            var is_blank = tree.is_blank_at_pos ((int)x, (int)y, null, null, null, null);
            // Ensure blank area continues across row division
            is_blank = is_blank || cy < 5 || cy > height - 5;

            /* Do not allow rubberbanding to start except on a row in tree view */
            zone = (p != null && is_blank ? ClickZone.BLANK_PATH : ClickZone.INVALID);

            if (p != null && c != null && c == name_column) {
                Files.File? file = model.file_for_path (p);

                if (file == null) {
                    zone = ClickZone.INVALID;
                } else {
                    var rtl = (get_direction () == Gtk.TextDirection.RTL);
                    // Calculate position of the edge between icon to text renderers
                    int icon_text_edge;
                    if (rtl) {
                        icon_text_edge = tree.get_allocated_width () - rect.x - icon_size - 16;
                    } else {
                        icon_text_edge = icon_size + 16;
                    }
                    // Calculate whether pointer over icon renderer or text renderer
                    if (rtl ? cx > icon_text_edge : cx < icon_text_edge) {
                        // On icon renderer (or expander)
                        bool on_helper = false;
                        bool on_icon = is_on_icon ((int)x, (int)y, ref on_helper);
                        if (on_helper) {
                            zone = ClickZone.HELPER;
                        } else if (on_icon) {
                            zone = ClickZone.ICON;
                        } else {
                            zone = ClickZone.EXPANDER;
                        }
                    } else {
                        // On name renderer
                        // Cannot rely on current state of name_renderer so have to layout the
                        // text again to get pixel width
                        Gtk.TreeIter iter;
                        model.get_iter (out iter, path);
                        string? text = null;
                        model.@get (iter, ListModel.ColumnID.FILENAME, out text);
                        name_renderer.set_up_layout (text, name_renderer.width);
                        // Calculate where click will activate
                        var active_width = name_renderer.text_width + name_renderer.double_border_radius;
                        bool is_on_active;
                        if (rtl) {
                            is_on_active = cx >= icon_text_edge - active_width - 8;
                        } else {
                            is_on_active = cx <= icon_text_edge + active_width + 8;
                        }

                        if (is_on_active) {
                            zone = ClickZone.NAME;
                        } else if (!is_blank) {
                            zone = ClickZone.BLANK_PATH;
                        }
                    }
                }
            } else if (c != name_column) {
                /* Cause unselect all to occur on other columns and allow rubberbanding */
                zone = ClickZone.BLANK_NO_PATH;
            }

            return zone;
        }

        protected override void scroll_to_path (Gtk.TreePath path, bool scroll_to_top) {
            tree.scroll_to_cell (path, name_column, scroll_to_top, 0.5f, 0.5f);
        }

        protected override void set_cursor_on_cell (Gtk.TreePath path,
                                                    Gtk.CellRenderer renderer,
                                                    bool start_editing,
                                                    bool scroll_to_top) {
            scroll_to_cell (path, scroll_to_top);
            tree.set_cursor_on_cell (path, name_column, renderer, start_editing);
        }

        public override void set_cursor (Gtk.TreePath? path,
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

        public override Gtk.TreePath? get_path_at_cursor () {
            Gtk.TreePath? path;
            tree.get_cursor (out path, null);
            return path;
        }

        /* These two functions accelerate the loading of Views especially for large folders
         * Views are not displayed until fully loaded */
        protected override void freeze_tree () {
            if (!tree_frozen) {
                tree.freeze_child_notify ();
                tree_frozen = true;
            }
        }

        protected override void thaw_tree () {
            if (tree_frozen) {
                tree.thaw_child_notify ();
                tree_frozen = false;
            }
        }

        // For scrolling
        protected override void freeze_child_notify () {
            tree.freeze_child_notify ();
        }

        protected override void thaw_child_notify () {
            // Do not prematurely thaw tree when loading
            if (!tree_frozen) {
                tree.thaw_child_notify ();
            }

        }
    }

    protected class TreeView : Gtk.TreeView {
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

        /* Override base class in order to disable the Gtk.TreeView local search functionality */
        public override bool key_press_event (Gdk.EventKey event) {
            /* We still need the base class to handle cursor keys first */
            uint keyval;
            event.get_keyval (out keyval);
            switch (keyval) {
                case Gdk.Key.Up:
                case Gdk.Key.Down:
                case Gdk.Key.KP_Up:
                case Gdk.Key.KP_Down:
                case Gdk.Key.Page_Up:
                case Gdk.Key.Page_Down:
                case Gdk.Key.KP_Page_Up:
                case Gdk.Key.KP_Page_Down:
                case Gdk.Key.Home:
                case Gdk.Key.End:

                    return base.key_press_event (event);

                default:

                    return false; // Pass event to Window handler.
            }
        }
    }
}
