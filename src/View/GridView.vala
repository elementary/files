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
    public Gtk.MultiSelection multi_selection { get; construct; }
    public ZoomLevel zoom_level { get; set; default = ZoomLevel.NORMAL; }
    public ZoomLevel minimum_zoom { get; set; default = ZoomLevel.SMALLEST; }
    public ZoomLevel maximum_zoom { get; set; default = ZoomLevel.LARGEST; }

    public bool sort_directories_first { get; set; default = true; }
    public Files.SortType sort_type { get; set; default = Files.SortType.FILENAME; }
    public bool sort_reversed { get; set; default = false; }
    public bool all_selected { get; set; default = false; }

    public signal void selection_changed ();

    private Gtk.ScrolledWindow scrolled_window;
    private Gtk.CustomSorter sorter;
    private CompareDataFunc<Files.File>? file_compare_func;

    ~GridView () {
        while (this.get_last_child () != null) {
            this.get_last_child ().unparent ();
        }
    }

    construct {
        set_layout_manager (new Gtk.BinLayout ());
        scrolled_window = new Gtk.ScrolledWindow () {
            hexpand = true,
            vexpand = true
        };

        model = new GLib.ListStore (typeof (Files.File));
        multi_selection = new Gtk.MultiSelection (model);

        file_compare_func = ((filea, fileb) => {
            return filea.compare_for_sort (
                fileb, sort_type, sort_directories_first, sort_reversed
            );
        });

        var item_factory = new Gtk.SignalListItemFactory ();
        item_factory.setup.connect ((obj) => {
            var list_item = ((Gtk.ListItem)obj);
            var file_item = new FileItem () {
                gridview = grid_view
            };
            bind_property (
                "zoom-level",
                file_item, "zoom-level",
                BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE
            );
            list_item.child = file_item;
            // We handle file activation ourselves in FileItem
            list_item.activatable = false;
            list_item.selectable = true;
        });

        item_factory.bind.connect ((obj) => {
            var list_item = ((Gtk.ListItem)obj);
            var file = (Files.File)list_item.get_item ();
            var file_item = (FileItem)list_item.child;
            file_item.set_file (file);
            file_item.selected = list_item.selected;
            file_item.pos = list_item.position;
        });

        item_factory.unbind.connect ((obj) => {
            var list_item = ((Gtk.ListItem)obj);
            var file_item = (FileItem)list_item.child;
            file_item.set_file (null);
        });

        item_factory.teardown.connect ((obj) => {
        });

        grid_view = new Gtk.GridView (multi_selection, item_factory) {
            orientation = Gtk.Orientation.VERTICAL,
            min_columns = 5,
            max_columns = 20
        };

        grid_view.activate.connect ((pos) => {
            var file = (Files.File)grid_view.model.get_item (pos);
            if (file.is_folder ()) {
                path_change_request (file.location);
            } else {
                warning ("Open file with app");
            }
        });

        scrolled_window.child = grid_view;
        scrolled_window.set_parent (this);

        notify["sort-type"].connect (() => {
            model.sort (file_compare_func);
        });
        notify["sort-reversed"].connect (() => {
            model.sort (file_compare_func);
        });
        notify["sort-directories-first"].connect (() => {
            model.sort (file_compare_func);
        });
    }

    public override void add_file (Files.File file) {
        //TODO Delay sorting until adding finished?
        model.insert_sorted (file, file_compare_func);
    }

    public override void clear () {
        model.remove_all ();
    }

    public override void zoom_in () {
        if (zoom_level < maximum_zoom) {
            zoom_level = zoom_level + 1;
        }
    }
    public override void zoom_out () {
        if (zoom_level > minimum_zoom) {
            zoom_level = zoom_level - 1;
        }
    }
    public override void zoom_normal () {
        zoom_level = get_normal_zoom_level ();
    }

    private ZoomLevel get_normal_zoom_level () {
        var zoom = Files.icon_view_settings.get_enum ("default-zoom-level");
        Files.icon_view_settings.set_enum ("zoom-level", zoom);

        return (ZoomLevel)zoom;
    }

    public override void set_renaming (bool is_renaming) {
        var vscroll_bar = scrolled_window.get_vscrollbar ();
        vscroll_bar.visible = !is_renaming;
    }

    public override void show_and_select_file (
        Files.File? file, bool select, bool unselect_others
    ) {
        uint pos = 0;
        if (file != null) {
            model.find (file, out pos); //Inefficient?
        }

        //TODO Check pos same in sorted model and model
        if (select) {
            multi_selection.select_item (pos, unselect_others);
        }

        // Move focused item to top
        //TODO Work out how to move to middle of visible area?
        //Idle until gridview layed out.
        Idle.add (() => {
            var adj = scrolled_window.vadjustment;
            var val = adj.upper * double.min (
                (double)100 / (double) model.get_n_items (), adj.upper
            );

            return Source.REMOVE;
        });
    }

    public override void select_all () {
        multi_selection.select_all ();
        all_selected = true;
    }

    public override void unselect_all () {
        multi_selection.unselect_all ();
        all_selected = false;
    }

    public override void invert_selection () {
        uint pos = 0;
        var item = multi_selection.get_item (pos);
        while (item != null) {
            if (multi_selection.is_selected (pos)) {
                multi_selection.unselect_item (pos);
            } else {
                multi_selection.select_item (pos, false);
            }

            item = multi_selection.get_item (++pos);
        }
    }

    public override void set_show_hidden_files (bool show_hidden_files) {}
    public override void start_renaming_file (Files.File file) {}
    public override void file_icon_changed (Files.File file) {}
    public override void file_deleted (Files.File file) {}
    public override void file_changed (Files.File file) {} //TODO Update thumbnail

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

    private class FileItem : Gtk.Widget {
        private static Gtk.CssProvider fileitem_provider;
        static construct {
            set_layout_manager_type (typeof (Gtk.BoxLayout));
            set_css_name ("fileitem");
            fileitem_provider = new Gtk.CssProvider ();
            fileitem_provider.load_from_resource ("/io/elementary/files/GridViewFileItem.css");
        }

        private int thumbnail_request = -1;
        private Files.File? file = null;


        public Gtk.Image image { get; set; }
        public Gtk.Label label { get; set; }
        public Gtk.GridView gridview { get; set construct; }
        public uint pos;

        public ZoomLevel zoom_level {
            set {
                var size = value.to_icon_size ();
                image.pixel_size = size;
                update_pix ();
                image.margin_start = size / 2;
                image.margin_end = size / 2;
                image.margin_top = size / 4;
            }
        }
        public bool selected { get; set; default = false; }

        construct {
            var lm = new Gtk.BoxLayout (Gtk.Orientation.VERTICAL);
            set_layout_manager (lm);

            get_style_context ().add_provider (
                fileitem_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );

            var gesture_click = new Gtk.GestureClick () {
                button = 1
            };

            gesture_click.pressed.connect ((n_press, x, y) => {
                if (n_press == 2 || file.is_folder ()) {
                    // GridView will take appropriate action
                    gridview.activate (pos);
                }
            });

            add_controller (gesture_click);

            image = new Gtk.Image () {
                icon_name = "image-missing",
            };

            label = new Gtk.Label ("Unbound") {
                wrap = true,
                wrap_mode = Pango.WrapMode.WORD_CHAR,
                ellipsize = Pango.EllipsizeMode.END,
                lines = 5,
                margin_top = 3,
                margin_bottom = 3,
                margin_start = 3,
                margin_end = 3,
            };

            image.set_parent (this);
            label.set_parent (this);

            Thumbnailer.@get ().finished.connect ((req) => {
                if (req == thumbnail_request) {
                    thumbnail_request = -1;
                }

                update_pix ();
            });

            notify["selected"].connect (() => {
                if (selected && !has_css_class ("selected")) {
                    add_css_class ("selected");
                } else if (!selected && has_css_class ("selected")) {
                    remove_css_class ("selected");
                }
            });
        }

        public void set_file (Files.File? file) {
            this.file = file;
            if (file != null) {
                file.ensure_query_info ();
                label.label = file.custom_display_name ?? file.basename;
                image.icon_name = "image-missing";
                update_pix ();

                if (file.pix == null) {
                    file.query_thumbnail_update (); // Ensure thumbstate up to date
                    if (file.thumbstate == Files.File.ThumbState.UNKNOWN) {
                        get_thumbnail ();
                    }

                    if (file.icon != null) {
                        image.gicon = file.icon;
                    }
                }
            } else {
                label.label = "Unbound";
                image.icon_name = "image-missing";
                thumbnail_request = -1;
            }
        }

        private void update_pix () {
            if (file == null) {
                return;
            }

            file.update_icon (image.pixel_size, 1); //TODO Deal with scale
            if (file.pix != null) {
                image.paintable = Gdk.Texture.for_pixbuf (file.pix);
                queue_draw ();
            }
        }

        public void get_color_tag () {

        }

        private void get_thumbnail () {
            if (thumbnail_request > -1) {
                return;
            }

            Thumbnailer.@get ().queue_file (file, out thumbnail_request, image.pixel_size > 128);
        }

        ~FileItem () {
            while (this.get_last_child () != null) {
                this.get_last_child ().unparent ();
            }
        }
    }
}
