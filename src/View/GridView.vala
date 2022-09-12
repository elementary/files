/***
    Copyright (c) 2022 elementary LLC <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/
public class Files.GridView : Files.AbstractDirectoryView {
    public Gtk.GridView gridview { get; construct; }
    public ListStore list_store { get; set; }
    public Gtk.SignalListItemFactory item_factory { get; set; }
    public Gtk.MultiSelection multiselection { get; set; }
    /* Support for loading visible icons */
    protected uint last_pos = 0;
    protected uint first_pos = uint.MAX;
    /* support for linear selection mode in icon view, overriding native behaviour of Gtk.IconView */
    protected bool previous_selection_was_linear = false;
    // protected Gtk.TreePath? previous_linear_selection_path = null;
    protected int previous_linear_selection_direction = 0;
    protected bool linear_select_required = false;
    // protected Gtk.TreePath? most_recently_selected = null;

    public GridView (View.Slot _slot) {
        base (_slot);
    }

    construct {
        margin_start = 12;
        margin_top = 12;

        list_store = new ListStore (typeof (Files.File));
        item_factory = new Gtk.SignalListItemFactory ();

        item_factory.setup.connect ((factory, list_item) => {
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
                margin_start = 12,
                margin_end = 12,
                margin_bottom = 12,
                margin_top = 12
            };
            var file_image = new Gtk.Image () {
                margin_bottom = 6
            };
            var filename_label = new Gtk.Label (null) {
                lines = 5,
                wrap = true,
                wrap_mode = Pango.WrapMode.WORD_CHAR
            };
            box.append (file_image);
            box.append (filename_label);
            list_item.set_child (box);
        });
        item_factory.bind.connect ((factory, list_item) => {
            first_pos = uint.min (first_pos, list_item.position);
            last_pos = uint.max (last_pos, list_item.position);
            var box = (Gtk.Box)(list_item.child);
            var file = (Files.File)(list_item.get_item ());
            var image = (Gtk.Image)(box.get_first_child ());
            image.pixel_size = icon_size * this.scale_factor;
            var tp = file.get_thumbnail_path ();
            if (tp != null) {
                image.file = tp;
            } else if (file.pix != null) {
                image.paintable = Gdk.Texture.for_pixbuf (file.pix);
            } else if (file.icon != null) {
                image.gicon = file.icon;
            } else {
                image.icon_name = "image-missing";
            }

            box.margin_start = image.pixel_size / 2;
            box.margin_end = box.margin_start;
            var label = (Gtk.Label)(image.get_next_sibling ());
            label.label = file.basename;
        });
        item_factory.teardown.connect ((factory, list_item) => {
            //warning ("Item teardown");

        });
        item_factory.unbind.connect ((factory, list_item) => {
            // warning ("Item unbind");
            var box = (Gtk.Box)(list_item.child);
            var file = (Files.File)(list_item.get_item ());
            var image = (Gtk.Image)(box.get_first_child ());
            image.clear ();
        });
        multiselection = new Gtk.MultiSelection (list_store);
        gridview = new Gtk.GridView (
            multiselection,
            item_factory
        );

        view = gridview;
    }

    // Do not insert many files sorted with this, use add_files ()
    protected override void add_file (
        Files.File file, Directory dir, bool select = true, bool sorted = false
    ) {
        uint pos = 0;
        if (sorted) {
            pos = list_store.insert_sorted (file, file_compare_func);
        } else {
            list_store.insert (0, file);
        }

        if (select) { /* This true once view finished loading */
            multiselection.select_item (pos, false);
        }
    }

    protected override void clear () {
        list_store.remove_all ();
    }

    protected override void set_up_zoom_level () {
        Files.icon_view_settings.bind (
            "zoom-level",
            this, "zoom-level",
            GLib.SettingsBindFlags.DEFAULT
        );

        minimum_zoom = (ZoomLevel)Files.icon_view_settings.get_enum ("minimum-zoom-level");
        maximum_zoom = (ZoomLevel)Files.icon_view_settings.get_enum ("maximum-zoom-level");

        if (zoom_level < minimum_zoom) {
            zoom_level = minimum_zoom;
        }

        if (zoom_level > maximum_zoom) {
            zoom_level = maximum_zoom;
        }
    }

    public override ZoomLevel get_normal_zoom_level () {
        var zoom = Files.icon_view_settings.get_enum ("default-zoom-level");
        Files.icon_view_settings.set_enum ("zoom-level", zoom);

        return (ZoomLevel)zoom;
    }

    public override void change_zoom_level () {
        // No other way to force refreshing of items?
        gridview.factory = null;
        gridview.factory = item_factory;
    }

    public override void tree_select_all () {
        gridview.get_model ().select_all ();
    }

    public override void tree_unselect_all () {
        gridview.get_model ().unselect_all ();
    }

    protected override uint get_selected_files_from_model (out GLib.List<Files.File> selected_files) {
        GLib.List<Files.File> list = null;
        uint count = 0;
        //TODO Implement for GridView

        selected_files = (owned)list;
        return count;
    }

    protected override bool view_has_focus () {
        return gridview.has_focus;
    }

    protected override uint get_event_position_info (double x, double y) {
        //TODO Implement for GridView
        return 0;
    }

    protected override void scroll_to_file (Files.File file, bool scroll_to_top) {
        //TODO Implement for GridView
    }

    protected override bool will_handle_button_press (bool no_mods, bool only_control_pressed,
                                                      bool only_shift_pressed) {

        linear_select_required = only_shift_pressed;
        if (linear_select_required) {
            return true;
        } else {
            return base.will_handle_button_press (no_mods, only_control_pressed, only_shift_pressed);
        }
    }

    protected override List<Files.File> get_visible_files () {
        var visible_files = new List<Files.File> ();
        uint index = first_pos;
        Object? item;
        while (index++ <= last_pos) {
            item = list_store.get_item (index);
            if (item != null && item is Files.File) {
                visible_files.prepend ((Files.File)item);
            }
        }

        return visible_files;
    }
    protected override void add_gof_file_to_selection (Files.File file) {}
    protected override void remove_gof_file (Files.File file) {}
    protected override uint select_gof_files (
        Gee.LinkedList<Files.File> files_to_select, GLib.File? focus_file
    ) {return 0;}
    protected override void select_gof_file (Files.File file) {}
    protected override void select_and_scroll_to_gof_file (Files.File file) {}
    protected override void invert_selection () {}
    protected override void resort () {}
}
