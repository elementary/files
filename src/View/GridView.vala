/***
    Copyright (c) 2015-2023 elementary LLC <https://elementary.io>

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

public class Files.GridView : Gtk.Widget, Files.ViewInterface, Files.DNDInterface {
    static construct {
        set_layout_manager_type (typeof (Gtk.BinLayout));
    }

    protected Gtk.ScrolledWindow scrolled_window { get; set; }

    // ViewInterface properties
    protected Gtk.PopoverMenu popover_menu { get; set; }
    protected GLib.ListStore root_store { get; set; }
    protected Gtk.FilterListModel filter_model { get; set; }
    protected Gtk.MultiSelection multi_selection { get; set; }
    protected Files.Preferences prefs { get; default = Files.Preferences.get_default (); }
    protected string current_drop_uri { get; set; default = "";}
    protected uint current_drag_button { get; set; default = 1;}
    protected bool drop_accepted { get; set; default = false; }

    //DNDInterface properties
    protected uint auto_open_timeout_id { get; set; default = 0; }
    protected FileItemInterface? previous_target_item { get; set; default = null; }
    protected string? uri_string { get; set; default = null;}

    // Construct properties
    public Gtk.GridView grid_view { get; construct; }

    protected unowned GLib.List<Gtk.Widget> fileitem_list { get; set; default = null; }
    public unowned SlotInterface slot { get; set construct; }
    public ZoomLevel zoom_level { get; set; default = ZoomLevel.NORMAL; }
    public ZoomLevel minimum_zoom { get; set; default = ZoomLevel.SMALLEST; }
    public ZoomLevel maximum_zoom { get; set; default = ZoomLevel.LARGEST; }
    public Files.SortType sort_type { get; set; default = Files.SortType.FILENAME; }
    public bool sort_reversed { get; set; default = false; }
    public bool all_selected { get; set; default = false; }
    public bool is_renaming { get; set; default = false; }

    // Simpler than using signals and delegates to call actions after file has been added
    public bool rename_after_add { get; set; default = false;}
    public bool select_after_add { get; set; default = false;}

    public GridView (Files.Slot slot) {
        Object (slot: slot);
    }

    ~GridView () {
        warning ("GridView destruct");
        while (this.get_last_child () != null) {
            this.get_last_child ().unparent ();
        }
    }

    construct {
        set_layout_manager (new Gtk.BinLayout ());
        var item_factory = new Gtk.SignalListItemFactory ();
        grid_view = new Gtk.GridView (null, item_factory) {
            orientation = Gtk.Orientation.VERTICAL,
            enable_rubberband = true,
            focusable = true
        };
        set_model (set_up_model ());
        bind_prefs ();
        bind_sort ();
        build_ui (grid_view);
        bind_popover_menu ();
        set_up_gestures ();
        set_up_drag_source ();
        set_up_drop_target ();

        item_factory.setup.connect ((obj) => {
            var list_item = ((Gtk.ListItem)obj);
            var file_item = new GridFileItem (this);
            list_item.set_data<GridFileItem> ("file-item", file_item);
            fileitem_list.prepend ((FileItemInterface)file_item);
            bind_property (
                "zoom-level",
                file_item, "zoom-level",
                BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE
            );
            list_item.child = file_item;
            // We handle file activation ourselves in GridFileItem
            list_item.activatable = false;
            list_item.selectable = true;
        });

        item_factory.bind.connect ((obj) => {
            Object child;
            var list_item = ((Gtk.ListItem)obj);
            var file = get_file_and_child (obj, out child);
            var file_item = (GridFileItem)child;

            file_item.bind_file (file);
            file_item.selected = list_item.selected;
            file_item.pos = list_item.position;
        });

        item_factory.teardown.connect ((obj) => {
            fileitem_list.remove (obj.get_data<GridFileItem> ("file-item"));
        });

        // Restore saved zoom level
        if (slot.view_mode == ViewMode.ICON) {
            Files.icon_view_settings.bind ("zoom-level", this, "zoom-level", SettingsBindFlags.DEFAULT);
        } else {
            Files.column_view_settings.bind ("zoom-level", this, "zoom-level", SettingsBindFlags.DEFAULT);
        }
    }

    protected Files.File get_file_and_child (
        Object obj,
        out Object child
    ) {
warning ("GRID get file and child from %s", obj.get_type ().name ());
        var list_item = (Gtk.ListItem)obj;
        child = list_item.child;
        var fileobj = list_item.get_item ();
        return (Files.File)fileobj;
    }

    protected Gtk.CustomFilter get_custom_filter () {
        return new Gtk.CustomFilter ((obj) => {
            assert (obj is Files.File);
            var file = (Files.File)obj;
            return prefs.show_hidden_files || !file.is_hidden;
        });
    }

    protected void bind_sort () {
        notify["sort-type"].connect (sort_model);
        notify["sort-reversed"].connect (sort_model);
        //TODO Persist setting in file metadata
    }

    protected override void sort_model () {
        root_store.sort ((a , b) => {
            return ((Files.File)a).compare_for_sort (
                (Files.File)b,
                sort_type,
                prefs.sort_directories_first,
                sort_reversed
            );
        });
    }

    public void set_model (Gtk.SelectionModel? model) {
        grid_view.set_model (model);
    }

    private ZoomLevel get_normal_zoom_level () {
        int zoom;
        if (slot.view_mode == ViewMode.ICON) {
            zoom = Files.icon_view_settings.get_enum ("default-zoom-level");
            Files.icon_view_settings.set_enum ("zoom-level", zoom);
        } else {
            zoom = Files.column_view_settings.get_enum ("default-zoom-level");
            Files.column_view_settings.set_enum ("zoom-level", zoom);
        }

        return (ZoomLevel)zoom;
    }

    /* ViewInterface methods */
    public unowned Gtk.Widget get_view_widget () {
        return grid_view;
    }

    //Cannot move entirely to interface because of plugins hook
    public void show_context_menu (FileItemInterface? item, double x, double y) {
        var selected_files = build_popover_menu (item, x, y, Config.APP_NAME);
        plugins.hook_context_menu (popover_menu, selected_files);

        Idle.add (() => {
          popover_menu.popup ();
          return Source.REMOVE;
        });
    }

    public override void set_up_zoom_level () {
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
}
