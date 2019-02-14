/***
    Copyright (c) 2019 Jeremy Wootten <https://github.com/jeremypw/widget-grid>

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

/*** WidgetGrid.View handles layout and scrollbar, adding items to and sorting the model, and reacting
     to some user input. The details of laying out the widgets in a grid, scrolling and zooming them is
     passed off to the WidgetGrid.LayoutHandler.

     An Overlay as used as a base in order that the scrollbar does not trigger a reflow by expanding when hovered.

     The layout is under an EventBox in order to capture events before they reach the displayed widgets to allow
     rubberbanding and to emit special signals depending on where the event occured (on item or on background).
     It is up to the App to deal with these signals appropriately, e.g. by displaying a context menu.
***/
namespace WidgetGrid {

public class View : Gtk.Overlay {
    private static int total_items_added = 0; /* Used to ID data; only ever increases */
    private const int DEFAULT_HPADDING = 12;
    private const int DEFAULT_VPADDING = 24;

    private const double SCROLL_SENSITIVITY = 0.5; /* The scroll delta required to move the grid position by one step */
    private const double ZOOM_SENSITIVITY = 1.0; /* The scroll delta required to change the item width by one step */

    private Gtk.Layout layout;
    private Gtk.EventBox event_box;
    private LayoutHandler layout_handler;

    public int minimum_item_width { get; set; default = 16; }
    public int maximum_item_width { get; set; default = 512; }

    private int _item_width_index = 0;
    public int item_width_index {
        get {
            if (fixed_item_widths) {
                return _item_width_index;
            } else {
                return -1;
            }
        }

        set {
            if (fixed_item_widths && value != _item_width_index) {
                _item_width_index = value.clamp (0, allowed_item_widths.length - 1);
                item_width = allowed_item_widths[item_width_index];
            }
        }
    }

    public Model<WidgetData>model {get; set construct; }
    public AbstractItemFactory factory { get; construct; }

    private int[] allowed_item_widths = {16, 24, 32, 48, 64, 96, 128, 256, 512};
    public int width_increment { get; set; default = 6; }
    public bool fixed_item_widths { get; set; default = true;}

    private int _item_width = 0;
    public int item_width {
        get {
            return _item_width;
        }

        set {
            if (value == _item_width) {
                return;
            }

            int new_width = 0;
            var n_allowed = allowed_item_widths.length;
            if (fixed_item_widths && n_allowed > 0) {
                var width = value.clamp (minimum_item_width, maximum_item_width);
                var index = 0;
                while (index < n_allowed && (new_width < minimum_item_width || new_width < width)) {
                    new_width = allowed_item_widths[index++];
                }

                item_width_index = index - 1;
                new_width = allowed_item_widths[item_width_index];
            } else {
                new_width = value.clamp (minimum_item_width, maximum_item_width);
            }

            _item_width = new_width;
        }
    }

    public int hpadding { get; set; }
    public int vpadding { get; set; }

    public signal void selection_changed ();
    public signal void item_clicked (Item item, Gdk.EventButton event);
    public signal void background_clicked (Gdk.EventButton event);

    construct {
        item_width_index = 3;

        event_box = new Gtk.EventBox ();
        event_box.set_above_child (true);

        layout = new Gtk.Layout ();
        layout.margin_start = 24; /* So that background always available */
        layout.can_focus = true;

        layout_handler = new LayoutHandler (layout, factory, model);

        bind_property ("item-width", layout_handler, "item-width", BindingFlags.DEFAULT);
        bind_property ("hpadding", layout_handler, "hpadding", BindingFlags.DEFAULT);
        bind_property ("vpadding", layout_handler, "vpadding", BindingFlags.DEFAULT);

        /* Need to assign after binding */
        hpadding = DEFAULT_HPADDING;
        vpadding = DEFAULT_VPADDING;

        var scrollbar = new Gtk.Scrollbar (Gtk.Orientation.VERTICAL, layout_handler.vadjustment);
        scrollbar.set_slider_size_fixed (true);
        scrollbar.halign = Gtk.Align.END;

        event_box.add (layout);
        add (event_box);
        add_overlay (scrollbar);

        size_allocate.connect (() => {
            layout_handler.configure ();
        });

        event_box.add_events (Gdk.EventMask.SCROLL_MASK |
                    Gdk.EventMask.SMOOTH_SCROLL_MASK |
                    Gdk.EventMask.BUTTON_PRESS_MASK |
                    Gdk.EventMask.BUTTON_RELEASE_MASK |
                    Gdk.EventMask.POINTER_MOTION_MASK
        );

        event_box.scroll_event.connect ((event) => {
            if ((event.state & Gdk.ModifierType.CONTROL_MASK) == 0) { /* Control key not pressed */
                return handle_scroll (event);
            } else {
                return handle_zoom (event);
            }
        });

        event_box.key_press_event.connect (on_key_press_event);

        event_box.button_press_event.connect ((event) => {


            var item = layout_handler.get_item_at_pos (get_corrected_event_position (event));
            var on_item = item != null;

            if (event.button == Gdk.BUTTON_PRIMARY &&
                layout_handler.can_rubber_band &&
                !on_item) {

                layout_handler.start_rubber_banding (event);
            } else if (on_item) {
                item_clicked (item, event);
            } else {
                background_clicked (event);
            }
        });

        event_box.button_release_event.connect ((event) => {
            layout_handler.end_rubber_banding ();
        });

        delete_event.connect (() => {
            layout_handler.close ();
            return false;
        });

        event_box.motion_notify_event.connect ((event) => {
            if ((event.state & Gdk.ModifierType.BUTTON1_MASK) > 0) {
                layout_handler.do_rubber_banding (event);
            }

            return false;
        });

        show_all ();
    }

    public View (AbstractItemFactory _factory, Model<WidgetData>? _model = null) {
        Object (factory: _factory,
                model: _model != null ? _model : new SimpleModel ()
        );
    }

    public void add_data (WidgetData data) {
        data.data_id = View.total_items_added;
        model.add (data);
        View.total_items_added++;
    }

    public void sort (CompareDataFunc? func) {
        model.sort (func);
        queue_draw ();
    }

    private bool on_key_press_event (Gdk.EventKey event) {
        var control_pressed = (event.state & Gdk.ModifierType.CONTROL_MASK) != 0;
        if (control_pressed) {
            switch (event.keyval) {
                case Gdk.Key.plus:
                case Gdk.Key.equal:
                    zoom_in ();
                    return true;

                case Gdk.Key.minus:
                    zoom_out ();
                    return true;

                default:
                    break;
            }
        } else {
            switch (event.keyval) {
                case Gdk.Key.Escape:
                    layout_handler.clear_selection ();
                    break;

                default:
                    break;
            }
        }

        return false;
    }

    private double total_delta_y = 0.0;
    private bool handle_scroll (Gdk.EventScroll event) {
        switch (event.direction) {
            case Gdk.ScrollDirection.SMOOTH:
                double delta_x, delta_y;
                event.get_scroll_deltas (out delta_x, out delta_y);
                /* try to emulate a normal scrolling event by summing deltas.
                 * step size of 0.5 chosen to match sensitivity */
                total_delta_y += delta_y;

                if (total_delta_y >= SCROLL_SENSITIVITY) {
                    total_delta_y = 0.0;
                    layout_handler.scroll_steps (1);
                } else if (total_delta_y <= -SCROLL_SENSITIVITY) {
                    total_delta_y = 0.0;
                    layout_handler.scroll_steps (-1);
                }

                return true;

            default:
                return false;
        }
    }

    private bool handle_zoom (Gdk.EventScroll event) {
       switch (event.direction) {
            case Gdk.ScrollDirection.UP:
                zoom_in ();
                return true;

            case Gdk.ScrollDirection.DOWN:
                zoom_out ();
                return true;

            case Gdk.ScrollDirection.SMOOTH:
                double delta_x, delta_y;
                event.get_scroll_deltas (out delta_x, out delta_y);
                /* try to emulate a normal scrolling event by summing deltas.
                 * step size of 0.5 chosen to match sensitivity */
                total_delta_y += delta_y;

                if (total_delta_y >= ZOOM_SENSITIVITY) {
                    total_delta_y = 0;
                    zoom_out ();
                } else if (total_delta_y <= -ZOOM_SENSITIVITY) {
                    total_delta_y = 0;
                    zoom_in ();
                }
                return true;

            default:
                return false;
        }
    }

    private void zoom_in () {
        if (fixed_item_widths) {
            if (item_width_index < allowed_item_widths.length - 1) {
                item_width = allowed_item_widths[++item_width_index];
            }
        } else {
            item_width += width_increment;
        }
    }

    private void zoom_out () {
        if (fixed_item_widths) {
            if (item_width_index >= 1) {
                item_width = allowed_item_widths[--item_width_index];
            }
        } else {
            item_width -= width_increment;
        }
    }

    private Gdk.Point get_corrected_event_position (Gdk.EventButton event) {
        var point = Gdk.Point ();
        point.x = (int)(event.x) - layout.margin_start;
        point.y = (int)(event.y);

        return point;
    }

    public override bool draw (Cairo.Context ctx) {
        base.draw (ctx);
        return layout_handler.draw_rubberband (ctx);
    }

    public WidgetData[] get_selected () {
        return layout_handler.selected_data.to_array ();
    }

    public int[] get_allowed_widths () {
        var allowed_widths = new int[allowed_item_widths.length];
        int index = 0;
        foreach (int i in allowed_item_widths) {
            allowed_widths[index] = i;
            index++;
        }

        return allowed_widths;
    }

    public void set_allowed_widths (int[] widths) {
        if (widths.length > 0) {

            /* Ensure allowed widths are unique and sorted in ascending order */
            var sorted_width_set = new Gee.TreeSet<int> ((a, b) => {
                    if (a == b) {
                        return 0;
                    } else if (a > b) {
                        return 1;
                    } else {
                        return -1;
                    }
                });

            foreach (int i in widths) {
                sorted_width_set.add (i.clamp (minimum_item_width, maximum_item_width));
            }

            allowed_item_widths = new int[sorted_width_set.size];

            int index = 0;
            foreach (int i in sorted_width_set) {
                allowed_item_widths[index] = i;
                index++;
            }

            item_width = item_width - 1;
        }
    }
}
}
