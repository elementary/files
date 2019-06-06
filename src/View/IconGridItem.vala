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

/*** WidgetGrid.Item interface defines the characteristics needed by a widget to be used
     for display by WidgetGrid.View and generated by a WidgetGrid.ItemFactory.
***/
namespace FM {
public class IconGridItem : Gtk.EventBox, WidgetGrid.Item {
    private static uint64 get_new_id () {
        return get_monotonic_time ();
    }

    private static int _max_height;
    public static int max_height { get { return _max_height; } set { _max_height = value; } default = 256;}
    private static int _min_height;
    public static int min_height { get { return _min_height; } set { _min_height = value; } default = 16;}

    private const Gtk.IconSize default_helper_size = Gtk.IconSize.SMALL_TOOLBAR;
    private const Gtk.IconSize focused_helper_size = Gtk.IconSize.LARGE_TOOLBAR;

    static construct {
        WidgetGrid.Item.min_height = 16;
        WidgetGrid.Item.max_height = 256;
    }

    private Gtk.Grid grid;
    private Gtk.Overlay overlay;
/*    private Gtk.Frame frame; */
    private Gtk.Box frame;
    private Gtk.Image icon;
    private Gtk.Image helper;
    private Gdk.Rectangle helper_allocation;
    private Gtk.Label label;
/*    private Gtk.Label id_label; */
    private int set_max_width_request = 0;
    private int pix_size = 0;
    private int total_padding;
    private Gtk.CssProvider provider;

    public WidgetGrid.DataInterface data { get; set; default = null; }
    public bool is_hovered { get; set; default = false; }
    private bool renaming = false;
    private int renaming_index = -1;

    public string item_name {
        get {
            return file != null ? file.get_display_name () : "";
        }
    }

    public bool is_selected { get {return data != null ? data.is_selected : false;} }
    public bool is_cursor_position { get {return data != null ? data.is_cursor_position : false;} }
    public uint64 data_id { get {return data != null ? data.data_id : -1;} }
    public uint64 widget_id { get; construct; }
    public GOF.File? file { get { return data != null ? (GOF.File)data : null; } }

    public signal void edited (int data_index, string new_name);
    public signal void editing_canceled ();

    construct {
        provider =  new Gtk.CssProvider ();
        above_child = false;
        hexpand = false;
        widget_id = IconGridItem.get_new_id ();
        overlay = new Gtk.Overlay ();
/*        frame = new Gtk.Frame (null); */
        frame = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
/*        frame.shadow_type = Gtk.ShadowType.NONE; */
        frame.halign = Gtk.Align.CENTER;
        frame.show_all ();

        grid = new Gtk.Grid ();
        grid.margin = 3;
        grid.orientation = Gtk.Orientation.VERTICAL;
        grid.halign = Gtk.Align.CENTER;
        grid.valign = Gtk.Align.CENTER;

        icon = new Gtk.Image.from_pixbuf (null);
        icon.margin_top = icon.margin_bottom = 6;
        icon.margin_start = icon.margin_end = 3;
        icon.halign = Gtk.Align.CENTER;

        label = new Gtk.Label (item_name);
        label.halign = Gtk.Align.CENTER;
        label.vexpand = true;
        label.margin_top = label.margin_bottom = 6;
        label.set_line_wrap (true);
        label.set_line_wrap_mode (Pango.WrapMode.WORD_CHAR);
        label.set_ellipsize (Pango.EllipsizeMode.END);
        label.set_lines (5);
        label.set_justify (Gtk.Justification.CENTER);
        label.get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

/*        id_label = new Gtk.Label (widget_id.to_string ()); */

        helper = new Gtk.Image ();
        helper.margin = 0;
        helper.set_from_icon_name ("selection-add", Gtk.IconSize.LARGE_TOOLBAR);
        helper.halign = Gtk.Align.START;
        helper.valign = Gtk.Align.START;
        helper.show_all ();

        grid.add (icon);
        grid.add (label);
/*        grid.add (id_label); */

        overlay.add (grid);
        overlay.add_overlay (helper);

        frame.add (overlay);

        add (frame);

        overlay.get_child_position.connect (on_get_child_position);

        total_padding += margin_start;
        total_padding += frame.margin_start;
        total_padding += grid.margin_start;
        total_padding += icon.margin_start;
        total_padding += margin_end;
        total_padding += frame.margin_end;
        total_padding += grid.margin_end;
        total_padding += icon.margin_end;

        show_all ();
    }

    public IconGridItem (WidgetGrid.DataInterface? data = null) {
        Object (data: data);
    }

    private bool on_get_child_position (Gtk.Widget widget, out Gdk.Rectangle allocation) {
        allocation = Gtk.Allocation ();
        var w_alloc = Gtk.Allocation ();
        frame.get_allocation (out w_alloc);
        allocation.x = w_alloc.x;
        allocation.y = w_alloc.y;
        allocation.width = 24;
        allocation.height = 24;

        helper_allocation = (Gdk.Rectangle)allocation;
        return true;
    }

    private uint last_thumbstate = -1;
    public bool get_new_pix (int size) {
        var px_size = Marlin.icon_size_get_nearest_from_value (size);
        icon.set_size_request (px_size, px_size);

        if (file == null || file.is_null) {
            return false;
        } else {
            pix_size = px_size;
            last_thumbstate = file.thumbstate;
        }


        file.update_icon (pix_size, 1);
        icon.set_from_pixbuf (file.pix);

        return true;
    }

    public bool equal (WidgetGrid.Item b) {
        if (b is IconGridItem) {
            return (( IconGridItem) b).item_name == item_name;
        } else {
            return false;
        }
    }

    public bool set_max_width (int width, bool force = false) {
        if (force) {
            file.query_thumbnail_update ();
        }

        if (width != set_max_width_request || force) {
            set_max_width_request = width;
            set_size_request (width, -1);
            get_new_pix (width - total_padding);
        }

        return true;
    }

    /** Call with null to refresh from existing data **/
    public void update_item (WidgetGrid.DataInterface? _data = null) {
        var prev_data_id = data_id;
        var current_data_id = _data != null ? _data.data_id : -1;
        var new_data = (prev_data_id != current_data_id || prev_data_id < 0);

        if (_data != null && new_data) {
            data = _data;
        }

        if (file != null && !file.is_null) {
            update_state ();
            label.label = item_name;
            set_max_width (set_max_width_request, new_data || file.thumbstate != last_thumbstate);
        }
    }

    /** The point supplied must be in IconGridItem coordinates **/
    public FM.ClickZone get_zone (Gdk.Point p) {
        var p_rect = Gdk.Rectangle () {x = p.x, y = p.y, width = 1, height = 1};
        FM.ClickZone result = FM.ClickZone.BLANK_NO_PATH;

        if (helper_allocation.intersect (p_rect, null)) {
            result = FM.ClickZone.HELPER;
        } else if (label.intersect (p_rect, null)) {
            result = FM.ClickZone.NAME;
        } else if (icon.intersect (p_rect, null)) {
            result = FM.ClickZone.ICON;
        } else if (frame.intersect (p_rect, null)){
            result = FM.ClickZone.BLANK_PATH;
        }

        return result;
    }

    private void update_state () {
        if (is_selected) {
            grid.set_state_flags (Gtk.StateFlags.SELECTED, false);
            helper.set_from_icon_name ("selection-checked", default_helper_size);
        } else {
            grid.unset_state_flags (Gtk.StateFlags.SELECTED);
        }

        if (is_cursor_position) {
            grid.set_state_flags (Gtk.StateFlags.PRELIGHT, false);
            helper.set_from_icon_name (is_selected ? "selection-remove" : "selection-add", focused_helper_size);
        } else {
            grid.unset_state_flags (Gtk.StateFlags.PRELIGHT);
        }

        /* set label background if color tagged */
        string data;
        data = "* {border-radius: 5px;}";

        if (file.color > 0 && !is_selected) {
            data = "* {border-radius: 5px; background-color: %s;}".printf (GOF.Preferences.TAGS_COLORS[file.color]);
        }

        try {
            provider.load_from_data (data);
        } catch (Error e) {
            critical (e.message);
        }

        helper.visible = is_cursor_position || is_selected || is_hovered;
    }

    public void leave () {
        is_hovered = false;
        update_state ();
    }

    public void hovered (Gdk.EventMotion event) {
        update_state ();
    }

    public void enter () {
        is_hovered = true;
        update_state ();
    }

    public Gtk.CellEditable rename (int data_index) {
        renaming = true;
        renaming_index = data_index;
        var entry = new Marlin.MultiLineEditableLabel ();
        entry.hexpand = false;
        entry.set_line_wrap (true);
        entry.set_line_wrap_mode (Pango.WrapMode.WORD_CHAR);
        entry.set_text (item_name);

        Gtk.Allocation alloc;
        label.get_allocation (out alloc);
        entry.size_allocate (alloc);
        grid.remove (label);
        grid.add (entry);
        grid.show_all ();

        entry.editing_done.connect (() => {
            if (entry.editing_canceled) {
                editing_canceled ();
            } else {
                edited (renaming_index, entry.get_text ());
            }
        });

        entry.remove_widget.connect (() => {
            grid.add (label);
            entry.destroy ();
        });

        entry.get_real_editable ().focus_out_event.connect_after (() => {
            entry.editing_done (); /* This generates remove widget signal */
            return true;
        });

        entry.key_press_event.connect (on_entry_key_press_event);

        entry.start_editing (null);
        return entry;
    }

    public virtual bool on_entry_key_press_event (Gtk.Widget widget, Gdk.EventKey event) {
        var entry = (Marlin.MultiLineEditableLabel)widget;
        var mods = event.state & Gtk.accelerator_get_default_mod_mask ();
        bool only_control_pressed = (mods == Gdk.ModifierType.CONTROL_MASK);

        switch (event.keyval) {
            case Gdk.Key.Return:
            case Gdk.Key.KP_Enter:
                /*  Only end rename with unmodified Enter. This is to allow use of Ctrl-Enter
                 *  to commit Chinese/Japanese characters when using some input methods, without ending rename.
                 */
                if (mods == 0) {
                    entry.activate ();
                    return true;
                }

                break;

            case Gdk.Key.Escape:
                editing_canceled ();
                entry.remove_widget ();
                return true;

            case Gdk.Key.z:
                /* Undo with Ctrl-Z only */
                if (only_control_pressed) {
                    entry.set_text (entry.original_name);
                    return true;
                }
                break;

            default:
                break;
        }
        return false;
    }
}
}
