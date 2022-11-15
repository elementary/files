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

public class Files.MultiSlot : Gtk.Box {
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
    public unowned Slot? current_slot { get; private set; }
    private Gee.ArrayList<Slot> slot_list = null;
    // private GLib.List<Slot> slot_list = null;
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
        slot_list = new Gee.ArrayList<Slot> (null);
        scrolled_window = new Gtk.ScrolledWindow () {
            hscrollbar_policy = Gtk.PolicyType.ALWAYS,
            vscrollbar_policy = Gtk.PolicyType.NEVER
        };
        hadj = scrolled_window.get_hadjustment ();
        viewport = new Gtk.Viewport (null, null) {
            scroll_to_focus = true //TODO Is this sufficient?
        };
        scrolled_window.set_child (viewport);

        overlay = new Gtk.Overlay ();
        overlay.child = scrolled_window;
        overlay.set_parent (this);
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

        // is_frozen = true;
    }

    /** Creates a new slot in the last slot hpane */
    public void add_location (GLib.File? loc) {
        // Always create new Slot rather than navigate for simplicity.
        //TODO Check for performance/memory leak
        var guest = new Slot (loc, ctab, view_mode);
// warning ("new slot refs %u", guest.ref_count);
        var size = slot_list.size;
        var host = (size == 0 ? null : slot_list.@get (size - 1));

        if (view_mode == ViewMode.MULTICOLUMN && host != null) {
            guest.slot_number = host.slot_number + 1;
            host.hpaned.end_child = guest.hpaned;
        } else {
            clear ();
            viewport.child = guest.hpaned;
        }
// warning ("after add hpaned slot refs %u", guest.ref_count);
        guest.slot_number = slot_list.size;
        slot_list.insert (guest.slot_number, guest); // Must add to list before scrolling
// warning ("after add slot list refs %u", guest.ref_count);
        connect_slot_signals (guest);
// warning ("after connect refs %u", guest.ref_count);
        // Must set the new slot to be  active here as the tab does not change (which normally sets its slot active)
        guest.active (true, true);
// warning ("aftersignal active refs %u", guest.ref_count);
        update_total_width ();
// warning ("after update total wi refs %u", guest.ref_count);
// warning ("after add location slot refs %u", guest.ref_count);
    }

    public void clear () {
        truncate_list_after_slot (null);
    }

    private void truncate_list_after_slot (Slot? slot) {
        if (slot_list.size <= 0) { //Can be assumed to limited in length
            return;
        }

        int n = slot != null ? slot.slot_number : -1;
        int index = slot_list.size;
        while (--index > n) {
            var s = slot_list.remove_at (index);
warning ("truncate slot %i - remaining refs %u", s.slot_number, s.ref_count);
                disconnect_slot_signals (s);
                s.close ();
                s.hpaned.unparent ();
                s.dispose ();
warning ("disposed slot %i - remaining refs %u", s.slot_number, s.ref_count);
        }

warning ("slot list size now %u", slot_list.size);
        if (slot_list.size == 0) {
            current_slot = null;
        } else {
            current_slot = slot_list.@get (slot_list.size - 1);
        }

        // if (n >= 0) {
        //     var child = ((Slot)slot).hpaned.end_child;
        //     child.unparent ();
        //     child.destroy ();
        // } else {
        //     var child = viewport.child;
        //     child.unparent ();
        //     child.destroy ();
        // }
        // //TODO Check for memory leak
        // if (n >= 0) {
        //     slot_list.nth (n).next = null;
        //     current_slot = slot;
        //     slot.active ();
        // } else {
        //     slot_list = null;
        //     current_slot = null;
        // }
    }

    private void calculate_total_width () {
        total_width = 300; // Extra space to allow increasing the size of columns by dragging the edge
        foreach (var slot in slot_list) {
            total_width += slot.width;
        }
    }

    private void update_total_width () {
        calculate_total_width ();
        viewport.set_size_request (total_width, -1);
    }

/*********************/
/** Signal handling **/
/*********************/
    private void change_path (GLib.File loc) {
        var first_slot = slot_list.@get (0);
        string root_uri = first_slot.uri;
        string target_uri = loc.get_uri ();
        bool found = false;

        if (target_uri.has_prefix (root_uri) && target_uri != root_uri) {
            /* Try to add location relative to each slot in turn, starting at end */
            // var copy_slot_list = slot_list.copy ();
            // copy_slot_list.reverse ();
            int index = slot_list.size;
            while (--index >= 0) {
                var s = slot_list.@get (index);
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

                    var last_slot = slot_list.@get (slot_list.size - 1);
                    var file = GLib.File.new_for_uri (last_uri);
                    var list = new List<GLib.File> ();
                    list.prepend (file);
                    last_slot.select_glib_files (list, file);
                    Thread.usleep (100000);
                    add_location (file);
                    // add_location (file, last_slot);

                }
            }
        } else {
            return false;
        }
        return true;
    }

    private void connect_slot_signals (Slot slot) {
        slot.active.connect (on_slot_active);
    }

    private void disconnect_slot_signals (Slot slot) {
        slot.active.disconnect (on_slot_active);
    }

    public void folder_deleted (GLib.File file) {
        foreach (var slot in slot_list) {
            if (slot.file.uri == file.get_uri ()) { // Showing a deleted location
                if (slot.slot_number > 0) {
                    Slot? previous_slot = slot_list.@get (slot.slot_number - 1);
                    if (previous_slot != null) {
                        truncate_list_after_slot (slot);
                    }
                } else {
                    clear ();
                }

                break;
            }
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
            foreach (var s in slot_list) {
                if (s != slot) {
                    s.inactive ();
                }
            }

            current_slot = slot;
        }
        /* Always emit this signal so that UI updates (e.g. pathbar) */
        ctab.refresh_slot_info (current_slot.location);
    }

    private void show_hidden_files_changed (bool show_hidden) {
        if (!show_hidden) {
            /* we are hiding hidden files - check whether any slot is a hidden directory */
            int i = -1;
            int hidden = -1;

            foreach (var s in slot_list) {
                i ++;
                if (s.directory.file.is_hidden && hidden <= 0) {
                    hidden = i;
                }
            }

            /* Return if no hidden folder found or only first folder hidden */
            if (hidden <= 0) {
                return;
            }

            /* Remove hidden slots and make the slot before the first hidden slot active */
            var slot = slot_list.@get (hidden - 1);
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

        int current_position = current_slot.slot_number;

        // if (slot_list.nth_data (current_position).get_view_widget ().renaming) {
        //     return false;
        // }

        Slot to_activate = null;
        switch (keyval) {
            case Gdk.Key.Left:
                if (current_position > 0) {
                    to_activate = slot_list.@get (current_position - 1);
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
                if (current_position < slot_list.size - 1) { //Can be assumed to limited in length
                    next_location = slot_list.@get (current_position + 1).location;
                }

                if (next_location != null && next_location.equal (current_location)) {
                    to_activate = slot_list.@get (current_position + 1);
                } else if (selected_file.is_folder ()) {
                    truncate_list_after_slot (slot_list.@get (current_position));
                    add_location (current_location);
                    // add_location (current_location, current_slot);
                    return true;
                }

                break;

            case Gdk.Key.BackSpace:
                    if (current_position > 0) {
                        truncate_list_after_slot (slot_list.@get (current_position - 1));
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
    public List<Files.File> get_selected_files () {
        if (current_slot != null) {
            List<Files.File> selected_files = ((Slot)(current_slot)).get_selected_files ();
            return (owned)selected_files;
        } else {
            return null;
        }
    }

    public string? get_tip_uri () {
        if (slot_list.size > 0) {
            return slot_list.@get (slot_list.size - 1).uri;
        } else {
            return null;
        }
    }

    public string? get_root_uri () {
        return root_location != null ? root_location.get_uri () : null;
    }
}
