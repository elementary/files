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

    Authors: Jeremy Wootten <jeremy@elementaryos.org>
***/

namespace Files {
    public class TextRenderer: Gtk.CellRendererText {

        const int MAX_LINES = 5;
        private int border_radius;
        private int double_border_radius;
        private Gtk.CssProvider text_css;
        private Gdk.RGBA previous_background_rgba;
        private Gdk.RGBA previous_contrasting_rgba;

        private ZoomLevel _zoom_level;
        public ZoomLevel zoom_level {
            get {
                return _zoom_level;
            }

            set {
                var icon_size = value.to_icon_size ();
                border_radius = 5 + icon_size / 40;
                double_border_radius = 2 * border_radius;

                if (is_list_view) {
                    set_fixed_size (-1, icon_size);
                } else {
                    wrap_width = item_width - double_border_radius;
                }

                _zoom_level = value;
            }
        }

        public Files.File? file {set; private get;}
        private int _item_width = -1;
        public int item_width {
            set {
                _item_width = value;
            }

            private get {
                return _item_width;
            }
        }

        public bool modifier_is_pressed { get; set; default = false; }
        private bool is_list_view;

        public int text_width;
        public int text_height;

        int char_height;

        Pango.Layout layout;
        Gtk.Widget widget;
        AbstractEditableLabel entry;

        construct {
            this.mode = Gtk.CellRendererMode.EDITABLE;
            text_css = new Gtk.CssProvider ();
            previous_background_rgba = { 0, 0, 0, 0 };
            previous_contrasting_rgba = { 0, 0, 0, 0 };
        }

        public TextRenderer (ViewMode viewmode) {
            if (viewmode == ViewMode.ICON) {
                entry = new MultiLineEditableLabel ();
                is_list_view = false;
            } else {
                entry = new SingleLineEditableLabel ();
                is_list_view = true;
            }

            entry.editing_done.connect (on_entry_editing_done);
        }

        public override void get_preferred_height_for_width (Gtk.Widget widget, int width,
                                                               out int minimum_size, out int natural_size) {
            set_widget (widget);
            set_up_layout (text, width);
            natural_size = text_height + 4 * border_radius;
            minimum_size = natural_size;
        }

        public override void render (Cairo.Context cr,
                                     Gtk.Widget widget,
                                     Gdk.Rectangle background_area,
                                     Gdk.Rectangle cell_area,
                                     Gtk.CellRendererState flags) {
            set_widget (widget);
            Gtk.StateFlags state = widget.get_state_flags ();

            if ((flags & Gtk.CellRendererState.SELECTED) == Gtk.CellRendererState.SELECTED) {
                state |= Gtk.StateFlags.SELECTED;
            } else if ((flags & Gtk.CellRendererState.PRELIT) == Gtk.CellRendererState.PRELIT) {
                state = Gtk.StateFlags.PRELIGHT;
            } else {
                state = widget.get_sensitive () ? Gtk.StateFlags.NORMAL : Gtk.StateFlags.INSENSITIVE;
            }

            set_up_layout (text, cell_area.width, state);

            var style_context = widget.get_parent ().get_style_context ();
            style_context.save ();
            style_context.set_state (state);

            int x_offset, y_offset, focus_rect_width, focus_rect_height;
            draw_focus (cr, cell_area, flags, style_context, state, out x_offset, out y_offset,
                        out focus_rect_width, out focus_rect_height);

            /* Position text relative to the focus rectangle */
            if (!is_list_view) {
                x_offset += (focus_rect_width - wrap_width) / 2;
                y_offset += (focus_rect_height - text_height) / 2;
            } else {
                y_offset = (cell_area.height - char_height) / 2;
                x_offset += border_radius;
            }

            if (background_set) {
                if (!background_rgba.equal (previous_background_rgba)) {
                    /* Using Gdk.RGBA copy () causes a segfault for some reason */
                    previous_background_rgba.red = background_rgba.red;
                    previous_background_rgba.green = background_rgba.green;
                    previous_background_rgba.blue = background_rgba.blue;
                    previous_background_rgba.alpha = background_rgba.alpha;

                    var contrasting_foreground_rgba = Granite.contrasting_foreground_color (background_rgba);
                    if (!contrasting_foreground_rgba.equal (previous_contrasting_rgba)) {
                    /* Using Gdk.RGBA copy () causes a segfault for some reason */
                        previous_contrasting_rgba.red = contrasting_foreground_rgba.red;
                        previous_contrasting_rgba.green = contrasting_foreground_rgba.green;
                        previous_contrasting_rgba.blue = contrasting_foreground_rgba.blue;
                        previous_contrasting_rgba.alpha = contrasting_foreground_rgba.alpha;
                        string data = "* {color: %s;}".printf (contrasting_foreground_rgba.to_string ());
                        try {
                            text_css.load_from_data (data);
                        } catch (Error e) {
                            critical (e.message);
                        }
                    }
                }

                style_context.add_provider (text_css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            }

            style_context.render_layout (cr,
                                         cell_area.x + x_offset,
                                         cell_area.y + y_offset,
                                         layout);

            style_context.restore (); /* NOTE: This does not remove added classes */
            style_context.remove_provider (text_css); /* No error if provider not added */


            /* The render call should always be preceded by a set_property call
               from GTK. It should be safe to unreference or free the allocated
               memory here. */
            file = null;
        }

        public void set_up_layout (
            string? text, int cell_width, Gtk.StateFlags state_flags = Gtk.StateFlags.NORMAL
        ) {
            if (text == null) {
                text= " ";
            }

            if (is_list_view) {
                layout.set_width ((cell_width - double_border_radius) * Pango.SCALE);
                layout.set_height (- 1);
            } else {
                layout.set_width (wrap_width * Pango.SCALE);
                layout.set_wrap (this.wrap_mode);
                layout.set_height (- MAX_LINES);
            }

            layout.set_ellipsize (Pango.EllipsizeMode.END);

            if (!is_list_view) {
                layout.set_alignment (Pango.Alignment.CENTER);
            }

            if (!modifier_is_pressed &&
                file.is_directory &&
                (state_flags & Gtk.StateFlags.PRELIGHT) > 0) {

                layout.set_markup (
                    "<span underline='low'>" + Markup.escape_text (text) + "</span>", -1
                );
            } else {
                layout.set_markup (Markup.escape_text (text), -1);
            }

            /* calculate the real text dimension */
            int width, height;
            layout.get_pixel_size (out width, out height);
            text_width = width;
            text_height = height;
        }

        public override unowned Gtk.CellEditable? start_editing (Gdk.Event? event,
                                                                 Gtk.Widget widget,
                                                                 string path,
                                                                 Gdk.Rectangle background_area,
                                                                 Gdk.Rectangle cell_area,
                                                                 Gtk.CellRendererState flags) {

            if (!visible || mode != Gtk.CellRendererMode.EDITABLE) {
                return null;
            }

            float xalign, yalign;
            get_alignment (out xalign, out yalign);

            entry.set_text (text);
            entry.set_line_wrap (true);
            entry.set_line_wrap_mode (wrap_mode);

            if (!is_list_view) {
                entry.set_justify (Gtk.Justification.CENTER);
                entry.draw_outline = true;
            } else {
                entry.set_justify (Gtk.Justification.LEFT);
                entry.draw_outline = false;
            }

            entry.yalign = this.yalign;
            entry.set_size_request (wrap_width, -1);
            entry.set_position (-1);
            entry.set_data ("marlin-text-renderer-path", path.dup ());
            entry.show_all ();

            base.start_editing (event, widget, path, background_area, cell_area, flags);
            return entry;
        }

        public void end_editing (bool cancel) {
            entry.end_editing (cancel);
        }

        private void set_widget (Gtk.Widget? _widget) {
            Pango.FontMetrics metrics;
            Pango.Context context;

            if (_widget == widget) {
                return;
            }

            /* disconnect from the previously set widget */
            if (widget != null) {
                disconnect_widget_signals ();
            }

            widget = _widget;

            if (widget != null) {
                connect_widget_signals ();
                context = widget.get_pango_context ();
                layout = new Pango.Layout (context);

                /* We do not want hyphens inserted when text wraps */
                var attr = new Pango.AttrList ();
                attr.insert (Pango.attr_insert_hyphens_new (false));
                layout.set_attributes (attr);

                layout.set_auto_dir (false);
                layout.set_single_paragraph_mode (true);
                metrics = context.get_metrics (layout.get_font_description (), context.get_language ());
                char_height = (metrics.get_ascent () + metrics.get_descent () + 512) >> 10;
            } else {
                layout = null;
                char_height = 0;
            }
        }

        private void connect_widget_signals () {
            widget.destroy.connect (invalidate);
            widget.style_updated.connect (invalidate);
        }

        private void disconnect_widget_signals () {
            widget.destroy.disconnect (invalidate);
            widget.style_updated.disconnect (invalidate);
        }

        private void invalidate () {
            disconnect_widget_signals ();
            set_widget (null);
            file = null;
        }

        private void on_entry_editing_done () {
            bool cancelled = entry.editing_canceled;
            base.stop_editing (cancelled);

            entry.hide ();

            if (!cancelled) {
                string text = entry.get_text ();
                string path = entry.get_data ("marlin-text-renderer-path");
                edited (path, text);
            }
            file = null;
        }

        private void draw_focus (Cairo.Context cr,
                                 Gdk.Rectangle cell_area,
                                 Gtk.CellRendererState flags,
                                 Gtk.StyleContext style_context,
                                 Gtk.StateFlags state,
                                 out int x_offset,
                                 out int y_offset,
                                 out int focus_rect_width,
                                 out int focus_rect_height) {

            bool selected = false;
            focus_rect_width = 0;
            focus_rect_height = 0;
            x_offset = 0;
            y_offset = 0;

            selected = ((flags & Gtk.CellRendererState.SELECTED) == Gtk.CellRendererState.SELECTED);
            focus_rect_height = text_height + border_radius;
            focus_rect_width = text_width + double_border_radius;

            /* Ensure that focus_rect is at least one pixel small than cell_area on each side */
            focus_rect_width = int.min (focus_rect_width, cell_area.width - 2);
            focus_rect_height = int.min (focus_rect_height, cell_area.height - 2);

            get_offsets (cell_area, focus_rect_width, focus_rect_height, out x_offset, out y_offset);

            /* render the background if selected or colorized */
            if (selected || this.background_set) {
                int x0 = cell_area.x + x_offset;
                int y0 = cell_area.y + y_offset;
                var provider = new Gtk.CssProvider ();
                string data;
                if (selected && !background_set) {
                    data = "* {border-radius: 5px;}";
                } else {
                    data = "* {border-radius: 5px; background-color: %s;}".printf (background_rgba.to_string ());
                }

                try {
                    provider.load_from_data (data);
                    style_context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                    style_context.render_background (cr, x0, y0, focus_rect_width, focus_rect_height);
                    style_context.remove_provider (provider);
                } catch (Error e) {
                    critical (e.message);
                }
            }

            /* Icons are highlighted when focussed - there is no focus indicator on text */
        }

        private void get_offsets (Gdk.Rectangle cell_area,
                                  int width,
                                  int height,
                                  out int x_offset,
                                  out int y_offset) {

            if (widget.get_direction () == Gtk.TextDirection.RTL) {
                x_offset = (int)((1.0f - xalign) * (cell_area.width - width));
                if (is_list_view) {
                    x_offset -= border_radius;
                }
            } else {
                x_offset = (int)(xalign * (cell_area.width - width));
                if (is_list_view ) {
                    x_offset += border_radius;
                }
            }

            y_offset = (int)(yalign * (cell_area.height - height));

            if (!is_list_view) {
                y_offset += border_radius;
            }
        }
    }
}
