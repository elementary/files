/*
 Copyright (C) 2014 elementary Developers

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

namespace Marlin {
    public class TextRenderer: Gtk.CellRendererText {

        const int MAX_LINES = 3;

        public Marlin.ZoomLevel zoom_level {get; set;}
        public bool follow_state {get; set;}
        public new string background { set; private get;}

        Pango.Layout layout;
        Gtk.Widget widget;
        int char_width;
        int char_height;
        public int text_width;
        public int text_height;
        int focus_border_width;

        Marlin.EditableLabel entry;

        public TextRenderer () {
            this.mode = Gtk.CellRendererMode.EDITABLE;
            this.entry = new Marlin.EditableLabel ();
            connect_entry_signals ();
        }

        private void set_widget (Gtk.Widget? widget) {
debug ("set  widget");
            Pango.FontMetrics metrics;
            Pango.Context context;
            int focus_padding;
            int focus_line_width;

            if (widget == this.widget)
                return;

            /* disconnect from the previously set widget */
            if (this.widget != null)
                disconnect_widget_signals ();

            this.widget = widget;

            if (widget != null) {
                connect_widget_signals ();
                context = widget.get_pango_context ();
                this.layout = new Pango.Layout (context);
                layout.set_auto_dir (false);
                layout.set_single_paragraph_mode (true);
                metrics = context.get_metrics (layout.get_font_description (), context.get_language ());
                this.char_width = (metrics.get_approximate_char_width () + 512 ) >> 10;
                this.char_height = (metrics.get_ascent () + metrics.get_descent () + 512) >> 10;
                if (this.wrap_width < 0)
                    (this as Gtk.CellRenderer).set_fixed_size (-1, this.char_height);

                widget.style_get ("focus-padding", out focus_padding, "focus-line-width", out focus_line_width);
                this.focus_border_width = int.max (focus_padding + focus_line_width, 2);
            } else {
                this.layout = null;
                this.char_width = 0;
                this.char_height = 0;
            }
        }

        private void connect_widget_signals () {
//message ("connect widget signals");
            widget.destroy.connect (invalidate);
            widget.style_set.connect (invalidate);
        }
        private void disconnect_widget_signals () {
//message ("disconnect widget signals");
            widget.destroy.disconnect (invalidate);
            widget.style_set.disconnect (invalidate);
        }

        private void invalidate () {
//message ("invalidate");
            set_widget (null);
        }

        /* Needs patched gtk+-3.0.vapi file - incorrect function signature up to version 0.25.4 */
        public override unowned Gtk.CellEditable? start_editing (Gdk.Event? event,
                                                                 Gtk.Widget widget,
                                                                 string  path,
                                                                 Gdk.Rectangle  background_area,
                                                                 Gdk.Rectangle  cell_area,
                                                                 Gtk.CellRendererState flags) {
//message ("TR Start editing");
            if (!this.visible || this.mode != Gtk.CellRendererMode.EDITABLE)
                return null;

            float xalign, yalign;
            get_alignment (out xalign, out yalign);
            entry.set_text (this.text);
            entry.set_line_wrap (true);
            entry.set_line_wrap_mode (this.wrap_mode);

            /* presume we're in POSITION UNDER */
            if (wrap_width > 0)
                entry.set_justify (Gtk.Justification.CENTER);
            else 
                entry.set_justify (Gtk.Justification.LEFT);

            entry.yalign = this.yalign;
            entry.set_padding ((int)xpad, (int)ypad);

            var context = widget.get_style_context ();
            var state = widget.get_state_flags ();
            var font = (context.get_property ("font", state) as Pango.FontDescription);

            if (zoom_level < Marlin.ZoomLevel.NORMAL || (text.length + 3)* char_width > 3 * wrap_width) {
                font.set_size ((int)(font.get_size () * Pango.Scale.SMALL));
            } else {
                font_desc.set_size ((int)(font.get_size () * Pango.Scale.MEDIUM));
            }

            entry.override_font (font);
            entry.set_size_request (wrap_width, -1);
            entry.show_all ();
            entry.set_position (-1);
            entry.set_data ("marlin-text-renderer-path", path.dup ());

            return entry as Gtk.CellEditable;
        }


        private void connect_entry_signals () {
//message ("Connect entry signals");
            entry.editing_done.connect (on_entry_editing_done);
            entry.focus_out_event.connect (on_entry_focus_out_event);
        }

        private void on_entry_editing_done () {
//message ("TV Editing done");
            bool cancelled = entry.editing_canceled;
            base.stop_editing (cancelled);
            if (!cancelled) {
                string text = entry.get_text ();
                string path = entry.get_data ("marlin-text-renderer-path");
                edited (path, text);
            }
            entry.hide ();
        }

        private bool on_entry_focus_out_event (Gdk.Event event) {
//message ("TV Focus out event");
            on_entry_editing_done ();
            return false;
        }

        public override void render (Cairo.Context cr, Gtk.Widget widget, Gdk.Rectangle background_area, Gdk.Rectangle cell_area, Gtk.CellRendererState flags) {
            set_widget (widget);
            Gtk.StateFlags state = widget.get_state_flags ();

            if ((flags & Gtk.CellRendererState.SELECTED) == Gtk.CellRendererState.SELECTED)
                state |= Gtk.StateFlags.SELECTED;
            else if ((flags & Gtk.CellRendererState.PRELIT) == Gtk.CellRendererState.PRELIT)
                state = Gtk.StateFlags.PRELIGHT;
            else
                state = widget.get_sensitive () ? Gtk.StateFlags.NORMAL : Gtk.StateFlags.INSENSITIVE;

            set_up_layout (this.text, cell_area);

            Gtk.StyleContext style_context = widget.get_parent ().get_style_context ();
            style_context.save ();
            style_context.set_state (state);

            if (follow_state || background != null)
                draw_focus (cr, cell_area, flags, style_context, state);


            int x_offset, y_offset;
            get_offsets (cell_area, text_width, text_height, xalign, out x_offset, out y_offset);

            /* Adjust text offsets for best appearance in each view */
            if (xalign == 0.5f) { /* Icon view */
                x_offset = (cell_area.width - this.wrap_width) / 2;
                y_offset += focus_border_width + (int)ypad;
            } else {    
                x_offset += focus_border_width + 2 * (int)xpad;
                y_offset += focus_border_width;
            }

            style_context.render_layout (cr,
                                   cell_area.x + x_offset,
                                   cell_area.y + y_offset,
                                   layout);

            style_context.restore ();
        }

        public void set_up_layout (string? text, Gdk.Rectangle cell_area) {
            /* render small/normal text depending on the zoom_level */
            if (text == null)
                text= " ";
                
            if (this.zoom_level < Marlin.ZoomLevel.NORMAL)
                this.layout.set_attributes (EelPango.attr_list_small ());
            else
                this.layout.set_attributes (null);

            if (this.wrap_width < 0) {
                layout.set_width (cell_area.width * Pango.SCALE);
                layout.set_height (- 1);
            } else {
                layout.set_width (wrap_width * Pango.SCALE);
                layout.set_wrap (this.wrap_mode);
                /* ellipsize to max lines except for selected or prelit items */
                layout.set_height (- MAX_LINES);
            }

            layout.set_ellipsize (Pango.EllipsizeMode.END);

            if (this.xalign == 0.5f)
                layout.set_alignment (Pango.Alignment.CENTER);

            layout.set_text (text, -1);

            /* calculate the real text dimension */
            int width, height;
            layout.get_pixel_size (out width, out height);
            text_width = width;
            text_height = height;
        }

        private void draw_focus (Cairo.Context cr, Gdk.Rectangle cell_area, Gtk.CellRendererState flags, Gtk.StyleContext style_context, Gtk.StateFlags state) {
            bool selected = ((flags & Gtk.CellRendererState.SELECTED) == Gtk.CellRendererState.SELECTED && this.follow_state);
            int focus_rect_width = text_width + 4 * this.focus_border_width;
            int focus_rect_height = text_height + 2 * this.focus_border_width;

            float x;
            if (widget.get_direction () == Gtk.TextDirection.RTL)
                x = 1.0f - xalign;
            else
                x = xalign;

            int x_offset, y_offset;
            get_offsets (cell_area, focus_rect_width, focus_rect_height, x, out x_offset, out y_offset);

            /* render the background if selected or colorized */
            if (selected || this.background != null) {
                int x0 = cell_area.x + x_offset + (int)xpad;
                int y0 = cell_area.y + y_offset + (int)ypad;
                int x1 = x0 + focus_rect_width;
                int y1 = y0 + focus_rect_height;

                const uint border_radius = 6;
                cr.move_to (x0 + border_radius, y0);
                cr.line_to (x1 - border_radius, y0);
                cr.curve_to (x1 - border_radius, y0, x1, y0, x1, y0 + border_radius);
                cr.line_to (x1, y1 - border_radius);
                cr.curve_to (x1, y1 - border_radius, x1, y1, x1 - border_radius, y1);
                cr.line_to (x0 + border_radius, y1);
                cr.curve_to (x0 + border_radius, y1, x0, y1, x0, y1 - border_radius);
                cr.line_to (x0, y0 + border_radius);
                cr.curve_to (x0, y0 + border_radius, x0, y0, x0 + border_radius, y0);

                Gdk.RGBA color ={};
                if (this.background != null && !selected) {
                    if (!color.parse (this.background)) {
                        critical ("Can't parse this color value: %s", background);
                        color = style_context.get_background_color (state);
                    }
                } else
                    color = style_context.get_background_color (state);

                Gdk.cairo_set_source_rgba (cr, color);
                cr.fill ();
            }
            /* draw the focus indicator */
            if (this.follow_state && (flags & Gtk.CellRendererState.FOCUSED) != 0)
                style_context.render_focus (cr, cell_area.x + x_offset, cell_area.y + y_offset, focus_rect_width, focus_rect_height);
        }

        private void get_offsets (Gdk.Rectangle cell_area, int width, int height, float x, out int x_offset, out int y_offset) {
            x_offset = (int)(x * (cell_area.width - width - 2 * (int)xpad));
            x_offset = int.max (x_offset, 0);

            y_offset = (int)(yalign * (cell_area.height - height - 2 * (int)ypad));
            y_offset = int.max (y_offset, 0);
        }
    }
}
