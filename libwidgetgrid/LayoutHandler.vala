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

/*** WidgetGrid.LayoutHandler handles direct manipulation of the layout.
     Functions for positioning items in the layout and identifying items from a position are contained in
     the PositionHandler interface.
     Functions for selecting items by rubberbanding and storing the selection are contained in
     the SelectionHandler interface
***/
namespace WidgetGrid {
public class LayoutHandler : Object, PositionHandler, SelectionHandler {
    private const int REFLOW_DELAY_MSEC = 100;
    private const int MAX_WIDGETS = 1000;

    private int pool_size = 0;
    private int previous_first_displayed_data_index = 0;
    private int previous_first_displayed_row_height = 0;
    private int n_widgets = 0;

    private int total_rows = 0;
    private int first_displayed_widget_index = 0;
    private int highest_displayed_widget_index = 0;
    public int first_displayed_data_index { get; private set; default = 0; }
    public int last_displayed_data_index { get; private set; default = 0; }

    public Gtk.Adjustment vadjustment { get; construct; }
    public AbstractItemFactory factory { get; construct; }
    public Gtk.Layout layout { get; construct; }

    /* PositionHandler properties */
    public int vpadding { get; set; }
    public int hpadding { get; set; }
    public int item_width { get; set; }
    public int cols { get; protected set; }
    public int n_items { get; private set; default = 0; }

    public WidgetGrid.Model<WidgetData> model { get; construct; }
    public Gee.AbstractList<Item> widget_pool { get; construct; }
    public Gee.AbstractList<RowData> row_data { get; set; }

    /* SelectionHandler interface properties */
    public SelectionFrame frame { get; construct; }
    public Gee.TreeSet<WidgetData> selected_data { get; construct; }
    public bool rubber_banding { get; set; default = false; }
    public bool can_rubber_band { get; set; default = true; }
    public bool deselect_before_rubber_band { get; set; default = true; }

    construct {
        widget_pool = new Gee.ArrayList<Item> ();
        selected_data = new Gee.TreeSet<WidgetData> ((CompareDataFunc?)(WidgetData.compare_data_func));

        row_data = new Gee.ArrayList<RowData> ();
        vadjustment = new Gtk.Adjustment (0.0, 0.0, 10.0, 1.0, 1.0, 1.0);
        frame = new SelectionFrameRectangle ();

        vadjustment.value_changed.connect (on_adjustment_value_changed);

        model.n_items_changed.connect ((change) => {
            n_items += change;
            if (change > 0 && n_widgets < MAX_WIDGETS) {
                widget_pool.add (factory.new_item ());
                n_widgets++;
            }

            configure ();
        });

        notify["hpadding"].connect (() => {
            configure ();
        });

        notify["vpadding"].connect (() => {
            configure ();
        });

        notify["item-width"].connect (() => {
            configure ();
        });
    }

    public LayoutHandler (Gtk.Layout _layout, AbstractItemFactory _factory, WidgetGrid.Model _model) {
        Object (
            layout: _layout,
            factory: _factory,
            model: _model
        );
    }

    public void show_data_index (int index, bool use_align, float yalign) { /* Only align rows */
        return_if_fail (cols > 0);

        var row_containing_index = index / cols;
        var n_displayed_items_approx = last_displayed_data_index - first_displayed_data_index + 1;
        var n_rows_displayed_approx = n_displayed_items_approx / cols + 1;
        var rows_to_offset = (int)((double)n_rows_displayed_approx * (double)yalign);
        var first_row = row_containing_index - rows_to_offset;

        vadjustment.set_value ((double)first_row);
    }

    protected void position_items (int first_displayed_row, double offset) {
        int data_index, widget_index, row_height;

        data_index = first_displayed_row * cols;

        if (n_items == 0 || data_index >= n_items) {
            return;
        } else if (data_index < 0) {
            data_index = 0;
            offset = 0;
        }

        if (previous_first_displayed_data_index != data_index) {
            clear_layout ();
            previous_first_displayed_data_index = data_index;
            first_displayed_widget_index = data_index % (highest_displayed_widget_index + 1);
        }

        first_displayed_data_index = data_index;
        last_displayed_data_index = data_index;
        row_height = get_row_height (first_displayed_widget_index, data_index);
        previous_first_displayed_row_height = row_height;
        widget_index = first_displayed_widget_index;

        int y = vpadding - (int)offset;
        int r;
        for (r = 0; y < layout.get_allocated_height () + offset && data_index < n_items; r++) {
            if (r > row_data.size - 1) {
                row_data.add (new RowData ());
            }

            row_data[r].update (data_index, widget_index, y, row_height);

            int x = hpadding;
            for (int c = 0; c < cols && data_index < n_items; c++) {
                var item = widget_pool[widget_index];

                if (item.get_parent () != null) {
                    layout.move (item, x, y);
                } else {
                    layout.put (item, x, y);
                }

                item.set_size_request (item_width, row_height - 2 * vpadding);

                x += item_width + hpadding;

                last_displayed_data_index = data_index;
                highest_displayed_widget_index = int.max (highest_displayed_widget_index, widget_index);
                widget_index = next_widget_index (widget_index);
                data_index++;
            }

            y += row_height + vpadding;
            row_height = get_row_height (widget_index, data_index);
        }

        if (r > row_data.size - 1) {
            row_data.add (new RowData ());
        } else {
            row_data[r].update (int.MAX, int.MAX, int.MAX, int.MAX);
        }

        var items_displayed = last_displayed_data_index - first_displayed_data_index + 1;
        pool_size = int.max (pool_size, items_displayed + 2 * cols - items_displayed % cols);
        pool_size = pool_size.clamp (0, n_widgets - 1);

        layout.queue_draw ();
    }

    /* Reflow at most 1000 / REFLOW_DELAY_MSEC times a second */
    private uint reflow_timeout_id = 0;
    public void configure () {
        if (reflow_timeout_id > 0) {
            return;
        } else {
            reflow_timeout_id = Timeout.add (REFLOW_DELAY_MSEC, () => {
                reflow ();
                reflow_timeout_id = 0;
                return Source.REMOVE;
            });
        }
    }

    private void reflow (Gtk.Allocation? alloc = null) {
        if (column_width == 0) {
            return;
        }

        cols = (layout.get_allocated_width ()) / column_width;

        if (cols == 0) {
            return;
        }

        var first_displayed_row = previous_first_displayed_data_index / cols;
        var val = first_displayed_row;

        var min_val = 0.0;
        var max_val = (double)(total_rows + 1);
        var step_increment = 0.05;
        var page_increment = 1.0;
        var page_size = 5.0;

        var new_total_rows = (n_items) / cols + 1;
        if (total_rows != new_total_rows) {
            clear_layout ();
            total_rows = new_total_rows;
            highest_displayed_widget_index = 0;
            pool_size = 0;
            max_val = (double)(total_rows + 1);
            vadjustment.configure (val, min_val, max_val, step_increment, page_increment, page_size);
        }

        on_adjustment_value_changed ();
    }

    /* This implements an accelerating scroll rate during a continuous smooth scroll with touchpad
     * so that small movements have low sensitivity but can also make large movements easily.
     * TODO: implement kinetic scrolling.
     */
    uint32 last_event_time = 0;
    double accel = 0.0;
    uint scroll_accel_timeout_id = 0;
    bool wait = false;
    private const double MAX_ACCEL = 128.0;
    private const double ACCEL_RATE = 1.3;
    private const int SCROLL_ACCEL_DELAY_MSEC = 100;
    double previous_adjustment_val;
    private void on_adjustment_value_changed () {
        var now = Gtk.get_current_event_time ();
        uint32 rate = now - last_event_time;  /* min about 24, typical 50 - 150 */
        last_event_time = now;

        /* Increase acceleration factor if multiple events received with in SCROLL_ACCEL_DELAY_MSEC */
        if (rate > 300) {
            accel = 1.0;
        } else {
            accel += (ACCEL_RATE / 300 * (300 - rate));
        }

        if (scroll_accel_timeout_id > 0) {
            wait = true;
        } else {
            wait = false;
            scroll_accel_timeout_id = Timeout.add (SCROLL_ACCEL_DELAY_MSEC, () => {
                if (wait) {
                    wait = false;
                    accel /= ACCEL_RATE;
                    return Source.CONTINUE;
                } else {
                    scroll_accel_timeout_id = 0;
                    accel = 1.0;
                    return Source.REMOVE;
                }
            });
        }

        /* Prepare to reposition widgets according to new adjustment value (which is in row units) */
        var new_val = vadjustment.get_value ();
        var first_displayed_row = (int)(new_val);
        double offset = 0.0;
        var row_fraction = new_val - (double)first_displayed_row;

        /* Calculate fraction of first row hidden */
        if (new_val < previous_adjustment_val) { /* Scroll up */
            var first_displayed_data_index = first_displayed_row * cols;
            var row_height = get_row_height (first_displayed_widget_index, first_displayed_data_index);
            offset = row_fraction * row_height;

        } else {
            offset = row_fraction * previous_first_displayed_row_height;
        }

        /* Reposition items when idle */
        Idle.add (() => {
            position_items (first_displayed_row, offset);
            return false;
        });

        previous_adjustment_val = new_val;
    }

    public void scroll_steps (int steps) {
        vadjustment.set_value (vadjustment.get_value () + vadjustment.get_step_increment () * steps * accel);
    }

    private void clear_layout () {
        Value val = {};
        val.init (typeof (int));
        /* Removing is slow so first move out of window if current displayed else remove */
        int removed = 0;
        int moved = 0;
        foreach (unowned Gtk.Widget w in layout.get_children ()) {
            layout.child_get_property (w, "x", ref val);
            if (val.get_int () < -500) {
                layout.remove (w);
                removed++;
            } else {
                layout.move (w, -1000, -1000);
                moved++;
            }
        }
    }

    public void close () {
        if (scroll_accel_timeout_id > 0) {
            Source.remove (scroll_accel_timeout_id);
        }

        if (reflow_timeout_id > 0) {
            Source.remove (reflow_timeout_id);
        }
    }

    private void update_item_with_data (Item item, WidgetData data) {
        if (item.data_id != data.data_id) {
            item.update_item (data);
        }

        item.set_max_width (item_width);
    }


    private int next_widget_index (int widget_index) {
        widget_index++;

        if (widget_index > (pool_size > 0 ? pool_size : n_widgets - 1)) {
            widget_index = 0;
        }

        return widget_index;
    }

    protected Gtk.Widget get_widget () {
        return layout;
    }
}
}
