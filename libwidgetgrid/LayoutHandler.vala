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
public class LayoutHandler : Object, PositionHandler, SelectionHandler, CursorHandler {
    private const int REFLOW_DELAY_MSEC = 100;
    private const int REFRESH_DELAY_MSEC = 100;
    private const int MAX_WIDGETS = 1000;

    private int n_widgets = 0;

    private int pool_size = 0;
    private int previous_first_displayed_data_index = -1;
    private int previous_first_displayed_row_height = -1;
    private int total_rows = 0;
    public int first_displayed_widget_index { get; set; default = 0;}
    public int last_displayed_widget_index { get; set; default = 0;}


    private uint32 last_event_time = 0;
    private double accel = 0.0;
    private uint scroll_accel_timeout_id = 0;
    private bool wait = false;
    private const double MAX_ACCEL = 128.0;
    private const double ACCEL_RATE = 1.3;
    private const int SCROLL_ACCEL_DELAY_MSEC = 100;
    private double previous_adjustment_val;

    private uint reflow_timeout_id = 0;

    public int first_displayed_data_index { get; private set; default = -1; }
    public int last_displayed_data_index { get; private set; default = -1; }

    public Gtk.Adjustment vadjustment { get; construct; }
    public AbstractItemFactory factory { get; construct; }
    public Gtk.Layout layout { get; construct; }

    /* PositionHandler properties */
    public int vpadding { get; set; }
    public int hpadding { get; set; }
    public int item_width { get; set; }
    public int cols { get; protected set; }
    public int n_items { get; protected set; default = 0; }
    public DataInterface data_at_cursor { get; set; }
    public int cursor_index { get; set; default = -1;}

    public WidgetGrid.Model<DataInterface> model { get; construct; }
    public Gee.ArrayList<Item> widget_pool { get; construct; }
    public Gee.ArrayList<RowData> row_data { get; set; }

    /* SelectionHandler interface properties */
    public SelectionFrame frame { get; construct; }
    public Gee.TreeSet<DataInterface> selected_data { get; set; }
    public bool rubber_banding { get; set; default = false; }
    public bool can_rubber_band { get; set; default = true; }
    public bool deselect_before_rubber_band { get; set; default = true; }
    public int initial_linear_selection_index {get; set; default = -1; }
    public int previous_linear_selection_index {get; set; default = -1; }
    public int last_selected_index {get; set; default = -1;}
    public int first_displayed_row {get; set; default = 0;}
    public double display_offset {get; set; default = 0.0;}

    public bool ignore_model_changes { get; set; default = false;}

    construct {
        widget_pool = new Gee.ArrayList<Item> ();
        selected_data = new Gee.TreeSet<DataInterface> ((CompareDataFunc?)(DataInterface.compare_data_func));
        row_data = new Gee.ArrayList<RowData> ();
        vadjustment = new Gtk.Adjustment (0.0, 0.0, 10.0, 1.0, 1.0, 1.0);
        frame = new SelectionFrameRectangle ();

        initialize_layout_data ();

        vadjustment.value_changed.connect (() => {
            on_adjustment_value_changed (false);
        });

        model.n_items_changed.connect ((change) => {
            if (!ignore_model_changes) {
                n_items = model.get_n_items ();
                if (change > 0 && n_widgets < MAX_WIDGETS) {
                    widget_pool.add (factory.new_item ());
                    n_widgets++;
                    pool_size = 0;
                }

                if (change < 0) {
                    clear_layout (); /* Ensure deleted items are not displayed */
                }

                configure ();
            }
        });

        model.data_removed.connect ((data) => {
            if (!ignore_model_changes && data.is_selected) {
                selected_data.remove (data);
            }
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

        notify["cursor-index"].connect (() => {
            refresh ();
        });

        selection_changed.connect (() => {
            refresh ();
        });
    }

    public LayoutHandler (Gtk.Layout _layout, AbstractItemFactory _factory, WidgetGrid.Model<DataInterface> _model) {
        Object (
            layout: _layout,
            factory: _factory,
            model: _model
        );
    }

    public void show_data_index (int index, bool use_align = false, float yalign = 0.5f) { /* Only align rows */
        if (cols <= 0) {
            return;
        }

        var idx = index.clamp (0, n_items);
        var row_containing_index = idx / cols + 1;
        var n_displayed_items_approx = last_displayed_data_index - first_displayed_data_index + 1;
        var n_rows_displayed_approx = n_displayed_items_approx / cols + 1;
        var rows_to_offset = (int)((double)n_rows_displayed_approx * (double)yalign) + 1;
        var first_displayed_row = row_containing_index - rows_to_offset;
        if ((int)(vadjustment.get_value ()) != first_displayed_row) {
            vadjustment.set_value ((double)first_displayed_row);
        }

        /* Must set this now */
        previous_first_displayed_data_index = first_displayed_row * cols;
    }

    public void apply_to_visible_items (WidgetFunc func) {
        Item item;
        int index = first_displayed_widget_index;

        if (index >= 0 && !widget_pool.is_empty) {
            do {
                item = widget_pool[index];
                if (item != null && item.data_id != -1) {
                    func (item);
                }

                if (index == last_displayed_widget_index) {
                    break;
                } else {
                    index = next_widget_index (index);
                }

            } while (true);
        }
    }

    public void refresh () {
        if (ignore_model_changes) {
            return;
        }

        apply_to_visible_items ((item) => {
            item.update_item ();
        });

        position_items ();
    }

    protected void position_items () {
        int data_index, widget_index, row_height;
        if (n_items == 0 || cols == 0) {
            return;
        }

        data_index = first_displayed_row * cols;
        return_if_fail (data_index < n_items && data_index >= 0);

        if (pool_size == 0) {
            pool_size = n_widgets - 1;
        }

        if (previous_first_displayed_data_index >= 0) {
            if (previous_first_displayed_data_index != data_index) {
                clear_layout ();
                first_displayed_widget_index = 0;
            }
        }

        previous_first_displayed_data_index = data_index;

        first_displayed_data_index = data_index;
        last_displayed_data_index = data_index;

        /* This puts data in widgets */
        row_height = get_row_height (first_displayed_widget_index, data_index);

        previous_first_displayed_row_height = row_height;
        widget_index = first_displayed_widget_index;

        int y = vpadding - (int)display_offset;
        int r;
        for (r = 0; y < layout.get_allocated_height () + display_offset && data_index < n_items; r++) {
            if (r > row_data.size - 1) {
                row_data.add (new RowData ());
            }

            row_data[r].update (data_index, widget_index, y, row_height);

            int x = hpadding;
            for (int c = 0; c < cols && data_index < n_items && row_height > 2 * vpadding; c++) {
                var item = widget_pool[widget_index];
                item.set_size_request (item_width, row_height - 2 * vpadding);

                if (item.get_parent () != null) {
                    layout.move (item, x, y);
                } else {
                    layout.put (item, x, y);
                }

                x += item_width + hpadding;

                last_displayed_data_index = data_index;

                last_displayed_widget_index = widget_index;
                widget_index = next_widget_index (widget_index);
                data_index++;
            }

            y += row_height + vpadding;
            row_height = get_row_height (widget_index, data_index);
        }

        if (r > row_data.size - 1) {
            assert (r == row_data.size);
            row_data.add (new RowData ());
        } else {
            row_data[r].update (int.MAX, int.MAX, int.MAX, int.MAX);
        }

        last_displayed_data_index = data_index - 1;
        var items_displayed = last_displayed_data_index - first_displayed_data_index + 1;
        pool_size = (items_displayed + 2 * cols - items_displayed % cols).clamp (0, n_widgets - 1);
        layout.queue_draw ();
    }

    public void configure () {
        if (column_width > 0) {
            cols = (layout.get_allocated_width ()) / column_width;
            if (cols > 0) {
                if (cursor_index < 0) {
                   initialize_cursor ();
                }

                var first_displayed_row = previous_first_displayed_data_index / cols;
                var val = first_displayed_row;

                var min_val = 0.0;
                var max_val = (double)(total_rows + 2);
                var step_increment = 0.05;
                var page_increment = 1.0;
                var page_size = 5.0;

                var new_total_rows = n_items / cols + 2;
                if (total_rows != new_total_rows) {
                    clear_layout ();
                    total_rows = new_total_rows;
                    last_displayed_widget_index = 0;
                    pool_size = 0;
                    max_val = (double)(total_rows + 2); /* Ensure bottom row fully exposed */
                    vadjustment.configure (val, min_val, max_val, step_increment, page_increment, page_size);
                }

                on_adjustment_value_changed (true);
                Idle.add (() => {refresh (); return Source.REMOVE;});
            }
        }
    }

    /* This implements an accelerating scroll rate during a continuous smooth scroll with touchpad
     * so that small movements have low sensitivity but can also make large movements easily.
     * TODO: implement kinetic scrolling.
     * If @force is true, then items are positioned immediately.
     */
    private void on_adjustment_value_changed (bool force = false) {
        var now = Gtk.get_current_event_time ();
        uint32 rate = now - last_event_time;  /* min about 24, typical 50 - 150 */
        last_event_time = now;

        /* Increase acceleration factor if multiple events received with in SCROLL_ACCEL_DELAY_MSEC */
        if (rate > 300) {
            accel = 1.0;
        } else {
            accel += (ACCEL_RATE / 300 * (300 - rate));
        }

        if (scroll_accel_timeout_id > 0 || force) {
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
        first_displayed_row = (int)(new_val);

        var row_fraction = new_val - (double)first_displayed_row;

        /* Calculate fraction of first row hidden */
        if (new_val < previous_adjustment_val) { /* Scroll up */
            var first_displayed_data_index = first_displayed_row * cols;
            var row_height = get_row_height (first_displayed_widget_index, first_displayed_data_index);
            display_offset = row_fraction * row_height;

        } else {
            display_offset = row_fraction * previous_first_displayed_row_height;
        }

        position_items ();
        Idle.add (() => {
            if (rubber_banding) {
                mark_selected_in_rectangle (false);
            }
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

            ((Item)w).data = null;
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

    public Item? get_item_for_data_index (int data_index) {
        if (data_index < 0 || row_data.is_empty) {
            return null;
        }

        var offset = data_index - row_data[0].first_data_index;
        if (offset < 0 || offset > (last_displayed_data_index - first_displayed_data_index)) {
            return null;
        } else {
            var widget_index = first_displayed_widget_index + offset;
            if (widget_index >= pool_size) {
                widget_index -= pool_size;
            }

            return widget_pool[widget_index];
        }
    }

    public void update_from_model () {
        var new_n_items = model.get_n_items ();

        if (new_n_items != n_items) {
            if (n_widgets < new_n_items && n_widgets < MAX_WIDGETS) {
                var count = new_n_items - n_widgets;
                for (int i = 0; i < count; i++) {
                    if (i > MAX_WIDGETS) {
                        break;
                    }

                    widget_pool.add (factory.new_item ());
                    n_widgets++;
                }
            }
        }

        clear_selection ();
        n_items = new_n_items;
    }

    public void initialize_layout_data () {
        first_displayed_data_index = 0;
        first_displayed_widget_index = 0;
        previous_first_displayed_data_index = -1;
        previous_first_displayed_row_height = -1;
        last_selected_index = -1;
        pool_size = 0;

        row_data = new Gee.ArrayList<RowData> ();
        total_rows = 0;

        clear_layout ();
    }

    public void queue_draw () {
        layout.queue_draw ();
    }
}
}
