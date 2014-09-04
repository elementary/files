/*
 Copyright (C) 2014 ELementary Developers

 This program is free software: you can redistribute it and/or modify it
 under the terms of the GNU Lesser General Public License version 3, as published
 by the Free Software Foundation.

 This program is distributed in the hope that it will be useful, but
 WITHOUT ANY WARRANTY; without even the implied warranties of
 MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 PURPOSE. See the GNU General Public License for more details.

 You should have received a copy of the GNU General Public License along
 with this program. If not, see <http://www.gnu.org/licenses/>.

 Authors : Jeremy Wootten <jeremy@elementary.org>
*/


namespace Marlin.View {
    public class Miller : GOF.AbstractSlot {
        private unowned Marlin.View.ViewContainer ctab;
        private GLib.File root_location; /* Need private copy of initial location as Miller does not have its own Asyncdirectory object */
        private Gtk.Box colpane;

        public Gtk.ScrolledWindow scrolled_window;
        public Gtk.Adjustment hadj;
        public Marlin.View.Slot? current_slot;
        public GLib.List<Marlin.View.Slot> slot_list = null;
        public int total_width = 0; /*TODO Use AbstractSlot width? */

        public Miller (GLib.File loc, Marlin.View.ViewContainer ctab, Marlin.ViewMode mode) {
//message ("Making new Miller View %s", loc.get_uri());
            base.init ();
            this.ctab = ctab;
            this.root_location = loc;

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

            this.colpane.add_events (Gdk.EventMask.KEY_RELEASE_MASK);
            this.colpane.key_release_event.connect (on_key_pressed);
            this.make_view ();
        }

        ~Miller () {
//message ("Miller destructor");
        }

        protected override void make_view () {
//message ("Miller View: making root view");
            this.current_slot = null;
            add_location (root_location, null);  /* current slot gets set by this */
        }

        /* TODO Make Expand Miller View a MillerView function */
        /** Creates a new slot in the host slot hpane */
        public void add_location (GLib.File loc, GOF.AbstractSlot? host = null) {
//message ("MV add location %s", loc.get_uri ());
            Marlin.View.Slot new_slot = new Marlin.View.Slot (loc, this.ctab, Marlin.ViewMode.MILLER_COLUMNS);
            new_slot.slot_number = (host != null) ? host.slot_number + 1 : 0;
            this.total_width += new_slot.width;
            this.colpane.set_size_request (total_width, -1);

            nest_slot_in_host_slot (new_slot, (Marlin.View.Slot?)host);
            connect_slot_signals (new_slot);
            new_slot.directory.load ();
            slot_list.append (new_slot);
            new_slot.active ();
        }

        private void nest_slot_in_host_slot (Marlin.View.Slot slot, Marlin.View.Slot? host) {
//message ("Miller: nest slot");
            var hpane1 = new Granite.Widgets.ThinPaned (Gtk.Orientation.HORIZONTAL);
            hpane1.hexpand = true;
            slot.hpane = hpane1;

            var box1 = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            slot.colpane = box1;

            unowned Gtk.Widget column = slot.get_directory_view ();
            column.size_allocate.connect ((a) => {update_total_width (a, slot);});

            hpane1.pack1 (column, false, false);
            hpane1.pack2 (box1, true, true);
            hpane1.show_all ();

            if (host != null) {
                truncate_list_after_slot (host);
                host.colpane.add (hpane1);
            } else
                this.colpane.add (hpane1);
        }

        private void truncate_list_after_slot (Marlin.View.Slot slot) {
//message ("truncate list after slot");
            if (slot_list.length () <= 0)
                return;

            /* destroy the nested slots */
            ((Marlin.View.Slot)(slot)).colpane.@foreach ((w) => {
                if (w != null) {
                    w.destroy ();
                }
            });

            uint n = slot.slot_number;
            slot_list.@foreach ((s) => {
                if (s.slot_number > n) {
                    disconnect_slot_signals (s);
                }
            });
            slot_list.nth (n).next = null;
            calculate_total_width ();
            current_slot = slot;
        }

        private void calculate_total_width () {
            total_width = 100;
            slot_list.@foreach ((slot) => {
                total_width += slot.width;
            });
        }

        private void update_total_width (Gtk.Allocation allocation, Slot slot) {
            if (total_width != 0 && slot.width != allocation.width) {
                total_width += allocation.width - slot.width;
                slot.width = allocation.width;
                this.colpane.set_size_request (total_width, -1);
            }
        }

        
/*********************/
/** Signal handling **/
/*********************/

        public override void user_path_change_request (GLib.File loc) {
//message ("MV user path change request %s", loc.get_uri ());
            /* user request always make new root */
            var slot = slot_list.first().data;
            assert (slot != null);
            truncate_list_after_slot (slot);
            slot.user_path_change_request (loc);
            root_location = loc;
        }

        private void connect_slot_signals (Slot slot) {
            slot.frozen_changed.connect (on_slot_frozen_changed);
            slot.active.connect (on_slot_active);
            slot.horizontal_scroll_event.connect (on_slot_horizontal_scroll_event);
            slot.miller_slot_request.connect (on_miller_slot_request);
        }

        private void disconnect_slot_signals (Slot slot) {
            slot.frozen_changed.disconnect (on_slot_frozen_changed);
            slot.active.disconnect (on_slot_active);
            slot.horizontal_scroll_event.disconnect (on_slot_horizontal_scroll_event);
            slot.miller_slot_request.disconnect (on_miller_slot_request);
        }

        private void on_miller_slot_request (Marlin.View.Slot slot, GLib.File loc, bool make_root) {
                if (make_root)
                    user_path_change_request (loc);
                else
                    add_location (loc, slot);
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
        //private void on_slot_active (GOF.AbstractSlot slot) {
        private void on_slot_active (Marlin.View.Slot slot) {
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
                Marlin.View.Slot slot = slot_list.nth_data (hidden - 1);
                truncate_list_after_slot (slot);
                slot.active ();
            }
        }

        private bool on_key_pressed (Gtk.Widget box, Gdk.EventKey event) {
//message ("Miller key press");
            int current_position = slot_list.index (current_slot);
            Marlin.View.Slot to_activate = null;

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
                this.colpane.key_release_event.disconnect (on_key_pressed);
            else
                this.colpane.key_release_event.connect (on_key_pressed);

            slot_list.@foreach ((abstract_slot) => {
                var s = abstract_slot as Marlin.View.Slot;
                if (s != null) {
                    s.frozen_changed.disconnect (on_slot_frozen_changed);
                    s.set_view_updates_frozen (frozen);
                    s.frozen_changed.connect (on_slot_frozen_changed);
                }
            });
        }


/** Helper functions */

        private void scroll_to_slot (GOF.AbstractSlot slot) {
//message ("scroll_to_slot");
            int width = 0;
            int previous_width = 0;

            /* Calculate width up to left-hand edge of given slot */
            unowned GLib.List<GOF.AbstractSlot> l = slot_list;
            while (l.data != slot) {
                previous_width = width;
                width += l.data.width;
                l = l.next;
            }

            int total_width = width;
            while (l != null) {
                total_width += l.data.width;
                l = l.next;
            }

            int page_size = (int) this.hadj.get_page_size ();
            int current_value = (int) this.hadj.get_value (); ;
            int new_value = current_value;

            if (current_value > previous_width) {
                /*scroll right until left hand edge of slot before the active slot is in view*/
                new_value = previous_width;
            }

            if (new_value > width) {
                /*scroll right until left hand edge of active slot is in view*/
                new_value = width;
            }
            int val = page_size - (width + slot.width + 100);
            if (val < 0) {
                /*scroll left until right hand edge of active slot is in view*/
                new_value =  -val;
            }

            Marlin.Animation.smooth_adjustment_to (this.hadj, new_value);
        }

        public override unowned GOF.AbstractSlot? get_current_slot () {
            return current_slot;
        }

        public override unowned GLib.List<unowned GOF.File>? get_selected_files () {
            return ((Marlin.View.Slot)(current_slot)).get_selected_files ();
        }


        public override void set_active_state (bool set_active) {
            if (set_active)
                current_slot.active ();
            else
                current_slot.inactive ();
        }

        public void expand_miller_view (string tip_uri) {
//message ("expand miller view to %s", tip_uri);
            assert (slot_list.length () == 1);
            
            var unescaped_tip_uri = GLib.Uri.unescape_string (tip_uri);
            var tip_location = GLib.File.new_for_uri (unescaped_tip_uri);
            var relative_path = root_location.get_relative_path (tip_location);
            GLib.File gfile;

            if (relative_path != null) {
                string [] dirs = relative_path.split (GLib.Path.DIR_SEPARATOR_S);
                string uri = root_location.get_uri ();

                foreach (string dir in dirs) {
                    uri += (GLib.Path.DIR_SEPARATOR_S + dir);
                    gfile = GLib.File.new_for_uri (uri);;
                    add_location (gfile, current_slot);
                }
            } else {
                warning ("Invalid tip uri for Miller View");
            }
        }

        public override string? get_tip_uri () {
//message ("MILLER get_tip_uri");
            if (slot_list != null && slot_list.last () != null && slot_list.last ().data is GOF.AbstractSlot) {
                return slot_list.last ().data.uri;
            } else {
                return null;
            }
        }

        public override string? get_root_uri () {
//message ("MV get root uri %s", root_location.get_uri ());
            return root_location.get_uri ();
        }

        public override void zoom_in () {((Marlin.View.Slot)(current_slot)).zoom_in ();}
        public override void zoom_out () {((Marlin.View.Slot)(current_slot)).zoom_out ();}
        public override void zoom_normal () {((Marlin.View.Slot)(current_slot)).zoom_normal ();}
        public override void grab_focus () {((Marlin.View.Slot)(current_slot)).grab_focus ();}
        public override void reload () {((Marlin.View.Slot)(current_slot)).reload ();}

    }
}
