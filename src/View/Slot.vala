/***
    Copyright (c) 2015-2018 elementary LLC <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/

namespace Files {
public class Slot : Files.AbstractSlot {
    private unowned Files.ViewContainer ctab;
    private ViewMode mode;
    private int preferred_column_width;
    private Files.DirectoryView? dir_view = null;
    public Files.ViewInterface? view_widget {
        get {
            if (dir_view != null) {
                return dir_view.view_widget;
            } else {
                return null;
            }
        }
    }

    private uint reload_timeout_id = 0;
    private uint path_change_timeout_id = 0;
    private bool original_reload_request = false;

    private const string EMPTY_MESSAGE = _("This Folder Is Empty");
    private const string EMPTY_TRASH_MESSAGE = _("Trash Is Empty");
    private const string EMPTY_RECENT_MESSAGE = _("There Are No Recent Files");
    private const string DENIED_MESSAGE = _("Access Denied");

    public bool is_active {get; protected set;}
    public int displayed_files_count {
        get {
            if (directory != null && directory.state == Directory.State.LOADED) {
                return (int)(directory.displayed_files_count);
            }

            return -1;
        }
    }

    public unowned Files.Window window {
        get {return ctab.window;}
    }

    public override bool is_frozen {
        set {
            dir_view.is_frozen = value;
            frozen_changed (value);
        }

        get {
            return dir_view == null || dir_view.is_frozen;
        }
    }

    public override bool locked_focus {
        get {
            return dir_view.renaming;
        }
    }

    public signal void frozen_changed (bool freeze);
    public signal void folder_deleted (Files.File file, Directory parent);

    /* Support for multi-slot view (Miller)*/
    public Gtk.Box colpane;
    public Gtk.Paned hpane;
    public signal void miller_slot_request (GLib.File file, bool make_root);
    public signal void size_change ();

    public Slot (GLib.File _location, ViewContainer _ctab, ViewMode _mode) {
        ctab = _ctab;
        mode = _mode;
        is_active = false;
        preferred_column_width = Files.column_view_settings.get_int ("preferred-column-width");
        width = preferred_column_width;

        set_up_directory (_location); /* Connect dir signals before making view */
        make_view ();
        connect_dir_view_signals ();
        connect_view_widget_signals ();
        connect_slot_signals ();

        is_frozen = true;
    }

    ~Slot () {
        debug ("Slot %i destruct", slot_number);
        // Ensure dir view does not redraw with invalid slot, causing a crash
        dir_view.destroy ();
    }

    private void connect_slot_signals () {
        active.connect (() => {
            if (is_active) {
                return;
            }

            is_active = true;
            view_widget.grab_focus ();
        });

        inactive.connect (() => {
            is_active = false;
        });

        folder_deleted.connect ((file, dir) => {
           ((Files.Application)(window.application)).folder_deleted (file.location);
        });
    }

    private void connect_view_widget_signals () {
        view_widget.path_change_request.connect (path_change_requested);
    }
    private void connect_dir_view_signals () {
        dir_view.selection_changed.connect (on_dir_view_selection_changed);
    }

    private void disconnect_dir_view_signals () {
        dir_view.selection_changed.disconnect (on_dir_view_selection_changed);
    }

    private void on_dir_view_selection_changed (GLib.List<Files.File> files) {
        selection_changed (files);
    }

    private void connect_dir_signals () {
        directory.done_loading.connect (on_directory_done_loading);
        directory.need_reload.connect (on_directory_need_reload);
    }

    private void disconnect_dir_signals () {
        directory.done_loading.disconnect (on_directory_done_loading);
        directory.need_reload.disconnect (on_directory_need_reload);
    }

    private void on_directory_done_loading (Directory dir) {
        directory_loaded (dir);

        /*  Column View requires slots to determine their own width (other views' width determined by Window */
        if (mode == ViewMode.MILLER_COLUMNS) {

            if (dir.is_empty ()) { /* No files in the file cache */
                Pango.Rectangle extents;
                var layout = dir_view.create_pango_layout (null);
                layout.set_markup (get_empty_message (), -1);
                layout.get_extents (null, out extents);
                width = (int) Pango.units_to_double (extents.width);
            } else {
                width = preferred_column_width;
            }

            width += view_widget.zoom_level.to_icon_size () + 64; /* allow some extra room for icon padding and right margin*/

            /* Allow extra room for MESSAGE_CLASS styling of special messages */
            if (dir.is_empty () || dir.permission_denied) {
                width += width;
            }

            size_change ();
            hpane.set_position (width);

            if (colpane.get_realized ()) {
                colpane.queue_draw ();
            }
        }

        is_frozen = false;
    }

    private void on_directory_need_reload (Directory dir, bool original_request) {
        if (!is_frozen) {
            dir_view.prepare_reload (dir); /* clear model but do not change directory */
            /* view and slot are unfrozen when done loading signal received */
            is_frozen = true;
            path_changed ();
            /* if original_request false, leave original_load_request as it is (it may already be true
             * if reloading in response to reload button press). */
            if (original_request) {
                original_reload_request = true;
            }
            /* Only need to initialise directory once - the slot that originally received the
             * reload request does this */
            if (original_reload_request) {
                schedule_reload ();
                original_reload_request = false;
            }
        }
    }

    private void schedule_reload () {
        /* Allow time for other slots showing this directory to prepare for reload.
         * Also a delay is needed when a mount is added and trash reloads. */
        if (reload_timeout_id > 0) {
            warning ("Path change request received too rapidly");
            return;
        }

        reload_timeout_id = Timeout.add (100, () => {
            directory.reload ();
            reload_timeout_id = 0;
            return GLib.Source.REMOVE;
        });
    }

    private void set_up_directory (GLib.File loc) {
        if (directory != null) {
            disconnect_dir_signals ();
        }

        directory = Directory.from_gfile (loc);
        assert (directory != null);

        connect_dir_signals ();
    }

    public override void path_change_requested (GLib.File loc, Files.OpenFlag flag) {
        switch (flag) {
            case Files.OpenFlag.DEFAULT:
                if (mode == ViewMode.MILLER_COLUMNS) {
                    miller_slot_request (loc, false); /* signal to parent MillerView */
                } else {
                    user_path_change_request (loc); /* Handle ourselves */
                }
                break;
            case Files.OpenFlag.NEW_TAB:
            case Files.OpenFlag.NEW_WINDOW:
                new_container_request (loc, flag);
                break;
            case Files.OpenFlag.NEW_ROOT:
                if (mode == ViewMode.MILLER_COLUMNS) {
                    miller_slot_request (loc, true); /* signal to parent MillerView */
                } else {
                    user_path_change_request (loc); /* Handle ourselves */
                }
                break;
            case Files.OpenFlag.APP:
                warning ("Unexpected flag");
                break;
        }
    }

    private void on_dir_view_path_change_request (GLib.File loc, Files.OpenFlag flag, bool make_root) {
        if (flag == 0) { /* make view in existing container */
            if (mode == ViewMode.MILLER_COLUMNS) {
                miller_slot_request (loc, make_root); /* signal to parent MillerView */
            } else {
                user_path_change_request (loc); /* Handle ourselves */
            }
        } else {
            new_container_request (loc, flag);
        }
    }

    private void user_path_change_request (GLib.File loc) {
    /** Only this function must be used to change or reload the path **/
        var old_dir = directory;
        set_up_directory (loc);

        path_changed ();
        /* ViewContainer listens to this signal takes care of updating appearance */
        dir_view.change_directory (old_dir, directory);
        initialize_directory ();
    }

    public override void initialize_directory () {
        if (directory.is_loading ()) {
            /* This can happen when restoring duplicate tabs */
            debug ("Slot.initialize_directory () called when directory already loading - ignoring");
            return;
        }
        /* view and slot are unfrozen when done loading signal received */
        is_frozen = true;
        directory.init ();
    }

    public override void reload (bool non_local_only = false) {
        if (!non_local_only || !directory.is_local) {
            original_reload_request = true;
            /* Propagate reload signal to any other slot showing this directory indicating it is not
             * the original signal */
            directory.need_reload (false);
        }
    }

    protected override void make_view () {
        assert (dir_view == null);

        switch (mode) {
            case ViewMode.ICON:
                dir_view = new Files.DirectoryView (mode, this);
                break;

            default:
                dir_view = new Files.DirectoryView (mode, this);
                break;
        }

        /* Miller View creates its own overlay and handles packing of the directory view */
        if (dir_view != null && mode != ViewMode.MILLER_COLUMNS) {
            add_overlay (dir_view);
        }

        assert (dir_view != null);
    }

    public override bool set_all_selected (bool select_all) {
        if (dir_view != null) {
            // if (select_all) {
            //     dir_view.select_all ();
            // } else {
            //     dir_view.unselect_all ();
            // }
            return true;
        } else {
            return false;
        }
    }

    public override List<Files.File> get_selected_files () {
        List<Files.File> selected_files = null;
        if (view_widget != null) {
            view_widget.get_selected_files (out selected_files);
        }

        return (owned)selected_files;
    }

    public override void select_glib_files (GLib.List<GLib.File> locations, GLib.File? focus_location) {

        if (view_widget != null) {
            var files_to_select = new List<Files.File> ();
            locations.@foreach ((loc) => {
                files_to_select.prepend (Files.File.@get (loc));
            });

            var focus_after_select = focus_location != null ? focus_location.dup () : null;

            view_widget.select_files (files_to_select);
            if (focus_location != null) {
                view_widget.show_and_select_file (Files.File.@get (focus_location), false, false, true);
            }
        }
    }

    public void select_gof_file (Files.File gof) {

        if (view_widget != null) {
            view_widget.show_and_select_file (gof, true, false, false);
        }
    }

    public override void show_first_item () {
        if (view_widget != null) {
            view_widget.show_and_select_file (null, false, false);
        }
    }

    public override void set_active_state (bool set_active, bool animate = true) {
        if (set_active) {
            active (true, animate);
        } else {
            inactive ();
        }
    }

    public override unowned Files.AbstractSlot? get_current_slot () {
        return this as Files.AbstractSlot;
    }

    public unowned Files.DirectoryView? get_directory_view () {
        return dir_view;
    }

    public override void grab_focus () {
        if (view_widget != null) {
            view_widget.grab_focus ();
        }
    }

    public override void zoom_in () {
        if (dir_view != null) {
            dir_view.zoom_in ();
        }
    }

    public override void zoom_out () {
        if (dir_view != null) {
            dir_view.zoom_out ();
        }
    }

    public override void zoom_normal () {
        if (dir_view != null) {
            dir_view.zoom_normal ();
        }
    }

    public override void close () {
        debug ("SLOT close %s", uri);
        cancel_timeouts ();

        if (directory != null) {
            directory.cancel ();
            disconnect_dir_signals ();
        }

        if (dir_view != null) {
            dir_view.close ();
            disconnect_dir_view_signals ();
        }
    }

    public void refresh_files () {
        if (directory != null) {
            directory.update_files ();
        }
    }

    public override FileInfo? lookup_file_info (GLib.File loc) {
        Files.File? gof = directory.file_hash_lookup_location (loc);
        if (gof != null) {
            return gof.info;
        } else {
            return null;
        }
    }

    private void cancel_timeouts () {
        cancel_timeout (ref reload_timeout_id);
        cancel_timeout (ref path_change_timeout_id);
    }

    private void cancel_timeout (ref uint id) {
        if (id > 0) {
            Source.remove (id);
            id = 0;
        }
    }

    public string get_empty_message () {
        string msg = EMPTY_MESSAGE;
        if (directory.is_recent) {
            msg = EMPTY_RECENT_MESSAGE;
        } else if (directory.is_trash && (uri == Files.TRASH_URI + Path.DIR_SEPARATOR_S)) {
            msg = EMPTY_TRASH_MESSAGE;
        } else if (directory.permission_denied) {
            msg = DENIED_MESSAGE;
        }
        return msg;
    }
}
}
