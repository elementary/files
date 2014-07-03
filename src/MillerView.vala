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
    public class Window.Columns : GOF.Window.Slot {

        public Gtk.ScrolledWindow scrolled_window;
        public Gtk.Adjustment hadj;
        public GOF.Window.Slot active_slot;
        public GLib.List<GOF.Window.Slot> slot_list;

        public int preferred_column_width;
        public int total_width = 0;
        private int handle_size;

        public Columns (GLib.File location, Marlin.View.ViewContainer ctab) {
            base (location, ctab);
            preferred_column_width = Preferences.marlin_column_view_settings.get_int ("preferred-column-width");
            (GOF.Preferences.get_default ()).notify.connect (show_hidden_files_changed);

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

        public string get_tip_uri () {
            return slot_list.last ().data.directory.file.uri.dup ();
        }

        public string get_root_uri () {
            return slot_list.first ().data.directory.file.uri.dup ();
        }

        /** Called by ViewContainer to make initial root slot */
        public new Gtk.Widget make_view () {
            this.active_slot = this;
            add_location (this.location);
            return this.content_box as Gtk.Widget;
        }

        /** Called locally by make view and externally by Window.expand_miller_view and View Container*/
        /* TODO Make Expand Miller View a MillerView function */
        /** Creates a new slot in the active slot hpane */
        public void add_location (GLib.File location) {
            /* First prepare active slot to receive new child slot*/
            truncate_list_after_slot (this.active_slot);

            var slot = new GOF.Window.Slot (location, this.ctab);
            slot.slot_number = this.active_slot.slot_number + 1;
            slot_list.append (slot);
            slot.width = preferred_column_width;
            this.total_width += slot.width + 100;
            this.colpane.set_size_request (total_width, -1);

            make_view_in_slot (slot);
            connect_slot_signals (slot);

            /* Set mwcols->active_slot now in case another slot is created before
             * this one really becomes active, e.g. during restoring tabs on startup */
            slot.active ();
        }

        /** Called only by add_location */
        private Gtk.Widget make_view_in_slot (GOF.Window.Slot slot) {
            slot.make_column_view ();
            nest_slot_in_active_slot (slot);
            slot.directory.track_longest_name = true;
            slot.directory.load ();
            return content_box as Gtk.Widget;
        }

        /** Was GOF.Window.Slot.column_add () 
        /*  Called only by make_view_in_slot 
        /*  Nests a given slot into the active_slot colpane */ 
        private void nest_slot_in_active_slot (GOF.Window.Slot slot) {
            var hpane1 = new Granite.Widgets.ThinPaned (Gtk.Orientation.HORIZONTAL);
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

            if (active_slot.slot_number >= 0 && active_slot.colpane != null)
                this.active_slot.colpane.add (hpane1);
            else
                this.colpane.add (hpane1);
        }

        /** Was GOF.Window.Slot.columns_add_location ()
          * Called locally by add_location, show_hidden_files_changed
          * and as callback when file deleted. */
        private void truncate_list_after_slot (GOF.Window.Slot? slot) {
            if (slot == null || slot_list.length () < 2)
                return;

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
            if (total_width != 0 && slot.width != allocation.width) {
                total_width += allocation.width - slot.width;
                slot.width = allocation.width;
                this.colpane.set_size_request (total_width, -1);

            }
        }

        
/*********************/
/** Signal handling **/
/*********************/
        private void connect_slot_signals (GOF.Window.Slot slot) {
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
                on_slot_active (slot);
            });
        }

         private void autosize_slot (GOF.Window.Slot slot) {
            slot.autosize (handle_size, preferred_column_width);
            this.colpane.show_all ();
            this.colpane.queue_draw ();
        }

        /** Called in response to slot active signal */
        private void on_slot_active (GOF.Window.Slot slot) {
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

            if (active_slot != slot)
                active_slot = slot;

            slot.view_box.grab_focus ();
            Marlin.Animation.smooth_adjustment_to (hadj, width + slot.slot_number * handle_size);
        }

        private void show_hidden_files_changed () {
            if (!GOF.Preferences.get_default ().pref_show_hidden_files) {
                /* we are hiding hidden files - check whether any slot is a hidden directory */
                int i = -1;
                int hidden = -1;
                slot_list.@foreach ((s) => {
                    i ++;
                    if (s.directory.file.is_hidden && hidden <= 0)
                        hidden = i;
                });

                /* Return if no hidden folder found or only first folder hidden */
                if (hidden <= 0)
                    return;

                /* Remove hidden slots and make the slot before the first hidden slot active */
                unowned GOF.Window.Slot slot = slot_list.nth_data (hidden - 1);
                truncate_list_after_slot (slot);
                on_slot_active (slot);
            }
        }

        private bool on_key_pressed (Gtk.Widget box, Gdk.EventKey event) {
            int active_position = slot_list.index (active_slot);
            GOF.Window.Slot to_activate = null;

            switch (event.keyval) {
                case Gdk.Key.Left:
                    if (active_position > 0)
                        to_activate = slot_list.nth_data (active_position - 1);

                    break;

                case Gdk.Key.Right:
                    if (active_position < slot_list.length () - 1)
                        to_activate = slot_list.nth_data (active_position + 1);

                    break;
            }

            if (to_activate != null) {
                to_activate.active ();
                return true;
            } else
                return false;
        }

        private void on_slot_frozen_changed (bool frozen) {
            if (frozen)
                GLib.SignalHandler.block_by_func (colpane, (void*)on_key_pressed, this);
            else
                GLib.SignalHandler.unblock_by_func (colpane, (void*)on_key_pressed, this);

            slot_list.@foreach ((s) => {
                s.updates_frozen = frozen;
            });
        }
    }
}
