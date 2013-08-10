/*
 * Copyright (c) 2011 Lucas Baudin <xapantu@gmail.com>
 *
 * Marlin is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * Marlin is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; see the file COPYING.  If not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

public class Marlin.View.Chrome.BreadcrumbsEntry : GLib.Object {
    Gtk.IMContext im_context;
    public string text = "";
    public int cursor = 0;
    public string completion = "";
    uint timeout;
    bool blink = true;
    public Gdk.Pixbuf arrow_img;

    double selection_mouse_start = -1;
    double selection_mouse_end = -1;
    double selection_start = 0;
    double selection_end = 0;
    int selected_start = -1;
    int selected_end = -1;
    internal bool hover = false;
    bool focus = false;

    bool is_selecting = false;
    bool need_selection_update = false;

    double text_width;
    double text_height;

    public signal void enter ();
    public signal void backspace ();
    public signal void left ();
    public signal void up ();
    public signal void down ();
    public signal void left_full ();
    public signal void need_draw ();
    public signal void paste ();
    public signal void need_completion ();
    public signal void completed ();
    public signal void escape ();

    /**
     * Create a new BreadcrumbsEntry object. It is used to display the entry
     * which is a the left of the pathbar. It is *not* a Gtk.Widget, it is
     * only a class which holds some data and draws an entry to a given
     * Cairo.Context.
     * Events must be sent to the appropriate function (key_press_event,
     * key_release_event, mouse_motion_event, etc...). These events must be
     * relative to the widget, so, you need to do some things like
     * event.x -= entry_x before sending the events.
     * It can be drawn using the draw() function.
     **/
    public BreadcrumbsEntry () {
        im_context = new Gtk.IMMulticontext ();
        im_context.commit.connect (commit);

        /* Load arrow image */
        try {
            arrow_img = Gtk.IconTheme.get_default ().load_icon ("go-jump-symbolic", 16, Gtk.IconLookupFlags.GENERIC_FALLBACK);
        } catch (Error err) {
            stderr.printf ("Unable to load home icon: %s", err.message);
        }
    }

    /**
     * Call this function if the parent widgets has the focus, it will start
     * computing the blink cursor, will enable cursor and selection drawing.
     **/
    public void show () {
        focus = true;

        if (timeout > 0)
            Source.remove (timeout);

        timeout = Timeout.add (700, () => {
            blink = !blink;
            need_draw ();

            return true;
        });
    }

    /**
     * Delete the text selected.
     **/
    public void delete_selection () {
        if (selected_start > 0 && selected_end > 0) {
            int first = selected_start > selected_end ? selected_end : selected_start;
            int second = selected_start > selected_end ? selected_start : selected_end;

            text = text.slice (0, first) + text.slice (second, text.length);
            reset_selection ();
            cursor = first;
        }
    }

    /**
     * Insert some text at the cursor position.
     *
     * @param to_insert The text you want to insert.
     **/
    public void insert (string to_insert) {
        if (to_insert != null && to_insert.length > 0) {
            int first = selected_start > selected_end ? selected_end : selected_start;
            int second = selected_start > selected_end ? selected_start : selected_end;

            if (first != second && second > 0) {
                text = text.slice (0, first) + to_insert + text.slice (second, text.length);
                selected_start = -1;
                selected_end = -1;
                selection_start = 0;
                selection_end = 0;
                cursor = first + to_insert.length;
            } else {
                text = text.slice (0,cursor) + to_insert + text.slice (cursor, text.length);
                cursor += to_insert.length;
            }
        }

        need_completion ();
    }

    /**
     * A callback from our im_context.
     **/
    private void commit (string character) {
        insert (character);
    }

    public void key_press_event (Gdk.EventKey event) {
        /* FIXME: I can't find the vapi to not use hardcoded key value. */
        /* FIXME: we should use Gtk.BindingSet, but the vapi file seems buggy */

        bool control_pressed = (event.state & Gdk.ModifierType.CONTROL_MASK) == 4;
        bool shift_pressed = ! ((event.state & Gdk.ModifierType.SHIFT_MASK) == 0);

        switch (event.keyval) {
        case 0xff51: /* left */
            if (cursor > 0 && !control_pressed && !shift_pressed) {
                cursor --; /* No control pressed, the cursor is not at the begin */
                reset_selection ();
            } else if (cursor == 0 && control_pressed) {
                left_full (); /* Control pressed, the cursor is at the begin */
            } else if (control_pressed) {
                cursor = 0;
            } else if (cursor > 0 && shift_pressed) {
                if (selected_start < 0) {
                    selected_start = cursor;
                }

                if (selected_end < 0) {
                    selected_end = cursor;
                }

                cursor--;
                selected_start = cursor;
                need_selection_update = true;
            } else {
                left ();
            }

            break;

        case 0xff53: /* right */
            if (cursor < text.length && !shift_pressed) {
                cursor++;
                reset_selection ();
            } else if (cursor < text.length && shift_pressed) {
                if (selected_start < 0) {
                    selected_start = cursor;
                }

                if (selected_end < 0) {
                    selected_end = cursor;
                }

                cursor++;
                selected_start = cursor;
                need_selection_update = true;
            } else if (!shift_pressed) {
                complete ();
            }

            break;

        case 0xff0d: /* enter */
            reset_selection ();
            enter ();
            break;

        case 0xff08: /* backspace */
            if (get_selection () != null) {
                delete_selection ();
                need_completion ();
            } else if (cursor > 0) {
                text = text.slice (0, cursor - 1) + text.slice (cursor, text.length);
                cursor--;
                need_completion ();
            } else {
                backspace ();
            }

            break;

        case 0xffff: /* delete */
            if (get_selection () == null && cursor < text.length && control_pressed) {
                text = text.slice (0, cursor);
            } else if (get_selection () == null && cursor < text.length) {
                text = text.slice (0, cursor) + text.slice (cursor + 1, text.length);
            } else if (get_selection () != null) {
                delete_selection ();
            }

            need_completion ();
            break;

        case 0xff09: /* tab */
            complete ();
            break;

        case 0xff54: /* down */
            down ();
            break;

        case 0xff52: /* up */
            up ();
            break;

        case 0xff1b: /* escape */
            escape ();
            break;

        case 0xff50: /* Home */
            cursor = 0;
            break;

        case 0xff57: /* End */
            cursor = text.length;
            break;

        default:
            im_context.filter_keypress (event);
            break;
        }

        blink = true;
        print ("%x\n", event.keyval);
    }

    public void complete () {
        reset_selection ();

        if (completion != "") {
            text += completion + "/";
            cursor += completion.length + 1;
            completion = "";
            completed ();
        }
    }

    public string? get_selection () {
        int first = selected_start > selected_end ? selected_end : selected_start;
        int second = selected_start > selected_end ? selected_start : selected_end;

        if (!(first < 0 || second < 0))
            return text.slice (first,second);

        return null;
    }

    public void key_release_event (Gdk.EventKey event) {
        im_context.filter_keypress (event);
    }

    public void mouse_motion_event (Gdk.EventMotion event, double width) {
        hover = false;

        if (event.x < width && event.x > width - arrow_img.get_width ())
            hover = true;

        if (is_selecting)
            selection_mouse_end = event.x > 0 ? event.x : 1;
    }

    public void mouse_press_event(Gdk.EventButton event, double width) {
        reset_selection ();
        blink = true;

        if (event.x < width && event.x > width - arrow_img.get_width ()) {
            enter ();
        } else if (event.x >= 0) {
            is_selecting = true;
            selection_mouse_start = event.x;
            selection_mouse_end = event.x;
        } else if (event.x >= -20) {
            is_selecting = true;
            selection_mouse_start = -1;
            selection_mouse_end = -1;
        }
        need_draw ();
    }

    public void mouse_release_event (Gdk.EventButton event) {
        selection_mouse_end = event.x;
        is_selecting = false;
    }

    /**
     * Reset the current selection. This function won't ask for re-drawing,
     * so, you will need to re-draw your entry by hand. It can be used after
     * a #text set, to avoid weird things.
     **/
    public void reset_selection () {
        selected_start = -1;
        selected_end = -1;
        selection_start = 0;
        selection_end = 0;
    }

    private void update_selection (Cairo.Context cr, Gtk.Widget widget) {
        double last_diff = double.MAX;
        Pango.Layout layout = widget.create_pango_layout (text);

        if (selection_mouse_start > 0) {
            selected_start = -1;
            selection_start = 0;
            cursor = text.length;

            for (int i = 0; i <= text.length; i++) {
                layout.set_text (text.slice(0, i), -1);

                if (Math.fabs (selection_mouse_start - get_width (layout)) < last_diff) {
                    last_diff = Math.fabs (selection_mouse_start - get_width (layout));
                    selection_start = get_width (layout);
                    selected_start = i;
                }
            }

            selection_mouse_start = -1;
        }

        if (selection_mouse_end > 0) {
            last_diff = double.MAX;
            selected_end = -1;
            selection_end = 0;
            cursor = text.length;

            for (int i = 0; i <= text.length; i++) {
                layout.set_text (text.slice (0, i), -1);

                if (Math.fabs (selection_mouse_end - get_width (layout)) < last_diff) {
                    last_diff = Math.fabs (selection_mouse_end - get_width (layout));
                    selection_end = get_width (layout);
                    selected_end = i;
                    cursor = i;
                }
            }

            selection_mouse_end = -1;
        }
    }

    private void computetext_width (Pango.Layout pango) {
        int text_width, text_height;
        pango.get_size (out text_width, out text_height);
        this.text_width = Pango.units_to_double (text_width);
        this.text_height = Pango.units_to_double (text_height);
    }

    /**
     * A utility function to get the width of a Pango.Layout. Maybe it could
     * be moved to a less specific file/lib.
     *
     * @param pango a pango layout
     * @return the width of the layout
     **/
    private double get_width (Pango.Layout pango) {
        int text_width, text_height;
        pango.get_size (out text_width, out text_height);
        return Pango.units_to_double (text_width);
    }

    private void update_selection_key (Cairo.Context cr, Gtk.Widget widget) {
        Pango.Layout layout = widget.create_pango_layout (text);
        layout.set_text (text.slice (0, selected_end), -1);
        selection_end = get_width (layout);
        layout.set_text (text.slice (0, selected_start), -1);
        selection_start = get_width (layout);
        need_selection_update = false;
    }

    public void draw(Cairo.Context cr,
                     double x, double height, double width,
                     Gtk.Widget widget, Gtk.StyleContext button_context) {

        update_selection (cr, widget);

        if (need_selection_update)
            update_selection_key (cr, widget);

        cr.set_source_rgba (0, 0, 0, 0.8);

        Pango.Layout layout = widget.create_pango_layout (text);
        computetext_width (layout);
        button_context.render_layout (cr, x, height / 2 - text_height / 2, layout);

        layout.set_text (text.slice (0, cursor), -1);

        if (blink && focus) {
            cr.rectangle (x + get_width (layout), height / 6, 1, 4 * height / 6);
            cr.fill ();
        }

        if (text != "") {
                Gdk.cairo_set_source_pixbuf (cr,arrow_img,
                                             x + width - arrow_img.get_width() - 10,
                                             height/2 - arrow_img.get_height() / 2);

            if (hover)
                cr.paint ();
            else
                cr.paint_with_alpha (0.8);
        }

        /* draw completion */
        cr.move_to (x + text_width, height / 2 - text_height / 2);
        layout.set_text (completion, -1);

#if VALA_0_14
        Gdk.RGBA color = button_context.get_color (Gtk.StateFlags.NORMAL);
#else
        Gdk.RGBA color = Gdk.RGBA ();
        button_context.get_color (Gtk.StateFlags.NORMAL, color);
#endif
        cr.set_source_rgba (color.red, color.green, color.blue, color.alpha - 0.3);
        Pango.cairo_show_layout (cr, layout);

        /* draw selection */
        if (focus && selected_start >= 0 && selected_end >= 0) {
            cr.rectangle (x + selection_start, height / 6, selection_end - selection_start, 4 * height / 6);
#if VALA_0_14
            color = button_context.get_background_color (Gtk.StateFlags.SELECTED);
#else
            button_context.get_background_color (Gtk.StateFlags.SELECTED, color);
#endif
            Gdk.cairo_set_source_rgba (cr, color);
            cr.fill ();

            layout.set_text (get_selection (), -1);

#if VALA_0_14
            color = button_context.get_color (Gtk.StateFlags.SELECTED);
#else
            button_context.get_color (Gtk.StateFlags.SELECTED, color);
#endif
            Gdk.cairo_set_source_rgba (cr, color);
            cr.move_to (x + Math.fmin (selection_start, selection_end),
                        height / 2 - text_height / 2);

            Pango.cairo_show_layout (cr, layout);
        }
    }

    public void reset () {
        text = "";
        cursor = 0;
        completion = "";
    }

    public void hide () {
        focus = false;
        if (timeout > 0)
            Source.remove (timeout);
    }

    ~BreadcrumbsEntry () {
        hide ();
    }
}
