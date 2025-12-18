/*
* Copyright (c) 2010 Mathijs Henquet <mathijs.henquet@gmail.com>
*               2017-2020 elementary, Inc. <https://elementary.io>
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
* Authored by: Mathijs Henquet <mathijs.henquet@gmail.com>
*              ammonkey <am.monkeyd@gmail.com>
*/

public class Files.BasicWindow : Gtk.EventBox {
    public Browser browser { get; private set; }
    public Files.BasicHeaderBar headerbar;
    public SidebarInterface sidebar { get; private set; }
    public BasicSlot slot { get; private set; }
    private Gtk.Paned lside_pane;
    private Gtk.Box slot_container;

    public string title { get; private set; default = "";}
    public bool can_select_zero { get; set; default = true; }

    public ViewMode default_mode {
        get {
            return ViewMode.PREFERRED;
        }
    }

    public GLib.File default_location {
        owned get {
            return GLib.File.new_for_path (PF.UserUtils.get_real_user_home ());
        }
    }

    public int sidebar_width {
        get {
            return lside_pane.position;
        }

        set {
            lside_pane.position = value;
        }
    }

    public Gtk.SelectionMode selection_mode {
        get {
            return slot != null ? slot.dir_view.get_selection_mode () : Gtk.SelectionMode.NONE;
        }

        set {
            assert (slot != null);
            slot.dir_view.set_selection_mode (value);
        }
    }

    public Gtk.FileFilter? filter {
        get {
            return slot != null ? slot.dir_view.filter : null;
        }

        set {
            assert (slot != null);
            slot.dir_view.filter = value;
        }
    }

    public List<Files.File> selected_files {
        get {
            assert (slot != null);
            return slot.dir_view.get_selected_files ();
        }
    }

    public string? uri { // The current displayed uri
        get {
            return slot != null ? slot.uri : null;
        }
    }

    public GLib.File? location { // The currently displayed folder
        get {
            return slot != null ? slot.location : null;
        }
    }

    public bool is_renaming {
        get {
            assert (slot != null);
            return slot.dir_view.renaming;
        }
    }
    private bool locked_focus { get; set; default = false; }

    public signal void folder_deleted (GLib.File location);
    public signal void free_space_change ();
    public signal void file_activated ();
    public signal void selection_changed ();

    construct {
        browser = new Browser ();
        //We create and connect headerbar but leave to the parent where to put it.
        headerbar = new Files.BasicHeaderBar ();
        headerbar.path_change_request.connect (path_change);
        headerbar.change_view_mode.connect (on_change_view_mode_request);

        headerbar.go_back.connect ((steps) => {
            string? uri = browser.go_back (steps);
            if (uri != null) {
                path_change (uri);
            } else {
                warning ("Null path");
            }
        });
        headerbar.go_forward.connect ((steps) => {
            string? uri = browser.go_forward (steps);
            if (uri != null) {
                path_change (uri);
            }
        });

        slot_container = new Gtk.Box (HORIZONTAL, 0); //Potential for extra widgets e.g. preview

        lside_pane = new Gtk.Paned (Gtk.Orientation.HORIZONTAL) {
            expand = true,
        };

        sidebar = new Sidebar.BasicSidebarWindow ();
        sidebar.path_change_request.connect (path_change);

        lside_pane.pack1 (sidebar, false, false);
        lside_pane.pack2 (slot_container, false, false);
        add (lside_pane);

        //Must create headerbar and slot container first

        show_all ();
    }

    public void add_slot (string uri, ViewMode mode) {
        if (slot != null) {
            if (slot.mode == mode) {
                return;
            }

            slot.close ();
            slot_container.remove (slot.get_content_box ());
            slot = null; //TODO check slot is destructed
        }

        slot = new BasicSlot (GLib.File.new_for_uri (uri), mode);
        slot.file_activated.connect (() => {
            file_activated ();
        });
        slot.directory_loaded.connect (on_directory_loaded);
        slot.bookmark_uri_request.connect (bookmark_uri);
        slot.selection_changed.connect (() => {
            selection_changed ();
        });

        slot.notify["uri"].connect (() => {
            update_labels (slot.uri);
        });

        slot_container.add (slot.get_content_box ());
        slot_container.show_all ();

        headerbar.set_view_mode (slot.mode);
    }

    public void get_selection_details (out uint n_selected, out bool folder_selected, out bool file_selected) {
        n_selected = 0;
        folder_selected = false;
        file_selected = false;
        foreach (var f in selected_files) {
            n_selected++;
            if (f.is_folder ()) {
                folder_selected = true;
            } else {
                file_selected = true;
            }
        }
    }
    // Alway operates on (or creates) this.content
    public bool set_location (
        GLib.File? _location,
        ViewMode mode) {
            GLib.File location;
            GLib.FileType ftype;

            if (_location == null) {
                location = this.default_location;
            } else {
            // For simplicity we do not use cancellable. If issues arise may need to do this.
                try {
                    var info = _location.query_info (
                        FileAttribute.STANDARD_TYPE,
                        FileQueryInfoFlags.NONE
                    );

                    ftype = info.get_file_type ();
                } catch (Error e) {
                    warning ("No info for requested location - abandon loading");
                    return false;
                }


                if (ftype == FileType.REGULAR) {
                    location = _location.get_parent ();
                } else {
                    location = _location.dup ();
                }
            }

            path_change (location.get_uri ());
            return true;
    }

    /*
     * If folder shows that with nothing selected
     * If file shows parent folder with the file selected
     */
    public void path_change (string uri) {
        slot.on_path_change_request (uri);
        browser.record_uri (uri);
    }

    public void set_selected_location (GLib.File loc) {
        path_change (loc.get_uri ());
    }

    private void on_directory_loaded () {
        headerbar.set_back_menu (browser.go_back_list (), browser.get_can_go_back ());
        headerbar.set_forward_menu (browser.go_forward_list (), browser.get_can_go_forward ());
        headerbar.update_location_bar (uri, true);
        slot.focus_first_for_empty_selection (!can_select_zero);
        //TODO Handle dir cannot load
    }

    public void bookmark_uri (string uri, string custom_name = "") {
        sidebar.add_favorite_uri (uri, custom_name);
    }

    public bool can_bookmark_uri (string uri) {
        return !sidebar.has_favorite_uri (uri);
    }

    public void on_change_view_mode_request (ViewMode mode) {
        warning ("on change view mode request");
        add_slot (slot.uri, mode);
    }

    private void action_view_mode (GLib.SimpleAction action, GLib.Variant? param) {
        //TODO Allow Slot to change view mode rather than create new slot?
        on_change_view_mode_request ((ViewMode)param.get_uint32 ());
        // add_slot (slot.location, (ViewMode)(param.get_uint32 ())); //Closes and destroys old slot
        // view_mode = mode;
        // loading (false);
        // store_selection ();
        /* Make sure async loading and thumbnailing are cancelled and signal handlers disconnected */
        // disconnect_slot_signals (view);
        // add_view (mode, loc ?? location);
        /* Slot is created inactive so we activate now since we must be the current tab
         * to have received a change mode instruction */
        // set_active_state (true);
        /* Do not update top menu (or record uri) unless folder loads successfully */
        // load_directory ();
    }

    public void change_state_show_hidden (GLib.SimpleAction action) {
        bool state = !action.state.get_boolean ();
        action.set_state (new GLib.Variant.boolean (state));
    }

    public void change_state_single_click_select (GLib.SimpleAction action) {
        bool state = !action.state.get_boolean ();
        action.set_state (new GLib.Variant.boolean (state));
        Files.Preferences.get_default ().singleclick_select = state;
    }

    public void change_state_show_remote_thumbnails (GLib.SimpleAction action) {
        bool state = !action.state.get_boolean ();
        action.set_state (new GLib.Variant.boolean (state));
    }

    public void change_state_show_local_thumbnails (GLib.SimpleAction action) {
        bool state = !action.state.get_boolean ();
        action.set_state (new GLib.Variant.boolean (state));
    }

    public void change_state_folders_before_files (GLib.SimpleAction action) {
        bool state = !action.state.get_boolean ();
        action.set_state (new GLib.Variant.boolean (state));
    }

    public virtual void quit () {
        headerbar.destroy (); /* stop unwanted signals if quit while pathbar in focus */
        slot.close ();
        this.destroy ();
    }

    private void update_labels (string uri) {
        headerbar.update_location_bar (uri);
        sidebar.sync_uri (uri);
    }

    public new void grab_focus () {
        slot.grab_focus ();
    }
}
