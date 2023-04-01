/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later

 * Authored by: Jeremy Wootten <jeremy@elementaryos.org>
*/

public class Files.ListView : Gtk.Widget, Files.ViewInterface, Files.DNDInterface {
    static construct {
        set_layout_manager_type (typeof (Gtk.BinLayout));
    }

    protected Gtk.ScrolledWindow scrolled_window { get; set; }

    //ViewInterface properties
    protected Gtk.PopoverMenu popover_menu { get; set; }
    protected GLib.ListStore root_store { get; set; } // Root model of tree
    private Gtk.TreeListModel tree_model;
    protected Gtk.FilterListModel filter_model { get; set; }
    protected Gtk.MultiSelection multi_selection { get; set; }
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
    private Gtk.ColumnViewColumn name_column;
    private Gtk.ColumnViewColumn size_column;
    private Gtk.ColumnViewColumn type_column;
    private Gtk.ColumnViewColumn modified_column;

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

    private Gee.HashMap<string, Subdirectory> subdirectory_map;

    public ListView (Files.Slot slot) {
        Object (slot: slot);
    }

    ~ListView () {
        clear ();
        debug ("GridView destruct");
        while (this.get_last_child () != null) {
            this.get_last_child ().unparent ();
        }
    }

    construct {
        set_layout_manager (new Gtk.BinLayout ());
        subdirectory_map = new Gee.HashMap<string, Subdirectory> ();

        column_view = new Gtk.ColumnView (null) {
            enable_rubberband = true,
            focusable = true,
            show_column_separators = true
        };

        set_model (set_up_model ());

        bind_prefs ();
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
            assert (obj is Gtk.ListItem);
            var list_item = ((Gtk.ListItem)obj);
            var file_item = new GridFileItem (this);
            list_item.set_data<GridFileItem> ("file-item", file_item);
            fileitem_list.prepend (file_item);
            bind_property (
                "zoom-level",
                file_item, "zoom-level",
                BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE
            );
            var expander = new Gtk.TreeExpander ();
            expander.set_child (file_item);

            list_item.child = expander;
            // We handle file activation ourselves in GridFileItem
            list_item.activatable = false;
            list_item.selectable = false;
        });
        name_item_factory.bind.connect ((obj) => {
            Object child;
            var list_item = (Gtk.ListItem)obj;
            var file = get_file_and_child (list_item, out child);
            var expander = (Gtk.TreeExpander)(child);
            expander.list_row = ((Gtk.TreeListRow)list_item.get_item ());
            expander.list_row.notify["expanded"].connect (() => {
                if (expander.list_row.expanded) {
                    if (subdirectory_map.has_key (file.uri)) {
                        var subdir = subdirectory_map.get (file.uri);
                        subdir.expand ();
                    }
                } else {
                    // Need to unexpand  this and all child folders (like Nautilus)
                    foreach (var key in subdirectory_map.keys) {
                        if (key.has_prefix (file.uri)) {
                            subdirectory_map.get (key).collapse ();
                        }
                    }
                }
            });
            list_item.selectable = !file.is_dummy;

            var file_item = (GridFileItem)(expander.child);
            file_item.bind_file (file);
            file_item.selected = !file.is_dummy && list_item.selected;
            file_item.pos = list_item.position;
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
        size_item_factory.bind.connect ((obj) => {
            Object child;
            var file = get_file_and_child (obj, out child);
            ((Gtk.Label)child).label = file.format_size;
        });
        type_item_factory.bind.connect ((obj) => {
            Object child;
            var file = get_file_and_child (obj, out child);
            ((Gtk.Label)child).label = file.formated_type;
        });
        modified_item_factory.bind.connect ((obj) => {
            Object child;
            var file = get_file_and_child (obj, out child);
            ((Gtk.Label)child).label = file.formated_modified;
        });

        name_item_factory.teardown.connect ((obj) => {
            assert (obj is Gtk.ListItem);
            fileitem_list.remove (obj.get_data<GridFileItem> ("file-item"));
        });

        name_column = new Gtk.ColumnViewColumn (_("Name"), name_item_factory) {
            expand = true,
            resizable = true,
        };
        var name_sorter = new Gtk.CustomSorter ((a, b) => {
            return ((Files.File)a).compare_for_sort (
                ((Files.File)b), Files.SortType.FILENAME, prefs.sort_directories_first, false
            );
        });
        name_column.set_sorter (name_sorter);

        size_column = new Gtk.ColumnViewColumn (_("Size"), size_item_factory) {
            expand = false,
            resizable = false
        };
        var size_sorter = new Gtk.CustomSorter ((a, b) => {
            return ((Files.File)a).compare_for_sort (
                ((Files.File)b), Files.SortType.SIZE, prefs.sort_directories_first, false
            );
        });
        size_column.set_sorter (size_sorter);

        type_column = new Gtk.ColumnViewColumn (_("Type"), type_item_factory) {
            expand = false,
            resizable = true
        };
        var type_sorter = new Gtk.CustomSorter ((a, b) => {
            return ((Files.File)a).compare_for_sort (
                ((Files.File)b), Files.SortType.TYPE, prefs.sort_directories_first, false
            );
        });
        type_column.set_sorter (type_sorter);

        modified_column = new Gtk.ColumnViewColumn (_("Modified"), modified_item_factory) {
            expand = true,
            resizable = true
        };
        var modified_sorter = new Gtk.CustomSorter ((a, b) => {
            return ((Files.File)a).compare_for_sort (
                ((Files.File)b), Files.SortType.MODIFIED, prefs.sort_directories_first, false
            );
        });
        modified_column.set_sorter (modified_sorter);

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

        //TODO Restore saved sort order when directory loads.
        // Default to Name Ascending.
        column_view.sort_by_column (name_column, Gtk.SortType.ASCENDING);

        notify["sort-type"].connect (set_sort);
        notify["sort-reversed"].connect (set_sort);
    }

    protected Files.File get_file_and_child (
        Object obj,
        out Object child
    ) {
        var list_item = (Gtk.ListItem)obj;
        var item = list_item.get_item ();
        child = list_item.child;
        var fileobj = ((Gtk.TreeListRow)item).get_item ();
        return (Files.File)fileobj;
    }

    protected Gtk.CustomFilter get_custom_filter () {
        return new Gtk.CustomFilter ((obj) => {
            return true;
        });
    }

    private void set_sort () {
        // Need to set sort column to null in order to remove arrow (Gtk bug?)
        column_view.sort_by_column (null, Gtk.SortType.ASCENDING);
        var direction = sort_reversed ? Gtk.SortType.DESCENDING : Gtk.SortType.ASCENDING;
        switch (sort_type) {
            case Files.SortType.FILENAME:
                column_view.sort_by_column (name_column, direction);
                break;
            case Files.SortType.SIZE:
                column_view.sort_by_column (size_column, direction);
                break;
            case Files.SortType.TYPE:
                column_view.sort_by_column (type_column, direction);
                break;
            case Files.SortType.MODIFIED:
                column_view.sort_by_column (modified_column, direction);
                break;
        }
    }

    protected override ListModel set_up_list_model () {
        root_store = new ListStore (typeof (Files.File));
        tree_model = new Gtk.TreeListModel (
            root_store,
            false, //Passthrough - must be false for expanders to work
            false, //autoexpand
            new_model_func // Function to create child model
        );
        return tree_model;
    }

    private ListModel? new_model_func (Object obj) {
        Object child;
        var file = (Files.File)obj;
        if (file != null && file.is_folder ()) {
            //For some reason this function gets called multiple times on same folder
            // Creating a new model every time leads to infinite loop and crash
            if (subdirectory_map.has_key (file.uri)) {
                return (ListModel)(subdirectory_map.get (file.uri).model);
            }

            var new_liststore = new ListStore (typeof (Files.File));
            var dir = Files.Directory.from_gfile (file.location);
            var subdir = new Subdirectory (dir, new_liststore, this);
            subdirectory_map.set (file.uri, subdir); //Keep reference to directory
            return new_liststore;
        } else {
            return null;
        }
    }

    protected override ListModel set_up_sort_model (ListModel list_model) {
        var multi_sorter = new Gtk.MultiSorter ();
        var column_sorter = column_view.get_sorter ();
        var row_sorter = new Gtk.TreeListRowSorter (column_sorter);
        var dir_sorter = new Gtk.CustomSorter ((a, b) => {
            if (!prefs.sort_directories_first) {
                return 0;
            }

            var rowa = (Gtk.TreeListRow)a;
            var rowb = (Gtk.TreeListRow)b;
            if (rowa.depth != rowb.depth) {
                return 0;
            }

            var filea = (Files.File)(rowa.get_item ());
            var fileb = (Files.File)(rowb.get_item ());
            var a_is_dir = filea.is_folder ();
            var b_is_dir = fileb.is_folder ();

            if (a_is_dir == b_is_dir) {
                return 0;
            } else {
                return a_is_dir ? -1 : 1;
            }
        });

        multi_sorter.append (dir_sorter);
        multi_sorter.append (row_sorter);
        return new Gtk.SortListModel (list_model, multi_sorter);
    }

    protected override Files.File? get_file_from_selection_pos (uint pos) {
        return (Files.File)(((Gtk.TreeListRow)(multi_selection.get_item (pos))).get_item ());
    }

    public void set_model (Gtk.SelectionModel? model) {
        column_view.set_model (model);
    }

    public override void clear () {
        clear_root ();
        subdirectory_map.clear ();
        //TODO Fix any memory leak
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

//     /* View Interface abstract methods */
    //Cannot move entirely to interface because of plugins hook
    public void show_context_menu (FileItemInterface? item, double x, double y) {
        var selected_files = build_popover_menu (item, x, y, Config.APP_NAME);
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

    public void set_up_zoom_level () {
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

    private class Subdirectory : Object {
        public Directory directory { get; construct; }
        public unowned ListView list_view { get; construct; }
        public ListStore model { get; construct; }
        public bool loaded { get; private set; default = false; }
        public string uri { get; construct; }
        private Files.File dummy;
        private bool is_empty = true;

        public Subdirectory (Directory dir, ListStore model, ListView view) {
            Object (
                directory: dir,
                uri: dir.file.uri,
                model: model,
                list_view: view
            );

            dummy = Files.File.get_dummy (dir.file);
            model.append (dummy);
        }

        ~Subdirectory () {
            debug ("Subdirectory destruct %s", uri);
        }

        private void on_file_added (Directory dir, Files.File? file, bool is_internal) {
            if (is_empty) {
                mark_empty (false);
            }

            list_view.add_file (file, model);
        }

        private void on_file_deleted (Directory dir, Files.File? file) {
            list_view.file_deleted (file, model);
            if (model.get_n_items () == 0) {
                mark_empty (true);
            }
        }

        private void mark_empty (bool mark_empty) {
            if (mark_empty) {
                model.append (dummy);
                is_empty = true;
            } else {
                model.remove (0);
                is_empty = false;
            }
        }
        public void expand () {
            directory.file.set_expanded (true);
            if (!loaded) {
                directory.init.begin (null, () => {
                    loaded = true;
                    if (directory.displayed_files_count > 0) {
                        model.remove (0);
                        is_empty = false;
                    }

                    list_view.add_files (directory.get_files (), model);

                    directory.file_added.connect (on_file_added);
                    directory.file_deleted.connect (on_file_deleted);
                });
            }
        }

        public void collapse () {
            directory.file.set_expanded (false);
        }

        public void clear () {
            directory.file_added.disconnect (on_file_added);
            directory.file_deleted.disconnect (on_file_deleted);
            directory.file.set_expanded (false);
            loaded = false;
            model.remove_all ();
        }
    }
}
