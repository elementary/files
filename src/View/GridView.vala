/***
    Copyright (c) 2015-2020 elementary LLC <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISitem_factory QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/

public class Files.GridView : Gtk.Widget, Files.ViewInterface {
    static construct {
        set_layout_manager_type (typeof (Gtk.BinLayout));
    }

    public Gtk.GridView grid_view { get; construct; }
    public GLib.ListStore model { get; construct; }

    public ZoomLevel zoom_level { get; set; default = ZoomLevel.NORMAL; }
    public ZoomLevel minimum_zoom { get; set; default = ZoomLevel.SMALLEST; }
    public ZoomLevel maximum_zoom { get; set; default = ZoomLevel.LARGEST; }

    public signal void selection_changed ();

    ~GridView () {
        warning ("Grid View destruct");
        grid_view.unparent ();
        grid_view.dispose ();
    }

    construct {
        set_layout_manager (new Gtk.BinLayout ());
        model = new GLib.ListStore (typeof (Files.File));
        var sorter = new Gtk.StringSorter (null); //TODO Provide expression to get strings from File
        var sorted_model = new Gtk.SortListModel (model, sorter);
        var selection_model = new Gtk.MultiSelection (sorted_model);
        var item_factory = new Gtk.SignalListItemFactory ();
        item_factory.setup.connect ((obj) => {
            var file_item = new FileItem (96);
            ((Gtk.ListItem)obj).child = file_item;
        });
        item_factory.bind.connect ((obj) => {
            var list_item = ((Gtk.ListItem)obj);
            var file = (Files.File)list_item.get_item ();
            var file_item = (FileItem)list_item.child;
            file_item.label.label = file.basename;
        });
        item_factory.unbind.connect ((obj) => {
            var list_item = ((Gtk.ListItem)obj);
            var file_item = (FileItem)list_item.child;
            file_item.label.label = "Unbound";
        });
        item_factory.teardown.connect ((obj) => {
        });

        grid_view = new Gtk.GridView (selection_model, item_factory);
        grid_view.activate.connect ((pos) => {

        });
        grid_view.realize.connect ((w) => {
            grid_view.grab_focus ();
        });

        grid_view.set_parent (this);
    }

    public override void add_file (Files.File file) {
        model.append (file);
    }

    public override void clear () {
        model.remove_all ();
    }

    public override void change_zoom_level (ZoomLevel zoom) {}
    public override void show_and_select_file (Files.File file, bool show, bool select) {}
    public override void invert_selection () {}
    public override void set_should_sort_directories_first (bool sort_directories_first) {}
    public override void set_show_hidden_files (bool show_hidden_files) {}
    public override void set_sort (Files.ListModel.ColumnID? col_name, Gtk.SortType reverse) {}
    public override void get_sort (out string sort_column_id, out string sort_order) {}
    public override void start_renaming_file (Files.File file) {}
    public override void zoom_in () {}
    public override void zoom_out () {}
    public override void zoom_normal () {}
    public override void focus_first_for_empty_selection (bool select) {}
    public override void select_all () {}
    public override void unselect_all () {}
    public override void file_icon_changed (Files.File file) {}
    public override void file_deleted (Files.File file) {}
    public override void file_changed (Files.File file) {}
    public override List<Files.File>? get_files_to_thumbnail (out uint actually_visible) { return null; }

    public uint get_selected_files (out GLib.List<Files.File> selected_files) {
        selected_files = null;
        uint pos = 0;
        uint count = 0;
        var iter = Gtk.BitsetIter ();
        if (iter.init_first (grid_view.model.get_selection (), out pos)) {
            selected_files.prepend (
                (Files.File)(grid_view.model.get_item (pos))
            );
            count++;
            while (iter.next (out pos)) {
                selected_files.prepend (
                    (Files.File)(grid_view.model.get_item (pos))
                );
                count++;
            }
        }

        return count;
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

    private class FileItem : Gtk.Box {
        public Gtk.Image image { get; set; }
        public Gtk.Label label { get; set; }
        public int pixel_size {
            get {
                return image.pixel_size;
            }

            set {
                image.pixel_size = value;
                var marg = value / 3;
                margin_top = marg;
                margin_bottom = marg;
                margin_start = marg;
                margin_end = marg;
            }
        }

        public FileItem (int size) {
            pixel_size = size;
        }

        construct {
            orientation = Gtk.Orientation.VERTICAL;
            spacing = 6;


            image = new Gtk.Image () {
                icon_name = "image-missing",
            };

            label = new Gtk.Label ("Unbound") {
                wrap = true,
                wrap_mode = Pango.WrapMode.WORD_CHAR
            };

            append (image);
            append (label);
        }
    }
}
