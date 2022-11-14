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

[GtkTemplate (ui = "/io/elementary/files/GridView.ui")]
public class Files.GridView : Gtk.Widget, Files.ViewInterface, Files.DNDInterface {
    private static Files.Preferences prefs;
    static construct {
        set_layout_manager_type (typeof (Gtk.BinLayout));
        prefs = Files.Preferences.get_default ();
    }



    // Properties defined in template NOTE: cannot use construct; here
    public Menu background_menu { get; set; }
    public Menu item_menu { get; set; }

    // Construct properties
    public Gtk.GridView grid_view { get; construct; }
    public GLib.ListStore list_store { get; construct; }
    public Gtk.MultiSelection multi_selection { get; construct; }
    public Gtk.PopoverMenu menu_popover { get; construct; }

    //Interface properties
    public AbstractSlot slot { get; set construct; }
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
    private EqualFunc<Files.File>? file_equal_func;
    private GLib.List<GridFileItem> fileitem_list;
    private Files.DndHandler dnd_handler;
    private Gtk.ScrolledWindow? scrolled_window;

    public GridView (Files.AbstractSlot slot) {
        Object (slot: slot);
    }

    ~GridView () {
        while (this.get_last_child () != null) {
            this.get_last_child ().unparent ();
        }
    }

    construct {
        set_layout_manager (new Gtk.BinLayout ());
        //Menu structure defined by GridView.ui
        item_menu.set_data<List<AppInfo>> ("open-with-apps", new List<AppInfo> ());
        dnd_handler = new Files.DndHandler (this, grid_view, grid_view);
        fileitem_list = new GLib.List<GridFileItem> ();

        //Set up models
        list_store = new GLib.ListStore (typeof (Files.File));
        var filter_model = new Gtk.FilterListModel (list_store, null);
        multi_selection = new Gtk.MultiSelection (filter_model);
        file_equal_func = ((filea, fileb) => {
            return filea.basename == fileb.basename;
        });
        file_compare_func = ((filea, fileb) => {
            return filea.compare_for_sort (
                fileb, sort_type, prefs.sort_directories_first, sort_reversed
            );
        });
        var custom_filter = new Gtk.CustomFilter ((obj) => {
            var file = (Files.File)obj;
            return prefs.show_hidden_files || !file.is_hidden;
        });
        filter_model.set_filter (custom_filter);

        //Setup gridview
        var item_factory = new Gtk.SignalListItemFactory ();
        grid_view = new Gtk.GridView (multi_selection, item_factory) {
            orientation = Gtk.Orientation.VERTICAL,
            max_columns = 20,
            enable_rubberband = true
        };
        scrolled_window = new Gtk.ScrolledWindow () {
            hexpand = true,
            vexpand = true,
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };
        scrolled_window.child = grid_view;
        scrolled_window.set_parent (this);

        //Setup context menu popover
        //No obvious way to create nested submenus with template so create manually
        //No obvious way to position at corner
        menu_popover = new Gtk.PopoverMenu.from_model_full (new Menu (), Gtk.PopoverMenuFlags.NESTED) {
          has_arrow = false
        };
        menu_popover.set_parent (this);


        // Implement single-click navigate
        var gesture_primary_click = new Gtk.GestureClick () {
            button = Gdk.BUTTON_PRIMARY,
            propagation_phase = Gtk.PropagationPhase.CAPTURE
        };
        gesture_primary_click.released.connect ((n_press, x, y) => {
            var widget = grid_view.pick (x, y, Gtk.PickFlags.DEFAULT);
            if (widget is Gtk.GridView) { // Click on background
                unselect_all ();
                grid_view.grab_focus ();
            } else {
                var should_activate = (
                    widget is Gtk.Image && // Not ideal as it relies on details of item structure but do not want to activate on label
                    (n_press == 1 && !prefs.singleclick_select ||
                    n_press == 2)
                );
                // Activate item
                var item = get_item_at (x, y);
                if (should_activate) {
                    unselect_all ();
                    var file = item.file;
                    if (file.is_folder ()) {
                        path_change_request (file.location, Files.OpenFlag.DEFAULT);
                    } else {
                        warning ("Open file with app");
                    }
                }
            }
            //Allow click to propagate to item selection helper and then Gtk
        });
        grid_view.add_controller (gesture_primary_click);

        // Implement item context menu launching
        var gesture_secondary_click = new Gtk.GestureClick () {
            button = Gdk.BUTTON_SECONDARY,
            propagation_phase = Gtk.PropagationPhase.CAPTURE
        };
        gesture_secondary_click.released.connect ((n_press, x, y) => {
            show_context_menu_at (x, y);
            gesture_secondary_click.set_state (Gtk.EventSequenceState.CLAIMED);
        });
        add_controller (gesture_secondary_click);

        //Signal Handlers
        multi_selection.selection_changed.connect (() => {
            selection_changed ();
        });

        item_factory.setup.connect ((obj) => {
            var list_item = ((Gtk.ListItem)obj);
            var file_item = new GridFileItem ();
            // var file_item = new GridFileItem (this);
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

        item_factory.bind.connect ((obj) => {
            var list_item = ((Gtk.ListItem)obj);
            var file = (Files.File)list_item.get_item ();
            var file_item = (GridFileItem)list_item.child;
            file_item.bind_file (file);
            file_item.selected = list_item.selected;
            file_item.pos = list_item.position;
        });

        item_factory.unbind.connect ((obj) => {
            var list_item = ((Gtk.ListItem)obj);
            var file_item = (GridFileItem)list_item.child;
            file_item.bind_file (null);
        });

        item_factory.teardown.connect ((obj) => {
            var list_item = ((Gtk.ListItem)obj);
            var file_item = (GridFileItem)list_item.child;
            fileitem_list.remove (file_item);
        });

        menu_popover.closed.connect (() => {
            grid_view.grab_focus (); //FIXME This should happen automatically?
            //Open with submenu must always be at pos 0
            //This is awkward but can only amend open-with-menu by removing and re-adding.
            if (has_open_with) {
                item_menu.remove (0);
                has_open_with = false;
            }
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
    }

    /* Private methods */
    private void refresh_view () {
        // Needed to load thumbnails when settings change.  Is there a better way?
        grid_view.model = null;
        Idle.add (() => {
            grid_view.model = multi_selection;
            return Source.REMOVE;
        });
    }

    private ZoomLevel get_normal_zoom_level () {
        var zoom = Files.icon_view_settings.get_enum ("default-zoom-level");
        Files.icon_view_settings.set_enum ("zoom-level", zoom);

        return (ZoomLevel)zoom;
    }

    private bool focus_item (uint pos) {
        foreach (var item in fileitem_list) {
            if (item.pos == pos) {
                return item.grab_focus ();
            }
        }

        return false;
    }

    private bool focus_appropriate_item () {
        var item = get_selected_file_item ();
        if (item != null) {
            return item.grab_focus ();
        } else {
            return focus_item (0);
        }
    }

    private Files.GridFileItem? get_item_at (double x, double y) {
        var widget = grid_view.pick (x, y, Gtk.PickFlags.DEFAULT);
        if (widget is GridFileItem) {
            return (GridFileItem)widget;
        } else {
            var ancestor = (GridFileItem)(widget.get_ancestor (typeof (Files.GridFileItem)));
            return ancestor;
        }
    }

    private unowned GridFileItem? get_selected_file_item () {
        //NOTE This assumes that the target selected file is bound to a GridFileItem (ie visible?)
        GLib.List<Files.File>? selected_files = null;
        if (get_selected_files (out selected_files) == 1) {
            return get_file_item_for_file (selected_files.data);
        }

        return null;
    }

    private unowned GridFileItem? get_file_item_for_file (Files.File file) {
        foreach (unowned var file_item in fileitem_list) {
            if (file_item.file == file) {
                return file_item;
            }
        }

        return null;
    }

    /* View Interface abstract methods */
    private void show_context_menu_at (double x, double y) {
        var item = get_item_at (x, y);
        show_context_menu (item, x, y);
    }

    public void show_context_menu (FileItemInterface? item, double x, double y) {
        // If no selected item show background context menu
        double menu_x, menu_y;
        MenuModel menu;
        if (item == null) {
            menu_x = x;
            menu_y = y;
            menu = background_menu;
        } else {
            Graphene.Point point_item, point_gridview;
            item.compute_point (grid_view, {(float)x, (float)y}, out point_gridview);

            if (!item.selected) {
                multi_selection.select_item (item.pos, true);
            }

            List<Files.File> selected_files = null;
            get_selected_files (out selected_files);

            var open_with_menu = new Menu ();
            var open_with_apps = MimeActions.get_applications_for_files (selected_files, Config.APP_NAME, true, true);
            foreach (var appinfo in open_with_apps) {
                open_with_menu.append (
                    appinfo.get_name (),
                    Action.print_detailed_name ("win.open-with", new Variant.string (appinfo.get_commandline ()))
                );
            }

            assert (!has_open_with); //Must not add twice
            item_menu.prepend_submenu (_("Open With"), open_with_menu);
            has_open_with = true;
            menu_x = (double)point_gridview.x;
            menu_y = (double)point_gridview.y;
            menu = item_menu;
        }

        menu_popover.menu_model = menu;
        menu_popover.set_pointing_to ({(int)x, (int)y, 1, 1});
        Idle.add (() => {
          menu_popover.popup ();
          return Source.REMOVE;
        });
    }

    public void show_appropriate_context_menu () { //Deal with Menu Key
        if (list_store.get_n_items () > 0) {
            List<Files.File> selected_files = null;
            var n_selected = get_selected_files (out selected_files);
            if (n_selected > 0) {
                Files.File first_file = selected_files.first ().data;
                show_and_select_file (first_file, false, false); //Do not change selection
                var item = get_file_item_for_file (first_file);
                show_context_menu (item, 0.0, 0.0);
                return;
            }
        }

        show_context_menu (null, 0.0, 0.0);
    }

    /* View Interface virtual methods */
    public override void clear () {
        list_store.remove_all ();
        rename_after_add = false;
        select_after_add = false;
    }

    public override void refresh_visible_items () {
        foreach (var file_item in fileitem_list) {
            file_item.rebind ();
        }
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

    public override void show_and_select_file (
        Files.File? file, bool select, bool unselect_others, bool show = true
    ) {
        uint pos = 0;
        if (file != null) {
            list_store.find_with_equal_func (file, file_equal_func, out pos); //Inefficient?
        }

        //TODO Check pos same in sorted model and list_store
        if (select) {
            multi_selection.select_item (pos, unselect_others);
        }

        if (show) {
            // Move specified item to top
            //TODO Work out how to move to middle of visible area? Need number of columns/width of fileitem?
            //Idle until gridview layed out.
            Idle.add (() => {
                var adj = scrolled_window.vadjustment;
                adj.value = adj.upper * double.min (
                    (double)pos / (double) list_store.get_n_items (), adj.upper
                );
                focus_item (pos);
                return Source.REMOVE;
            });
        }
    }

    public override void select_files (List<Files.File> files_to_select) {
    warning ("GV select files");
        foreach (var file in files_to_select) {
            show_and_select_file (file, true, false, false);
        }
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

    public override void open_selected (Files.OpenFlag flag) {
        warning ("open selected %s", flag.to_string ());
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

    public uint get_selected_files (out GLib.List<Files.File>? selected_files = null) {
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

    public override bool grab_focus () {
        if (grid_view != null) {
            return focus_appropriate_item ();
        } else {
            return false;
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

    private Gdk.Paintable get_paintable_for_drag (GridFileItem dragged_item, uint item_count) {
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
                        path_change_request (droptarget.file.location, Files.OpenFlag.DEFAULT);
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
