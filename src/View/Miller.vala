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

namespace Marlin.View {
    public class Miller : GOF.AbstractSlot {

        public Gtk.ScrolledWindow scrolled_window;
        public Gtk.Adjustment hadj;
        public Slot current_slot;
        public GLib.List<Slot> slot_list;

        public int preferred_column_width;
        public int total_width = 0;
        private int handle_size;
        private GLib.File location;
        private Marlin.View.ViewContainer ctab;
        private Gtk.Box colpane;

        public Miller (GLib.File location, Marlin.View.ViewContainer ctab) {
//message ("Making new Miller View");
            base.init ();
            this.location = location;
            this.ctab = ctab;

            preferred_column_width = Preferences.marlin_column_view_settings.get_int ("preferred-column-width");

            (GOF.Preferences.get_default ()).notify["show-hidden-files"].connect ((s, p) => {
                show_hidden_files_changed (((GOF.Preferences)s).show_hidden_files);
            });

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
            //ctab.content = content_box;

            this.colpane.add_events (Gdk.EventMask.KEY_RELEASE_MASK);
            this.colpane.key_release_event.connect (on_key_pressed);
//message ("Leaving Making new Miller View");
        }

        ~Miller () {
message ("In Miller destruct");
        }

        public string get_tip_uri () {
            return slot_list.last ().data.directory.file.uri.dup ();
        }

        public string get_root_uri () {
            return slot_list.first ().data.directory.file.uri.dup ();
        }

        /** Called by ViewContainer to make initial root slot */
        public Gtk.Widget make_view () {
//message ("Miller View: making root view");
            this.current_slot = null;
            add_location (this.location, null);  /* current slot gets set by this */
            current_slot.hpane.style_get ("handle-size", out this.handle_size);

//message ("Miller View: leaving making root view");
            return this.content_box as Gtk.Widget;
        }

        /** Called locally by make view and externally by Window.expand_miller_view and View Container*/
        /* TODO Make Expand Miller View a MillerView function */
        /** Creates a new slot in the active slot hpane */

        public void add_location (GLib.File location, Slot? host) {
if (host != null)
//message ("Miller: Add location in host %s", host.directory.file.uri);

            /* host is null when creating the root slot */
            if (host != null)
                host.inactive (); /* Unmerge menus */

            Slot new_slot = new Slot (location, this.ctab);
            new_slot.slot_number = (host != null) ? host.slot_number + 1 : 0;

            new_slot.width = preferred_column_width;
            this.total_width += new_slot.width + 180;
//message ("total width is %i", total_width);
            this.colpane.set_size_request (total_width, -1);

            //make_view_in_slot (new_slot);
            new_slot.make_column_view ();
            connect_slot_signals (new_slot);

            /* Set mwcols->current_slot now in case another slot is created before
             * this one really becomes active, e.g. during restoring tabs on startup */
            //this.current_slot = new_slot;

            nest_slot_in_host_slot (new_slot, host);

            new_slot.directory.track_longest_name = true;
            new_slot.directory.load ();

//message ("Appending slot number %i", slot.slot_number);
            slot_list.append (new_slot);
            new_slot.active ();

//message ("Miller: leasving Add location");
        }

        /** Was Slot.column_add () 
        /*  Called only by add location
        /*  Nests a given slot into the current_slot colpane */ 
        private void nest_slot_in_host_slot (Slot slot, Slot? host) {
//message ("Miller: nest slot");
            //assert (slot != null);

            var hpane1 = new Granite.Widgets.ThinPaned (Gtk.Orientation.HORIZONTAL);
            hpane1.hexpand = true;
            slot.hpane = hpane1;

            var box1 = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            slot.colpane = box1;

            var column = slot.view_box;
//message ("preferred column width is %i", preferred_column_width);
            column.set_size_request (preferred_column_width, -1);
            column.size_allocate.connect ((a) => {update_total_width (a, slot);});

            hpane1.pack1 (column, false, false);
            hpane1.pack2 (box1, true, true);
            hpane1.show_all ();

            if (host != null) {
                truncate_list_after_slot (host);
                host.colpane.add (hpane1);
            } else
                this.colpane.add (hpane1);
//message ("Miller: leaving nest slot");
        }

        /** Was Slot.columns_add_location ()
          * Called locally by make_view_in_slot, show_hidden_files_changed
          * and as callback when file deleted. */
        private void truncate_list_after_slot (Slot slot) {
//message ("Miller: truncate after slot");
            if (slot_list.length () < 2) {
//message ("Not truncating - slot_list length is %u", slot_list.length ());
                return;
            }
//message ("Truncating after slot number %i", slot.slot_number);
            /* destroy the nested slots */
            slot.colpane.@foreach ((w) => {
                if (w != null)
                    w.destroy ();
            });

            int current_slot_position = slot_list.index (slot);
            assert (current_slot_position >= 0);

            unowned GLib.List<Slot> last_valid_slot = slot_list.nth (slot.slot_number);
            last_valid_slot.next = null;

//message ("Miller: leaving truncate after slot");

        }

        public void autosize_slot (Slot slot) {
//message ("autosize_slot");
            Pango.Layout layout = slot.view_box.create_pango_layout (null);

            if (slot.directory.is_empty ())
                layout.set_markup (slot.empty_message, -1);
            else
                layout.set_markup (GLib.Markup.escape_text (slot.directory.longest_file_name), -1);

            Pango.Rectangle extents;
            layout.get_extents (null, out extents);

            slot.width = (int) Pango.units_to_double (extents.width)
                  + 2 * slot.directory.icon_size
                  + 2 * handle_size
                  + 12;

//message ("width is %i", slot.width);
            /* TODO make min and max width to be properties of mwcols */
//message ("preferred_width/2 is %i,  twice preferred width is %i ", preferred_column_width / 2, preferred_column_width * 2);
            slot.width = slot.width.clamp (preferred_column_width / 3, preferred_column_width * 2);
//message ("width is now %i", slot.width);
            slot.hpane.set_position (slot.width);
            slot.colpane.show_all ();
            slot.colpane.queue_draw ();
        }

        private void update_total_width (Gtk.Allocation allocation, Slot slot) {
//message ("update_total_width current %i", total_width);
            if (total_width != 0 && slot.width != allocation.width) {
                total_width += allocation.width - slot.width;
                slot.width = allocation.width;
//message ("update total width to %i", total_width);
                this.colpane.set_size_request (total_width, -1);

            }
        }

        
/*********************/
/** Signal handling **/
/*********************/
        private void connect_slot_signals (Slot slot) {
            var dir = slot.directory;
            dir.done_loading.connect (() => {
                autosize_slot (slot);
            });

            dir.file_deleted.connect ((f) => {
                if (f.is_directory)
                    //TODO Check if this is right - copied from existing code
                    truncate_list_after_slot (current_slot);
            });

            slot.frozen_changed.connect (on_slot_frozen_changed);

            slot.active.connect (on_slot_active);

            slot.horizontal_scroll_event.connect (on_slot_horizontal_scroll_event);

            //slot.autosize.connect (autosize_slot);
        }

        private bool on_slot_horizontal_scroll_event (double delta_x) {
            /* We can assume this is a horizontal or smooth scroll with out control pressed*/
            double increment = 0.0;
            increment = delta_x * 10.0;
            if (increment != 0.0);
                hadj.set_value (hadj.get_value () + increment);

            return true;
        }

        /** Called in response to slot active signal.
         *  Should not be called directly */
        private void on_slot_active (Slot slot) {
//message ("Miller: Slot active");
            if (this.current_slot == slot)
                return;

            slot_list.@foreach ((s) => {
                if (s != slot)
                    s.inactive ();
            });

            this.current_slot = slot;
            scroll_to_slot (slot);
        }

        private void show_hidden_files_changed (bool show_hidden) {
//message ("default prefs notification");
            if (!show_hidden) {
//message ("files hidden");
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
                unowned Slot slot = slot_list.nth_data (hidden - 1);
                truncate_list_after_slot (slot);
                slot.active ();
            }
        }

        private bool on_key_pressed (Gtk.Widget box, Gdk.EventKey event) {
            int current_position = slot_list.index (current_slot);
            Slot to_activate = null;

            switch (event.keyval) {
                case Gdk.Key.Left:
                    if (current_position > 0)
                        to_activate = slot_list.nth_data (current_position - 1);

                    break;

                case Gdk.Key.Right:
                    if (current_position < slot_list.length () - 1)
                        to_activate = slot_list.nth_data (current_position + 1);

                    break;
            }

            if (to_activate != null) {
                to_activate.active ();
                return true;
            } else
                return false;
        }

        private void on_slot_frozen_changed (Slot slot, bool frozen) {
            /* Ensure all slots synchronise the frozen state and suppress key press event processing when frozen*/
//message ("on_slot_frozen_changed");
            if (frozen)
                GLib.SignalHandler.block_by_func (this.colpane, (void*)on_key_pressed, this);
            else
                GLib.SignalHandler.unblock_by_func (this.colpane, (void*)on_key_pressed, this);

            slot_list.@foreach ((s) => {
                if (s != null && s.view_box != null) {
                    GLib.SignalHandler.block_by_func (s, (void*)on_slot_frozen_changed, this);
                    s.view_box.set_updates_frozen (frozen);
                    GLib.SignalHandler.unblock_by_func (s, (void*)on_slot_frozen_changed, this);
                }
            });

//message ("SLots are %s", frozen ? "Frozen" : "Unfrozen");
        }
/** Helper functions */

        private void scroll_to_slot (Slot slot) {
//message ("scroll_to_slot");
//            assert (slot != null);
//            assert (this.slot_list != null);
//            assert (this.slot_list.length () > 0);
            int width = 0;
            int previous_width = 0;
            //bool sum_completed = false;

//message ("Starting scan of slot_list");
//            this.slot_list.@foreach ((s) => {
//                if (s != slot) {
//                    //s.inactive ();
//                } else {
////message ("MillerView: on_slot_active - sum completed  at slot number %i", slot.slot_number);
//                    sum_completed = true;
//                }

//                if (!sum_completed) {
//                    previous_width = width;
//                    width += s.width;
//                }
//            });

            /* Calculate width up to left-hand edge of given slot */
            unowned GLib.List<Slot> l = slot_list;
            while (l.data != slot) {
                previous_width = width;
                width += l.data.width;
                l = l.next;
            }

            int total_width = width;
//message ("calculating total width starting at %i", total_width);
            while (l != null) {
                total_width += l.data.width;
//message ("total width now %i", total_width);
                l = l.next;
            }

//message ("Finished scan of slot_list");
            int page_size = (int) this.hadj.get_page_size ();
            int current_value = (int) this.hadj.get_value (); ;
            int new_value = current_value;

//message ("Page size is %i", page_size);
//message ("width is %i", width);
//message ("previous width is %i", previous_width);
//message ("total width is %i", total_width);
//message ("slot width is %i", slot.width);
//message ("current value/new value is %i", current_value);

            if (current_value > previous_width) {
                /*scroll right until left hand edge of slot before the active slot is in view*/
                //Marlin.Animation.smooth_adjustment_to (this.hadj, previous_width);
                //return;
                new_value = previous_width;
            }

            if (new_value > width) {
                /*scroll right until left hand edge of active slot is in view*/
                //Marlin.Animation.smooth_adjustment_to (this.hadj, width);
                //return;
                new_value = width;
            }
//message ("new value is %i", new_value);
            int val = page_size - (width + slot.width + 100);
//message ("val is %i",val);
            if (val < 0) {
                /*scroll left until right hand edge of active slot is in view*/
                //Marlin.Animation.smooth_adjustment_to (this.hadj, new_value);
                //return;
                new_value =  -val;
            }
//message ("new value is %i", new_value);


            Marlin.Animation.smooth_adjustment_to (this.hadj, new_value);

            //this.hadj.set_value (new_value);
//message ("Finished scan_to_slot");
        }
    }
}
