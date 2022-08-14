/*
* Copyright (c) 2018 elementary LLC (https://elementary.io)
*               2011 Lucas Baudin <xapantu@gmail.com>
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

namespace Files.View.Chrome {
    public class BasicBreadcrumbsEntry : Gtk.Entry, Navigatable {
        public enum TargetType {
            TEXT_URI_LIST,
        }

        public string? action_icon_name {
            get {
                return get_icon_name (Gtk.EntryIconPosition.SECONDARY);
            }
            set {
                if (value != null) {
                    set_icon_from_icon_name (Gtk.EntryIconPosition.SECONDARY, value);
                    secondary_icon_activatable = true;
                    secondary_icon_sensitive = true;
                } else {
                    hide_action_icon ();
                }
            }
        }

        public bool hide_breadcrumbs { get; set; default = false; }
        public const double MINIMUM_LOCATION_BAR_ENTRY_WIDTH = 16;
        public const double MINIMUM_BREADCRUMB_WIDTH = 12;
        public const int ICON_WIDTH = 32;
        protected string placeholder = ""; /*Note: This is not the same as the Gtk.Entry placeholder_text */
        protected BreadcrumbElement? clicked_element = null;
        protected string? current_dir_path = null;
        /* This list will contain all BreadcrumbElement */
        protected Gee.ArrayList<BreadcrumbElement> elements;
        private BreadcrumbIconList breadcrumb_icons;
        private int minimum_width;

        /*Animation support */
        protected bool animation_visible = true;
        uint animation_timeout_id = 0;
        protected Gee.Collection<BreadcrumbElement>? old_elements;

        protected Gtk.StyleContext button_context;
        protected Gtk.StyleContext button_context_active;
        protected const int BREAD_SPACING = 12;
        protected const double YPAD = 0; /* y padding */

        private Gdk.Window? entry_window = null;

        protected bool context_menu_showing = false;

        construct {
            truncate_multiline = true;
            weak Gtk.StyleContext style_context = get_style_context ();
            style_context.add_class ("pathbar");

            var css_provider = new Gtk.CssProvider ();
            try {
                css_provider.load_from_data (".noradius-button { border-radius: 0; }");
                style_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) {
                critical ("Unable to style pathbar button: %s", e.message);
            }

            breadcrumb_icons = new BreadcrumbIconList (style_context);

            elements = new Gee.ArrayList<BreadcrumbElement> ();
            old_elements = new Gee.ArrayList<BreadcrumbElement> ();
            connect_signals ();

            minimum_width = 100;
            notify["scale-factor"].connect (() => {
                breadcrumb_icons.scale = scale_factor;
            });
        }

        protected virtual void connect_signals () {
            realize.connect_after (after_realize);
            activate.connect (on_activate);
            button_release_event.connect (on_button_release_event);
            button_press_event.connect (on_button_press_event);
            icon_press.connect (on_icon_press);
            motion_notify_event.connect_after (after_motion_notify);
            focus_in_event.connect (on_focus_in);
            focus_out_event.connect (on_focus_out);
            key_press_event.connect (on_key_press_event);
            changed.connect (on_entry_text_changed);
        }

    /** Navigatable Interface **/
    /***************************/
        public void set_breadcrumbs_path (string path) {
            string protocol;
            string newpath;
            string sanitized_path = FileUtils.sanitize_path (path);

            FileUtils.split_protocol_from_path (sanitized_path, out protocol, out newpath);
            var newelements = new Gee.ArrayList<BreadcrumbElement> ();
            make_element_list_from_protocol_and_path (protocol, newpath, newelements);
            GLib.List<BreadcrumbElement> displayed_breadcrumbs = null;
            get_displayed_breadcrumbs_natural_width (out displayed_breadcrumbs);
            minimum_width = get_breadcrumbs_minimum_width (displayed_breadcrumbs);
            this.set_size_request (minimum_width, -1);
        }

        public string get_breadcrumbs_path ( bool include_file_protocol = true) {
            return get_path_from_element (null, include_file_protocol);
        }

        protected void set_action_icon_tooltip (string? tip) {
            if (secondary_icon_pixbuf != null && tip != null && tip.length > 0) {
                set_icon_tooltip_markup (Gtk.EntryIconPosition.SECONDARY, tip);
            }
        }
        public string? get_action_icon_tooltip () {
            if (secondary_icon_pixbuf != null) {
                return get_icon_tooltip_markup (Gtk.EntryIconPosition.SECONDARY);
            } else {
                return null;
            }
        }

        protected void hide_action_icon () {
            secondary_icon_pixbuf = null;
        }

        public void set_entry_text (string? txt) {
            if (text != null) {
                this.text = txt;
                set_position (-1);
            } else {
                this.text = "";
            }
        }
        public string get_entry_text () {
            return text;
        }
        public virtual void reset () {
            set_entry_text ("");
            hide_action_icon ();
            set_placeholder ("");
        }

        public void set_animation_visible (bool visible) {
            animation_visible = visible;
        }

        public void set_placeholder (string txt) {
            placeholder = txt;
        }

        public void show_default_action_icon () {
            action_icon_name = Files.ICON_PATHBAR_SECONDARY_NAVIGATE_SYMBOLIC;
            set_default_action_icon_tooltip ();
        }

        public void hide_default_action_icon () {
            set_action_icon_tooltip ("");
            action_icon_name = null;
        }
        public void set_default_action_icon_tooltip () {
            set_action_icon_tooltip (_("Navigate to %s").printf (get_entry_text ()));
        }

    /** Signal handling **/
    /*********************/
        public virtual bool on_key_press_event (Gdk.EventKey event) {
            if (event.is_modifier == 1) {
                return true;
            }

            Gdk.ModifierType state;
            event.get_state (out state);
            var mods = state & Gtk.accelerator_get_default_mod_mask ();
            bool only_control_pressed = (mods == Gdk.ModifierType.CONTROL_MASK);

            uint keyval;
            event.get_keyval (out keyval);
            switch (keyval) {
                /* Do not trap unmodified Down and Up keys - used by some input methods */
                case Gdk.Key.KP_Down:
                case Gdk.Key.Down:
                    if (only_control_pressed) {
                        go_down ();
                        return true;
                    }

                    break;

                case Gdk.Key.KP_Up:
                case Gdk.Key.Up:
                    if (only_control_pressed) {
                        go_up ();
                        return true;
                    }

                    break;

                case Gdk.Key.Escape:
                    activate_path ("");
                    return true;

                case Gdk.Key.l:
                    if (only_control_pressed) {
                        set_entry_text (current_dir_path);
                        grab_focus ();
                        return true;
                    } else {
                        break;
                    }
                default:
                    break;
            }

            return false;
        }

        protected virtual bool on_button_press_event (Gdk.EventButton event) {
            uint button;
            event.get_button (out button);
            context_menu_showing = has_focus && button == Gdk.BUTTON_SECONDARY;
            return !has_focus;  // Only pass to default Gtk handler when focused and Entry showing.
        }

         protected virtual bool on_button_release_event (Gdk.EventButton event) {
            /* Only activate breadcrumbs with primary click when pathbar does not have focus and breadcrumbs showing.
             * Note that in home directory, the breadcrumbs are hidden and a placeholder shown even when pathbar does
             * not have focus. */
            uint button;
            event.get_button (out button);
            if (button == Gdk.BUTTON_PRIMARY && !has_focus && !hide_breadcrumbs && !is_icon_event (event)) {
                reset_elements_states ();
                double x, y;
                event.get_coords (out x, out y);
                var el = get_element_from_coordinates ((int)x, (int)y);
                if (el != null) {
                    activate_path (get_path_from_element (el));
                    return true;
                }
            }

            if (!has_focus) {
                grab_focus (); // Hide breadcrumbs and behave as Gtk.Entry.
            }

            return false;
        }

        protected bool is_icon_event (Gdk.EventButton event) {
            /* We need to distinguish whether the event comes from one of the icons.
             * There doesn't seem to be a way of doing this directly so we check the window width */
            return (event.get_window ().get_width () <= ICON_WIDTH);
        }

        void on_icon_press (Gtk.EntryIconPosition pos) {
            if (pos == Gtk.EntryIconPosition.SECONDARY) {
                action_icon_press ();
            } else {
                primary_icon_press ();
            }
        }

        void after_realize () {
            /* After realizing, we take a reference on the Gdk.Window of the Entry so
             * we can set the cursor icon as needed. This relies on Gtk storing the
             * owning widget as the user data on a Gdk.Window. The required window
             * will be the first child of the entry.
             */
            entry_window = get_window ().get_children_with_user_data (this).data;
        }

        bool after_motion_notify (Gdk.EventMotion event) {
            if (is_focus) {
                return false;
            }

            string? tip = null;
            if (secondary_icon_pixbuf != null) {
                tip = get_icon_tooltip_markup (Gtk.EntryIconPosition.SECONDARY);
            }


            set_tooltip_markup ("");
            double x, y;
            event.get_coords (out x, out y);
            var el = get_element_from_coordinates ((int)x, (int)y);
            if (el != null && !hide_breadcrumbs) {
                set_tooltip_markup (_("Go to %s").printf (el.text_for_display));
                set_entry_cursor ("default");
            } else {
                set_entry_cursor ("text");
                set_default_entry_tooltip ();
            }

            if (tip != null) {
            /* We must reset the icon tooltip as the above line turns all tooltips off */
                set_icon_tooltip_markup (Gtk.EntryIconPosition.SECONDARY, tip);
            }
            return false;
        }

        private uint focus_out_timeout_id = 0;
        protected virtual bool on_focus_out (Gdk.EventFocus event) {
            if (focus_out_timeout_id == 0) {
                /* Delay acting on focus out - may be temporary, due to keyboard layout change */
                focus_out_timeout_id = GLib.Timeout.add (10, () => {
                    focus_out_event (event);
                    return GLib.Source.REMOVE;
                });

                return true;
            } else {
                /* This the delayed propagated event */
                base.focus_out_event (event);

                if (context_menu_showing) {
                    return true;
                }

                // Reset if window has top level focus or is iconified
                // Do not lose entry text if another window is focused
                var top_level = (Gtk.Window)(get_toplevel ());
                if (top_level.has_toplevel_focus ||
                     (top_level.get_window ().get_state () & Gdk.WindowState.ICONIFIED) > 0) {
                    reset ();
                }

                focus_out_timeout_id = 0;
                return false;
            }
        }

        protected virtual bool on_focus_in (Gdk.EventFocus event) {
            if (focus_out_timeout_id > 0) {
                /* There was a temporary focus out due to keyboard layout change.
                 * Cancel propagation of focus out event and ignore focus in event */
                GLib.Source.remove (focus_out_timeout_id);
                focus_out_timeout_id = 0;
                return true;
            } else {
                context_menu_showing = false;
                current_dir_path = get_breadcrumbs_path (false);
                set_entry_text (current_dir_path);
                return false;
            }
        }

        protected virtual void on_activate () {
            activate_path (FileUtils.sanitize_path (text, current_dir_path));
            text = "";
        }

        protected virtual void on_entry_text_changed () {
            entry_text_changed (text);
        }

        protected virtual void go_down () {
            activate_path ("");
        }

        protected virtual void go_up () {
            text = FileUtils.get_parent_path_from_path (text);
            set_position (-1);
        }

    /** Entry functions **/
    /****************************/
        public void set_entry_cursor (string cursor_name) {
            entry_window.set_cursor (new Gdk.Cursor.from_name (entry_window.get_display (), cursor_name));
        }

        protected virtual void set_default_entry_tooltip () {
            set_tooltip_markup (_("Type Path"));
        }


    /** Breadcrumb related functions **/
    /****************************/
        public void reset_elements_states () {
            foreach (BreadcrumbElement element in elements) {
                element.pressed = false;
            }
            queue_draw ();
        }

        /** Returns a list of breadcrumbs that are displayed in natural order - that is, the breadcrumb at the start
          * of the pathbar is at the start of the list
         **/
        public double get_displayed_breadcrumbs_natural_width (out GLib.List<BreadcrumbElement> displayed_breadcrumbs) {
            double total_width = 0.0;
            displayed_breadcrumbs = null;
            foreach (BreadcrumbElement element in elements) {
                if (element.display) {
                    total_width += element.natural_width;
                    element.can_shrink = true;
                    element.display_width = -1;
                    displayed_breadcrumbs.prepend (element);
                }
            }
            displayed_breadcrumbs.reverse ();
            return total_width;
        }

        private int get_breadcrumbs_minimum_width (GLib.List<BreadcrumbElement> displayed_breadcrumbs) {
            var l = (int)displayed_breadcrumbs.length (); //can assumed to be limited in length
            var w = displayed_breadcrumbs.first ().data.natural_width;
            if (l > 1) {
                weak Gtk.StyleContext style_context = get_style_context ();
                var state = style_context.get_state ();
                var padding = style_context.get_padding (state);
                w += (l - 1) * (MINIMUM_BREADCRUMB_WIDTH + padding.left + padding.right);

                /* Allow extra space for last breadcrumb */
                w += 3 * (MINIMUM_BREADCRUMB_WIDTH + padding.left + padding.right);
            }

            /* Allow enough space after the breadcrumbs for secondary icon and entry */
            w += 2 * YPAD + MINIMUM_LOCATION_BAR_ENTRY_WIDTH + ICON_WIDTH;

            return (int) (w);
        }

        private void fix_displayed_widths (GLib.List<BreadcrumbElement> elements, double target_width) {
            /* first element (protocol) always untruncated */
            elements.first ().data.can_shrink = false;
            return;
        }

        private void distribute_shortfall (GLib.List<BreadcrumbElement> elements, double target_width) {
            double shortfall = target_width;
            double free_width = 0;
            uint index = 0;
            uint length = elements.length (); //Can assumed to be limited in length
            /* Calculate the amount by which the breadcrumbs can be shrunk excluding the fixed and last */
            foreach (BreadcrumbElement el in elements) {
                shortfall -= el.natural_width;
                if (++index < length && el.can_shrink) {
                    free_width += (el.natural_width - MINIMUM_BREADCRUMB_WIDTH);
                }
            }

            double fraction_reduction = double.max (0.000, 1.0 + (shortfall / free_width));
            index = 0;
            foreach (BreadcrumbElement el in elements) {
                if (++index < length && el.can_shrink) {
                    el.display_width = (el.natural_width - MINIMUM_BREADCRUMB_WIDTH) * fraction_reduction +
                                        MINIMUM_BREADCRUMB_WIDTH;
                }
            }

            var remaining_shortfall = (shortfall + free_width);
            if (remaining_shortfall < 0) {
                var el = elements.last ().data;
                el.can_shrink = true;
                /* The last breadcrumb does not shrink as much as the others */
                el.display_width = double.max (4 * MINIMUM_BREADCRUMB_WIDTH, el.natural_width + remaining_shortfall);
            }
        }

        protected BreadcrumbElement? get_element_from_coordinates (int x, int y) {
            double width = get_allocated_width () - ICON_WIDTH;
            double height = get_allocated_height ();
            var is_rtl = Gtk.StateFlags.DIR_RTL in get_style_context ().get_state ();
            double x_render = is_rtl ? width : 0;
            foreach (BreadcrumbElement element in elements) {
                if (element.display) {
                    if (is_rtl) {
                        x_render -= (element.real_width + height / 2); /* add width of arrow to element width */
                        if (x >= x_render - 5) {
                            return element;
                        }
                    } else {
                        x_render += (element.real_width + height / 2); /* add width of arrow to element width */
                        if (x <= x_render - 5 ) {
                            return element;
                        }
                    }
                }
            }
            return null;
        }

        /** Return an unescaped path from the breadcrumbs **/
        protected string get_path_from_element (BreadcrumbElement? el, bool include_file_protocol = true) {
            /* return path up to the specified element or, if the parameter is null, the whole path */
            string newpath = "";

            foreach (BreadcrumbElement element in elements) {
                    string s = element.text; /* element text should be an escaped string */
                    newpath += (s + Path.DIR_SEPARATOR_S);

                    if (el != null && element == el) {
                        break;
                    }
            }

            return FileUtils.sanitize_path (newpath, null, include_file_protocol);
        }

        private void make_element_list_from_protocol_and_path (string protocol,
                                                               string path,
                                                               Gee.ArrayList<BreadcrumbElement> newelements) {
            /* Ensure the breadcrumb texts are escaped strings whether or not
             * the parameter newpath was supplied escaped */
            string newpath = FileUtils.escape_uri (Uri.unescape_string (path) ?? path);
            newelements.add (new BreadcrumbElement (protocol, this, get_style_context ()));
            foreach (string dir in newpath.split (Path.DIR_SEPARATOR_S)) {
                if (dir != "") {
                    newelements.add (new BreadcrumbElement (dir, this, get_style_context ()));
                }
            }

            set_element_icons (protocol, newelements);
            replace_elements (newelements);
        }

        private void set_element_icons (string protocol, Gee.ArrayList<BreadcrumbElement> newelements) {
            /*Store the current list length */
            var breadcrumb_icons_list = breadcrumb_icons.length (); //Can assumed to be limited in length
            breadcrumb_icons.add_mounted_volumes ();

            foreach (BreadcrumbIconInfo icon in breadcrumb_icons.get_list ()) {
                if (icon.protocol && protocol.has_prefix (icon.path)) {
                    newelements[0].set_icon (icon);
                    newelements[0].text_for_display = icon.text_displayed;
                    newelements[0].text_is_displayed = (icon.text_displayed != null);
                    break;
                } else if (!icon.protocol && icon.exploded.length <= newelements.size) {
                    bool found = true;
                    int h = 0;

                    for (int i = 1; i < icon.exploded.length; i++) {
                        if (icon.exploded[i] != newelements[i].text) {
                            found = false;
                            break;
                        }

                        h = i;
                    }

                    if (found) {
                        for (int j = 0; j < h; j++) {
                            newelements[j].display = false;
                        }

                        newelements[h].display = true;
                        newelements[h].set_icon (icon);
                        newelements[h].text_is_displayed = (icon.text_displayed != null) || !icon.break_loop;
                        newelements[h].text_for_display = icon.text_displayed;

                        if (icon.break_loop) {
                            break;
                        }
                    }
                }
            }

            /* Remove the volume icons we added just before. */
            breadcrumb_icons.truncate_to_length (breadcrumb_icons_list);
        }

        private void replace_elements (Gee.ArrayList<BreadcrumbElement> new_elements) {
            /* Stop any animation */
            if (animation_timeout_id > 0) {
                remove_tick_callback (animation_timeout_id);
                animation_timeout_id = 0;
            }
            old_elements = null;
            if (!has_focus && animation_visible) {
                int change = new_elements.size - elements.size;
                int max_path = int.min (elements.size, new_elements.size);
                if (change > 0) {
                    animate_adding_elements (new_elements.slice (max_path, new_elements.size));
                } else if (change < 0) {
                    old_elements = elements.slice (max_path, elements.size); /*elements being removed */
                    animate_removing_elements (old_elements);
                } else { /* Equal length */
                    /* This is to make sure breadcrumbs are rendered properly when switching to a duplicate tab */
                    animate_adding_elements (new_elements.slice (max_path, new_elements.size));
                }
            }
            elements.clear ();
            /* This occurs *before* the animations run, so the new elements are always drawn
             * whether or not the old elements are animated as well */
            elements = new_elements;
            queue_draw ();
        }

    /** Animation functions **/
    /****************************/
        private void prepare_to_animate (Gee.Collection<BreadcrumbElement> els, double offset) {
            foreach (BreadcrumbElement bread in els) {
                bread.offset = offset;
            }
        }

        private double ease_out_cubic (double t) {
            double p = t - 1;
            return 1 + p * p * p;
        }

        private uint make_animation (Gee.Collection<BreadcrumbElement> els,
                                     double initial_offset,
                                     double final_offset,
                                     uint64 time_usec) {
            if (!get_settings ().gtk_enable_animations) {
                prepare_to_animate (els, final_offset);
                return 0;
            }

            prepare_to_animate (els, initial_offset);
            var anim_state = initial_offset;
            int64 start_time = get_frame_clock ().get_frame_time ();
            var anim = add_tick_callback ((widget, frame_clock) => {
                int64 time = frame_clock.get_frame_time ();
                double t = (double) (time - start_time) / LOCATION_BAR_ANIMATION_TIME_USEC;
                t = 1 - ease_out_cubic (t.clamp (0, 1));

                anim_state = final_offset + (initial_offset - final_offset) * t;

                foreach (BreadcrumbElement bread in els) {
                    bread.offset = anim_state;
                }

                queue_draw ();

                if (time >= start_time + LOCATION_BAR_ANIMATION_TIME_USEC) {
                    old_elements = null;
                    animation_timeout_id = 0;
                    return GLib.Source.REMOVE;
                } else {
                    return GLib.Source.CONTINUE;
                }
            });

            return anim;
        }

        private void animate_adding_elements (Gee.Collection<BreadcrumbElement> els) {
            animation_timeout_id = make_animation (els, 1.0, 0.0, Files.LOCATION_BAR_ANIMATION_TIME_USEC);
        }

        private void animate_removing_elements (Gee.Collection<BreadcrumbElement> els) {
            animation_timeout_id = make_animation (els, 0.0, 1.0, Files.LOCATION_BAR_ANIMATION_TIME_USEC);
        }

        public override bool draw (Cairo.Context cr) {
            weak Gtk.StyleContext style_context = get_style_context ();
            if (button_context_active == null) {
                button_context_active = new Gtk.StyleContext ();
                button_context_active.set_path (style_context.get_path ());
                button_context_active.set_state (Gtk.StateFlags.ACTIVE);
            }
            var state = style_context.get_state ();
            var is_rtl = Gtk.StateFlags.DIR_RTL in state;
            var padding = style_context.get_padding (state);
            base.draw (cr);
            double height = get_allocated_height ();
            double width = get_allocated_width ();

            int scale = style_context.get_scale ();
            if (breadcrumb_icons.scale != scale) {
                breadcrumb_icons.scale = scale;

                string protocol = "";
                if (elements.size > 0) {
                    protocol = elements[0].text;
                }
                set_element_icons (protocol, elements);
            }

            style_context.save ();
            style_context.set_state (Gtk.StateFlags.ACTIVE);
            Gtk.Border border = style_context.get_margin (state);
            style_context.restore ();

            if (!is_focus && !hide_breadcrumbs) {
                double margin = border.top;

                /* Ensure there is an editable area to the right of the breadcrumbs */
                double width_marged = width - 2 * margin - MINIMUM_LOCATION_BAR_ENTRY_WIDTH - ICON_WIDTH;
                double height_marged = height - 2 * margin;
                double x_render;
                if (is_rtl) {
                    x_render = width - margin;
                } else {
                    x_render = margin;
                }
                GLib.List<BreadcrumbElement> displayed_breadcrumbs = null;
                double max_width = get_displayed_breadcrumbs_natural_width (out displayed_breadcrumbs);
                /* each element must not be bigger than the width/breadcrumbs count */
                double total_arrow_width = displayed_breadcrumbs.length () * (height_marged / 2 + padding.left);
                width_marged -= total_arrow_width;
                if (max_width > width_marged) { /* let's check if the breadcrumbs are bigger than the widget */
                    var unfixed = displayed_breadcrumbs.length () - 2; //Can assumed to be limited in length
                    if (unfixed > 0) {
                        width_marged -= unfixed * MINIMUM_BREADCRUMB_WIDTH;
                    }
                    fix_displayed_widths (displayed_breadcrumbs, width_marged);
                    distribute_shortfall (displayed_breadcrumbs, width_marged);
                }
                cr.save ();
                /* Really draw the elements */
                foreach (BreadcrumbElement element in displayed_breadcrumbs) {
                    x_render = element.draw (cr, x_render, margin, height_marged, this);
                    /* save element x axis position */
                    if (is_rtl) {
                        element.x = x_render + element.real_width;
                    } else {
                        element.x = x_render - element.real_width;
                    }
                }
                /* Draw animated removal of elements when shortening the breadcrumbs */
                if (old_elements != null) {
                    foreach (BreadcrumbElement element in old_elements) {
                        if (element.display) {
                            x_render = element.draw (cr, x_render, margin, height_marged, this);
                            /* save element x axis position */
                            if (is_rtl) {
                                element.x = x_render + element.real_width;
                            } else {
                                element.x = x_render - element.real_width;
                            }
                        }
                    }
                }
                cr.restore ();
            } else if (placeholder != "") {
                assert (placeholder != null);
                assert (text != null);
                int layout_width, layout_height;
                double text_width, text_height;
                Pango.Layout layout;
                /** TODO - Get offset due to margins from style context **/
                int icon_width = primary_icon_pixbuf != null ? primary_icon_pixbuf.width + 5 : 0;

                Gdk.RGBA rgba;
                var colored = get_style_context ().lookup_color ("placeholder_text_color", out rgba);
                if (!colored) {
                    colored = get_style_context ().lookup_color ("text_color", out rgba);
                    if (!colored) {
                    /* If neither "placeholder_text_color" or "text_color" defined in theme (unlikely) fallback to a
                     *  color that is hopefully still visible in light and dark variants */
                        rgba = {0.6, 0.6, 0.5, 1};
                    }
                }

                cr.set_source_rgba (rgba.red, rgba.green, rgba.blue, 1);

                if (is_rtl) {
                    layout = create_pango_layout (text + placeholder);
                } else {
                    layout = create_pango_layout (text);
                }

                layout.get_size (out layout_width, out layout_height);
                text_width = Pango.units_to_double (layout_width);
                text_height = Pango.units_to_double (layout_height);
                /** TODO - Get offset due to margins from style context **/
                var vertical_offset = get_allocated_height () / 2 - text_height / 2;
                if (is_rtl) {
                   cr.move_to (width - (text_width + icon_width + 6), vertical_offset);
                } else {
                   cr.move_to (text_width + icon_width + 6, vertical_offset);
                }

                layout.set_text (placeholder, -1);
                Pango.cairo_show_layout (cr, layout);
            }

            return true;
        }

        public int get_minimum_width () {
            return minimum_width;
        }

        /**Functions to aid testing **/
        public string get_first_element_icon_name () {
            if (elements.size >= 1) {
                return elements[0].get_icon_name ();
            } else {
                return "null";
            }
        }
    }
}
