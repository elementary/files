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
        var guest = new Slot (loc, view_mode);
        var hpaned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        hpaned.start_child = guest;
        Gtk.Paned? host = null;
        if (view_mode == ViewMode.MULTICOLUMN) {
            host = get_host_for_loc (loc);
        }

        if (host != null) {
            truncate_list_after_host (host);
            host.end_child = hpaned;
        } else {
            clear ();
            viewport.child = hpaned;
        }
        current_slot = guest;
        // update_total_width ();
    }

    private Gtk.Paned? get_host_for_loc (GLib.File file) {
        var host = (Gtk.Paned)(viewport.child);
        while (host != null) {
            var slot = (Slot)(host.start_child);
            if (slot.file.location.get_relative_path (file) == null) {
                break;
            }

            if (host.end_child is Gtk.Paned) {
                host = (Gtk.Paned)(host.end_child);
                break;
            }
        }

        return host;
    }

    public void clear () {
        while (viewport.get_last_child () != null) {
            viewport.get_last_child ().unparent ();
        }
    }

    private void truncate_list_after_host (Gtk.Paned host) {
        var to_unparent = host.end_child;
        while (to_unparent.get_last_child () != null) {
            to_unparent.get_last_child ().unparent ();
        }
        to_unparent.unparent ();
    }

    public void update_total_width () {
        total_width = 300; // Extra space to allow increasing the size of columns by dragging the edge
        var host = (Gtk.Paned)(viewport.child);
        while (host != null && (host is Gtk.Paned)) {
            var slot = (Slot)(((Gtk.Paned)host).start_child);
            total_width += slot.width;

            if (host.end_child is Gtk.Paned) {
                host = (Gtk.Paned)(host.end_child);
            } else {
                break;
            }
        }

        scrolled_window.min_content_width = total_width;
// warning ("setting total width %i", total_width);
        viewport.set_size_request (total_width, -1);
    }

    public void folder_deleted (GLib.File file) {
        var host = (Gtk.Paned)(viewport.child);
        while (host != null) {
            var slot = (Slot)(((Gtk.Paned)host).start_child);
            if (slot.file.uri == file.get_uri ()) { // Showing a deleted location
                var parent = host.get_parent ();
                if (parent is Gtk.Paned) {
                    truncate_list_after_host ((Gtk.Paned)parent);
                } else {
                    clear ();
                }

                break;
            }

            if (host.end_child is Gtk.Paned) {
                host = (Gtk.Paned)(host.end_child);
            } else {
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
        if (show_hidden) {
            return;
        }
        /* we are hiding hidden files - check whether any slot is a hidden directory */
        int i = -1;
        int hidden = -1;

        var host = (Gtk.Paned)(viewport.child);
        while (host != null) {
            var slot = (Slot)(((Gtk.Paned)host).start_child);
            if (slot.file.is_hidden) {
                var parent = host.get_parent ();
                if (parent is Gtk.Paned) {
                    truncate_list_after_host ((Gtk.Paned)parent);
                } else {
                    clear ();
                }

                break;
            }

            if (host.end_child is Gtk.Paned) {
                host = (Gtk.Paned)(host.end_child);
            } else {
                break;
            }
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

        var current_host = (Gtk.Paned)(current_slot.parent);
        var parent_host = current_host.parent;
        Slot to_activate = null;
        switch (keyval) {
            case Gdk.Key.Left:
                if (parent_host is Gtk.Viewport) {
                } else {
                    to_activate = (Slot)((Gtk.Paned)parent_host).start_child;
                }

                break;

            case Gdk.Key.Right:
                var selected_files = current_slot.get_selected_files ();
                if (selected_files == null) {
                    return true;
                }

                var selected_file = selected_files.first ().data;
                unowned var selected_location = selected_files.first ().data.location;
                GLib.File? next_location = null;
                var next_host = current_host.end_child;
                if (next_host != null && (next_host is Gtk.Paned)) {
                    next_location = ((Slot)(((Gtk.Paned)next_host).start_child)).file.location;
                }

                if (next_location != null && next_location.equal (selected_location)) {
                    to_activate = ((Slot)(((Gtk.Paned)next_host).start_child));
                } else if (selected_file.is_folder ()) {
                    // truncate_list_after_host (current_host);
                    add_location (((Slot)(current_host.start_child)).file.location);
                    return true;
                }

                break;

            case Gdk.Key.BackSpace:
                    if (!(parent_host is Gtk.Viewport)) {
                        truncate_list_after_host ((Gtk.Paned)parent_host);
                    }

                break;

            default:
                return false;
        }

        return true;
    }

/** Helper functions */
    public List<Files.File>? get_selected_files () {
        if (current_slot != null) {
            List<Files.File> selected_files = ((Slot)(current_slot)).get_selected_files ();
            return (owned)selected_files;
        } else {
            return null;
        }
    }

    public string? get_tip_uri () {
        var host = (Gtk.Paned)(viewport.child);
        while (host != null && (host.end_child is Gtk.Paned)) {
            host = (Gtk.Paned)(host.end_child);
        }

        if (host != null) {
            return ((Slot)((host.start_child))).file.uri;
        }

        return null;
    }

    public string? get_root_uri () {
        var host = (Gtk.Paned)(viewport.child);
        if (host != null) {
            return ((Slot)(host.start_child)).file.uri;
        }

        return null;
    }
}
