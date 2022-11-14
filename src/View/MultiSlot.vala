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

public class Files.MultiSlot : Object {
    public Gtk.Box content_box { get; construct; }
    public Gtk.Overlay overlay { get; construct; }
    public ViewContainer ctab { get; construct; }
    public GLib.File root_location { get; set construct; }
    public ViewMode view_mode { get; set; }
    /* Need private copy of initial location as MultiSlot
     * does not have its own Asyncdirectory object */

    private uint scroll_to_slot_timeout_id = 0;
    private Gtk.ScrolledWindow scrolled_window;
    private Gtk.Viewport viewport;
    private Gtk.Adjustment hadj;
    private Slot? current_slot = null;
    private GLib.List<Slot> slot_list = null;
    private int total_width = 0;

    // public bool is_frozen {
    //     set {
    //         if (current_slot != null) {
    //             current_slot.is_frozen = value;
    //         }
    //     }

    //     get {
    //         return current_slot == null || current_slot.is_frozen;
    //     }
    // }

    public MultiSlot (ViewContainer ctab) {
        Object (
            ctab: ctab
        );
    }

    ~MultiSlot () {
        debug ("MultiSlot destruct");
    }

    construct {
        scrolled_window = new Gtk.ScrolledWindow () {
            hscrollbar_policy = Gtk.PolicyType.ALWAYS,
            vscrollbar_policy = Gtk.PolicyType.NEVER
        };
        hadj = scrolled_window.get_hadjustment ();
        viewport = new Gtk.Viewport (null, null) {
            scroll_to_focus = true //TODO Is this sufficient?
        };
        scrolled_window.set_child (viewport);
        overlay.child = scrolled_window;
        //
        // add_main_child (scrolled_window);

        var key_controller = new Gtk.EventControllerKey () {
            propagation_phase = Gtk.PropagationPhase.CAPTURE
        };
        viewport.add_controller (key_controller);
        key_controller.key_pressed.connect (on_key_pressed);
        (Files.Preferences.get_default ()).notify["show-hidden-files"].connect ((s, p) => {
            show_hidden_files_changed (((Files.Preferences)s).show_hidden_files);
        });

        // add_location (root_location, null); /* current slot gets set by this */
        // is_frozen = true;
    }

    /** Creates a new slot in the host slot hpane */
    public void add_location (GLib.File loc, Slot? host = null) {
        var guest = new Slot (loc, ctab, ViewMode.MULTI_COLUMN);
        /* Notify view container of path change - will set tab to working and change pathbar */
        // path_changed ();
        guest.slot_number = (host != null) ? host.slot_number + 1 : 0;
        connect_slot_signals (guest);

        if (host != null) {
            truncate_list_after_slot (host);
            host.hpaned.end_child = guest.hpaned;
            guest.initialize_directory ();
        } else {
            viewport.child = guest.hpaned;
        }

        slot_list.append (guest); // Must add to list before scrolling
        // Must set the new slot to be  activehere as the tab does not change (which normally sets its slot active)
        guest.active (true, true);

        update_total_width ();
    }

    public void clear () {
        current_slot = null;
        truncate_list_after_slot (null);
        // while (viewport.get_last_child () != null) {
        //     viewport.get_last_child ().unparent ();
        // }
    }

    private void truncate_list_after_slot (Slot? slot) {
        if (slot_list.length () <= 0) { //Can be assumed to limited in length
            return;
        }

        uint n = slot != null ? slot.slot_number : -1;
        slot_list.@foreach ((s) => {
            if (s.slot_number > n) {
                disconnect_slot_signals (s);
                s.close ();
            }
        });

        var child = ((Slot)slot).hpaned.end_child;
        child.unparent ();
        child.destroy ();
//TODO Check for memory leak
        if (n >= 0) {
            slot_list.nth (n).next = null;
            current_slot = slot;
            slot.active ();
        }
    }

    private void calculate_total_width () {
        total_width = 300; // Extra space to allow increasing the size of columns by dragging the edge
        slot_list.@foreach ((slot) => {
            total_width += slot.width;
        });
    }

    private void update_total_width () {
        calculate_total_width ();
        viewport.set_size_request (total_width, -1);
    }

/*********************/
/** Signal handling **/
/*********************/

    public void user_path_change_request (GLib.File loc) {
        /* Requests from history buttons, pathbar come here with make_root = false.
         * These do not create a new root.
         * Requests from the sidebar have make_root = true
         */
        change_path (loc);
    }

    private void change_path (GLib.File loc) {
        var first_slot = slot_list.first ().data;
        string root_uri = first_slot.uri;
        string target_uri = loc.get_uri ();
        bool found = false;

        if (target_uri.has_prefix (root_uri) && target_uri != root_uri) {
            /* Try to add location relative to each slot in turn, starting at end */
            var copy_slot_list = slot_list.copy ();
            copy_slot_list.reverse ();
            foreach (Slot s in copy_slot_list) {
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
                first_slot.user_path_change_request (loc);
                root_location = loc;
                // Sidebar requests make_root true - first directory will be selected;
                //  * Go_up requests make_root false - previous directory will be selected
                //
                // if (make_root) {
                //     /* Do not select (match behaviour of other views) */
                //     first_slot.focus_first_for_empty_selection (false);
                // }
            }
        }
    }

    private bool add_relative_path (Slot root, GLib.File loc) {
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
        // slot.selection_changing.connect (on_slot_selection_changing);
        // slot.update_selection.connect (on_slot_update_selection);
        // slot.frozen_changed.connect (on_slot_frozen_changed);
        slot.active.connect (on_slot_active);
        slot.miller_slot_request.connect (on_miller_slot_request);
        // slot.new_container_request.connect (on_new_container_request);
        // slot.size_change.connect (update_total_width);
        slot.folder_deleted.connect (on_slot_folder_deleted);
        //TODO Use EventController
        // slot.colpane.key_press_event.connect (on_key_pressed);
        // slot.path_changed.connect (on_slot_path_changed);
        // slot.directory_loaded.connect (on_slot_directory_loaded);
    }

    private void disconnect_slot_signals (Slot slot) {
        // slot.selection_changing.disconnect (on_slot_selection_changing);
        // slot.update_selection.disconnect (on_slot_update_selection);
        // slot.frozen_changed.disconnect (on_slot_frozen_changed);
        slot.active.disconnect (on_slot_active);
        slot.miller_slot_request.disconnect (on_miller_slot_request);
        // slot.new_container_request.disconnect (on_new_container_request);
        // slot.size_change.disconnect (update_total_width);
        slot.folder_deleted.disconnect (on_slot_folder_deleted);
        // slot.colpane.key_press_event.disconnect (on_key_pressed);
        // slot.path_changed.disconnect (on_slot_path_changed);
        // slot.directory_loaded.disconnect (on_slot_directory_loaded);
    }

    private void on_miller_slot_request (Slot slot, GLib.File loc, bool make_root) {
        if (make_root) {
            /* Start a new tree with root at loc */
            if (make_root) {
                //Clear slots
            }
            change_path (loc);
        } else {
            /* Just add another column to the end. */
            add_location (loc, slot);
        }
    }

    // private void on_new_container_request (GLib.File loc, Files.OpenFlag flag) {
    //     new_container_request (loc, flag);
    // }

    // private void on_slot_path_changed () {
    //     path_changed ();
    // }

    // private void on_slot_directory_loaded (Directory dir) {
    //     directory_loaded (dir);
    // }

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
        Slot slot;

        if (!(aslot is Slot)) {
            return;
        } else {
            slot = aslot as Slot;
        }

        // if (scroll) {
        //     schedule_scroll_to_slot (slot, animate);
        // }

        if (this.current_slot != slot) {
            slot_list.@foreach ((s) => {
                if (s != slot) {
                    s.inactive ();
                }
            });

            current_slot = slot;
        }
        /* Always emit this signal so that UI updates (e.g. pathbar) */
        ctab.refresh_slot_info (current_slot.location);
    }

    public void show_first_item () {
        if (current_slot != null) {
            current_slot.show_first_item ();
        }
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
            Slot slot = slot_list.nth_data (hidden - 1);
            truncate_list_after_slot (slot);
            slot.active ();
        }
    }

    private bool on_key_pressed (
        uint keyval,
        uint keycode,
        Gdk.ModifierType state
    ) requires (current_slot != null) {

        /* Only handle unmodified keys */
        if ((state & Gtk.accelerator_get_default_mod_mask ()) > 0) {
            return false;
        }

        int current_position = slot_list.index (current_slot);

        // if (slot_list.nth_data (current_position).get_view_widget ().renaming) {
        //     return false;
        // }

        Slot to_activate = null;
        switch (keyval) {
            case Gdk.Key.Left:
                if (current_position > 0) {
                    to_activate = slot_list.nth_data (current_position - 1);
                }

                break;

            case Gdk.Key.Right:
                    var selected_files = current_slot.get_selected_files ();
                    if (selected_files == null) {
                        return true;
                    }

                    var selected_file = selected_files.first ().data;
                unowned var current_location = selected_files.first ().data.location;
                GLib.File? next_location = null;
                if (current_position < slot_list.length () - 1) { //Can be assumed to limited in length
                    next_location = slot_list.nth_data (current_position + 1).location;
                }

                if (next_location != null && next_location.equal (current_location)) {
                    to_activate = slot_list.nth_data (current_position + 1);
                } else if (selected_file.is_folder ()) {
                    add_location (current_location, current_slot);
                    return true;
                }

                break;

            case Gdk.Key.BackSpace:
                    if (current_position > 0) {
                        truncate_list_after_slot (slot_list.nth_data (current_position - 1));
                    }

                break;

            default:
                return false;
        }

        if (to_activate != null) {
            to_activate.active ();
            // to_activate.focus_first_for_empty_selection (true); /* Selects as well as focusses */
        }

        return true;
    }

    private void on_slot_update_selection (GLib.List<Files.File> files) {
        // update_selection (files);
    }

    private void on_slot_selection_changing () {
        // selection_changing ();

    }

    // private void on_slot_frozen_changed (Slot slot, bool frozen) {
    //     /* Ensure all slots synchronise the frozen state */

    //     slot_list.@foreach ((abstract_slot) => {
    //         var s = abstract_slot as Slot;
    //         if (s != null) {
    //             s.frozen_changed.disconnect (on_slot_frozen_changed);
    //             s.is_frozen = frozen;
    //             s.frozen_changed.connect (on_slot_frozen_changed);
    //         }
    //     });
    // }


/** Helper functions */
    public unowned Slot? get_current_slot () {
        return current_slot;
    }

    public List<Files.File> get_selected_files () {
        List<Files.File> selected_files = ((Slot)(current_slot)).get_selected_files ();
        return (owned)selected_files;
    }

    public void set_active_state (bool set_active, bool animate = true) {
        if (set_active) {
            current_slot.active (true, animate);
        } else {
            current_slot.inactive ();
        }
    }

    public string? get_tip_uri () {
        if (slot_list != null &&
            slot_list.last () != null &&
            slot_list.last ().data is Files.AbstractSlot) {

            return slot_list.last ().data.uri;
        } else {
            return null;
        }
    }

    public string? get_root_uri () {
        return root_location.get_uri ();
    }

    public void select_glib_files (GLib.List<GLib.File> files, GLib.File? focus_location) {
        current_slot.select_glib_files (files, focus_location);
    }

    public void zoom_in () {
        ((Slot)(current_slot)).zoom_in ();
    }

    public void zoom_out () {
        ((Slot)(current_slot)).zoom_out ();
    }

    public void zoom_normal () {
        ((Slot)(current_slot)).zoom_normal ();
    }

    public void grab_focus () {
        ((Slot)(current_slot)).grab_focus ();
    }

    public void initialize_directory () {
        ((Slot)(current_slot)).initialize_directory ();
    }

    public void reload (bool non_local_only = false) {
        ((Slot)(current_slot)).reload (non_local_only);
    }

    public void close () {
        current_slot = null;

        if (scroll_to_slot_timeout_id > 0) {
            GLib.Source.remove (scroll_to_slot_timeout_id);
        }

        truncate_list_after_slot (slot_list.first ().data);
    }

    public bool set_all_selected (bool all) {
        return ((Slot)(current_slot)).set_all_selected (all);
    }

    public FileInfo? lookup_file_info (GLib.File loc) {
        return current_slot.lookup_file_info (loc);
    }
}
