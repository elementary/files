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

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/

namespace Files.View {
    public class Miller : Files.AbstractSlot {
        private unowned View.ViewContainer ctab;

        /* Need private copy of initial location as Miller
         * does not have its own Asyncdirectory object */
        private GLib.File root_location;

        private Gtk.Box colpane;

        private uint scroll_to_slot_timeout_id = 0;

        private Gtk.ScrolledWindow scrolled_window;
        private Gtk.Viewport viewport;
        public Gtk.Adjustment hadj;
        public unowned View.Slot? current_slot;
        public GLib.List<View.Slot> slot_list = null;
        public int total_width = 0;

        public override bool is_frozen {
            set {
                if (current_slot != null) {
                    current_slot.is_frozen = value;
                }
            }

            get {
                return current_slot == null || current_slot.is_frozen;
            }
        }

        public Miller (GLib.File loc, View.ViewContainer ctab, ViewMode mode) {
            this.ctab = ctab;
            this.root_location = loc;

            (Files.Preferences.get_default ()).notify["show-hidden-files"].connect ((s, p) => {
                show_hidden_files_changed (((Files.Preferences)s).show_hidden_files);
            });

            colpane = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

            scrolled_window = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                vscrollbar_policy = Gtk.PolicyType.NEVER
            };

            hadj = scrolled_window.get_hadjustment ();

            viewport = new Gtk.Viewport (null, null);
            viewport.set_child (this.colpane);

            scrolled_window.set_child (viewport);
            add_overlay (scrolled_window);

            make_view ();

            is_frozen = true;
        }

        ~Miller () {
            debug ("Miller destruct");
        }

        protected override void make_view () {
            current_slot = null;
            add_location (root_location, null); /* current slot gets set by this */
        }

        /** Creates a new slot in the host slot hpane */
        public void add_location (GLib.File loc, View.Slot? host = null) {
            var guest = new View.Slot (loc, ctab, ViewMode.MILLER_COLUMNS);
            /* Notify view container of path change - will set tab to working and change pathbar */
            path_changed ();
            guest.slot_number = (host != null) ? host.slot_number + 1 : 0;
            guest.colpane = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            guest.colpane.set_size_request (guest.width, -1);
            guest.hpane = new Gtk.Paned (Gtk.Orientation.HORIZONTAL) {
                hexpand = true
            };

            guest.hpane.start_child = guest.get_directory_view ();
            guest.hpane.end_child = guest.colpane;

            connect_slot_signals (guest);

            if (host != null) {
                truncate_list_after_slot (host);
                host.select_gof_file (guest.file);
                host.colpane.append (guest.hpane);
                guest.initialize_directory ();
            } else {
                this.colpane.append (guest.hpane);
            }

            slot_list.append (guest); // Must add to list before scrolling
            // Must set the new slot to be  activehere as the tab does not change (which normally sets its slot active)
            guest.active (true, true);

            update_total_width ();
        }

        private void truncate_list_after_slot (View.Slot slot) {
            if (slot_list.length () <= 0) { //Can be assumed to limited in length
                return;
            }

            uint n = slot.slot_number;

            slot_list.@foreach ((s) => {
                if (s.slot_number > n) {
                    disconnect_slot_signals (s);
                    s.close ();
                }
            });

            var child = ((View.Slot)slot).colpane.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                child.destroy ();
                child = next;
            }

            slot_list.nth (n).next = null;
            calculate_total_width ();
            current_slot = slot;
            slot.active ();
        }

        private void calculate_total_width () {
            total_width = 100; // Extra space to allow increasing the size of columns by dragging the edge
            slot_list.@foreach ((slot) => {
                total_width += slot.width;
            });
        }

        private uint total_width_timeout_id = 0;
        private void update_total_width () {
            if (total_width_timeout_id > 0) {
                return;
            }

            total_width_timeout_id = Timeout.add (200, () => {
                total_width_timeout_id = 0;
                calculate_total_width ();
                this.colpane.set_size_request (total_width, -1);
                return Source.REMOVE;
            });
        }

/*********************/
/** Signal handling **/
/*********************/

        public override void user_path_change_request (GLib.File loc, bool make_root = false) {
            /* Requests from history buttons, pathbar come here with make_root = false.
             * These do not create a new root.
             * Requests from the sidebar have make_root = true
             */
            change_path (loc, make_root);
        }

        private void change_path (GLib.File loc, bool make_root) {
            var first_slot = slot_list.first ().data;
            string root_uri = first_slot.uri;
            string target_uri = loc.get_uri ();
            bool found = false;

            if (!make_root && target_uri.has_prefix (root_uri) && target_uri != root_uri) {
                /* Try to add location relative to each slot in turn, starting at end */
                var copy_slot_list = slot_list.copy ();
                copy_slot_list.reverse ();
                foreach (View.Slot s in copy_slot_list) {
                    if (add_relative_path (s, loc)) {
                        found = true;
                        break;
                    }
                }
            }

            /* If requested location is not a child of any slot, start a new tree */
            if (!found) {
                truncate_list_after_slot (first_slot);
                if (loc.get_uri () != first_slot.uri) {
                    first_slot.user_path_change_request (loc, true);
                    root_location = loc;
                    /* Sidebar requests make_root true - first directory will be selected;
                     * Go_up requests make_root false - previous directory will be selected
                     */
                    if (make_root) {
                        /* Do not select (match behaviour of other views) */
                        first_slot.focus_first_for_empty_selection (false);
                    }
                }
            }
        }

        private bool add_relative_path (View.Slot root, GLib.File loc) {
            if (root.location.get_uri () == loc.get_uri ()) {
                truncate_list_after_slot (root);
                return true;
            }
            string? relative_path = FileUtils.escape_uri (root.location.get_relative_path (loc), false);
            if (relative_path != null && relative_path.length > 0) {
                truncate_list_after_slot (root);
                string [] dirs = relative_path.split (Path.DIR_SEPARATOR_S);
                string last_uri = root.uri;
                if (last_uri.has_suffix (Path.DIR_SEPARATOR_S)) {
                    last_uri = last_uri.slice (0, -1);
                }

                foreach (unowned string d in dirs) {
                    if (d.length > 0) {
                        last_uri = GLib.Path.build_path (Path.DIR_SEPARATOR_S, last_uri, d);

                        var last_slot = slot_list.last ().data;
                        var file = GLib.File.new_for_uri (last_uri);
                        var list = new List<GLib.File> ();
                        list.prepend (file);
                        last_slot.select_glib_files (list, file);
                        Thread.usleep (100000);
                        add_location (file, last_slot);

                    }
                }
            } else {
                return false;
            }
            return true;
        }

        private void connect_slot_signals (Slot slot) {
            slot.selection_changed.connect (on_slot_selection_changed);
            slot.frozen_changed.connect (on_slot_frozen_changed);
            slot.active.connect (on_slot_active);
            slot.miller_slot_request.connect (on_miller_slot_request);
            slot.new_container_request.connect (on_new_container_request);
            slot.size_change.connect (update_total_width);
            slot.folder_deleted.connect (on_slot_folder_deleted);
            //TODO Use EventController
            // slot.colpane.key_press_event.connect (on_key_pressed);
            slot.path_changed.connect (on_slot_path_changed);
            slot.directory_loaded.connect (on_slot_directory_loaded);
            slot.hpane.notify["position"].connect (update_total_width);
        }

        private void disconnect_slot_signals (Slot slot) {
            slot.selection_changed.disconnect (on_slot_selection_changed);
            slot.frozen_changed.disconnect (on_slot_frozen_changed);
            slot.active.disconnect (on_slot_active);
            slot.miller_slot_request.disconnect (on_miller_slot_request);
            slot.new_container_request.disconnect (on_new_container_request);
            slot.size_change.disconnect (update_total_width);
            slot.folder_deleted.disconnect (on_slot_folder_deleted);
            // slot.colpane.key_press_event.disconnect (on_key_pressed);
            slot.path_changed.disconnect (on_slot_path_changed);
            slot.directory_loaded.disconnect (on_slot_directory_loaded);
        }

        private void on_miller_slot_request (View.Slot slot, GLib.File loc, bool make_root) {
            if (make_root) {
                /* Start a new tree with root at loc */
                change_path (loc, true);
            } else {
                /* Just add another column to the end. */
                add_location (loc, slot);
            }
        }

        private void on_new_container_request (GLib.File loc, Files.OpenFlag flag) {
            new_container_request (loc, flag);
        }

        private void on_slot_path_changed () {
            path_changed ();
        }

        private void on_slot_directory_loaded (Directory dir) {
            directory_loaded (dir);
        }

        private void on_slot_folder_deleted (Slot slot, Files.File file, Directory dir) {
            Slot? next_slot = slot_list.nth_data (slot.slot_number + 1);
            if (next_slot != null && next_slot.directory == dir) {
                truncate_list_after_slot (slot);
            }
        }

        /** Called in response to slot active signal.
         *  Should not be called directly
         **/
        private void on_slot_active (Files.AbstractSlot aslot, bool scroll = true, bool animate = true) {
            View.Slot slot;

            if (!(aslot is View.Slot)) {
                return;
            } else {
                slot = aslot as View.Slot;
            }

            if (scroll) {
                schedule_scroll_to_slot (slot, animate);
            }

            if (this.current_slot != slot) {
                slot_list.@foreach ((s) => {
                    if (s != slot) {
                        s.inactive ();
                    }
                });

                current_slot = slot;
            }
            /* Always emit this signal so that UI updates (e.g. pathbar) */
            active ();
        }

        private void show_hidden_files_changed (bool show_hidden) {
            if (!show_hidden) {
                /* we are hiding hidden files - check whether any slot is a hidden directory */
                int i = -1;
                int hidden = -1;

                slot_list.@foreach ((s) => {
                    i ++;
                    if (s.directory.file.is_hidden && hidden <= 0) {
                        hidden = i;
                    }
                });

                /* Return if no hidden folder found or only first folder hidden */
                if (hidden <= 0) {
                    return;
                }

                /* Remove hidden slots and make the slot before the first hidden slot active */
                View.Slot slot = slot_list.nth_data (hidden - 1);
                truncate_list_after_slot (slot);
                slot.active ();
            }
        }

        //TODO Use EventController
        // private bool on_key_pressed (Gtk.Widget box, Gdk.EventKey event) {
        //     /* Only handle unmodified keys */
        //     Gdk.ModifierType state;
        //     event.get_state (out state);
        //     if ((state & Gtk.accelerator_get_default_mod_mask ()) > 0) {
        //         return false;
        //     }

        //     int current_position = slot_list.index (current_slot);

        //     if (slot_list.nth_data (current_position).get_directory_view ().renaming) {
        //         return false;
        //     }

        //     View.Slot to_activate = null;

        //     uint keyval;
        //     event.get_keyval (out keyval);
        //     switch (keyval) {
        //         case Gdk.Key.Left:
        //             if (current_position > 0) {
        //                 to_activate = slot_list.nth_data (current_position - 1);
        //             }

        //             break;

        //         case Gdk.Key.Right:
        //             if (current_slot.get_selected_files () == null) {
        //                 return true;
        //             }

        //             Files.File? selected_file = current_slot.get_selected_files ().data;

        //             if (selected_file == null) {
        //                 return true;
        //             }

        //             GLib.File current_location = selected_file.location;
        //             GLib.File? next_location = null;

        //             if (current_position < slot_list.length () - 1) { //Can be assumed to limited in length
        //                 next_location = slot_list.nth_data (current_position + 1).location;
        //             }

        //             if (next_location != null && next_location.equal (current_location)) {
        //                 to_activate = slot_list.nth_data (current_position + 1);
        //             } else if (selected_file.is_folder ()) {
        //                 add_location (current_location, current_slot);
        //                 return true;
        //             }

        //             break;

        //         case Gdk.Key.BackSpace:
        //                 if (current_position > 0) {
        //                     truncate_list_after_slot (slot_list.nth_data (current_position - 1));
        //                 } else {
        //                     ctab.go_up ();
        //                     return true;
        //                 }

        //             break;

        //         default:
        //             break;
        //     }

        //     if (to_activate != null) {
        //         to_activate.active ();
        //         to_activate.focus_first_for_empty_selection (true); /* Selects as well as focusses */
        //     }

        //     return false;
        // }

        private void on_slot_selection_changed (GLib.List<Files.File> files) {
            selection_changed (files);
        }

        private void on_slot_frozen_changed (Slot slot, bool frozen) {
            /* Ensure all slots synchronise the frozen state */

            slot_list.@foreach ((abstract_slot) => {
                var s = abstract_slot as View.Slot;
                if (s != null) {
                    s.frozen_changed.disconnect (on_slot_frozen_changed);
                    s.is_frozen = frozen;
                    s.frozen_changed.connect (on_slot_frozen_changed);
                }
            });
        }


/** Helper functions */

        private void schedule_scroll_to_slot (View.Slot slot, bool animate = true) {
            if (scroll_to_slot_timeout_id > 0) {
                GLib.Source.remove (scroll_to_slot_timeout_id);
            }

            scroll_to_slot_timeout_id = GLib.Timeout.add (200, () => {
                /* Wait until slot realized and loaded before scrolling
                 * Cannot accurately scroll until directory finishes loading because width will change
                 * according the length of the longest filename */
                if (!scrolled_window.get_realized () || slot.directory.state != Directory.State.LOADED) {
                    return Source.CONTINUE;
                }

                if (get_animating ()) {
                    cancel_animation ();
                }

                // Calculate position to scroll to
                int total_width_before = 0; /* left edge of active slot */
                slot_list.@foreach ((abs) => {
                    if (abs.slot_number < slot.slot_number) {
                        total_width_before += abs.width;
                    }
                });

                int hadj_value = (int) this.hadj.get_value ();
                int offset = total_width_before - hadj_value;
                if (offset < 0) { /*scroll until left hand edge of active slot is in view*/
                    hadj_value += offset;
                }

                offset = total_width_before + slot.width - hadj_value - viewport.child.get_width ();
                if (offset > 0) { /*scroll  until right hand edge of active slot is in view*/
                    hadj_value += offset;
                }

                // Perform scroll
                if (animate) {
                    smooth_adjustment_to (this.hadj, hadj_value);
                } else { /* On startup we do not want to animate */
                    hadj.set_value (hadj_value);
                }

                scroll_to_slot_timeout_id = 0;
                return Source.REMOVE;
            });
        }

        public override unowned Files.AbstractSlot? get_current_slot () {
            return current_slot;
        }

        public override unowned GLib.List<Files.File>? get_selected_files () {
            return ((View.Slot)(current_slot)).get_selected_files ();
        }

        public override void set_active_state (bool set_active, bool animate = true) {
            if (set_active) {
                current_slot.active (true, animate);
            } else {
                current_slot.inactive ();
            }
        }

        public override string? get_tip_uri () {
            if (slot_list != null &&
                slot_list.last () != null &&
                slot_list.last ().data is Files.AbstractSlot) {

                return slot_list.last ().data.uri;
            } else {
                return null;
            }
        }

        public override string? get_root_uri () {
            return root_location.get_uri ();
        }

        public override void select_glib_files (GLib.List<GLib.File> files, GLib.File? focus_location) {
            current_slot.select_glib_files (files, focus_location);
        }

        public override void focus_first_for_empty_selection (bool select = true) {
            current_slot.focus_first_for_empty_selection (select);
        }

        public override void zoom_in () {
            ((View.Slot)(current_slot)).zoom_in ();
        }

        public override void zoom_out () {
            ((View.Slot)(current_slot)).zoom_out ();
        }

        public override void zoom_normal () {
            ((View.Slot)(current_slot)).zoom_normal ();
        }

        public override void grab_focus () {
            ((View.Slot)(current_slot)).grab_focus ();
        }

        public override void initialize_directory () {
            ((View.Slot)(current_slot)).initialize_directory ();
        }

        public override void reload (bool non_local_only = false) {
            ((View.Slot)(current_slot)).reload (non_local_only);
        }

        public override void close () {
            current_slot = null;

            if (scroll_to_slot_timeout_id > 0) {
                GLib.Source.remove (scroll_to_slot_timeout_id);
            }
            if (total_width_timeout_id > 0) {
                GLib.Source.remove (total_width_timeout_id);
            }

            truncate_list_after_slot (slot_list.first ().data);
        }

        public override bool set_all_selected (bool all) {
            return ((View.Slot)(current_slot)).set_all_selected (all);
        }

        public override FileInfo? lookup_file_info (GLib.File loc) {
            return current_slot.lookup_file_info (loc);
        }

        /* Animation functions */

        private uint animation_timeout_source_id = 0;
        private void smooth_adjustment_to (Gtk.Adjustment adj, int final) {
            cancel_animation ();

            var initial = adj.value;
            var to_do = final - initial;

            int factor;
            (to_do > 0) ? factor = 1 : factor = -1;
            to_do = (double) (((int) to_do).abs () + 1);

            var newvalue = 0;
            var old_adj_value = adj.value;

            animation_timeout_source_id = Timeout.add (1000 / 60, () => {
                /* If the user move it at the same time, just stop the animation */
                if (old_adj_value != adj.value) {
                    animation_timeout_source_id = 0;
                    return GLib.Source.REMOVE;
                }

                if (newvalue >= to_do - 10) {
                    /* to be sure that there is not a little problem */
                    adj.value = final;
                    animation_timeout_source_id = 0;
                    return GLib.Source.REMOVE;
                }

                newvalue += 10;

                adj.value = initial + factor *
                            Math.sin (((double) newvalue / (double) to_do) * Math.PI / 2) * to_do;

                old_adj_value = adj.value;
                return GLib.Source.CONTINUE;
            });
        }

        private bool get_animating () {
            return animation_timeout_source_id > 0;
        }

        private void cancel_animation () {
            if (animation_timeout_source_id > 0) {
                Source.remove (animation_timeout_source_id);
                animation_timeout_source_id = 0;
            }
        }
    }
}
