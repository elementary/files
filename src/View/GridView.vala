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
    private static Files.Preferences prefs;
    static construct {
        set_layout_manager_type (typeof (Gtk.BinLayout));
        prefs = Files.Preferences.get_default ();
    }

    public Gtk.GridView grid_view { get; construct; }
    public GLib.ListStore model { get; construct; }
    public Gtk.FilterListModel filter_model { get; construct; }
    public Gtk.CustomFilter custom_filter { get; construct; }
    public Gtk.MultiSelection multi_selection { get; construct; }
    public ZoomLevel zoom_level { get; set; default = ZoomLevel.NORMAL; }
    public ZoomLevel minimum_zoom { get; set; default = ZoomLevel.SMALLEST; }
    public ZoomLevel maximum_zoom { get; set; default = ZoomLevel.LARGEST; }

    public bool sort_directories_first { get; set; default = true; }
    public Files.SortType sort_type { get; set; default = Files.SortType.FILENAME; }
    public bool sort_reversed { get; set; default = false; }
    public bool all_selected { get; set; default = false; }
    public bool show_hidden_files { get; set; default = true; }
    public bool is_renaming { get; set; default = false; }

    public signal void selection_changed ();

    private Gtk.ScrolledWindow scrolled_window;
    private Gtk.CustomSorter sorter;
    private CompareDataFunc<Files.File>? file_compare_func;
    private GLib.List<FileItem> fileitem_list;

    ~GridView () {
        while (this.get_last_child () != null) {
            this.get_last_child ().unparent ();
        }
    }

    construct {
        set_layout_manager (new Gtk.BinLayout ());
        scrolled_window = new Gtk.ScrolledWindow () {
            hexpand = true,
            vexpand = true,
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };

        model = new GLib.ListStore (typeof (Files.File));
        filter_model = new Gtk.FilterListModel (model, null);
        multi_selection = new Gtk.MultiSelection (filter_model);

        file_compare_func = ((filea, fileb) => {
            return filea.compare_for_sort (
                fileb, sort_type, sort_directories_first, sort_reversed
            );
        });

        custom_filter = new Gtk.CustomFilter ((obj) => {
            var file = (Files.File)obj;
            return prefs.show_hidden_files || !file.is_hidden;
        });
        filter_model.set_filter (custom_filter);

        fileitem_list = new GLib.List<FileItem>();
        var item_factory = new Gtk.SignalListItemFactory ();
        item_factory.setup.connect ((obj) => {
            var list_item = ((Gtk.ListItem)obj);
            var file_item = new FileItem () {
                gridview = grid_view
            };
            fileitem_list.prepend (file_item);
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
            file_item.bind_file (file);
            file_item.selected = list_item.selected;
            file_item.pos = list_item.position;
        });

        item_factory.unbind.connect ((obj) => {
            var list_item = ((Gtk.ListItem)obj);
            var file_item = (FileItem)list_item.child;
            file_item.bind_file (null);
        });

        item_factory.teardown.connect ((obj) => {
            var list_item = ((Gtk.ListItem)obj);
            var file_item = (FileItem)list_item.child;
            fileitem_list.remove (file_item);
            //Do we need to destroy the FileItem?
        });

        grid_view = new Gtk.GridView (multi_selection, item_factory) {
            orientation = Gtk.Orientation.VERTICAL,
            max_columns = 20
        };

        grid_view.activate.connect ((pos) => {
            var file = (Files.File)grid_view.model.get_item (pos);
            if (file.is_folder () && multi_selection.get_selection ().get_size () == 1) {
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
        notify["is_renaming"].connect (() => {
            if (is_renaming) {
warning ("is renaming");
                scrolled_window.vscrollbar_policy = Gtk.PolicyType.NEVER;
            } else {
                scrolled_window.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
            }
        });
        prefs.notify["show-hidden-files"].connect (() => {
            // This refreshes the filter as well
            model.sort (file_compare_func);
        });
        prefs.notify["show-remote-thumbnails"].connect (() => {
            if (prefs.show_remote_thumbnails) {
                refresh_view ();
            }
        });
        prefs.notify["hide-local-thumbnails"].connect (() => {
            if (!prefs.hide_local_thumbnails) {
                refresh_view ();
            }
        });
    }

    private void refresh_view () {
        // Needed to load thumbnails when settings change.  Is there a better way?
        grid_view.model = null;
        Idle.add (() => {
            grid_view.model = multi_selection;
            return Source.REMOVE;
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

    // public override void set_renaming (bool is_renaming) {
    //     var vscroll_bar = scrolled_window.get_vscrollbar ();
    //     vscroll_bar.visible = !is_renaming;
    // }

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

            pos++;
            item = multi_selection.get_item (pos);
        }
    }

    public override void file_deleted (Files.File file) {
        uint pos;
        if (model.find (file, out pos)) {
            model.remove (pos);
        }
    }

    public override void start_renaming_selected_file () {
        unowned var selected_file_item = get_selected_file_item ();
        if (selected_file_item != null) {
            is_renaming = true;
            var layout = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            var name_label = new Gtk.Label (_("Enter the new name"));
            var name_entry = new Gtk.Entry () {
                text = selected_file_item.file.basename
            };
            layout.append (name_label);
            layout.append (name_entry);
            var rename_dialog = new Granite.Dialog () {
                modal = true
            };
            rename_dialog.get_content_area ().append (layout);
            rename_dialog.add_button ("Cancel", Gtk.ResponseType.CANCEL);

            var suggested_button = rename_dialog.add_button ("Suggested Action", Gtk.ResponseType.ACCEPT);
            suggested_button.add_css_class ("suggested-action");

            rename_dialog.response.connect ((response_id) => {
                if (response_id == Gtk.ResponseType.ACCEPT) {
                    warning ("Do rename");
                }

                rename_dialog.destroy ();
                is_renaming = false;
            });
            rename_dialog.present ();
        }
    }

    public override void file_icon_changed (Files.File file) {}
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

    private unowned FileItem? get_selected_file_item () {
        GLib.List<Files.File>? selected_files = null;
        if (get_selected_files (out selected_files) == 1) {
            return get_file_item_for_file (selected_files.data);
        }

        return null;
    }

    private unowned FileItem? get_file_item_for_file (Files.File file) {
        foreach (unowned var file_item in fileitem_list) {
            if (file_item.file == file) {
                return file_item;
            }
        }

        return null;
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

        public Files.File? file { get; set; default = null; }
        public Gtk.Image file_icon { get; construct; }
        public Gtk.CheckButton selection_helper { get; construct; }
        public Gtk.Label label { get; construct; }
        public Gtk.TextView text_view { get; construct; }
        public Gtk.Stack name_stack { get; construct; }
        public Gtk.GridView gridview { get; set construct; }
        public uint pos;

        public ZoomLevel zoom_level {
            set {
                var size = value.to_icon_size ();
                file_icon.pixel_size = size;
                update_pix ();
                file_icon.margin_start = size / 2;
                file_icon.margin_end = size / 2;
                file_icon.margin_top = size / 4;
                selection_helper.margin_start = size / 3;
                selection_helper.margin_end = size / 3;
                selection_helper.margin_top = size / 6;
                selection_helper.margin_bottom = size / 6;
            }
        }
        public bool selected { get; set; default = false; }

        construct {
            var lm = new Gtk.BoxLayout (Gtk.Orientation.VERTICAL);
            set_layout_manager (lm);

            get_style_context ().add_provider (
                fileitem_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );


            var icon_overlay = new Gtk.Overlay ();
            file_icon = new Gtk.Image () {
                icon_name = "image-missing",
            };
            icon_overlay.child = file_icon;

            selection_helper = new Gtk.CheckButton () {
                visible = false,
                halign = Gtk.Align.START,
                valign = Gtk.Align.START
            };
            icon_overlay.add_overlay (selection_helper);

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

            text_view = new Gtk.TextView ();
            name_stack = new Gtk.Stack ();
            name_stack.add_child (label);
            name_stack.add_child (text_view);
            name_stack.visible_child = label;
            icon_overlay.set_parent (this);
            name_stack.set_parent (this);

            Thumbnailer.@get ().finished.connect ((req) => {
                if (req == thumbnail_request) {
                    thumbnail_request = -1;
                    update_pix ();
                }
            });

            notify["selected"].connect (() => {
                if (selected && !has_css_class ("selected")) {
                    add_css_class ("selected");
                    selection_helper.visible = true;
                } else if (!selected && has_css_class ("selected")) {
                    remove_css_class ("selected");
                    selection_helper.visible = false;
                }
            });

            var gesture_click = new Gtk.GestureClick () {
                button = 1
            };
            gesture_click.pressed.connect ((n_press, x, y) => {
                if (n_press == 2 || file.is_folder ()) {
                    // GridView will take appropriate action
                    gridview.activate (pos);
                }
            });
            file_icon.add_controller (gesture_click);

            var motion_controller = new Gtk.EventControllerMotion ();
            motion_controller.enter.connect (() => {
                selection_helper.visible = true;
            });
            motion_controller.leave.connect (() => {
                selection_helper.visible = selected;
            });
            add_controller (motion_controller);
            selection_helper.bind_property (
                "active", this, "selected", BindingFlags.BIDIRECTIONAL
            );
            selection_helper.toggled.connect (() => {
                if (selection_helper.active) {
                    gridview.model.select_item (pos, false);
                } else {
                    gridview.model.unselect_item (pos);
                }
            });
        }

        public void bind_file (Files.File? file) {
            this.file = file;
            if (file != null) {
                file.ensure_query_info ();
                label.label = file.custom_display_name ?? file.basename;
                if (file.pix == null) {
                    file_icon.paintable = null;
                    file.query_thumbnail_update (); // Ensure thumbstate up to date
                    if (file.thumbstate == Files.File.ThumbState.UNKNOWN &&
                        (prefs.show_remote_thumbnails || !file.is_remote_uri_scheme ()) &&
                        !prefs.hide_local_thumbnails) { // Also hide remote if local hidden?

                            Thumbnailer.@get ().queue_file (
                                file, out thumbnail_request, file_icon.pixel_size > 128
                            );
                    }

                    if (file.icon != null) {
                        file_icon.gicon = file.icon;
                    }
                }

                update_pix ();
            } else {
                label.label = "Unbound";
                file_icon.icon_name = "image-missing";
                thumbnail_request = -1;
            }
        }

        private void update_pix () {
            if (file != null) {
                file.update_icon (file_icon.pixel_size, 1); //TODO Deal with scale
                if (file.pix != null) {
                    file_icon.paintable = Gdk.Texture.for_pixbuf (file.pix);
                    queue_draw ();
                }
            }
        }

        public void get_color_tag () {

        }

        ~FileItem () {
            while (this.get_last_child () != null) {
                this.get_last_child ().unparent ();
            }
        }
    }
}
