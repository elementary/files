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
    private Slot? current_slot;
    private Gee.ArrayList<Slot> slot_list = null;
    private int total_width = 0;

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
            hscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
            vscrollbar_policy = Gtk.PolicyType.NEVER
        };
        hadj = scrolled_window.get_hadjustment ();
        viewport = new Gtk.Viewport (null, null) {
            hexpand = true
        };
        scrolled_window.set_child (viewport);

        overlay = new Gtk.Overlay ();
        overlay.child = scrolled_window;
        overlay.set_parent (this);

        var key_controller = new Gtk.EventControllerKey () {
            propagation_phase = Gtk.PropagationPhase.CAPTURE
        };
        viewport.add_controller (key_controller);
        key_controller.key_pressed.connect (on_key_pressed);
        (Files.Preferences.get_default ()).notify["show-hidden-files"].connect ((s, p) => {
            show_hidden_files_changed (((Files.Preferences)s).show_hidden_files);
        });
    }

    /** Creates a new slot in the last slot hpane */
    public void add_location (GLib.File? loc) {
        // Always create new Slot rather than navigate for simplicity.
        //TODO Check for performance/memory leak
        var guest = new Slot (loc, ctab, view_mode);
// warning ("new slot refs %u", guest.ref_count);
        var size = slot_list.size;
        Slot? host = null;
        if (view_mode == ViewMode.MULTICOLUMN) {
            host = get_host_for_loc (loc);
        }

        if (host != null) {
            truncate_list_after_slot (host);
            host.hpaned.end_child = guest.hpaned;
        } else {
            clear ();
            viewport.child = guest.hpaned;
        }
// warning ("after add hpaned slot refs %u", guest.ref_count);
        guest.slot_number = slot_list.size;
        slot_list.insert (guest.slot_number, guest); // Must add to list before scrolling
        current_slot = guest;
// warning ("after add slot list refs %u", guest.ref_count);
        // connect_slot_signals (guest);
// warning ("after connect refs %u", guest.ref_count);
        // Must set the new slot to be  active here as the tab does not change (which normally sets its slot active)
        // guest.active (true, true);
// warning ("aftersignal active refs %u", guest.ref_count);
        update_total_width ();
// warning ("after update total wi refs %u", guest.ref_count);
// warning ("after add location slot refs %u", guest.ref_count);
    }

    private Slot? get_host_for_loc (GLib.File file) {
        int index = 0;
        while (index < slot_list.size &&
               slot_list.@get (index).location.get_relative_path (file) != null) {

            index++;
        }
        if (index == 0 || index > slot_list.size) {
            return null;
        }

        return slot_list.@get (index - 1);
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
// warning ("truncate slot %i - remaining refs %u", s.slot_number, s.ref_count);
                // disconnect_slot_signals (s);
                s.close ();
                s.hpaned.unparent ();
                s.dispose ();
// warning ("disposed slot %i - remaining refs %u", s.slot_number, s.ref_count);
        }

        if (slot_list.size == 0) {
            current_slot = null;
        } else {
            current_slot = slot_list.@get (slot_list.size - 1);
        }
    }

    private void calculate_total_width () {
        total_width = 300; // Extra space to allow increasing the size of columns by dragging the edge
        foreach (var slot in slot_list) {
            total_width += slot.width;
        }

        scrolled_window.min_content_width = total_width;
    }

    public void update_total_width () {
        calculate_total_width ();
        viewport.set_size_request (total_width, -1);
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

    public void set_current_slot (Slot slot) {
        current_slot = slot;  //TODO Anything else needed?
    }

    public unowned Slot? get_current_slot () {
        return current_slot;  //TODO Anything else needed?
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
            // slot.active ();
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

        return true;
    }

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
