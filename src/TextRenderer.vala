/***
    Copyright (c) 2015-2017 elementary LLC (http://launchpad.net/elementary)

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

namespace Marlin {
    public class TextRenderer: Gtk.CellRendererText {

        const int MAX_LINES = 5;
        const int BORDER_RADIUS = 6;

        public Marlin.ZoomLevel zoom_level {get; set;}
        public new string background { set; private get;}
        public GOF.File? file {set; private get;}
        private int _item_width;
        public int item_width {
            set {
                _item_width = value;
                if (xalign == 0.5) {
                    wrap_width = _item_width - 2 * (focus_border_width + (int)xpad + BORDER_RADIUS);
                } else {
                    wrap_width = -1;
                }
            }

            private get {
                return _item_width;
            }
        }

        public int text_width;
        public int text_height;

        int char_height;
        int focus_border_width;

        Pango.Layout layout;
        Gtk.Widget widget;
        Marlin.AbstractEditableLabel entry;

        construct {
            this.mode = Gtk.CellRendererMode.EDITABLE;
        }

        public TextRenderer (Marlin.ViewMode viewmode) {
            if (viewmode == Marlin.ViewMode.ICON) {
                entry = new Marlin.MultiLineEditableLabel ();
            } else {
                entry = new Marlin.SingleLineEditableLabel ();
            }

            entry.editing_done.connect (on_entry_editing_done);
        }

        public override void get_preferred_height_for_width (Gtk.Widget widget, int width, out int minimum_size, out int natural_size) {
            set_widget (widget);
            set_up_layout (text, width);

            int h = int.max (16, char_height) + 2 * (int)ypad;

            natural_size = int.max (h, text_height) + h;
            minimum_size = natural_size;
        }

        public override void render (Cairo.Context cr,
                                     Gtk.Widget widget,
                                     Gdk.Rectangle background_area,
                                     Gdk.Rectangle cell_area,
                                     Gtk.CellRendererState flags) {
            set_widget (widget);
            Gtk.StateFlags state = widget.get_state_flags ();

            if ((flags & Gtk.CellRendererState.SELECTED) == Gtk.CellRendererState.SELECTED)
                state |= Gtk.StateFlags.SELECTED;
            else if ((flags & Gtk.CellRendererState.PRELIT) == Gtk.CellRendererState.PRELIT)
                state = Gtk.StateFlags.PRELIGHT;
            else
                state = widget.get_sensitive () ? Gtk.StateFlags.NORMAL : Gtk.StateFlags.INSENSITIVE;

            set_up_layout (text, cell_area.width);

            var style_context = widget.get_parent ().get_style_context ();
            style_context.save ();
            style_context.set_state (state);

            int x_offset, y_offset, focus_rect_width, focus_rect_height;
            draw_focus (cr, cell_area, flags, style_context, state, out x_offset, out y_offset,
                        out focus_rect_width, out focus_rect_height);

            /* Position text relative to the focus rectangle */
            y_offset += 2 * focus_border_width;
            if (xalign == 0.5f) {
                x_offset -= (wrap_width - text_width) / 2 - focus_border_width * 2 -(int)xpad;
            } else {
                if (widget.get_direction () == Gtk.TextDirection.RTL) {
                    x_offset += (focus_rect_width - text_width) - focus_border_width * 4;
                } else {
                    x_offset += focus_border_width * 2 + (int)xpad;
                }
            }

            style_context.render_layout (cr,
                                         cell_area.x + x_offset,
                                         cell_area.y + y_offset,
                                         layout);

            style_context.restore ();

            /* The render call should always be preceded by a set_property call
               from GTK. It should be safe to unreference or free the allocated
               memory here. */
            file = null;
        }

        public void set_up_layout (string? text, int cell_width) {
            /* render small/normal text depending on the zoom_level */
            if (text == null) {
                text= " ";
            }

            bool small = this.zoom_level < Marlin.ZoomLevel.NORMAL;
            if (small) {
                layout.set_attributes (EelPango.attr_list_small ());
            } else {
                layout.set_attributes (null);
            }

            if (wrap_width < 0) {
                layout.set_width (cell_width * Pango.SCALE);
                layout.set_height (- 1);
            } else {
                layout.set_width ((wrap_width) * Pango.SCALE);
                layout.set_wrap (this.wrap_mode);
                layout.set_height (- MAX_LINES);
            }

            layout.set_ellipsize (Pango.EllipsizeMode.END);

            if (xalign == 0.5f) {
                layout.set_alignment (Pango.Alignment.CENTER);
            }

            layout.set_text (text, -1);

            /* calculate the real text dimension */
            int width, height;
            layout.get_pixel_size (out width, out height);
            text_width = width;
            text_height = height;
        }

        public override unowned Gtk.CellEditable? start_editing (Gdk.Event? event,
                                                           Gtk.Widget widget,
                                                           string  path,
                                                           Gdk.Rectangle  background_area,
                                                           Gdk.Rectangle  cell_area,
                                                           Gtk.CellRendererState flags) {

            if (!visible || mode != Gtk.CellRendererMode.EDITABLE)
                return null;

            float xalign, yalign;
            get_alignment (out xalign, out yalign);

            entry.set_text (text);
            entry.set_line_wrap (true);
            entry.set_line_wrap_mode (wrap_mode);

            if (wrap_width > 0) { /* Icon view */
                entry.set_justify (Gtk.Justification.CENTER);
                entry.draw_outline = true;
            } else {  /*List and Column views */
                entry.set_justify (Gtk.Justification.LEFT);
                entry.draw_outline = false;
            }

            entry.yalign = this.yalign;
            entry.set_padding ((int)xpad, (int)ypad);
            entry.set_size_request (wrap_width, -1);
            entry.set_position (-1);
            entry.set_data ("marlin-text-renderer-path", path.dup ());
            entry.show_all ();

            base.start_editing (event, widget, path, background_area, cell_area, flags);
            return entry as Gtk.CellEditable;
        }

        public void end_editing (bool cancel) {
            entry.end_editing (cancel);
        }

        private void set_widget (Gtk.Widget? _widget) {
            Pango.FontMetrics metrics;
            Pango.Context context;

            if (_widget == widget)
                return;

            /* disconnect from the previously set widget */
            if (widget != null)
                disconnect_widget_signals ();

            widget = _widget;

            if (widget != null) {
                connect_widget_signals ();
                context = widget.get_pango_context ();
                layout = new Pango.Layout (context);
                layout.set_auto_dir (false);
                layout.set_single_paragraph_mode (true);
                metrics = context.get_metrics (layout.get_font_description (), context.get_language ());
                char_height = (metrics.get_ascent () + metrics.get_descent () + 512) >> 10;
                
                if (wrap_width < 0) {
                    (this as Gtk.CellRenderer).set_fixed_size (-1, char_height);
                }

                int focus_padding;
                int focus_line_width;
                widget.style_get ("focus-padding", out focus_padding, "focus-line-width", out focus_line_width);
                focus_border_width = int.max (focus_padding + focus_line_width, 2);

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

            focus_rect_height = text_height + 2 * this.focus_border_width + BORDER_RADIUS;
            focus_rect_width = text_width  + 4 * this.focus_border_width  + BORDER_RADIUS;

            get_offsets (cell_area, focus_rect_width, focus_rect_height, out x_offset, out y_offset);

            /* render the background if selected or colorized */
            if (selected || this.background != null) {
                int x0 = cell_area.x + x_offset;
                int y0 = cell_area.y + y_offset;
                int x1 = x0 + focus_rect_width;
                int y1 = y0 + focus_rect_height;

                cr.move_to (x0 + BORDER_RADIUS, y0);
                cr.line_to (x1 - BORDER_RADIUS, y0);
                cr.curve_to (x1 - BORDER_RADIUS, y0, x1, y0, x1, y0 + BORDER_RADIUS);
                cr.line_to (x1, y1 - BORDER_RADIUS);
                cr.curve_to (x1, y1 - BORDER_RADIUS, x1, y1, x1 - BORDER_RADIUS, y1);
                cr.line_to (x0 + BORDER_RADIUS, y1);
                cr.curve_to (x0 + BORDER_RADIUS, y1, x0, y1, x0, y1 - BORDER_RADIUS);
                cr.line_to (x0, y0 + BORDER_RADIUS);
                cr.curve_to (x0, y0 + BORDER_RADIUS, x0, y0, x0 + BORDER_RADIUS, y0);

                Gdk.RGBA color ={};
                if (background != null && !selected) {
                    if (!color.parse (background)) {
                        critical ("Can't parse this color value: %s", background);
                        color = style_context.get_background_color (state);
                    }
                } else
                    color = style_context.get_background_color (state);

                Gdk.cairo_set_source_rgba (cr, color);
                cr.fill ();
            }
            /* draw the focus indicator */
            if ((flags & Gtk.CellRendererState.FOCUSED) != 0)
                style_context.render_focus (cr,
                                            cell_area.x + x_offset,
                                            cell_area.y + y_offset,
                                            focus_rect_width,
                                            focus_rect_height);
        }

        private void get_offsets (Gdk.Rectangle cell_area,
                                  int width,
                                  int height,
                                  out int x_offset,
                                  out int y_offset) {

            if (widget.get_direction () == Gtk.TextDirection.RTL) {
                x_offset = (int)((1.0f - xalign) * (cell_area.width - width));
                x_offset -= (int)xpad;
            } else {
                x_offset = (int)(xalign * (cell_area.width - width));
                x_offset += (int)xpad;
            }

            y_offset = (int)(yalign * (cell_area.height - height)) + (int)ypad;
        }
    }
}
