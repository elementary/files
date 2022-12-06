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
    protected abstract GLib.ListStore list_store { get; set; }
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
    public virtual void grab_focus () {}
    public abstract void set_up_zoom_level ();
    public abstract ZoomLevel get_normal_zoom_level ();

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

    public virtual void show_and_select_file (
        Files.File? file, bool select, bool unselect_others, bool show = true
    ) {}
    public virtual void select_files (List<Files.File> files_to_select) {}
    public virtual void invert_selection () {}
    public virtual void select_all () {}
    public virtual void unselect_all () {}
    public virtual void file_deleted (Files.File file) {}
    public virtual void file_changed (Files.File file) {}
    public virtual void add_file (Files.File file) {}
    public virtual void clear () {}

    public virtual void open_selected (Files.OpenFlag flag) {}
    public virtual void change_path (GLib.File loc, OpenFlag flag) {}

    public abstract void show_context_menu (Files.FileItemInterface? clicked_item, double x, double y);
    public abstract void show_appropriate_context_menu ();
    public abstract uint get_selected_files (out GLib.List<Files.File>? selected_files = null);

    protected abstract unowned Gtk.Widget get_view_widget ();

    protected virtual void set_up_model () {
        list_store = new GLib.ListStore (typeof (Files.File));
        filter_model = new Gtk.FilterListModel (list_store, null);
        var custom_filter = new Gtk.CustomFilter ((obj) => {
            var file = (Files.File)obj;
            return prefs.show_hidden_files || !file.is_hidden;
        });
        filter_model.set_filter (custom_filter);
        multi_selection = new Gtk.MultiSelection (filter_model);
        multi_selection.selection_changed.connect (() => {
            selection_changed ();
        });
    }

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
            propagation_phase = Gtk.PropagationPhase.CAPTURE
        };
        gesture_primary_click.released.connect (handle_primary_release);
        get_view_widget ().add_controller (gesture_primary_click);

        // Implement item context menu launching
        var gesture_secondary_click = new Gtk.GestureClick () {
            button = Gdk.BUTTON_SECONDARY,
            propagation_phase = Gtk.PropagationPhase.CAPTURE
        };
        gesture_secondary_click.released.connect ((n_press, x, y) => {
            var item = get_item_at (x, y);
            show_context_menu (item, x, y);
            gesture_secondary_click.set_state (Gtk.EventSequenceState.CLAIMED);
        });
        get_view_widget ().add_controller (gesture_secondary_click);
    }

    protected virtual void handle_primary_release (int n_press, double x, double y) {
        var view_widget = get_view_widget ();
        var widget = view_widget.pick (x, y, Gtk.PickFlags.DEFAULT);
        if (widget == view_widget) { // Click on background
            unselect_all ();
            view_widget.grab_focus ();
        } else {
            var should_activate = (
                widget is Gtk.Image &&
                (n_press == 1 && !prefs.singleclick_select) ||
                n_press == 2 // Always activate on double click
            );
            // Activate item
            var item = get_item_at (x, y);
            if (should_activate) {
                unselect_all ();
                var file = item.file;
                if (file.is_folder ()) {
                    // We know we can append to multislot
                    change_path (file.location, Files.OpenFlag.APPEND);
                } else {
                    warning ("Open file with app");
                }
            }
        }
        //Allow click to propagate to item selection helper and then Gtk
    }

    protected void focus_item (uint pos) {
        foreach (var widget in fileitem_list) {
            assert_nonnull (widget);
            var item = (FileItemInterface)widget;
            if (item.pos == pos) {
                item.grab_focus ();
            }
        }
    }

    protected unowned FileItemInterface? get_selected_file_item () {
        //NOTE This assumes that the target selected file is bound to a GridFileItem (ie visible?)
        GLib.List<Files.File>? selected_files = null;
        if (get_selected_files (out selected_files) == 1) {
            return get_file_item_for_file (selected_files.data);
        }

        return null;
    }

    protected Files.FileItemInterface? get_item_at (double x, double y) {
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
