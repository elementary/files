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

public interface ViewInterface : Gtk.Widget {
    public abstract Model<DataInterface> model {get; set construct; }

    public abstract int minimum_item_width { get; set; }
    public abstract int maximum_item_width { get; set; }
    public abstract int item_width_index { get; set; }
    public abstract int width_increment { get; set; }
    public abstract bool fixed_item_widths { get; set; }
    public abstract int item_width { get; set; }
    public abstract int hpadding { get; set; }
    public abstract int vpadding { get; set; }
    public abstract bool handle_cursor_keys { get; set; default = true; }
    public abstract bool handle_zoom { get; set; default = true; }
    public abstract bool handle_events_first { get; set; }

    public abstract bool get_visible_range_indices (out int first, out int last);
    public abstract void select_index (int index);
    public abstract void unselect_index (int index);
    public abstract void clear_selection ();

    public abstract void refresh_layout ();

    public signal void selection_changed ();
    public signal void item_clicked (Item item, Gdk.EventButton event);
    public signal void background_clicked (Gdk.EventButton event);
    public signal void adjustment_value_changed (double val);
}

public class View : Gtk.Overlay, ViewInterface {
    private const int DEFAULT_HPADDING = 12;
    private const int DEFAULT_VPADDING = 24;

    private const double SCROLL_SENSITIVITY = 0.5; /* The scroll delta required to move the grid position by one step */
    private const double ZOOM_SENSITIVITY = 1.0; /* The scroll delta required to change the item width by one step */

    private Gtk.Layout layout;
    private Gtk.EventBox event_box;
    private Gtk.Scrollbar scrollbar;

    private Item? hovered_item = null;
    private Gdk.Point wp; /* Item relative pointer position */

    public int minimum_item_width { get; set; default = 32; }
    public int maximum_item_width { get; set; default = 512; }

    private int _item_width_index = 3;
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

    public Model<DataInterface> model {get; set construct; }
    public AbstractItemFactory factory { get; construct; }
    public LayoutHandler layout_handler {protected get; set construct; }

    private int[] allowed_item_widths = {16, 24, 32, 48, 64, 96, 128, 256, 512};
    public int width_increment { get; set; default = 6; }
    public bool fixed_item_widths { get; set; default = true;}
    public bool handle_cursor_keys { get; set; default = true; }
    public bool handle_zoom { get; set; default = true; }
    public bool handle_events_first {
        get {
            return event_box.above_child;
        }

        set {
            event_box.above_child = value;
            scrollbar.visible = value;
        }
    }

    public int item_width {
        get {
            return layout_handler.item_width;
        }

        set {
            if (value == layout_handler.item_width) {
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

            layout_handler.item_width = new_width;
        }
    }

    public int hpadding {
        get {
            return layout_handler.hpadding;
        }

        set {
            layout_handler.hpadding = value;
        }
    }

    public int vpadding {
        get {
            return layout_handler.vpadding;
        }

        set {
            layout_handler.vpadding = value;
        }
    }

    construct {
        wp = {0, 0};

        layout = new Gtk.Layout ();
        layout.margin_start = 24; /* So that background always available */
        layout.can_focus = true;

        layout_handler = new LayoutHandler (layout, factory, model);

        event_box = new Gtk.EventBox ();
        event_box.set_above_child (true);

        /* Need to assign after binding */
        hpadding = DEFAULT_HPADDING;
        vpadding = DEFAULT_VPADDING;

        scrollbar = new Gtk.Scrollbar (Gtk.Orientation.VERTICAL, layout_handler.vadjustment);
        scrollbar.set_slider_size_fixed (true);
        scrollbar.halign = Gtk.Align.END;

        event_box.add (layout);
        add (event_box);
        add_overlay (scrollbar);

        event_box.add_events (
            Gdk.EventMask.SCROLL_MASK |
            Gdk.EventMask.SMOOTH_SCROLL_MASK |
            Gdk.EventMask.BUTTON_PRESS_MASK |
            Gdk.EventMask.BUTTON_RELEASE_MASK |
            Gdk.EventMask.POINTER_MOTION_MASK
        );

        add_events (Gdk.EventMask.SCROLL_MASK);

        event_box.scroll_event.connect ((event) => {
            if (handle_events_first) {
                if ((event.state & Gdk.ModifierType.CONTROL_MASK) == 0) { /* Control key not pressed */
                    return handle_scroll (event);
                } else if (handle_zoom) {
                    return handle_zoom_event (event);
                }
            } else {
                return true;
            }
        });

        event_box.key_press_event.connect (on_key_press_event);

        event_box.button_press_event.connect ((event) => {
            layout.grab_focus ();
            var on_item = hovered_item != null;

            if (event.button == Gdk.BUTTON_PRIMARY &&
                layout_handler.can_rubber_band &&
                !on_item) {

                layout_handler.start_rubber_banding (event);
            } else if (on_item) {
                Gdk.EventButton w_event = (Gdk.EventButton)(event.copy ());
                w_event.x = (double)wp.x;
                w_event.y = (double)wp.y;
                item_clicked (hovered_item, w_event); /* Goes to any controller with clicked relative widget coords */
            } else {
                background_clicked (event);
            }

            return false;
        });

        event_box.button_release_event.connect ((event) => {
            layout_handler.end_rubber_banding ();
            return false;
        });

        event_box.motion_notify_event.connect ((event) => {
            if (!handle_events_first) {
                return false;
            }

            var cp = get_corrected_position ((int)(event.x), (int)(event.y));
            var item = layout_handler.get_item_at_pos (cp, out wp);
            var on_item = item != null;
            if ((!on_item || layout_handler.rubber_banding) && (event.state & Gdk.ModifierType.BUTTON1_MASK) > 0) {
                layout_handler.do_rubber_banding (event);
            } else {
                if (item != hovered_item) {
                    int index = layout_handler.get_index_at_pos (cp);
                    if (hovered_item != null) {
                        hovered_item.leave ();
                    }

                    if (on_item) {
                        item.enter ();
                    }

                    hovered_item = item;
                }

                if (hovered_item != null) {
                    var w_event = (Gdk.EventMotion)(event.copy ());
                    w_event.x = (double)wp.x;
                    w_event.y = (double)wp.y;
                    hovered_item.hovered (w_event);
                }
            }

            return false;
        });

        layout_handler.selection_changed.connect (() => {
            selection_changed ();
        });

        layout_handler.cursor_moved.connect ((prev, current) => {
            var prev_item = layout_handler.get_item_for_data_index (prev);
            if (prev_item != null) {
                prev_item.leave ();
            }

            var current_item = layout_handler.get_item_for_data_index (current);
            if (current_item != null) {
                current_item.enter ();
            }
        });

        layout_handler.vadjustment.value_changed.connect ((adj) => {
            adjustment_value_changed (adj.get_value ());
        });

        show_all ();
    }

    public View (AbstractItemFactory _factory, Model? _model = null) {
        Object (factory: _factory,
                model: _model != null ? _model : new SimpleModel ()
        );
    }

    public void sort (CompareDataFunc? func) {
        model.sort (func);
        layout_handler.cursor_invalidated ();
        queue_draw ();
    }

    private bool on_key_press_event (Gdk.EventKey event) {
        if (!handle_events_first) {
            return false;
        }

        var control_pressed = (event.state & Gdk.ModifierType.CONTROL_MASK) != 0;
        var shift_pressed = (event.state & Gdk.ModifierType.SHIFT_MASK) != 0;

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
        }

        switch (event.keyval) {
            case Gdk.Key.Escape:
                layout_handler.clear_selection ();
                break;

            case Gdk.Key.Up:
            case Gdk.Key.Down:
            case Gdk.Key.Left:
            case Gdk.Key.Right:
                if (handle_cursor_keys) {
                    bool linear_select = shift_pressed && !control_pressed;
                    bool deselect = !control_pressed;
                    layout_handler.move_cursor (event.keyval, linear_select, deselect);
                    return true;
                }

                break;

            default:
                break;
        }

        return false;
    }

    public bool get_visible_range_indices (out int first, out int last) {
        first = layout_handler.first_displayed_data_index;
        last = layout_handler.last_displayed_data_index;

        return first >= 0 && last >= 0;
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

                break;
            default:
                break;
        }

        return true;
    }

    public virtual bool handle_zoom_event (Gdk.EventScroll event) {
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

        item_width.clamp (minimum_item_width, maximum_item_width);
    }

    private void zoom_out () {
        if (fixed_item_widths) {
            if (item_width_index >= 1) {
                item_width = allowed_item_widths[--item_width_index];
            }
        } else {
            item_width -= width_increment;
        }

        item_width.clamp (minimum_item_width, maximum_item_width);
    }

    private Gdk.Point get_corrected_p (Gdk.Point p) {
        return get_corrected_position (p.x, p.y);
    }

    public Gdk.Point get_corrected_position (int x, int y) {
        var point = Gdk.Point ();
        point.x = x - layout.margin_start;
        point.y = y - layout.margin_top;

        return point;
    }

    public override bool draw (Cairo.Context ctx) {
        base.draw (ctx);
        return layout_handler.draw_rubberband (ctx);
    }

    public DataInterface[] get_selected () {
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

    public void select_all () {
        layout_handler.select_all_data ();
    }

    public void unselect_all () {
        layout_handler.clear_selection ();
    }

    public Item? get_item_at_coords (int x, int y, out Gdk.Point item_p) {
        item_p = {0, 0};
        var cp = get_corrected_p ({x, y});
        var item = layout_handler.get_item_at_pos (cp, out item_p);

        return item;
    }

    public Item? get_item_at_pos (Gdk.Point p, out Gdk.Point corrected_p) {
        Gdk.Point cp = {0, 0};
        var item = layout_handler.get_item_at_pos (get_corrected_p (p), out cp);
        corrected_p = cp;

        return item;
    }

    public int get_index_at_pos (Gdk.Point p) {
        return layout_handler.get_index_at_pos (get_corrected_p (p));
    }

    public int get_index_at_coords (int x, int y) {
        return get_index_at_pos ({x, y});
    }

    public DataInterface get_data_at_pos (Gdk.Point p) {
        return layout_handler.get_data_at_pos (get_corrected_p (p));
    }

    public DataInterface get_data_coords (int x, int y) {
        Gdk.Point p = {x, y};
        return get_data_at_pos (get_corrected_p (p));
    }

    public int get_n_columns () {
        return layout_handler.cols;
    }

    public new bool has_focus {
        get {
            return layout.has_focus;
        }
    }

    public int index_below (int index) {
        return layout_handler.index_below (index);
    }

    public int index_above (int index) {
        return layout_handler.index_above (index);
    }

    public void select_index (int index) {
        layout_handler.select_data_index (index);
    }

    public void unselect_index (int index) {
        layout_handler.unselect_data_index (index);
    }

    public int index_at_cursor () {
        return layout_handler.get_index_at_cursor ();
    }

    public void set_cursor_index (int index, bool select = false) {
        layout_handler.set_cursor (index);

        if (select) {
            layout_handler.select_data_index (index);
        }
    }

    public void linear_select_index (int index) {
        layout_handler.linear_select_index (index);
    }

    public new void grab_focus () {
        layout.grab_focus ();
    }

    public void move_cursor (uint keyval, bool linear_select, bool deselect) {
        layout_handler.move_cursor (keyval, linear_select, deselect);
    }

    public new void freeze_child_notify () {
        if (!layout_handler.ignore_model_changes) {
            layout_handler.ignore_model_changes = true;
        }
    }

    public new void thaw_child_notify () {
        if (layout_handler.ignore_model_changes) {
            layout_handler.ignore_model_changes = false;
            layout_handler.update_from_model ();
        }
    }

    public void clear_selection () {
        layout_handler.clear_selection ();
    }

    public void refresh_layout () {
        layout_handler.refresh ();
    }

    public unowned Gee.TreeSet<DataInterface> get_selected_data () {
        return layout_handler.selected_data;
    }

    public int get_index_for_data (DataInterface data) {
        return model.lookup_data (data);
    }

    public Item? get_item_for_data_index (int index) {
        return layout_handler.get_item_for_data_index (index);

    }

    public void initialize_layout () {
        layout_handler.initialize_layout_data ();
    }
}
}
