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
    protected Gtk.MultiSelection multi_selection { get; set; }
    protected Files.Preferences prefs { get; default = Files.Preferences.get_default (); }

    // Construct properties
    public Gtk.ColumnView column_view { get; construct; }
    // public Gtk.PopoverMenu popover_menu { get; construct; }

    //Interface properties
    protected unowned GLib.List<Gtk.Widget> fileitem_list  { get; set; default = null; }
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

    private CompareDataFunc<Files.File>? file_compare_func;
    private string? uri_string = null;

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

        file_compare_func = ((filea, fileb) => {
            return filea.compare_for_sort (
                fileb, sort_type, prefs.sort_directories_first, sort_reversed
            );
        });

        //Setup columnview
        column_view = new Gtk.ColumnView (multi_selection) {
            enable_rubberband = true,
            focusable = true,
            show_column_separators = true
        };

        build_ui (column_view);
        set_up_gestures ();

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

        popover_menu.closed.connect (() => {
            column_view.grab_focus (); //FIXME This should happen automatically?
            //Open with submenu must always be at pos 0
            //This is awkward but can only amend open-with-menu by removing and re-adding.
            if (has_open_with) {
                item_menu.remove (0);
                has_open_with = false;
            }
            // This removes any custom widgets (?)
            popover_menu.menu_model = null;
        });

        //Set up as drag source for bookmarking
        var drag_source = new Gtk.DragSource () {
            propagation_phase = Gtk.PropagationPhase.CAPTURE,
            actions = Gdk.DragAction.LINK | Gdk.DragAction.COPY | Gdk.DragAction.MOVE
        };
        column_view.add_controller (drag_source);
        drag_source.prepare.connect ((x, y) => {
            var widget = pick (x, y, Gtk.PickFlags.DEFAULT);
            var item = widget.get_ancestor (typeof (GridFileItem));
            if (item != null && (item is GridFileItem)) {
                var fileitem = ((GridFileItem)item);
                if (!fileitem.selected) {
                    multi_selection.select_item (fileitem.pos, true);
                }

                var selected_files = new GLib.List<Files.File> ();
                get_selected_files (out selected_files);
                uri_string = FileUtils.make_string_from_file_list (selected_files);
                // Use a simple string content to match sidebar drop target
                var list_val = new GLib.Value (Type.STRING);
                list_val.set_string (uri_string);
                return new Gdk.ContentProvider.for_value (list_val);
            }

            return null;
        });
        drag_source.drag_begin.connect ((drag) => {
            //TODO Set drag icon
            return;
        });
        drag_source.drag_end.connect ((drag, delete_data) => {
            //FIXME Does this leak memory?
            uri_string = null;
            return;
        });
        drag_source.drag_cancel.connect ((drag, reason) => {
            //FIXME Does this leak memory?
            uri_string = null;
            return true;
        });
        notify["sort-type"].connect (() => {
            list_store.sort (file_compare_func);
        });
        notify["sort-reversed"].connect (() => {
            list_store.sort (file_compare_func);
            //TODO Persist setting in file metadata
        });
        prefs.notify["sort-directories-first"].connect (() => {
            list_store.sort (file_compare_func);
        });
        prefs.notify["show-hidden-files"].connect (() => {
            // This refreshes the filter as well
            list_store.sort (file_compare_func);
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

        // Restore saved zoom level
        if (slot.view_mode == ViewMode.ICON) {
            Files.icon_view_settings.bind ("zoom-level", this, "zoom-level", SettingsBindFlags.DEFAULT);
        } else {
            Files.column_view_settings.bind ("zoom-level", this, "zoom-level", SettingsBindFlags.DEFAULT);
        }
    }

    /* Private methods */
    protected override void change_path (GLib.File loc, OpenFlag flag) {
        activate_action ("win.path-change-request", "(su)", loc.get_uri (), flag);
    }

    private void refresh_view () {
        // Needed to load thumbnails when settings change.  Is there a better way?
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

    private void focus_appropriate_item () {
        var item = get_selected_file_item ();
        if (item != null) {
            item.grab_focus ();
        } else if (list_store.get_n_items () > 0) {
            multi_selection.select_item (0, false);
            focus_item (0);
        } else {
            column_view.grab_focus ();
        }
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
    protected unowned Gtk.Widget get_view_widget () {
        return column_view;
    }

    public override void clear () {
        list_store.remove_all ();
        rename_after_add = false;
        select_after_add = false;
    }

    public override void add_file (Files.File file) {
        //TODO Delay sorting until adding finished?
        list_store.insert_sorted (file, file_compare_func);
        if (select_after_add) {
            select_after_add = false;
            show_and_select_file (file, true, true);
        } else if (rename_after_add) {
            rename_after_add = false;
            Idle.add (() => {
                show_and_select_file (file, true, true);
                activate_action ("win.rename", null);
                return Source.REMOVE;
            });
        }
    }

    public override void open_selected (Files.OpenFlag flag) {
        List<Files.File> selected_files = null;
        var n_files = get_selected_files (out selected_files);
        if (n_files == 0) {
            return;
        }
        //TODO Apply upper limit to number of files?
        switch (n_files) {
            case 1:
                open_file (selected_files.data, flag);
                break;
            default:
                //TODO Deal with multiple selection
                //Check common type
                //
                break;
        }
    }

    public override void file_deleted (Files.File file) {
        uint pos;
        if (list_store.find (file, out pos)) {
            list_store.remove (pos);
        }
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

    public override void file_changed (Files.File file) {
        var item = get_file_item_for_file (file);
        if (item != null) {
            item.bind_file (file); // Forces image to update
        }
    }

    public void grab_focus () {
        if (column_view != null) {
            focus_appropriate_item ();
        }
    }
    /* DNDInterface abstract methods */

    //Need to ensure fileitem gets selected before drag
    public List<Files.File> get_file_list_for_drag (double x, double y, out Gdk.Paintable? paintable) {
        paintable = null;
        var dragitem = get_item_at (x, y);
        List<Files.File> drag_files = null;
        if (dragitem != null) {
            uint n_items = 0;
            if (!dragitem.selected) {
                drag_files.append (dragitem.file);
                n_items = 1;
            } else {
                n_items = get_selected_files (out drag_files);
            }

            paintable = get_paintable_for_drag (dragitem, n_items);
        }
        return (owned) drag_files;
    }

    // private Gdk.Paintable get_paintable_for_drag (GridFileItem dragged_item, uint item_count) {
    private Gdk.Paintable get_paintable_for_drag (FileItemInterface dragged_item, uint item_count) {
        Gdk.Paintable paintable;
        if (item_count > 1) {
            var theme = Gtk.IconTheme.get_for_display (Gdk.Display.get_default ());
            paintable = theme.lookup_icon (
                "edit-copy", //TODO Provide better icon?
                 null,
                 16,
                 this.scale_factor,
                 get_default_direction (),
                 Gtk.IconLookupFlags.FORCE_REGULAR | Gtk.IconLookupFlags.PRELOAD
            );
        } else {
            paintable = dragged_item.get_paintable_for_drag ();
        }

        return paintable;
    }

    private uint auto_open_timeout_id = 0;
    private FileItemInterface? previous_target_item = null;
    public Files.File get_target_file_for_drop (double x, double y) {
        var droptarget = get_item_at (x, y);
        if (droptarget == null) {
            if (auto_open_timeout_id > 0) {
                Source.remove (auto_open_timeout_id);
                if (previous_target_item != null) {
                    previous_target_item.drop_pending = false;
                    previous_target_item = null;
                }
                auto_open_timeout_id = 0;
            }
            return root_file;
        } else {
            var target_file = droptarget.file;
            if (target_file.is_folder ()) {
                if (!droptarget.drop_pending) {
                    if (previous_target_item != null) {
                        previous_target_item.drop_pending = false;
                    }

                    droptarget.drop_pending = true;
                    previous_target_item = droptarget;
                    //TODO Start time for auto open
                    if (auto_open_timeout_id > 0) {
                        Source.remove (auto_open_timeout_id);
                    }

                    auto_open_timeout_id = Timeout.add (1000, () => {
                        auto_open_timeout_id = 0;
                        change_path (droptarget.file.location, Files.OpenFlag.DEFAULT);
                        // path_change_request (droptarget.file.location, Files.OpenFlag.DEFAULT);
                        return Source.REMOVE;
                    });
                }
            }

            return target_file;
        }
    }

    // Whether is accepting any drops at all
    public bool can_accept_drops () {
       // We cannot ever drop on some locations
        if (!root_file.is_folder () || root_file.is_recent_uri_scheme ()) {
            return false;
        }
        return true;
    }
    // Whether is accepting any drags at all
    public bool can_start_drags () {
        return root_file.is_readable ();
    }

    public void leave () {
        // Cancel auto-open and restore normal icon
        if (auto_open_timeout_id > 0) {
            Source.remove (auto_open_timeout_id);
            auto_open_timeout_id = 0;
        }

        if (previous_target_item != null) {
            previous_target_item.drop_pending = false;
        }
    }
}
