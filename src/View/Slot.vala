/***
    Copyright (c) 2015-2018 elementary LLC <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremywootten@gmail.com>
***/


namespace Files.View {
    public class Slot : Files.BasicSlot {
        private int preferred_column_width;

        public override bool is_frozen {
            set {
                dir_view.is_frozen = value;
                frozen_changed (value);
            }

            get {
                return dir_view == null || dir_view.is_frozen;
            }
        }

        public override bool locked_focus {
            get {
                return dir_view.renaming;
            }
        }

        public signal void frozen_changed (bool freeze);

        /* Support for multi-slot view (Miller)*/
        public signal void miller_slot_request (GLib.File file, bool make_root);
        public signal void size_change ();

        public Slot (
            GLib.File _location,
            SlotToplevelInterface? _top_level,
            ViewMode _mode
        ) {
            Object (
                location: _location,
                selection_mode: Gtk.SelectionMode.BROWSE,
                top_level: _top_level,
                mode: _mode
            );

            // Create dir_view here not in construct else both base and override methods run
            create_dir_view ();
            preferred_column_width = Files.column_view_settings.get_int ("preferred-column-width");
            width = preferred_column_width;
        }

        ~Slot () {
            debug ("Slot %i destruct", slot_number);
            // Ensure dir view does not redraw with invalid slot, causing a crash
            dir_view.destroy ();
        }

        protected override void create_dir_view () {
            switch (mode) {
                case ViewMode.MILLER_COLUMNS:
                    dir_view = new Files.ColumnView (this);
                    break;

                case ViewMode.LIST:;
                    dir_view = new Files.ListView (this);
                    break;

                case ViewMode.ICON:
                    dir_view = new Files.IconView (this);
                    break;

                default:
                    break;
            }

            /* Miller View creates its own overlay and handles packing of the directory view */
            if (mode != ViewMode.MILLER_COLUMNS) {
                add_overlay (dir_view);
            }

            connect_dir_view_signals ();
            is_frozen = true;
        }

        protected override void on_directory_done_loading (Directory dir) {
            directory_loaded (dir);
            /*  Column View requires slots to determine their own width (other views' width determined by Window */
            if (mode == ViewMode.MILLER_COLUMNS) {
                //TODO See if need to adjust width now using stack to show empty message
                if (dir.is_empty ()) { /* No files in the file cache */
                    Pango.Rectangle extents;
                    var layout = dir_view.create_pango_layout (null);
                    layout.set_markup (get_empty_message (), -1);
                    layout.get_extents (null, out extents);
                    width = (int) Pango.units_to_double (extents.width);
                } else {
                    width = preferred_column_width;
                }

                width += dir_view.icon_size + 64; /* allow some extra room for icon padding and right margin*/

                /* Allow extra room for MESSAGE_CLASS styling of special messages */
                if (dir.is_empty () || dir.permission_denied) {
                    width += width;
                }

                size_change ();
                hpane.set_position (width);
                colpane.show_all ();

                if (colpane.get_realized ()) {
                    colpane.queue_draw ();
                }
            }

            is_frozen = false;
        }

        protected override void on_dir_view_path_change_request (GLib.File loc, Files.OpenFlag flag, bool make_root) {
            if (flag == 0) { /* make view in existing container */
                if (mode == ViewMode.MILLER_COLUMNS) {
                    miller_slot_request (loc, make_root); /* signal to parent MillerView */
                } else {
                    user_path_change_request (loc, make_root); /* Handle ourselves */
                }
            } else {
                new_container_request (loc, flag);
            }
        }

        public override void user_path_change_request (GLib.File loc, bool make_root = true) {
        /** Only this function must be used to change or reload the path **/
            var old_dir = directory;
            if (directory != null) {
                disconnect_dir_signals ();
            }

            location = loc;
            connect_dir_signals ();
            path_changed ();
            /* ViewContainer listens to this signal takes care of updating appearance */
            dir_view.change_directory (old_dir, directory);
            initialize_directory ();
        }

        public override void initialize_directory () {
            if (directory.is_loading ()) {
                /* This can happen when restoring duplicate tabs */
                debug ("Slot.initialize_directory () called when directory already loading - ignoring");
                return;
            }
            /* view and slot are unfrozen when done loading signal received */
            is_frozen = true;
            directory.init ();
        }

        public override void reload (bool non_local_only = false) {
            if (!non_local_only || !directory.is_local) {
                original_reload_request = true;
                /* Propagate reload signal to any other slot showing this directory indicating it is not
                 * the original signal */
                directory.need_reload (false);
            }
        }

        public override bool set_all_selected (bool select_all) {
            if (dir_view != null) {
                if (select_all) {
                    dir_view.select_all ();
                } else {
                    dir_view.unselect_all ();
                }
                return true;
            } else {
                return false;
            }
        }

        public override unowned GLib.List<Files.File>? get_selected_files () {
            if (dir_view != null) {
                return dir_view.get_selected_files ();
            } else {
                return null;
            }
        }

        public override void select_glib_files (GLib.List<GLib.File> files, GLib.File? focus_location) {
            if (dir_view != null) {
                dir_view.select_glib_files_when_thawed (files, focus_location);
            }
        }

        public override void focus_first_for_empty_selection (bool select = true) {
            if (dir_view != null) {
                dir_view.focus_first_for_empty_selection (select);
            }
        }

        public override void set_active_state (bool set_active, bool animate = true) {
            if (set_active) {
                active (true, animate);
            } else {
                inactive ();
            }
        }

        public override unowned Files.AbstractSlot? get_current_slot () {
            return this as Files.AbstractSlot;
        }

        public override void grab_focus () {
            if (dir_view != null) {
                dir_view.grab_focus ();
            }
        }

        public override void zoom_in () {
            if (dir_view != null) {
                dir_view.zoom_in ();
            }
        }

        public override void zoom_out () {
            if (dir_view != null) {
                dir_view.zoom_out ();
            }
        }

        public override void zoom_normal () {
            if (dir_view != null) {
                dir_view.zoom_normal ();
            }
        }

        public override void close () {
            debug ("SLOT close %s", uri);
            cancel_timeouts ();

            if (directory != null) {
                directory.cancel ();
                disconnect_dir_signals ();
            }

            if (dir_view != null) {
                dir_view.close ();
                disconnect_dir_view_signals ();
            }
        }

        public override FileInfo? lookup_file_info (GLib.File loc) {
            Files.File? gof = directory.file_hash_lookup_location (loc);
            if (gof != null) {
                return gof.info;
            } else {
                return null;
            }
        }
    }
}
