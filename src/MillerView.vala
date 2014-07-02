/***
  Copyright (C)  

  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE. See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program. If not, see <http://www.gnu.org/licenses/>.

 Authors :    
***/

namespace Marlin {
    //public class Window.Columns : GOF.AbstractSlot {
    public class Window.Columns : GOF.Window.Slot {

        //public GOF.Directory.Async directory;
        //public GLib.File location;
        public Gtk.ScrolledWindow scrolled_window; // == viewbox
        public Gtk.Adjustment hadj;
        //public Gtk.Box colpane;

        //public Marlin.View.ViewContainer ctab;
        public GOF.Window.Slot active_slot;
        public GLib.List<GOF.Window.Slot> slot_list;

        public int preferred_column_width;
        public int total_width = 0;
        private int handle_size;

        //public signal void active ();
        //public signal void inactive ();

        public Columns (GLib.File location, Marlin.View.ViewContainer ctab) {
            base (location, ctab);
            preferred_column_width = Preferences.marlin_column_view_settings.get_int ("preferred-column-width");
            (GOF.Preferences.get_default ()).notify.connect (show_hidden_files_changed);

            //this.location = location;
            //this.ctab = ctab;

            this.colpane = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

            this.scrolled_window = new Gtk.ScrolledWindow (null, null);
            scrolled_window.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.NEVER);
            this.hadj = scrolled_window.get_hadjustment ();

            var viewport = new Gtk.Viewport (null, null);
            viewport.set_shadow_type (Gtk.ShadowType.NONE);
            viewport.add (this.colpane);

            scrolled_window.add (viewport);
            content_box.pack_start (scrolled_window);
            content_box.show_all ();
            ctab.content = content_box;

            this.colpane.add_events (Gdk.EventMask.KEY_RELEASE_MASK);
            this.colpane.key_release_event.connect (on_key_pressed);
        }

        public new Gtk.Widget make_view () {
//            var slot = new GOF.Window.Slot (location, ctab);
//            slot.colpane = this.colpane;
            this.active_slot = this;
//            this.slot_list.append (slot);
//            slot.hpane.style_get ("handle-size", out this.handle_size, null);

            add_location (this.location);
//            return make_view_in_slot (active_slot);
            return this.content_box as Gtk.Widget;
        }

        public string get_tip_uri () {
            return slot_list.last ().data.directory.file.uri.dup ();
        }

        public string get_root_uri () {
            return slot_list.first ().data.directory.file.uri.dup ();
        }

        private Gtk.Widget make_view_in_slot (GOF.Window.Slot slot) {
message ("Miller: make view in slot number %i", slot.slot_number);
            slot.make_column_view ();
            nest_slot_in_active_slot (slot);
            slot.directory.track_longest_name = true;
            slot.directory.load ();
message ("Miller: make view in slot - finished");
            return content_box as Gtk.Widget;

        }

        /* Was GOF.Window.Slot.column_add () */
        /* called only by make view in slot */
        /* Nests a given slot into the active_slot colpane*/ 
        private void nest_slot_in_active_slot (GOF.Window.Slot slot) {
            var hpane1 = new Granite.Widgets.ThinPaned (Gtk.Orientation.HORIZONTAL);
            //var hpane1 = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
            hpane1.hexpand = true;
            slot.hpane = hpane1;

            var box1 = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            slot.colpane = box1;
            var column = slot.view_box;
            column.set_size_request (preferred_column_width, -1);
            column.size_allocate.connect ((a) => {update_total_width (a, slot);});

            hpane1.pack1 (column, false, false);
            hpane1.pack2 (box1, true, false);
            hpane1.show_all ();

message ("Active slot number is %i", active_slot.slot_number);
            if (active_slot.slot_number >= 0 && active_slot.colpane != null)
                this.active_slot.colpane.add (hpane1);
            else {
                slot.colpane = this.colpane;
                slot.colpane.add (hpane1 as Gtk.Widget);
                this.active_slot = slot;
            }
//            /* If the directory finished loading before slot was ready then autosize the slot now.
//            * Otherwise the slot will be autosized by the directory_done_loading callback
//            * This is necessary because the directory loads faster from the cache than from disk
//            * On first use the directory loads from disk and we reach here before the directory
//            * has finished loading.
//            * On subsequent uses, the directory loads from cache before the slot is ready.
//            * Whichever finishes first sets slot->ready_to_autosize = TRUE
//            * Whichever finds slot->ready_to_autosize = TRUE does the autosizing.
//            */

            //autosize_slot (slot);

        }


        /* Called locally by make view and externally by Window.expand_miller_view */
        /* creates a new slot in the active slot hpane*/
        public void add_location (GLib.File location) {
message ("Miller: add_location");
        /* First prepare active slot to receive new child
         * then call marlin_window_columns_add */
            truncate_list_after_slot (this.active_slot);
            var slot = new GOF.Window.Slot (location, this.ctab);
            slot.width = preferred_column_width;
            slot.slot_number = this.active_slot.slot_number + 1;
            connect_slot_signals (slot);
            make_view_in_slot (slot);
            slot_list.append (slot);
            total_width += slot.width + 100;
            this.colpane.set_size_request (total_width, -1);
            /* Set mwcols->active_slot now in case another slot is created before
             * this one really becomes active, e.g. during restoring tabs on startup */
            make_slot_active (slot);
message ("Miller: add_location finish");
        }

        /* Was GOF.Window.Slot.columns_add_location () */
        /* Called locally by add_location, show_hidden_files_changed and as callback when file deleted. */
        private void truncate_list_after_slot (GOF.Window.Slot? slot) {

            if (slot == null || slot.colpane == null)
                return;

message ("Miller: truncate slot number %i", slot.slot_number);
            slot.colpane.@foreach ((w) => {
                w.destroy ();
            });

            int total_width = 0;
            unowned GLib.List<GOF.Window.Slot> slots = slot_list;
            int current_slot_position = slots.index (slot);
            GLib.List<GOF.Window.Slot> new_list = null;

            if (current_slot_position >= 0) {
                for (int i = 0; i < current_slot_position; i++) {
                    new_list.append (slots.data);
                    total_width += (slots.data as GOF.Window.Slot).width;
                    slots = slots.next;
                }
                slot_list = new_list.copy ();
            } else
                slot_list = null;
        }

        private void update_total_width (Gtk.Allocation allocation, GOF.Window.Slot slot) {
message ("Miller: update total width slot number %i", slot.slot_number);
            if (total_width != 0 && slot.width != allocation.width) {
                total_width += allocation.width - slot.width;
                slot.width = allocation.width;
                colpane.set_size_request (total_width, -1);
            }
        }

        private void make_slot_active (GOF.Window.Slot slot) {
message ("Miller: make slot number %i active", slot.slot_number);
            bool sum_completed = false;
            int width = 0;
            slot_list.@foreach ((s) => {
                if (s != slot)
                    s.inactive ();
                else
                    sum_completed = true;

                if (!sum_completed)
                    width += s.width;
            });

            active_slot = slot;
            //slot.active ();

            Marlin.Animation.smooth_adjustment_to (hadj, width + slot.slot_number * handle_size);
        }

/** Signal handling **/
        private void connect_slot_signals (GOF.Window.Slot slot) {
message ("Connect signals to slot number %i", slot.slot_number);
            GOF.Directory.Async dir = slot.directory;
            dir.done_loading.connect (() => {
                autosize_slot (slot);
            });
            dir.file_deleted.connect ((f) => {
                if (f.is_directory)
                    //TODO Check if this is right - copied from existing code
                    truncate_list_after_slot (active_slot);
            });
            slot.frozen.connect (on_slot_frozen_changed);
            slot.active.connect (() => {
                make_slot_active (slot);
            });
        }

         private void autosize_slot (GOF.Window.Slot slot) {
message ("autosize slot number %i", slot.slot_number);
            //if (slot.ready_to_autosize) {
                slot.autosize (handle_size, preferred_column_width);
                this.colpane.show_all ();
                this.colpane.queue_draw ();
            //} else
             //   slot.ready_to_autosize = true;
        }

        //private void show_hidden_files_changed (GLib.ParamSpec pspec) {
        private void show_hidden_files_changed () {
            if (!GOF.Preferences.get_default ().pref_show_hidden_files) {
                /* we are hiding hidden files - check whether any slot is a hidden directory */
                int i = 0;
                int hidden = -1;
                slot_list.@foreach ((s) => {
                    if (s.directory.file.is_hidden && hidden <= 0)
                        hidden = i;

                    i ++;
                });

                if (hidden <= 0)
                    /* no hidden folder found or only first folder hidden */
                    return;

                unowned GOF.Window.Slot slot = slot_list.nth_data (hidden - 1);
                truncate_list_after_slot (slot);
                make_slot_active (slot);
            }
        }

        private bool on_key_pressed (Gtk.Widget box, Gdk.EventKey event) {
            int active_position = slot_list.index (active_slot);
            GOF.Window.Slot to_active = null;

            switch (event.keyval) {
                case Gdk.Key.Left:
                    if (active_position > 0)
                        to_active = slot_list.nth_data (active_position - 1);

                    if (to_active != null) {
                        to_active.view_box.grab_focus ();
                        //TODO include grab focus in make_slot_active?
                        make_slot_active (to_active);
                        return true;
                    }
                    break;

                case Gdk.Key.Right:
                    if (active_position < slot_list.length () - 1)
                        to_active = slot_list.nth_data (active_position + 1);

                    if (to_active != null) {
                        to_active.view_box.grab_focus ();
                        make_slot_active (to_active);
                        to_active.view_box.select_first_for_empty_selection ();
                        return true;
                    }
                    break;
            }
            return false;
        }

        private void on_slot_frozen_changed (bool frozen) {
            if (frozen)
                GLib.SignalHandler.block_by_func (colpane, (void*)on_key_pressed, this);
            else
                GLib.SignalHandler.unblock_by_func (colpane, (void*)on_key_pressed, this);
        }
    }
}
