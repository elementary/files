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
public class Files.GridView : Gtk.Widget, Files.ViewInterface {
    private static Files.Preferences prefs;
    static construct {
        set_layout_manager_type (typeof (Gtk.BinLayout));
        prefs = Files.Preferences.get_default ();
    }

    // Components defined in GridView.ui template file
    [GtkChild]
    private unowned Gtk.ScrolledWindow? scrolled_window;
    [GtkChild]
    private unowned Gtk.PopoverMenu? menu_popover;
    [GtkCallback]
    public void secondary_release_handler (int n_press, double x, double y) {
        show_context_menu (background_gmenu, x, y);
    }
    [GtkCallback]
    public void on_grid_view_activate (uint pos) {
        var file = (Files.File)grid_view.model.get_item (pos);
        if (file.is_folder () && multi_selection.get_selection ().get_size () == 1) {
            path_change_request (file.location);
        } else {
            warning ("Open file with app");
        }
    }

    // Properties defined in template NOTE: cannot use construct; here
    public Gtk.GridView grid_view { get; set; }
    public MenuModel background_gmenu { get; set; }
    public MenuModel item_gmenu { get; set; }

    // Construct properties
    public GLib.ListStore list_store { get; construct; }
    public Gtk.MultiSelection multi_selection { get; construct; }

    //Interface properties
    public ZoomLevel zoom_level { get; set; default = ZoomLevel.NORMAL; }
    public ZoomLevel minimum_zoom { get; set; default = ZoomLevel.SMALLEST; }
    public ZoomLevel maximum_zoom { get; set; default = ZoomLevel.LARGEST; }
    public Files.SortType sort_type { get; set; default = Files.SortType.FILENAME; }
    public bool sort_reversed { get; set; default = false; }
    public bool all_selected { get; set; default = false; }
    public bool is_renaming { get; set; default = false; }

    private CompareDataFunc<Files.File>? file_compare_func;
    private EqualFunc<Files.File>? file_equal_func;
    private GLib.List<GridFileItem> fileitem_list;

    ~GridView () {
        while (this.get_last_child () != null) {
            this.get_last_child ().unparent ();
        }
    }

    construct {
        set_layout_manager (new Gtk.BinLayout ());
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

        fileitem_list = new GLib.List<GridFileItem> ();
        var item_factory = new Gtk.SignalListItemFactory ();
        item_factory.setup.connect ((obj) => {
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

        grid_view.model = multi_selection;
        grid_view.factory = item_factory;
        scrolled_window.child = grid_view;

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
        //FIXME This should happen automatically?
        menu_popover.closed.connect (() => {
            grid_view.grab_focus ();
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

    public override void refresh_visible_items () {
        foreach (var file_item in fileitem_list) {
            file_item.rebind ();
        }
    }

    public override void add_file (Files.File file) {
        //TODO Delay sorting until adding finished?
        list_store.insert_sorted (file, file_compare_func);
        Idle.add (() => {
            file_added (file);
            return Source.REMOVE;
        });
    }

    public override void clear () {
        list_store.remove_all ();
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

    public override void show_and_select_file (
        Files.File? file, bool select, bool unselect_others
    ) {
        uint pos = 0;
        if (file != null) {
            list_store.find_with_equal_func (file, file_equal_func, out pos); //Inefficient?
        } else {
            return;
        }

        //TODO Check pos same in sorted model and list_store
        if (select) {
            multi_selection.select_item (pos, unselect_others);
        }

        // Move focused item to top
        //TODO Work out how to move to middle of visible area? Need number of columns/width of fileitem?
        //Idle until gridview layed out.
        Idle.add (() => {
            var adj = scrolled_window.vadjustment;
            adj.value = adj.upper * double.min (
                (double)pos / (double) list_store.get_n_items (), adj.upper
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
        if (list_store.find (file, out pos)) {
            list_store.remove (pos);
        }
    }

    public void show_item_context_menu (Files.FileItemInterface? clicked_item, double x, double y) {
        var item = clicked_item;
        // clicked_item is null if called by keyboard action
        if (item == null) {
            List<Files.File> selected_files = null;
            if (get_selected_files (out selected_files) > 0) {
                Files.File first_file = selected_files.first ().data;
                show_and_select_file (first_file, false, false); //Do not change selection
                item = get_file_item_for_file (first_file);
            }
        }
        // If no selected item show background context menu
        if (item == null) {
            show_context_menu (background_gmenu, x, y);
        } else {
            if (!item.selected) {
                multi_selection.select_item (item.pos, true);
            }

            show_context_menu (item_gmenu, x, y);
        }
    }

    private void show_context_menu (MenuModel menu_model, double x, double y) {
        menu_popover.menu_model = menu_model;
        menu_popover.set_pointing_to ({(int)x, (int)y, 1, 1});
        Idle.add (() => {
          menu_popover.popup ();
          return Source.REMOVE;
        });
    }

    //Deal with Menu Key
    public void show_appropriate_context_menu () {
        if (list_store.get_n_items () > 0) {
            if (get_selected_files () > 0) {
                show_context_menu (item_gmenu, 0.0, 0.0);
            } else {
                show_context_menu (background_gmenu, 0.0, 0.0);
            }
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


    public override void file_icon_changed (Files.File file) {}
    public override void file_changed (Files.File file) {} //TODO Update thumbnail
}
