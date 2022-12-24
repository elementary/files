/***
    Copyright (c) 2015-2022 elementary LLC <https://elementary.io>

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

public class Files.ListView : Gtk.Widget, Files.ViewInterface, Files.DNDInterface {
    static construct {
        set_layout_manager_type (typeof (Gtk.BinLayout));
    }

    // Properties defined in View.ui template
    protected Menu background_menu { get; set; }
    protected Menu item_menu { get; set; }
    protected Gtk.ScrolledWindow scrolled_window { get; set; }

    //ViewInterface properties
    protected Gtk.PopoverMenu popover_menu { get; set; }
    protected GLib.ListStore list_store { get; set; }
    protected Gtk.FilterListModel filter_model { get; set; }
    public Gtk.MultiSelection multi_selection { get; protected set; }
    protected Files.Preferences prefs { get; default = Files.Preferences.get_default (); }
    protected string current_drop_uri { get; set; default = "";}
    protected uint current_drag_button { get; set; default = 1;}
    protected bool drop_accepted { get; set; default = false; }
    protected unowned List<GLib.File> dropped_files { get; set; default = null; }
    protected Gdk.DragAction accepted_actions { get; set; default = 0; }
    protected Gdk.DragAction suggested_action { get; set; default = 0; }

    //DNDInterface properties
    protected uint auto_open_timeout_id { get; set; default = 0; }
    protected FileItemInterface? previous_target_item { get; set; default = null; }
    protected string? uri_string { get; set; default = null;}

    // Construct properties
    public Gtk.ColumnView column_view { get; construct; }
    // public Gtk.PopoverMenu popover_menu { get; construct; }

    //Interface properties
    protected unowned GLib.List<Gtk.Widget> fileitem_list { get; set; default = null; }
    public SlotInterface slot { get; set construct; }
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
    protected bool has_open_with { get; set; default = false;}

    public ListView (Files.Slot slot) {
        Object (slot: slot);
    }

    ~ListView () {
        warning ("GridView destruct");
        while (this.get_last_child () != null) {
            this.get_last_child ().unparent ();
        }
    }

    construct {
        set_layout_manager (new Gtk.BinLayout ());
        set_up_model ();
        bind_prefs ();
        bind_sort ();

        //Setup columnview
        column_view = new Gtk.ColumnView (multi_selection) {
            enable_rubberband = true,
            focusable = true,
            show_column_separators = true
        };
        build_ui (column_view);
        bind_popover_menu ();
        set_up_gestures ();
        set_up_drag_source ();
        set_up_drop_target ();

        var name_item_factory = new Gtk.SignalListItemFactory ();
        var size_item_factory = new Gtk.SignalListItemFactory ();
        var type_item_factory = new Gtk.SignalListItemFactory ();
        var modified_item_factory = new Gtk.SignalListItemFactory ();

        name_item_factory.setup.connect ((obj) => {
            var list_item = ((Gtk.ListItem)obj);
            var file_item = new GridFileItem (this);
            fileitem_list.prepend (file_item);
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
        //TODO Use Gtk.Inscription when v4.9 available
        size_item_factory.setup.connect ((obj) => {
            var list_item = ((Gtk.ListItem)obj);
            var size_item = new Gtk.Label ("") {
                margin_start = 12,
                halign = Gtk.Align.START
            };
            list_item.child = size_item;
            list_item.activatable = false;
            list_item.selectable = false;
        });
        type_item_factory.setup.connect ((obj) => {
            var list_item = ((Gtk.ListItem)obj);
            var type_item = new Gtk.Label ("") {
                margin_start = 12,
                halign = Gtk.Align.START
            };
            list_item.child = type_item;
            list_item.activatable = false;
            list_item.selectable = false;
        });
        modified_item_factory.setup.connect ((obj) => {
            var list_item = ((Gtk.ListItem)obj);
            var modified_item = new Gtk.Label ("") {
                margin_start = 12,
                halign = Gtk.Align.START
            };
            list_item.child = modified_item;
            list_item.activatable = false;
            list_item.selectable = false;
        });

        name_item_factory.bind.connect ((obj) => {
            var list_item = ((Gtk.ListItem)obj);
            var file = (Files.File)list_item.get_item ();
            var file_item = (GridFileItem)list_item.child;
            file_item.bind_file (file);
            file_item.selected = list_item.selected;
            file_item.pos = list_item.position;
        });
        size_item_factory.bind.connect ((obj) => {
            var list_item = ((Gtk.ListItem)obj);
            var file = (Files.File)list_item.get_item ();
            var size_item = (Gtk.Label)list_item.child;
            size_item.label = file.format_size;
        });
        type_item_factory.bind.connect ((obj) => {
            var list_item = ((Gtk.ListItem)obj);
            var file = (Files.File)list_item.get_item ();
            var type_item = (Gtk.Label)list_item.child;
            type_item.label = file.formated_type;
        });
        modified_item_factory.bind.connect ((obj) => {
            var list_item = ((Gtk.ListItem)obj);
            var file = (Files.File)list_item.get_item ();
            var modified_item = (Gtk.Label)list_item.child;
            modified_item.label = file.formated_modified;
        });

        name_item_factory.teardown.connect ((obj) => {
            var list_item = ((Gtk.ListItem)obj);
            var file_item = (GridFileItem)list_item.child;
            fileitem_list.remove (file_item);
        });

        var name_column = new Gtk.ColumnViewColumn (_("Name"), name_item_factory) {
            expand = true,
            resizable = true
        };
        var size_column = new Gtk.ColumnViewColumn (_("Size"), size_item_factory) {
            expand = false,
            resizable = false
        };
        var type_column = new Gtk.ColumnViewColumn (_("Type"), type_item_factory) {
            expand = false,
            resizable = true
        };
        var modified_column = new Gtk.ColumnViewColumn (_("Modified"), modified_item_factory) {
            expand = true,
            resizable = true
        };

        column_view.append_column (name_column);
        column_view.append_column (size_column);
        column_view.append_column (type_column);
        column_view.append_column (modified_column);

        // Restore saved zoom level
        if (slot.view_mode == ViewMode.ICON) {
            Files.icon_view_settings.bind ("zoom-level", this, "zoom-level", SettingsBindFlags.DEFAULT);
        } else {
            Files.column_view_settings.bind ("zoom-level", this, "zoom-level", SettingsBindFlags.DEFAULT);
        }
    }

    // /* Private methods */
    private void refresh_view () {
        // Needed to load thumbnails when settings change.  Is there a better way?
        // Cannot move to interface (no access to model property)
        column_view.model = null;
        Idle.add (() => {
            column_view.model = multi_selection;
            return Source.REMOVE;
        });
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

    /* View Interface abstract methods */
    //Cannot move to interface because of plugins and Config.APP_NAME
    public void show_context_menu (FileItemInterface? item, double x, double y) {
        // If no selected item show background context menu
        double menu_x, menu_y;
        MenuModel menu;
        List<Files.File> selected_files = null;

        if (item == null) {
            menu_x = x;
            menu_y = y;
            menu = background_menu;
        } else {
            Graphene.Point point_item, point_gridview;
            item.compute_point (column_view, {(float)x, (float)y}, out point_gridview);

            if (!item.selected) {
                multi_selection.select_item (item.pos, true);
            }

            get_selected_files (out selected_files);

            var open_with_menu = new Menu ();
            var open_with_apps = MimeActions.get_applications_for_files (
                selected_files, Config.APP_NAME, true, true
            );
            foreach (var appinfo in open_with_apps) {
                open_with_menu.append (
                    appinfo.get_name (),
                    Action.print_detailed_name (
                        "win.open-with", new Variant.string (appinfo.get_commandline ())
                    )
                );
            }

            assert (!has_open_with); //Must not add twice
            // Base item menu is constructed by template
            item_menu.prepend_submenu (_("Open With"), open_with_menu);
            has_open_with = true;

            menu_x = (double)point_gridview.x;
            menu_y = (double)point_gridview.y;
            menu = item_menu;
        }

        popover_menu.menu_model = menu;
        popover_menu.set_pointing_to ({(int)x, (int)y, 1, 1});
        plugins.hook_context_menu (popover_menu, selected_files);

        Idle.add (() => {
            popover_menu.popup ();
            return Source.REMOVE;
        });
    }

    /* ViewInterface virtual methods */
    public unowned Gtk.Widget get_view_widget () {
        return column_view;
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
