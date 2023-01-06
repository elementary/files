/*
* Copyright 2022 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Jeremy Wootten <jeremy@elementaryos.org>
*/

// This interface assumes that the view widget is or contains a Gtk.ListBase widget
// (GridView or ListView or ColumnView) in order to maximise shared code.
// If this were no longer to be the case then several methods would have to be virtualised and
// reimplemented in the actual view which does not use a dynamic widget.
public interface Files.ViewInterface : Gtk.Widget {
    // Properties defined in template.
    protected abstract Menu background_menu { get; set; }
    protected abstract Menu item_menu { get; set; }

    public abstract SlotInterface slot { get; set construct; }
    public virtual Files.File? root_file {
        get {
            return slot.directory.file;
        }
    }

    /* Abstract properties */
    protected abstract Files.Preferences prefs { get; default = Files.Preferences.get_default (); }
    protected abstract GLib.ListStore root_store { get; set; }
    protected abstract Gtk.FilterListModel filter_model { get; set; }
    protected abstract Gtk.MultiSelection multi_selection { get; set; }
    protected abstract Gtk.ScrolledWindow scrolled_window { get; set; }
    protected abstract Gtk.PopoverMenu popover_menu { get; set; }
    protected abstract unowned GLib.List<Gtk.Widget> fileitem_list { get; set; default = null; }
    public abstract ZoomLevel zoom_level { get; set; }
    public abstract ZoomLevel minimum_zoom { get; set; }
    public abstract ZoomLevel maximum_zoom { get; set; }
    public abstract Files.SortType sort_type { get; set; }
    public abstract bool sort_reversed { get; set; }
    public abstract bool all_selected { get; set; }
    public abstract bool is_renaming { get; set; }
    public abstract bool rename_after_add { get; set; }
    public abstract bool select_after_add { get; set; }
    protected abstract bool has_open_with { get; set; default = false;}

    public signal void selection_changed (); // No obvious way to avoid this signal

    // Functions specific to particular view
    public abstract void set_up_zoom_level ();
    public abstract ZoomLevel get_normal_zoom_level ();
    public abstract void set_model (Gtk.SelectionModel? model);

    // The view widget must have a "model" property that is a GtkSelectionModel
    public abstract unowned Gtk.Widget get_view_widget ();
    //Functions requiring access to src
    public abstract void show_context_menu (Files.FileItemInterface? clicked_item, double x, double y) ;

    protected virtual void build_ui (Gtk.Widget view_widget) {
        var builder = new Gtk.Builder.from_resource ("/io/elementary/files/View.ui");
        item_menu = (Menu)(builder.get_object ("item_model"));
        background_menu = (Menu)(builder.get_object ("background_model"));
        item_menu.set_data<List<AppInfo>> ("open-with-apps", new List<AppInfo> ());
        scrolled_window = (Gtk.ScrolledWindow)(builder.get_object ("scrolled-window"));
        scrolled_window.child = view_widget;
        scrolled_window.set_parent (this);
        popover_menu = new Gtk.PopoverMenu.from_model_full (new Menu (), Gtk.PopoverMenuFlags.NESTED) {
          has_arrow = false
        };
        popover_menu.set_parent (this);
    }

    protected virtual void set_up_gestures () {
        // Implement single-click navigate
        var gesture_primary_click = new Gtk.GestureClick () {
            button = Gdk.BUTTON_PRIMARY,
            propagation_phase = Gtk.PropagationPhase.BUBBLE //selection helper handles before
        };
        get_view_widget ().add_controller (gesture_primary_click);
        gesture_primary_click.released.connect (handle_primary_release);
        gesture_primary_click.set_data<uint> ("timeout-id", 0);

        // Implement item context menu launching
        var gesture_secondary_click = new Gtk.GestureClick () {
            button = Gdk.BUTTON_SECONDARY,
            propagation_phase = Gtk.PropagationPhase.BUBBLE
        };
        get_view_widget ().add_controller (gesture_secondary_click);
        gesture_secondary_click.released.connect ((n_press, x, y) => {
            var item = get_item_at (x, y);
            if (item == null) {
                unselect_all ();
            }

            show_context_menu (item, x, y);
            gesture_secondary_click.set_state (Gtk.EventSequenceState.CLAIMED);
        });

        var key_controller = new Gtk.EventControllerKey () {
            propagation_phase = Gtk.PropagationPhase.CAPTURE
        };
        get_view_widget ().add_controller (key_controller);
        key_controller.key_pressed.connect ((val, code, state) => {
            switch (val) {
                case Gdk.Key.Escape:
                    if (state == 0) {
                        unselect_all ();
                        return true;
                    }

                    break;
                case Gdk.Key.Tab:
                    if (state == 0) {
                        activate_action ("win.focus-sidebar", null, null);
                        return true;
                    }

                    break;
                default:
                    break;
            }

            return false;
        });
    }

    protected void bind_prefs () {
        prefs.notify["sort-directories-first"].connect (() => {
            sort_model (file_compare_func);
        });
        prefs.notify["show-hidden-files"].connect (() => {
            // This refreshes the filter as well
            sort_model (file_compare_func);
        });
        prefs.notify["show-remote-thumbnails"].connect (() => {
            if (prefs.show_remote_thumbnails) {
                refresh_thumbnails ();
            }
        });
        prefs.notify["hide-local-thumbnails"].connect (() => {
            if (!prefs.hide_local_thumbnails) {
                refresh_thumbnails ();
            }
        });
    }

    protected void bind_sort () {
        notify["sort-type"].connect (() => {
            sort_model (file_compare_func);
        });
        notify["sort-reversed"].connect (() => {
            sort_model (file_compare_func);
            //TODO Persist setting in file metadata
        });
    }

    protected abstract void sort_model (CompareDataFunc<Object> compare_func);

    protected void bind_popover_menu () {
        popover_menu.closed.connect_after (() => {
            //Need Idle else actions not triggered
            Idle.add (() => {
                grab_focus (); //FIXME This should happen automatically?
                //Open with submenu must always be at pos 0
                //This is awkward but can only amend open-with-menu by removing and re-adding.
                if (has_open_with) {
                    item_menu.remove (0);
                    has_open_with = false;
                }
                // This removes any custom widgets (?)
                popover_menu.menu_model = null;
                return Source.REMOVE;
            });
        });
    }

    public void grab_focus () {
warning ("grab focus");
        if (get_view_widget () != null) {
            var item = get_selected_file_item ();
            // Assume item already focussed if there is a selection
            if (item != null) {
                item.grab_focus ();
                return;
            }

            //Note not all items may be visible so look at multi-selection
            //TODO Use `n_items` property when using Gtk version >= 4.8
            if (multi_selection.get_n_items () > 0) {
                var first_item = multi_selection.get_item (0);
                Files.File first_file;
                if (first_item is Gtk.TreeListRow) {
                    first_file = (Files.File)(((Gtk.TreeListRow)first_item).get_item ());
                } else {
                    first_file = (Files.File)(first_item);
                }
                show_and_select_file (first_file, false, false, true);
                item = get_file_item_for_file (first_file);
                if (item != null) {
                    item.grab_focus ();
                } else {
                    critical ("Grab focus: failed to get first item");
                }
            } else {
                get_view_widget ().grab_focus ();
            }
        } else {
            critical ("Attempt to focus null view");
        }
    }

    public void unselect_item (uint pos) {
        multi_selection.unselect_item (pos);
    }

    protected Gtk.ListBase? get_list_base () {
        var widget = get_view_widget ();
        Gtk.ListBase? list_base = null;
        if (widget is Gtk.ListBase) {
            list_base = (Gtk.ListBase)widget;
        } else {
            // Handle ColumnView which contains a ListView (private)
            var child = widget.get_first_child ();
            while (child != null && !(child is Gtk.ListBase)) {
                child = child.get_next_sibling ();
            }

            if (child is Gtk.ListBase) {
                list_base = (Gtk.ListBase)child;
            }
        }

        return list_base;
    }

    public void select_and_focus_position (
        uint focus_pos,
        bool change_select = false,
        bool unselect_others = false
    ) {
        var list_base = get_list_base ();
        var prev_select = multi_selection.is_selected (focus_pos);
        // Use this to keep keyboard focus tracking in sync (Workaround for bug report
        // https://gitlab.gnome.org/GNOME/gtk/-/issues/5485#note_1629646
        // Thanks to Nautilus team for this suggestion.
        // OK to deselect in model?
        if (list_base != null) {
            list_base.activate_action (
                "list.select-item",
                "(ubb)",
                focus_pos,
                !unselect_others, // Whther to only modify the current item
                false
            );
        }

        if (!change_select && !prev_select ) { // Focus item always selects
            multi_selection.unselect_item (focus_pos);
        }
    }

    public void zoom_in () {
        if (zoom_level < maximum_zoom) {
            zoom_level = zoom_level + 1;
        }
    }

    public void zoom_out () {
        if (zoom_level > minimum_zoom) {
            zoom_level = zoom_level - 1;
        }
    }
    public void zoom_normal () {
        zoom_level = get_normal_zoom_level ();
    }

    protected virtual int find_file_pos (Files.File file) {
// warning ("find file pos");
        //TODO Override in list view to allow for expanded rows
        uint pos;
        if (root_store.find_with_equal_func (
            file,
            (filea, fileb) => {
// warning ("find file pos");
                return ((Files.File)filea).basename == ((Files.File)fileb).basename;
            },
            out pos
        )) {

            return (int)pos;
        } else {
            return -1;
        }
    }

    public void show_and_select_file (
        Files.File? file,
        bool select,
        bool unselect_others,
        bool show = true
    ) {
        uint pos = 0;
        if (file != null) {
            pos = find_file_pos (file);
        }

        //TODO Check pos same in sorted model and root_store
        if (pos >= 0 && select) {
            select_and_focus_position (pos, select, unselect_others);
        }
        // Do not use this to deselect an item

        if (show) {
            // Idle until gridview layed out.
            Idle.add (() => {
                var adj = scrolled_window.vadjustment;
                adj.value = adj.upper * double.min (
                    (double)pos / (double) root_store.get_n_items (), adj.upper
                );
                // focus_item (pos);
                return Source.REMOVE;
            });
        }
    }

    public void select_files (List<Files.File> files_to_select) {
        foreach (var file in files_to_select) {
            show_and_select_file (file, true, false, false);
        }
    }

    public void select_all () {
        multi_selection.select_all ();
        all_selected = true;
    }

    public void unselect_all () {
        multi_selection.unselect_all ();
        all_selected = false;
    }

    public void invert_selection () {
        uint pos = 0;
        var item = multi_selection.get_item (pos);
        while (item != null) {
            if (multi_selection.is_selected (pos)) {
                multi_selection.unselect_item (pos);
            } else {
                select_and_focus_position (pos, false);
            }

            pos++;
            item = multi_selection.get_item (pos);
        }
    }

    public uint get_selected_files (out GLib.List<Files.File>? selected_files = null) {
warning ("get selected files");
        selected_files = null;
        uint pos = 0;
        uint count = 0;
        var iter = Gtk.BitsetIter ();
        if (iter.init_first (multi_selection.get_selection (), out pos)) {
            selected_files.prepend (
                (Files.File)(((Gtk.TreeListRow)(multi_selection.get_item (pos))).get_item ())
            );
            count++;
            while (iter.next (out pos)) {
                selected_files.prepend (
                     (Files.File)(((Gtk.TreeListRow)(multi_selection.get_item (pos))).get_item ())
                );
                count++;
            }
        }

        return count;
    }

    public virtual void file_deleted (Files.File file) {
        int pos = find_file_pos (file);
        if (pos >= 0) {
            root_store.remove (pos);
        }
    }

    public int file_compare_func (Object filea, Object fileb) {
// warning ("file compare func");
        return ((Files.File)filea).compare_for_sort (
            ((Files.File)fileb), sort_type, prefs.sort_directories_first, sort_reversed
        );
    }

    public void add_file (Files.File file) {
        //TODO Delay sorting until adding finished?
        root_store.insert_sorted (file, file_compare_func);
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

    // Use for initial loading of files
    public void add_files (
        List<unowned Files.File> files,
        ListStore? store = null
    ) requires (root_store != null) {

warning ("adding files");
        //TODO Delay sorting until adding finished?
        set_model (null);
        ListStore add_store;
        if (store == null) {
            add_store = root_store;
        } else {
            add_store = store;
        }
        foreach (var file in files) {
            add_store.append (file);
        }
        add_store.sort (file_compare_func);
        set_model (multi_selection);
        // Need to deal with selection after loading
    }

    public void file_changed (Files.File file) {
        var item = get_file_item_for_file (file);
        if (item != null) {
            item.bind_file (file); // Forces image to update
        }
    }

    public void clear () {
        root_store.remove_all ();
        rename_after_add = false;
        select_after_add = false;
    }

    /* Private methods */
    protected void refresh_thumbnails () {
        // Needed to load thumbnails when settings change.  Is there a better way?
        set_model (null);

        Idle.add (() => {
            set_model (multi_selection);
            grab_focus (); // This will show first file
            return Source.REMOVE;
        });
    }

    public void open_selected (Files.OpenFlag flag) {
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

    public void show_appropriate_context_menu () { //Deal with Menu Key
        if (root_store.get_n_items () > 0) {
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

    protected Gtk.SelectionModel set_up_model () {
        return set_up_selection_model (
            set_up_filter_model (
                set_up_sort_model (
                    set_up_list_model ()
                )
            )
        );
    }

    protected virtual ListModel set_up_sort_model (ListModel list_model) {
        return list_model; // Default ListStore has its own sorter.
    }

    protected virtual ListModel set_up_list_model () {
warning ("create root store");
        root_store = new GLib.ListStore (typeof (Files.File));
        return root_store;
    }

    protected virtual ListModel set_up_filter_model (ListModel list_model) {
warning ("setup filter model");
        filter_model = new Gtk.FilterListModel (list_model, null);
        var custom_filter = new Gtk.CustomFilter ((obj) => {
warning ("custom filter");
            Files.File file;
            if (obj is Gtk.TreeListRow) {
                file = (Files.File)(((Gtk.TreeListRow)obj).get_item ());
            } else {
                file = (Files.File)obj;
            }
            return prefs.show_hidden_files || !file.is_hidden;
        });
        filter_model.set_filter (custom_filter);
        return filter_model;
    }

    protected virtual Gtk.SelectionModel set_up_selection_model (ListModel list_model) {
        multi_selection = new Gtk.MultiSelection (list_model);
        multi_selection.selection_changed.connect (() => {
            selection_changed ();
        });
        return multi_selection;
    }

    protected virtual void handle_primary_release (
        Gtk.EventController controller,
        int n_press,
        double x,
        double y
    ) {
        var id = controller.get_data<uint> ("timeout-id") ;
        if (id > 0) {
            Source.remove (id);
            controller.set_data<uint> ("timeout-id", 0);
        }
        var view_widget = get_view_widget ();
        var widget = view_widget.pick (x, y, Gtk.PickFlags.DEFAULT);
        if (widget == view_widget) { // Click on background
            unselect_all ();
            view_widget.grab_focus ();
        } else {
            var item = get_item_at (x, y);
            if (item == null) {
                return;
            }

            var file = item.file;
            var is_folder = file.is_folder ();
            var mods = controller.get_current_event_state () & ~Gdk.ModifierType.BUTTON1_MASK;
            //FIXME Should we only activate on icon??
            var should_activate = (
                 // Only activate on unmodified single click or double click
                (mods == 0 && n_press == 1 && is_folder && !prefs.singleclick_select) ||
                n_press == 2 // Always activate on double click
            );
            // Activate item
            if (should_activate) {
                unselect_all ();
                if (is_folder) {
                    // We know we can append to multislot
                    //TODO Take mods into account e.g. open in new tab or window?

                    // In Column View in mixed mode, normal activation adds a new column while
                    // double-click starts a new root. However in singleclick_select mode,
                    // Column View always appends a new column.
                    var flag = n_press == 1 || prefs.singleclick_select ?
                               Files.OpenFlag.APPEND : Files.OpenFlag.NEW_ROOT;

                    if (n_press == 1 &&
                        slot.view_mode == ViewMode.MULTICOLUMN &&
                        !prefs.singleclick_select
                    ) {
                        // Need to wait for possible double-click else a slot will append and
                        // may be immediately closed.
                        controller.set_data<uint> ("timeout-id", Timeout.add (
                            Gtk.Settings.get_default ().gtk_double_click_time + 5,
                             () => {
                                controller.set_data<uint> ("timeout-id", 0);
                                //TODO Wait for possible double click before activating
                                change_path (file.location, flag);
                                return Source.REMOVE;
                            }
                        ));

                        return;
                    }

                    change_path (file.location, flag);
                } else {
                    open_file (file, Files.OpenFlag.APP);
                }
            }
        }
        //Allow click to propagate to item selection helper and then Gtk
    }

    protected unowned FileItemInterface? get_selected_file_item () {
        //NOTE This assumes that the target selected file is bound to a GridFileItem (ie visible?)
        GLib.List<Files.File>? selected_files = null;
        if (get_selected_files (out selected_files) == 1) {
            return get_file_item_for_file (selected_files.data);
        }

        return null;
    }

    // Access required by DNDInterface
    public void change_path (GLib.File loc, OpenFlag flag) {
        activate_action ("win.path-change-request", "(su)", loc.get_uri (), flag);
    }

    public Files.FileItemInterface? get_item_at (double x, double y) {
        var view_widget = get_view_widget ();
        var widget = view_widget.pick (x, y, Gtk.PickFlags.DEFAULT);
        if (widget is FileItemInterface) {
            return (FileItemInterface)widget;
        } else {
            var ancestor = (FileItemInterface)(widget.get_ancestor (typeof (Files.FileItemInterface)));
            return ancestor;
        }
    }

    protected unowned FileItemInterface? get_file_item_for_file (Files.File file) {
        foreach (unowned var widget in fileitem_list) {
            assert_nonnull (widget);
            unowned var item = (FileItemInterface)widget;
            if (item.file == file) {
                return item;
            }
        }

        return null;
    }

    public void refresh_visible_items () {
        foreach (var widget in fileitem_list) {
            assert_nonnull (widget);
            unowned var item = (FileItemInterface)widget;
            item.rebind ();
        }
    }

    protected void open_file (Files.File _file, Files.OpenFlag flag) {
        Files.File file = _file;
        if (_file.is_recent_uri_scheme ()) {
            file = Files.File.get_by_uri (file.get_display_target_uri ());
        }

        var is_folder_type = file.is_folder () ||
                             (file.get_ftype () == "inode/directory") ||
                             file.is_root_network_folder ();

        if (file.is_trashed () && !is_folder_type && flag == Files.OpenFlag.APP) {
            PF.Dialogs.show_error_dialog (
                ///TRANSLATORS: '%s' is a quoted placehorder for the name of a file.
                _("“%s” must be moved from Trash before opening").printf (file.basename),
                _("Files inside Trash cannot be opened. To open this file, it must be moved elsewhere."),
                (Gtk.Window)get_ancestor (typeof (Gtk.Window))
            );
            return;
        }

        var default_app = MimeActions.get_default_application_for_file (file);
        var location = file.get_target_location ();
        switch (flag) {
            case Files.OpenFlag.NEW_TAB:
            case Files.OpenFlag.NEW_WINDOW:
            case Files.OpenFlag.NEW_ROOT:
                change_path (location, flag);
                break;
            case Files.OpenFlag.DEFAULT: // Take default action
                if (is_folder_type) {
                    change_path (location, flag);
                } else if (file.is_executable ()) {
                    var content_type = FileUtils.get_or_guess_content_type (file);
                    //Do not execute scripts, desktop files etc
                    if (!ContentType.is_a (content_type, "text/plain")) {
                        try {
                            file.execute (null);
                        } catch (Error e) {
                            PF.Dialogs.show_warning_dialog (
                                _("Cannot execute this file"),
                                e.message,
                                (Gtk.Window)get_ancestor (typeof (Gtk.Window)
                            ));
                        }

                        return;
                    }
                } else {
                    if (FileUtils.can_open_file (
                            file, true, (Gtk.Window)get_ancestor (typeof (Gtk.Window)))
                        ) {
                        MimeActions.open_glib_file_request (file.location, this, default_app);
                    }
                }

                break;
            case Files.OpenFlag.APP:
                if (FileUtils.can_open_file (
                        file, true, (Gtk.Window)get_ancestor (typeof (Gtk.Window)))
                    ) {
                    MimeActions.open_glib_file_request (file.location, this, default_app);
                }
                break;
        }
    }
}
