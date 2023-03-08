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

public class Files.Window : Gtk.ApplicationWindow {
    private static Files.Preferences prefs;
    private static UndoManager undo_manager;
    private static Files.Application marlin_app;
    static construct {
        prefs = Files.Preferences.get_default ();
        undo_manager = UndoManager.instance ();
        marlin_app = (Files.Application)(GLib.Application.get_default ());
    }

    const GLib.ActionEntry [] WIN_ENTRIES = {
        {"new-window", action_new_window},
        {"new-folder", action_new_folder},
        {"new-file", action_new_file},
        {"copy", action_copy_to_clipboard},
        {"link", action_link_to_clipboard},
        {"cut", action_cut_to_clipboard},
        {"paste", action_paste_from_clipboard},
        {"trash", action_trash},
        {"delete", action_delete},
        {"quit", action_quit},
        {"refresh", action_reload},
        {"undo", action_undo},
        {"redo", action_redo},
        {"bookmark", action_bookmark},
        {"rename", action_rename},
        {"context-menu", action_context_menu},
        {"toggle-select-all", action_toggle_select_all},
        {"toggle-sidebar", action_toggle_sidebar},
        {"invert-selection", action_invert_selection},

        {"find", action_find, "s"},
        {"edit-path", action_edit_path},
        {"tab", action_tab, "s"},
        {"open-selected", action_open_selected, "s"},
        {"open-with", action_open_with, "s"},
        {"go-to", action_go_to, "s"},
        {"zoom", action_zoom, "s"},
        {"info", action_info, "s"},
        {"sort-type", action_sort_type, "s", "'FILENAME'"},
        {"forward", action_forward, "i"},
        {"back", action_back, "i"},

        {"view-mode", action_view_mode, "u", "0" },
        {"sort-reversed", null, null, "false", change_state_sort_reversed},
        {"sort-directories-first", null, null, "false", change_state_sort_directories_first},
        {"show-hidden", null, null, "false", change_state_show_hidden},
        {"show-remote-thumbnails", null, null, "true", change_state_show_remote_thumbnails},
        {"show-local-thumbnails", null, null, "false", change_state_show_local_thumbnails},
        {"folders-before-files", null, null, "true", change_state_folders_before_files},
        {"singleclick-select", null, null, "false", change_state_single_click_select},

        //Actions only used internally (no global shortcut)
        {"remove-content", action_remove_content, "i"},
        {"path-change-request", action_path_change_request, "(su)"},
        {"loading-uri", action_loading_uri, "s"},
        {"loading-finished", action_loading_finished},
        {"selection-changing", action_selection_changing},
        {"update-selection", action_update_selection},
        {"properties", action_properties, "s"},
        {"focus-view", action_focus_view},
        {"focus-sidebar", action_focus_sidebar}
    };

    public uint window_number { get; construct; }

    private Gtk.Paned lside_pane;
    private Files.HeaderBar top_menu;
    private Adw.TabView tab_view;
    private Adw.TabBar tab_bar;
    private Gtk.PopoverMenu tab_popover;
    private Sidebar.SidebarWindow sidebar;
    private bool is_first_window {
        get {
            return (window_number == 0);
        }
    }
    private ViewContainer? current_container {
        get {
            return tab_view.selected_page != null ?
                (ViewContainer)(tab_view.selected_page.child) : null;
        }
    }
    private ViewInterface? current_view_widget {
        get {
            if (current_container == null || current_container.slot == null) {
                return null;
            }

            return ((Files.Slot)(current_container.slot)).view_widget;
        }
    }
    private bool tabs_restored = false;
    private int restoring_tabs = 0;
    private bool doing_undo_redo = false;

    // public signal void folder_deleted (GLib.File location);

    public signal void free_space_change ();

    construct {
        title = _(APP_TITLE);
        height_request = 300;
        width_request = 500;
        window_number = marlin_app.window_count;

        add_action_entries (WIN_ENTRIES, this);
        // Setting accels on `application` does not work in construct clause
        // Must set before building window so ViewSwitcher can lookup the accels for tooltips
        if (is_first_window) {
            marlin_app.set_accels_for_action ("win.quit", {"<Ctrl>Q"});
            marlin_app.set_accels_for_action ("win.new-window", {"<Ctrl>N"});
            marlin_app.set_accels_for_action ("win.new-folder", {"<Shift><Ctrl>N"});
            marlin_app.set_accels_for_action ("win.new-file", {"<Ctrl><Alt>N"});
            marlin_app.set_accels_for_action ("win.copy", {"<Ctrl>C"});
            marlin_app.set_accels_for_action ("win.link", {"<Ctrl><Shift>C"});
            marlin_app.set_accels_for_action ("win.cut", {"<Ctrl>X"});
            marlin_app.set_accels_for_action ("win.paste", {"<Ctrl>V"});
            marlin_app.set_accels_for_action ("win.trash", {"Delete"});
            marlin_app.set_accels_for_action ("win.delete", {"<Shift>Delete"});
            marlin_app.set_accels_for_action ("win.undo", {"<Ctrl>Z"});
            marlin_app.set_accels_for_action ("win.redo", {"<Ctrl><Shift>Z"});
            marlin_app.set_accels_for_action ("win.bookmark", {"<Ctrl>D"});
            marlin_app.set_accels_for_action ("win.rename", {"F2"});
            marlin_app.set_accels_for_action ("win.find::", {"<Ctrl>F"});
            marlin_app.set_accels_for_action ("win.edit-path", {"<Ctrl>L"});
            marlin_app.set_accels_for_action ("win.sort-directories-first", {"<Alt>minus"});
            marlin_app.set_accels_for_action ("win.toggle-select-all", {"<Ctrl>A"});
            marlin_app.set_accels_for_action ("win.toggle-sidebar", {"<Ctrl>backslash"});
            marlin_app.set_accels_for_action ("win.invert-selection", {"<Shift><Ctrl>A"});
            marlin_app.set_accels_for_action ("win.context-menu", {"Menu", "MenuKB"});
            marlin_app.set_accels_for_action ("win.tab::NEW", {"<Ctrl>T"});
            marlin_app.set_accels_for_action ("win.tab::CLOSE", {"<Ctrl>W"});
            marlin_app.set_accels_for_action ("win.tab::NEXT", {"<Ctrl>Page_Down", "<Ctrl>Tab"});
            marlin_app.set_accels_for_action ("win.tab::PREVIOUS", {"<Ctrl>Page_Up", "<Shift><Ctrl>Tab"});
            marlin_app.set_accels_for_action ("win.tab::DUP", {"<Ctrl><Alt>T"});
            marlin_app.set_accels_for_action ("win.tab::WINDOW", {"<Ctrl><Super>N"});
            marlin_app.set_accels_for_action (
                GLib.Action.print_detailed_name ("win.view-mode", new Variant.uint32 (0)), {"<Ctrl>1"}
            );
            marlin_app.set_accels_for_action (
                GLib.Action.print_detailed_name ("win.view-mode", new Variant.uint32 (1)), {"<Ctrl>2"}
            );
            marlin_app.set_accels_for_action (
                GLib.Action.print_detailed_name ("win.view-mode", new Variant.uint32 (2)), {"<Ctrl>3"}
            );
            marlin_app.set_accels_for_action ("win.zoom::ZOOM_IN", {"<Ctrl>plus", "<Ctrl>equal"});
            marlin_app.set_accels_for_action ("win.zoom::ZOOM_OUT", {"<Ctrl>minus"});
            marlin_app.set_accels_for_action ("win.zoom::ZOOM_NORMAL", {"<Ctrl>0"});
            marlin_app.set_accels_for_action ("win.show-hidden", {"<Ctrl>H"});
            marlin_app.set_accels_for_action ("win.sort-reversed", {"<Alt>0"});
            marlin_app.set_accels_for_action ("win.show-remote-thumbnails", {"<Ctrl>bracketleft"});
            marlin_app.set_accels_for_action ("win.show-local-thumbnails", {"<Ctrl>bracketright"});
            marlin_app.set_accels_for_action ("win.refresh", {"<Ctrl>R", "F5"});
            marlin_app.set_accels_for_action ("win.go-to::HOME", {"<Alt>Home"});
            marlin_app.set_accels_for_action ("win.go-to::RECENT", {"<Alt>R"});
            marlin_app.set_accels_for_action ("win.go-to::TRASH", {"<Alt>T"});
            marlin_app.set_accels_for_action ("win.go-to::ROOT", {"<Alt>slash"});
            marlin_app.set_accels_for_action ("win.go-to::NETWORK", {"<Alt>N"});
            marlin_app.set_accels_for_action ("win.go-to::SERVER", {"<Alt>C"});
            marlin_app.set_accels_for_action ("win.go-to::UP", {"<Alt>Up"});
            marlin_app.set_accels_for_action ("win.go-to::FORWARD", {"<Alt>Right", "XF86Forward"});
            marlin_app.set_accels_for_action ("win.go-to::BACK", {"<Alt>Left", "XF86Back"});
            marlin_app.set_accels_for_action ("win.info::HELP", {"F1"});
            marlin_app.set_accels_for_action ("win.sort-type::FILENAME", {"<Alt>1"});
            marlin_app.set_accels_for_action ("win.sort-type::SIZE", {"<Alt>2"});
            marlin_app.set_accels_for_action ("win.sort-type::TYPE", {"<Alt>3"});
            marlin_app.set_accels_for_action ("win.sort-type::MODIFIED", {"<Alt>4"});
            // marlin_app.set_accels_for_action ("win.focus-view", {"Escape"});
        }

        get_action ("undo").set_enabled (false);
        get_action ("redo").set_enabled (false);
        /** Apply preferences */
        get_action ("show-hidden").set_state (prefs.show_hidden_files);
        get_action ("show-remote-thumbnails").set_state (prefs.show_remote_thumbnails);
        get_action ("show-local-thumbnails").set_state (prefs.show_local_thumbnails);
        get_action ("sort-directories-first").set_state (prefs.sort_directories_first);
        get_action ("singleclick-select").set_state (prefs.singleclick_select);

        top_menu = new Files.HeaderBar ();
        set_titlebar (top_menu);

        tab_view = new Adw.TabView ();

        tab_bar = new Adw.TabBar () {
            view = tab_view,
            inverted = true,
            autohide = false,
            expand_tabs = false
        };
        // Allow window dragging on blank part of tab bar
        var tab_handle = new Gtk.WindowHandle () {
            child = tab_bar
        };

        var builder = new Gtk.Builder.from_resource ("/io/elementary/files/Window.ui");
        var tab_menu = (Menu)(builder.get_object ("tab_model"));
        tab_popover = new Gtk.PopoverMenu.from_model_full (tab_menu, Gtk.PopoverMenuFlags.NESTED) {
            has_arrow = false
        };
        tab_popover.set_parent (tab_bar);

        var gesture_secondary_click = new Gtk.GestureClick () {
            button = Gdk.BUTTON_SECONDARY,
            propagation_phase = Gtk.PropagationPhase.CAPTURE // Receive before tab_bar
        };
        tab_bar.add_controller (gesture_secondary_click);
        gesture_secondary_click.released.connect ((n_press, x, y) => {
            show_tab_context_menu (x, y);
            gesture_secondary_click.set_state (Gtk.EventSequenceState.CLAIMED); // Do not propagate
        });

        var add_tab_button = new Gtk.Button () {
            icon_name = "list-add-symbolic",
            action_name = "win.tab",
            action_target = "NEW"
        };
        add_tab_button.add_css_class ("flat");
        tab_bar.start_action_widget = add_tab_button;

        var tab_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        tab_box.append (tab_handle);
        tab_box.append (tab_view);

        sidebar = new Sidebar.SidebarWindow ();
        free_space_change.connect (sidebar.on_free_space_change);

        lside_pane = new Gtk.Paned (Gtk.Orientation.HORIZONTAL) {
            position = Files.app_settings.get_int ("sidebar-width"),
            resize_start_child = false,
            shrink_start_child = false
        };
        lside_pane.start_child = sidebar;
        lside_pane.end_child = tab_box;

        set_child (lside_pane);

        tab_view.notify["selected-page"].connect (() => {
            update_top_menu ();
            //NOTE Current container is ill-defined at this point
        });
        tab_view.indicator_activated.connect (() => {});
        tab_view.setup_menu.connect (() => {});
        tab_view.close_page.connect ((tab) => {
            //TODO Implement save and restore closed tabs
            // tab_view.close_page_finish (tab, false); // No need to confirm
            var view_container = (ViewContainer)(tab.child);
            view_container.close ();
            view_container.destroy ();
            // tab.restore_data = view_container.location.get_uri ();

            return false;
        });
        tab_view.page_reordered.connect ((tab, position) => {
            change_tab (position);
        });
        //TODO Implement in Gtk4 (Signal absent in TabBar)
        // tab_view.tab_restored.connect ((label, restore_data, icon) => {
        //     add_tab_by_uri (restore_data);
        // });
        tab_view.create_window.connect (() => {
            return marlin_app.create_empty_window ().tab_view;
        });
        tab_view.page_attached.connect ((tab, pos) => {
        });
        tab_view.page_detached.connect (on_page_detached);

        sidebar.request_focus.connect (() => {
            return true;
            // return !current_container.locked_focus && !top_menu.locked_focus;
        });
        sidebar.sync_needed.connect (() => {
            sidebar.sync_uri (current_container.uri);
        });
        sidebar.path_change_request.connect (uri_path_change_request);
        sidebar.connect_server_request.connect (connect_to_server);

        undo_manager.request_menu_update.connect (update_undo_actions);

        int width, height;
        Files.app_settings.get ("window-size", "(ii)", out width, out height);
        default_width = width;
        default_height = height;

        close_request.connect (() => {
            quit ();
            return false;
        });
        present ();
    }

    public void folder_deleted (GLib.File folder) {
        uint i = 0;
        while (i < tab_view.n_pages) {
            var tab = (Adw.TabPage)(tab_view.pages.get_item (i++));
            ((ViewContainer)(tab.child)).folder_deleted (folder);
        }

        sidebar.reload (); // In case folder was bookmarked
    }

    private void on_page_detached () {
        if (tab_view.n_pages == 0) {
            add_tab ();
            set_default_location_and_mode ();
        }

        save_tabs ();
    }

    private void change_tab (int offset) {
        ViewContainer? old_tab = current_container;
        tab_view.selected_page = tab_view.get_nth_page (offset);

        if (current_container == null || old_tab == current_container) {
            return;
        }

        if (restoring_tabs > 0) { //Return if some restored tabs still loading
            return;
        }

        if (old_tab != null) {
            // old_tab.set_active_state (false);
            // old_tab.is_frozen = false;
        }

        update_top_menu ();
        save_active_tab_position ();
    }

    public void open_tabs (
        GLib.File[]? files = null,
        ViewMode mode = ViewMode.PREFERRED,
        bool ignore_duplicate = false
    ) {

        if (files == null) { //If files is empty assume this is intentional
            /* Restore session if not root and settings allow */
            if (Files.is_admin () ||
                !Files.app_settings.get_boolean ("restore-tabs") ||
                restore_tabs () < 1) {

                /* Open a tab pointing at the default location if no tabs restored*/
                add_tab ();
                set_default_location_and_mode ();
            }
        } else {
            /* Open tabs at each requested location */
            /* As files may be derived from commandline, we use a new sanitized one */
            foreach (var file in files) {
                add_tab ();
                set_current_location_and_mode (real_mode (mode), file, OpenFlag.DEFAULT);
            }
        }
    }

    private ViewContainer? add_tab () {
        var content = new ViewContainer ();
        var tab = tab_view.append (content);
        tab_view.selected_page = tab;
        /* Capturing ViewContainer object reference in closure prevents its proper destruction
         * so capture its unique id instead */
        var id = content.id;
        content.notify["tab-name"].connect (() => {
            set_tab_label (
                check_for_tab_with_same_name (id, content.display_uri),
                tab,
                content.tab_name
            );
        });
        return content;
    }

    private int location_is_duplicate (GLib.File location, out bool is_child) {
        is_child = false;
        var parent_path = "";
        var uri = location.get_uri ();
        bool is_folder = location.query_file_type (FileQueryInfoFlags.NONE) == FileType.DIRECTORY;
        /* Ensures consistent format of protocol and path */
        parent_path = FileUtils.get_parent_path_from_path (location.get_path ());
        int existing_position = 0;

        for (uint i = 0; i < tab_view.n_pages; i++) {
            var tab = (Adw.TabPage)(tab_view.pages.get_item (i));
            var tab_location = ((ViewContainer)(tab.child)).location;
            string tab_uri = tab_location.get_uri ();

            if (FileUtils.same_location (uri, tab_uri)) {
                return existing_position;
            } else if (!is_folder &&
                        FileUtils.same_location (location.get_parent ().get_uri (), tab_uri)) {

                is_child = true;
                return existing_position;
            }

            existing_position++;
        }

        return -1;
    }

    private string check_for_tab_with_same_name (int id, string new_uri) {
        if (new_uri == Files.INVALID_TAB_NAME) {
             return new_uri;
        }

// <<<<<<< HEAD
        var new_basename = Path.get_basename (new_uri);
        string new_tabname = new_basename;
        for (uint i = 0; i < tab_view.n_pages; i++) {
            var tab = (Adw.TabPage)(tab_view.pages.get_item (i));
            var content = (ViewContainer)(tab.child);
            if (content.id != id) {
                var content_uri = content.display_uri;
                var content_basename = Path.get_basename (content_uri);
                if (content_basename == new_basename &&
                    content_uri != new_uri) {

                    /* Same label, different uri. Relabel new tab */
                    new_tabname = disambiguate_name (new_basename, new_uri, content_uri);
                    if (content_basename == tab.title) {
                        /* Also relabel conflicting tab (but not before this function finishes) */
                        Idle.add_full (GLib.Priority.LOW, () => {
                            var unique_name = disambiguate_name (
                                Path.get_basename (content_uri),
                                content_uri,
                                new_uri
                            );
                            set_tab_label (unique_name, tab, content_uri);
                            return GLib.Source.REMOVE;
                        });
// =======
//         construct {
//             add_action_entries (WIN_ENTRIES, this);
//             undo_actions_set_insensitive ();

//             undo_manager = UndoManager.instance ();

//             // Setting accels on `application` does not work in construct clause
//             // Must set before building window so ViewSwitcher can lookup the accels for tooltips
//             if (is_first_window) {
//                 marlin_app.set_accels_for_action ("win.quit", {"<Ctrl>Q"});
//                 marlin_app.set_accels_for_action ("win.new-window", {"<Ctrl>N"});
//                 marlin_app.set_accels_for_action ("win.undo", {"<Ctrl>Z"});
//                 marlin_app.set_accels_for_action ("win.redo", {"<Ctrl><Shift>Z"});
//                 marlin_app.set_accels_for_action ("win.bookmark", {"<Ctrl>D"});
//                 marlin_app.set_accels_for_action ("win.find::", {"<Ctrl>F"});
//                 marlin_app.set_accels_for_action ("win.edit-path", {"<Ctrl>L"});
//                 marlin_app.set_accels_for_action ("win.tab::NEW", {"<Ctrl>T"});
//                 marlin_app.set_accels_for_action ("win.tab::CLOSE", {"<Ctrl>W"});
//                 marlin_app.set_accels_for_action ("win.tab::NEXT", {"<Ctrl>Page_Down", "<Ctrl>Tab"});
//                 marlin_app.set_accels_for_action ("win.tab::PREVIOUS", {"<Ctrl>Page_Up", "<Shift><Ctrl>Tab"});
//                 marlin_app.set_accels_for_action (
//                     GLib.Action.print_detailed_name ("win.view-mode", new Variant.uint32 (0)), {"<Ctrl>1"}
//                 );
//                 marlin_app.set_accels_for_action (
//                     GLib.Action.print_detailed_name ("win.view-mode", new Variant.uint32 (1)), {"<Ctrl>2"}
//                 );
//                 marlin_app.set_accels_for_action (
//                     GLib.Action.print_detailed_name ("win.view-mode", new Variant.uint32 (2)), {"<Ctrl>3"}
//                 );
//                 marlin_app.set_accels_for_action ("win.zoom::ZOOM_IN", {"<Ctrl>plus", "<Ctrl>equal"});
//                 marlin_app.set_accels_for_action ("win.zoom::ZOOM_OUT", {"<Ctrl>minus"});
//                 marlin_app.set_accels_for_action ("win.zoom::ZOOM_NORMAL", {"<Ctrl>0"});
//                 marlin_app.set_accels_for_action ("win.show-hidden", {"<Ctrl>H"});
//                 marlin_app.set_accels_for_action ("win.refresh", {"<Ctrl>R", "F5"});
//                 marlin_app.set_accels_for_action ("win.go-to::HOME", {"<Alt>Home"});
//                 marlin_app.set_accels_for_action ("win.go-to::RECENT", {"<Alt>R"});
//                 marlin_app.set_accels_for_action ("win.go-to::TRASH", {"<Alt>T"});
//                 marlin_app.set_accels_for_action ("win.go-to::ROOT", {"<Alt>slash"});
//                 marlin_app.set_accels_for_action ("win.go-to::NETWORK", {"<Alt>N"});
//                 marlin_app.set_accels_for_action ("win.go-to::SERVER", {"<Alt>C"});
//                 marlin_app.set_accels_for_action ("win.go-to::UP", {"<Alt>Up"});
//                 marlin_app.set_accels_for_action ("win.go-to::FORWARD", {"<Alt>Right", "XF86Forward"});
//                 marlin_app.set_accels_for_action ("win.go-to::BACK", {"<Alt>Left", "XF86Back"});
//                 marlin_app.set_accels_for_action ("win.info::HELP", {"F1"});
//                 marlin_app.set_accels_for_action ("win.tab::TAB", {"<Ctrl><Alt>T"});
//                 marlin_app.set_accels_for_action ("win.tab::WINDOW", {"<Ctrl><Alt>N"});
//             }

//             build_window ();
//             connect_signals ();

//             int width, height;
//             Files.app_settings.get ("window-size", "(ii)", out width, out height);
//             default_width = width;
//             default_height = height;

//             if (is_first_window) {
//                 Files.app_settings.bind ("sidebar-width", lside_pane,
//                                            "position", SettingsBindFlags.DEFAULT);

//                 var state = (Files.WindowState)(Files.app_settings.get_enum ("window-state"));

//                 switch (state) {
//                     case Files.WindowState.MAXIMIZED:
//                         maximize ();
//                         break;
//                     default:
//                         int default_x, default_y;
//                         Files.app_settings.get ("window-position", "(ii)", out default_x, out default_y);

//                         if (default_x != -1 && default_y != -1) {
//                             move (default_x, default_y);
//                         }

//                         break;
//                 }
//             }

//             loading_uri.connect (update_labels);
//             present ();
//         }

//         private void build_window () {
//             view_switcher = new Chrome.ViewSwitcher ((SimpleAction)lookup_action ("view-mode"));
//             view_switcher.set_mode (Files.app_settings.get_enum ("default-viewmode"));

//             top_menu = new Chrome.HeaderBar (view_switcher) {
//                 show_close_button = true,
//                 custom_title = new Gtk.Label (null)
//             };

//             tabs = new Granite.Widgets.DynamicNotebook.with_accellabels (
//                 new Granite.AccelLabel (_("New Tab"), "<Ctrl>t"),
//                 new Granite.AccelLabel (_("Undo Close Tab"), "<Shift><Ctrl>t")
//             ) {
//                 show_tabs = true,
//                 allow_restoring = true,
//                 allow_duplication = true,
//                 allow_new_window = true,
//                 group_name = Config.APP_NAME
//             };

//             this.configure_event.connect_after ((e) => {
//                 tabs.set_size_request (e.width / 2, -1);
//                 return false;
//             });

//             tabs.show ();

//             sidebar = new Sidebar.SidebarWindow ();
//             free_space_change.connect (sidebar.on_free_space_change);

//             lside_pane = new Gtk.Paned (Gtk.Orientation.HORIZONTAL) {
//                 expand = true,
//                 position = Files.app_settings.get_int ("sidebar-width")
//             };
//             lside_pane.pack1 (sidebar, false, false);
//             lside_pane.pack2 (tabs, true, true);

//             var grid = new Gtk.Grid ();
//             grid.attach (top_menu, 0, 0);
//             grid.attach (lside_pane, 0, 1);
//             grid.show_all ();

//             add (grid);

//             /** Apply preferences */
//             var prefs = Files.Preferences.get_default (); // Bound to settings schema by Application
//             get_action ("show-hidden").set_state (prefs.show_hidden_files);
//             get_action ("show-local-thumbnails").set_state (prefs.show_local_thumbnails);
//             get_action ("show-remote-thumbnails").set_state (prefs.show_remote_thumbnails);
//             get_action ("singleclick-select").set_state (prefs.singleclick_select);
//             get_action ("folders-before-files").set_state (prefs.sort_directories_first);
//         }

//         private void connect_signals () {
//             /*/
//             /* Connect and abstract signals to local ones
//             /*/

//             top_menu.forward.connect ((steps) => { current_tab.go_forward (steps); });
//             top_menu.back.connect ((steps) => { current_tab.go_back (steps); });
//             top_menu.escape.connect (grab_focus);
//             top_menu.path_change_request.connect ((loc, flag) => {
//                 current_tab.is_frozen = false;
//                 uri_path_change_request (loc, flag);
//             });
//             top_menu.reload_request.connect (action_reload);
//             top_menu.focus_location_request.connect ((loc) => {
//                 current_tab.focus_location_if_in_current_directory (loc, true);
//             });
//             top_menu.focus_in_event.connect (() => {
//                 current_tab.is_frozen = true;
//                 return true;
//             });
//             top_menu.focus_out_event.connect (() => {
//                 current_tab.is_frozen = false;
//                 return true;
//             });

//             undo_manager.request_menu_update.connect (update_undo_actions);

//             key_press_event.connect ((event) => {
//                 Gdk.ModifierType state;
//                 event.get_state (out state);
//                 uint keyval;
//                 event.get_keyval (out keyval);
//                 var mods = state & Gtk.accelerator_get_default_mod_mask ();
//                 bool no_mods = (mods == 0);
//                 bool shift_pressed = ((mods & Gdk.ModifierType.SHIFT_MASK) != 0);
//                 bool only_shift_pressed = shift_pressed && ((mods & ~Gdk.ModifierType.SHIFT_MASK) == 0);

//                 /* Use Tab to toggle View and Sidebar keyboard focus.  This works better than using a focus chain
//                  * because cannot tab out of location bar and also unwanted items tend to get focused.
//                  * There are other hotkeys for operating/focusing other widgets.
//                  * Using modified Arrow keys no longer works due to recent changes.  */
//                 switch (keyval) {
//                     case Gdk.Key.Tab:
//                         if (top_menu.locked_focus) {
//                             return false;
//                         }

//                         if (no_mods || only_shift_pressed) {
//                             if (!sidebar.has_focus) {
//                                 sidebar.grab_focus ();
//                             } else {
//                                 current_tab.grab_focus ();
//                             }

//                             return true;
//                         }

//                         break;
//                 }

//                 return false;
//             });

//             key_press_event.connect_after ((event) => {
//                 Gdk.ModifierType state;
//                 event.get_state (out state);
//                 uint keyval;
//                 event.get_keyval (out keyval);
//                 /* Use find function instead of view interactive search */
//                 if (state == 0 || state == Gdk.ModifierType.SHIFT_MASK) {
//                     /* Use printable characters to initiate search */
//                     var uc = (unichar)(Gdk.keyval_to_unicode (keyval));
//                     if (uc.isprint ()) {
//                         activate_action ("find", uc.to_string ());
//                         return true;
//                     }
//                 }

//                 return false;
//             });


//             //TODO Rewrite for Gtk4
//             window_state_event.connect ((event) => {
//                 if (Gdk.WindowState.ICONIFIED in event.changed_mask) {
//                     top_menu.cancel (); /* Cancel any ongoing search query else interface may freeze on uniconifying */
//                 }

//                 return false;
//             });

//             delete_event.connect (() => {
//                 quit ();
//                 return false;
//             });

//             tabs.new_tab_requested.connect (() => {
//                 add_tab ();
//             });

//             tabs.close_tab_requested.connect ((tab) => {
//                 var view_container = (ViewContainer)(tab.page);
//                 tab.restore_data = view_container.location.get_uri ();

//                 /* If closing tab is current, set current_tab to null to ensure
//                  * closed ViewContainer is destroyed. It will be reassigned in tab_changed
//                  */
//                 if (view_container == current_tab) {
//                     current_tab = null;
//                 }

//                 view_container.close ();

//                 if (tabs.n_tabs == 1) {
//                     add_tab ();
//                 }

//                 return true;
//             });

//             tabs.tab_switched.connect ((old_tab, new_tab) => {
//                 change_tab (tabs.get_tab_position (new_tab));
//             });

//             tabs.tab_restored.connect ((label, restore_data, icon) => {
//                 add_tab_by_uri (restore_data);
//             });

//             tabs.tab_duplicated.connect ((tab) => {
//                 add_tab_by_uri (((ViewContainer)(tab.page)).uri);
//             });

//             tabs.tab_moved.connect ((tab) => {
//                 /* Called when tab dragged out of notebook */
//                 var vc = (ViewContainer)(tab.page) ;
//                 /* Close view now to disconnect signal handler closures which can trigger after slot destruction */
//                 vc.close ();

//                 marlin_app.create_window (vc.location, real_mode (vc.view_mode));

//                 /* remove_tab function uses Idle loop to close tab */
//                 remove_tab (tab);
//             });


//             tabs.tab_added.connect ((tab) => {
//                 var vc = (ViewContainer)(tab.page) ;
//                 vc.window = this;
//             });

//             tabs.tab_removed.connect (on_tab_removed);

//             sidebar.request_focus.connect (() => {
//                 return !current_tab.locked_focus && !top_menu.locked_focus;
//             });

//             sidebar.sync_needed.connect (() => {
//                 loading_uri (current_tab.uri);
//             });

//             sidebar.path_change_request.connect (uri_path_change_request);
//             sidebar.connect_server_request.connect (connect_to_server);
//         }

//         private void on_tab_removed () {
//             if (tabs.n_tabs == 0) {
//                 add_tab ();
//             }

//             save_tabs ();
//         }

//         public new void set_title (string title) {
//             this.title = title;
//         }

//         private void change_tab (int offset) {
//             ViewContainer? old_tab = current_tab;
//             current_tab = (ViewContainer)((tabs.get_tab_by_index (offset)).page);

//             if (current_tab == null || old_tab == current_tab) {
//                 return;
//             }

//             if (restoring_tabs > 0) { //Return if some restored tabs still loading
//                 return;
//             }

//             if (old_tab != null) {
//                 old_tab.set_active_state (false);
//                 old_tab.is_frozen = false;
//             }

//             loading_uri (current_tab.uri);
//             current_tab.set_active_state (true, false); /* changing tab should not cause animated scrolling */
//             sidebar.sync_uri (current_tab.uri);
//             top_menu.working = current_tab.is_frozen;
//             save_active_tab_position ();
//         }

//         public void open_tabs (GLib.File[]? files = null,
//                                ViewMode mode = ViewMode.PREFERRED,
//                                bool ignore_duplicate = false) {

//             if (files == null || files.length == 0 || files[0] == null) {
//                 /* Restore session if not root and settings allow */
//                 if (Files.is_admin () ||
//                     !Files.app_settings.get_boolean ("restore-tabs") ||
//                     restore_tabs () < 1) {

//                     /* Open a tab pointing at the default location if no tabs restored*/
//                     var location = GLib.File.new_for_path (PF.UserUtils.get_real_user_home ());
//                     add_tab (location, mode);
//                     /* Ensure default tab's slot is active so it can be focused */
//                     current_tab = (ViewContainer)(tabs.current.page);
//                     current_tab.set_active_state (true, false);
//                 }
//             } else {
//                 /* Open tabs at each requested location */
//                 /* As files may be derived from commandline, we use a new sanitized one */
//                 foreach (var file in files) {
//                     add_tab (get_file_from_uri (file.get_uri ()), mode, ignore_duplicate);
//                 }
//             }
//         }

//         private void add_tab_by_uri (string uri, ViewMode mode = ViewMode.PREFERRED) {
//             var file = get_file_from_uri (uri);
//             if (file != null) {
//                 add_tab (file, mode);
//             } else {
//                 add_tab ();
//             }
//         }

//         private void add_tab (GLib.File _location = GLib.File.new_for_commandline_arg (Environment.get_home_dir ()),
//                              ViewMode mode = ViewMode.PREFERRED,
//                              bool ignore_duplicate = false) {

//             GLib.File location;
//             // For simplicity we do not use cancellable. If issues arise may need to do this.
//             var ftype = _location.query_file_type (FileQueryInfoFlags.NONE, null);

//             if (ftype == FileType.REGULAR) {
//                 location = _location.get_parent ();
//             } else {
//                 location = _location.dup ();
//             }

//             if (ignore_duplicate) {
//                 bool is_child;
//                 var existing_tab_position = location_is_duplicate (location, out is_child);
//                 if (existing_tab_position >= 0) {
//                     tabs.current = tabs.get_tab_by_index (existing_tab_position);
//                     change_tab (existing_tab_position);

//                     if (is_child) {
//                         /* Select the child  */
//                         ((ViewContainer)(tabs.current.page)).focus_location_if_in_current_directory (location);
//                     }

//                     return;
//                 }
//             }

//             mode = real_mode (mode);
//             var content = new View.ViewContainer (this);
//             var tab = new Granite.Widgets.Tab.with_accellabels (
//                 "",
//                 null,
//                 content,
//                 new Granite.AccelLabel (_("Close Tab"), "<Ctrl>w"),
//                 new Granite.AccelLabel (_("Duplicate Tab"), "<Ctrl><Alt>t"),
//                 new Granite.AccelLabel (_("Open in New Window"), "<Ctrl><Alt>n")
//             ) {
//                 ellipsize_mode = Pango.EllipsizeMode.MIDDLE
//             };

//             change_tab ((int)tabs.insert_tab (tab, -1));
//             tabs.current = tab;

//             content.tab_name_changed.connect ((tab_name) => {
//                 check_for_tabs_with_same_name (); // Also sets tab_label.
//             });

//             content.loading.connect ((is_loading) => {
//                 if (restoring_tabs > 0 && !is_loading) {
//                     restoring_tabs--;
//                     /* Each restored tab must signal with is_loading false once */
//                     assert (restoring_tabs >= 0);
//                     if (!content.can_show_folder) {
//                         warning ("Cannot restore %s, ignoring", content.uri);
//                         /* remove_tab function uses Idle loop to close tab */
//                         remove_content (content);
//                     }
//                 }

//                 tab.working = is_loading;
//                 update_top_menu ();
//                 if (restoring_tabs == 0 && !is_loading) {
//                     save_tabs ();
//                 }
//             });

//             content.active.connect (() => {
//                 update_top_menu ();
//             });

//             if (!location.equal (_location)) {
//                 content.add_view (mode, location, {_location});
//             } else {
//                 content.add_view (mode, location);
//             }
//         }

//         private int location_is_duplicate (GLib.File location, out bool is_child) {
//             is_child = false;
//             string parent_path = "";
//             string uri = location.get_uri ();
//             bool is_folder = location.query_file_type (FileQueryInfoFlags.NONE) == FileType.DIRECTORY;
//             /* Ensures consistent format of protocol and path */
//             parent_path = FileUtils.get_parent_path_from_path (location.get_path ());
//             int existing_position = 0;

//             foreach (Granite.Widgets.Tab tab in tabs.tabs) {
//                 var tab_location = ((ViewContainer)(tab.page)).location;
//                 string tab_uri = tab_location.get_uri ();

//                 if (FileUtils.same_location (uri, tab_uri)) {
//                     return existing_position;
//                 } else if (!is_folder && FileUtils.same_location (location.get_parent ().get_uri (), tab_uri)) {
//                     is_child = true;
//                     return existing_position;
//                 }

//                 existing_position++;
//             }

//             return -1;
//         }

//         /** Compare every tab label with every other and resolve ambiguities **/
//         private void check_for_tabs_with_same_name () {
//             // Take list copy so foreach clauses can be nested safely
//             var copy_tabs = tabs.tabs.copy ();
//             foreach (unowned var tab in tabs.tabs) {
//                 var content = (ViewContainer)(tab.page);
//                 if (content.tab_name == Files.INVALID_TAB_NAME) {
//                     set_tab_label (content.tab_name, tab, content.tab_name);
//                     continue;
//                 }

//                 var path = content.location.get_path ();
//                 if (path == null) { // e.g. for uris like network://
//                     set_tab_label (content.tab_name, tab, content.tab_name);
//                     continue;
//                 }
//                 var basename = Path.get_basename (path);

//                 // Ignore content not named from the path
//                 if (!content.tab_name.has_suffix (basename)) {
//                     set_tab_label (content.tab_name, tab, content.tab_name);
//                     continue;
//                 }

//                 // Tab label defaults to the basename.
//                 set_tab_label (basename, tab, content.tab_name);

//                 // Compare with every other tab for same label
//                 foreach (unowned var tab2 in copy_tabs) {
//                     var content2 = (ViewContainer)(tab2.page);
//                     if (content2 == content || content2.tab_name == Files.INVALID_TAB_NAME) {
//                         continue;
//                     }

//                     var path2 = content2.location.get_path ();
//                     if (path2 == null) { // e.g. for uris like network://
//                         continue;
//                     }
//                     var basename2 = Path.get_basename (path2);

//                     // Ignore content not named from the path
//                     if (!content2.tab_name.has_suffix (basename2)) {
//                         continue;
//                     }

//                     if (basename2 == basename && path2 != path) {
//                         set_tab_label (FileUtils.disambiguate_uri (path2, path), tab2, content2.tab_name);
//                         set_tab_label (FileUtils.disambiguate_uri (path, path2), tab, content.tab_name);
// >>>>>>> master
                    }

                    // Simpler to not try an revert previously ambiguous names.
                    // Would have to compare every tab with every other one
                    // Moreover there is still a possible ambiguity
                }
            }
// <<<<<<< HEAD
        }

        return new_tabname;
    }

    /* Just to append "as Administrator" when appropriate */
    private void set_tab_label (string label, Adw.TabPage tab, string? tooltip = null) {
        string lab = label;
        if (Files.is_admin ()) {
            lab += (" " + _("(as Administrator)"));
        }

        tab.title = lab;

        /* Needs change to Granite to allow (visible) tooltip amendment.
         * This compiles because tab is a widget but the tootip is overridden by that set internally */
        if (tooltip != null) {
            var tt = tooltip;
// =======

//             return;
//         }

//         /* Just to append "as Administrator" when appropriate */
//         private void set_tab_label (string label, Granite.Widgets.Tab tab, string? tooltip = null) {

//             string lab = label;
// >>>>>>> master
            if (Files.is_admin ()) {
                tt += (" " + _("(as Administrator)"));
            }

// <<<<<<< HEAD
            tab.tooltip = tt;
// =======
//             tab.label = lab;

//             /* Needs change to Granite to allow (visible) tooltip amendment.
//              * This compiles because tab is a widget but the tootip is overridden by that set internally */
//             if (tooltip != null) {
//                 var tt = tooltip;
//                 if (Files.is_admin ()) {
//                     tt += (" " + _("(as Administrator)"));
//                 }

//                 tab.set_tooltip_text (tt);
//             }
//         }

//         public void bookmark_uri (string uri, string custom_name = "") {
//             sidebar.add_favorite_uri (uri, custom_name);
//         }

//         public bool can_bookmark_uri (string uri) {
//             return !sidebar.has_favorite_uri (uri);
//         }

//         public void remove_content (ViewContainer view_container) {
//             remove_tab (tabs.get_tab_by_widget ((Gtk.Widget)view_container));
//         }

//         private void remove_tab (Granite.Widgets.Tab? tab) {
//             if (tab != null) {
//                 /* Use Idle in case of rapid closing of multiple tabs during restore */
//                 Idle.add_full (Priority.LOW, () => {
//                     tab.close ();
//                     return GLib.Source.REMOVE;
//                 });
//             }
//         }

//         private void add_window (GLib.File location = GLib.File.new_for_path (PF.UserUtils.get_real_user_home ()),
//                                  ViewMode mode = ViewMode.PREFERRED) {

//             marlin_app.create_window (location, real_mode (mode));
//         }

//         private void undo_actions_set_insensitive () {
//             GLib.SimpleAction action;
//             action = get_action ("undo");
//             action.set_enabled (false);
//             action = get_action ("redo");
//             action.set_enabled (false);
//         }

//         private void update_undo_actions () {
//             GLib.SimpleAction action;
//             action = get_action ("undo");
//             action.set_enabled (undo_manager.can_undo ());
//             action = get_action ("redo");
//             action.set_enabled (undo_manager.can_redo ());
//         }

//         private void action_edit_path () {
//             top_menu.enter_navigate_mode ();
//         }

//         private void action_bookmark (GLib.SimpleAction action, GLib.Variant? param) {
//             /* Note: Duplicate bookmarks will not be created by BookmarkList */
//             unowned var selected_files = current_tab.view.get_selected_files ();
//             if (selected_files == null) {
//                 sidebar.add_favorite_uri (current_tab.location.get_uri ());
//             } else if (selected_files.first ().next == null) {
//                 sidebar.add_favorite_uri (selected_files.first ().data.uri);
//             } // Ignore if more than one item selected
//         }

//         private void action_find (GLib.SimpleAction action, GLib.Variant? param) {
//             /* Do not initiate search while slot is frozen e.g. during loading */
//             if (current_tab == null || current_tab.is_frozen) {
//                 return;
//             }

//             if (param == null) {
//                 top_menu.enter_search_mode ();
//             } else {
//                 top_menu.enter_search_mode (param.get_string ());
//             }
//         }

//         private bool adding_window = false;
//         private void action_new_window (GLib.SimpleAction action, GLib.Variant? param) {
//             /* Limit rate of adding new windows using the keyboard */
//             if (adding_window) {
//                 return;
//             } else {
//                 adding_window = true;
//                 add_window ();
//                 GLib.Timeout.add (500, () => {
//                     adding_window = false;
//                     return GLib.Source.REMOVE;
//                 });
//             }
//         }

//         private void action_quit (GLib.SimpleAction action, GLib.Variant? param) {
//             ((Files.Application)(application)).quit ();
//         }

//         private void action_reload () {
//             /* avoid spawning reload when key kept pressed */
//             if (tabs.current.working) {
//                 warning ("Too rapid reloading suppressed");
//                 return;
//             }
//             current_tab.reload ();
//             sidebar.reload ();
//         }

//         private void action_view_mode (GLib.SimpleAction action, GLib.Variant? param) {
//             if (current_tab == null) { // can occur during startup
//                 return;
//             }

//             ViewMode mode = real_mode ((ViewMode)(param.get_uint32 ()));
//             current_tab.change_view_mode (mode);
//             /* ViewContainer takes care of changing appearance */
//         }

//         private void action_go_to (GLib.SimpleAction action, GLib.Variant? param) {
//             switch (param.get_string ()) {
//                 case "RECENT":
//                     uri_path_change_request (Files.RECENT_URI);
//                     break;

//                 case "HOME":
//                     uri_path_change_request ("file://" + PF.UserUtils.get_real_user_home ());
//                     break;

//                 case "TRASH":
//                     uri_path_change_request (Files.TRASH_URI);
//                     break;

//                 case "ROOT":
//                     uri_path_change_request (Files.ROOT_FS_URI);
//                     break;

//                 case "NETWORK":
//                     uri_path_change_request (Files.NETWORK_URI);
//                     break;

//                 case "SERVER":
//                     connect_to_server ();
//                     break;

//                 case "UP":
//                     current_tab.go_up ();
//                     break;

//                 case "FORWARD":
//                     current_tab.go_forward ();
//                     break;

//                 case "BACK":
//                     current_tab.go_back ();
//                     break;

//                 default:
//                     break;
//             }
//         }

//         private void action_zoom (GLib.SimpleAction action, GLib.Variant? param) {
//             if (current_tab != null) {
//                 assert (current_tab.view != null);
//                 switch (param.get_string ()) {
//                     case "ZOOM_IN":
//                         current_tab.view.zoom_in ();
//                         break;

//                     case "ZOOM_OUT":
//                         current_tab.view.zoom_out ();
//                         break;

//                     case "ZOOM_NORMAL":
//                         current_tab.view.zoom_normal ();
//                         break;

//                     default:
//                         break;
//                 }
//             }
//         }

//         private void action_tab (GLib.SimpleAction action, GLib.Variant? param) {
//             switch (param.get_string ()) {
//                 case "NEW":
//                     add_tab ();
//                     break;

//                 case "CLOSE":
//                     remove_tab (tabs.current);
//                     break;

//                 case "NEXT":
//                     tabs.next_page ();
//                     break;

//                 case "PREVIOUS":
//                     tabs.previous_page ();
//                     break;

//                 case "TAB":
//                     add_tab (current_tab.location, current_tab.view_mode);
//                     break;

//                 case "WINDOW":
//                     tabs.tab_moved (tabs.current, 0, 0);
//                     break;

//                 default:
//                     break;
//             }
//         }

//         private void action_info (GLib.SimpleAction action, GLib.Variant? param) {
//             switch (param.get_string ()) {
//                 case "HELP":
//                     show_app_help ();
//                     break;

//                 default:
//                     break;
//             }
//         }

//         private void action_undo (GLib.SimpleAction action, GLib.Variant? param) {
//             if (doing_undo_redo) { /* Guard against rapid pressing of Ctrl-Z */
//                 return;
//             }
//             before_undo_redo ();
//             undo_manager.undo.begin (this, null, (obj, res) => {
//                 try {
//                     undo_manager.undo.end (res);
//                     after_undo_redo ();
//                 } catch (Error e) {
//                     critical (e.message);
//                 }
//             });
//         }

//         private void action_redo (GLib.SimpleAction action, GLib.Variant? param) {
//             if (doing_undo_redo) { /* Guard against rapid pressing of Ctrl-Shift-Z */
//                 return;
//             }
//             before_undo_redo ();
//             undo_manager.redo.begin (this, null, (obj, res) => {
//                 try {
//                     undo_manager.redo.end (res);
//                     after_undo_redo ();
//                 } catch (Error e) {
//                     critical (e.message);
//                 }
//             });
//         }

//         private void before_undo_redo () {
//             doing_undo_redo = true;
//             update_undo_actions ();
//         }

//         public void after_undo_redo () {
//             if (current_tab.slot.directory.is_recent) {
//                 current_tab.reload ();
//             }

//             doing_undo_redo = false;
//         }

//         public void change_state_show_hidden (GLib.SimpleAction action) {
//             bool state = !action.state.get_boolean ();
//             action.set_state (new GLib.Variant.boolean (state));
//             Files.app_settings.set_boolean ("show-hiddenfiles", state);
//         }

//         public void change_state_single_click_select (GLib.SimpleAction action) {
//             bool state = !action.state.get_boolean ();
//             action.set_state (new GLib.Variant.boolean (state));
//             Files.Preferences.get_default ().singleclick_select = state;
//         }

//         public void change_state_show_remote_thumbnails (GLib.SimpleAction action) {
//             bool state = !action.state.get_boolean ();
//             action.set_state (new GLib.Variant.boolean (state));
//             Files.app_settings.set_boolean ("show-remote-thumbnails", state);
//         }

//         public void change_state_show_local_thumbnails (GLib.SimpleAction action) {
//             bool state = !action.state.get_boolean ();
//             action.set_state (new GLib.Variant.boolean (state));
//             Files.app_settings.set_boolean ("show-local-thumbnails", state);
//         }

//         private void connect_to_server () {
//             var dialog = new PF.ConnectServerDialog ((Gtk.Window) this);
//             string server_uri = "";

//             if (dialog.run () == Gtk.ResponseType.OK) {
//                 server_uri = dialog.server_uri;
//             }

//             dialog.destroy ();

//             if (server_uri != "") {
//                 uri_path_change_request (dialog.server_uri, Files.OpenFlag.DEFAULT);
//             }
//         }

//         void show_app_help () {
//             AppInfo.launch_default_for_uri_async.begin (Files.HELP_URL, null, null, (obj, res) => {
//                 try {
//                     AppInfo.launch_default_for_uri_async.end (res);
//                 } catch (Error e) {
//                     warning ("Could not open help: %s", e.message);
//                 }
//             });
//         }

//         public GLib.SimpleAction? get_action (string action_name) {
//             return (GLib.SimpleAction?)(lookup_action (action_name));
//         }

//         private ViewMode real_mode (ViewMode mode) {
//             switch (mode) {
//                 case ViewMode.ICON:
//                 case ViewMode.LIST:
//                 case ViewMode.MILLER_COLUMNS:
//                     return mode;

//                 case ViewMode.CURRENT:
//                     return current_tab.view_mode;

//                 default:
//                     break;
//             }

//             return (ViewMode)(Files.app_settings.get_enum ("default-viewmode"));
//         }

//         public void quit () {
//             save_geometries ();
//             save_tabs ();

//             top_menu.destroy (); /* stop unwanted signals if quit while pathbar in focus */

//             tabs.tab_removed.disconnect (on_tab_removed); /* Avoid infinite loop */

//             foreach (var tab in tabs.tabs) {
//                 current_tab = null;
//                 ((View.ViewContainer)(tab.page)).close ();
//             }

//             this.destroy ();
//         }

//         private void save_geometries () {
//             if (!is_first_window) {
//                 return; //TODO Save all windows
//             }
//             var sidebar_width = lside_pane.get_position ();
//             var min_width = Files.app_settings.get_int ("minimum-sidebar-width");

//             sidebar_width = int.max (sidebar_width, min_width);
//             Files.app_settings.set_int ("sidebar-width", sidebar_width);

//             int width, height, x, y;

//             // Includes shadow for normal windows (but not maximized or tiled)
//             get_size (out width, out height);
//             get_position (out x, out y);

//             var gdk_state = get_window ().get_state ();
//             // If window is tiled, is it on left (start = true) or right (start = false)?
//             var rect = get_display ().get_monitor_at_point (x, y).get_geometry ();
//             var start = x + width < rect.width;

//             Files.app_settings.set_enum ("window-state",
//                                            Files.WindowState.from_gdk_window_state (gdk_state, start));

//             Files.app_settings.set ("window-size", "(ii)", width, height);
//             Files.app_settings.set ("window-position", "(ii)", x, y);
//         }

//         private void save_tabs () {
//             if (!is_first_window) {
//                 return; //TODO Save all windows
//             }

//             if (!Files.Preferences.get_default ().remember_history) {
//                 return;  /* Do not clear existing settings if history is off */
//             }

//             VariantBuilder vb = new VariantBuilder (new VariantType ("a(uss)"));
//             foreach (var tab in tabs.tabs) {
//                 assert (tab != null);
//                 var view_container = (ViewContainer)(tab.page) ;

//                 /* Do not save if "File does not exist" or "Does not belong to you" */
//                 if (!view_container.can_show_folder) {
//                     continue;
//                 }
//                 /* ViewContainer is responsible for returning valid uris */
//                 vb.add ("(uss)",
//                         view_container.view_mode,
//                         view_container.get_root_uri () ?? PF.UserUtils.get_real_user_home (),
//                         view_container.get_tip_uri () ?? ""
//                        );
//             }

//             Files.app_settings.set_value ("tab-info-list", vb.end ());
//             save_active_tab_position ();
//         }

//         private void save_active_tab_position () {
//             Files.app_settings.set_int ("active-tab-position", tabs.get_tab_position (tabs.current));
//         }

//         public uint restore_tabs () {
//             /* Do not restore tabs if history off nor more than once */
//             if (!Files.Preferences.get_default ().remember_history || tabs_restored || !is_first_window) { //TODO Restore all windows
//                 return 0;
//             } else {
//                 tabs_restored = true;
//             }

//             GLib.Variant tab_info_array = Files.app_settings.get_value ("tab-info-list");
//             GLib.VariantIter iter = new GLib.VariantIter (tab_info_array);

//             ViewMode mode = ViewMode.INVALID;
//             string? root_uri = null;
//             string? tip_uri = null;

//             /* Changes of view and rendering of location bar are avoided while restoring tabs > 0
//              * as this causes all sorts of problems */
//             restoring_tabs = 0;

//             while (iter.next ("(uss)", out mode, out root_uri, out tip_uri)) {

//                 if (mode < 0 || mode >= ViewMode.INVALID ||
//                     root_uri == null || root_uri == "" || tip_uri == null) {

//                     continue;
//                 }

//                 /* We do not check valid location here because it may cause the interface to hang
//                  * before the window appears (e.g. if trying to connect to a server that has become unavailable)
//                  * Leave it to Files.Directory.Async to deal with invalid locations asynchronously.
//                  * Restored tabs with invalid locations are removed in the `loading` signal handler.
//                  */

//                 restoring_tabs++;
//                 add_tab_by_uri (root_uri, mode);

//                 if (mode == ViewMode.MILLER_COLUMNS && tip_uri != root_uri) {
//                     expand_miller_view (tip_uri, root_uri);
//                 }

//                 mode = ViewMode.INVALID;
//                 root_uri = null;
//                 tip_uri = null;

//                 /* As loading is now asynchronous we do not need a delay here any longer */
//             }

//             /* We assume that the following code is reached before restoring tabs have finished loading. Tests
//              * show this to be the case. */

//             /* Don't attempt to set active tab position if no tabs were restored.*/
//             if (restoring_tabs < 1) {
//                 return 0;
//             }

//             int active_tab_position = Files.app_settings.get_int ("active-tab-position");
//             if (active_tab_position < 0 || active_tab_position >= restoring_tabs) {
//                 active_tab_position = 0;
//             }

//             tabs.current = tabs.get_tab_by_index (active_tab_position);
//             current_tab = (ViewContainer?)(tabs.current.page);

//             string path = "";
//             if (current_tab != null) {
//                 path = current_tab.get_tip_uri ();

//                 if (path == null || path == "") {
//                     path = current_tab.get_root_uri ();
//                 }
//             }

//             /* Render the final path in the location bar without animation */
//             top_menu.update_location_bar (path, false);
//             return restoring_tabs;
//         }

//         private void expand_miller_view (string tip_uri, string unescaped_root_uri) {
//             /* It might be more elegant for Miller.vala to handle this */
//             var tab = tabs.current;
//             var view = (ViewContainer)(tab.page) ;
//             var mwcols = (Miller)(view.view) ;
//             var unescaped_tip_uri = FileUtils.sanitize_path (tip_uri);

//             if (unescaped_tip_uri == null) {
//                 warning ("Invalid tip uri for Miller View");
//                 return;
//             }

//             var tip_location = FileUtils.get_file_for_path (unescaped_tip_uri);
//             var root_location = FileUtils.get_file_for_path (unescaped_root_uri);
//             var relative_path = root_location.get_relative_path (tip_location);
//             GLib.File gfile;

//             if (relative_path != null) {
//                 string [] dirs = relative_path.split (GLib.Path.DIR_SEPARATOR_S);
//                 string uri = root_location.get_uri ();

//                 foreach (string dir in dirs) {
//                     uri += (GLib.Path.DIR_SEPARATOR_S + dir);
//                     gfile = get_file_from_uri (uri);

//                     mwcols.add_location (gfile, mwcols.current_slot); // MillerView can deal with multiple scroll requests
//                 }
//             } else {
//                 warning ("Invalid tip uri for Miller View %s", unescaped_tip_uri);
//             }
//         }

//         private void update_top_menu () {
//             if (restoring_tabs > 0 || current_tab == null) {
//                 return;
//             }

//             /* Update browser buttons */
//             top_menu.set_back_menu (current_tab.get_go_back_path_list ());
//             top_menu.set_forward_menu (current_tab.get_go_forward_path_list ());
//             top_menu.can_go_back = current_tab.can_go_back;
//             top_menu.can_go_forward = (current_tab.can_show_folder && current_tab.can_go_forward);
//             top_menu.working = current_tab.is_loading;

//             /* Update viewmode switch, action state and settings */
//             var mode = current_tab.view_mode;
//             view_switcher.set_mode (mode);
//             view_switcher.sensitive = current_tab.can_show_folder;
//             get_action ("view-mode").change_state (new Variant.uint32 (mode));
//             Files.app_settings.set_enum ("default-viewmode", mode);
//         }

//         private void update_labels (string uri) {
//             if (current_tab != null) { /* Can happen during restore */
//                 set_title (current_tab.tab_name); /* Not actually visible on elementaryos */
//                 top_menu.update_location_bar (uri);
//                 sidebar.sync_uri (uri);
//             }
//         }

//         public void mount_removed (Mount mount) {
//             debug ("Mount %s removed", mount.get_name ());
//             GLib.File root = mount.get_root ();

//             foreach (var page in tabs.get_children ()) {
//                 var view_container = (View.ViewContainer)page ;
//                 GLib.File location = view_container.location;

//                 if (location == null || location.has_prefix (root) || location.equal (root)) {
//                     if (view_container == current_tab) {
//                         view_container.focus_location (GLib.File.new_for_path (PF.UserUtils.get_real_user_home ()));
//                     } else {
//                         remove_content (view_container);
//                     }
//                 }
//             }
//         }

//         public void uri_path_change_request (string p, Files.OpenFlag flag = Files.OpenFlag.DEFAULT) {
//             /* Make a sanitized file from the uri */
//             var file = get_file_from_uri (p);
//             if (file != null) {
//                 switch (flag) {
//                     case Files.OpenFlag.NEW_TAB:
//                         add_tab (file, current_tab.view_mode);
//                         break;
//                     case Files.OpenFlag.NEW_WINDOW:
//                         add_window (file, current_tab.view_mode);
//                         break;
//                     default:
//                         grab_focus ();
//                         current_tab.focus_location (file);
//                         break;
//                 }
//             } else {
//                 warning ("Cannot browse %s", p);
//             }
//         }

//         /** Use this function to standardise how locations are generated from uris **/
//         private GLib.File? get_file_from_uri (string uri) {
//             string? current_uri = null;
//             if (current_tab != null && current_tab.location != null) {
//                 current_uri = current_tab.location.get_uri ();
//             }

//             string path = FileUtils.sanitize_path (uri, current_uri);
//             if (path.length > 0) {
//                 return GLib.File.new_for_uri (FileUtils.escape_uri (path));
//             } else {
//                 return null;
//             }
//         }

//         public new void grab_focus () {
//             current_tab.grab_focus ();
// >>>>>>> master
        }
    }

    private string disambiguate_name (string name, string path, string conflict_path) {
        string prefix = "";
        string prefix_conflict = "";
        string path_temp = path;
        string conflict_path_temp = conflict_path;

        /* Add parent directories until path and conflict path differ */
        while (prefix == prefix_conflict) {
            var parent_path= FileUtils.get_parent_path_from_path (path_temp);
            var parent_conflict_path = FileUtils.get_parent_path_from_path (conflict_path_temp);
            prefix = Path.get_basename (parent_path) + Path.DIR_SEPARATOR_S + prefix;
            prefix_conflict = Path.get_basename (parent_conflict_path) +
                              Path.DIR_SEPARATOR_S +
                              prefix_conflict;
            path_temp= parent_path;
            conflict_path_temp = parent_conflict_path;
        }

        return prefix + name;
    }

    public void bookmark_uri (string uri, string custom_name = "") {
        sidebar.add_favorite_uri (uri, custom_name);
    }

    public bool can_bookmark_uri (string uri) {
        return !sidebar.has_favorite_uri (uri);
    }

    public void remove_content (ViewContainer view_container) {
        for (uint i = 0; i < tab_view.n_pages; i++) {
            var tab = (Adw.TabPage)(tab_view.pages.get_item (i));
            if (tab.child == view_container) {
                remove_tab (tab);
                break;
            }
        }
    }

    private void remove_tab (Adw.TabPage? tab) {
        if (tab != null) {
            /* Use Idle in case of rapid closing of multiple tabs during restore */
            Idle.add_full (Priority.LOW, () => {
                tab_view.close_page (tab);
                return GLib.Source.REMOVE;
            });
        }
    }

    private void add_window (
        GLib.File location = GLib.File.new_for_path (PF.UserUtils.get_real_user_home ()),
        ViewMode mode = ViewMode.PREFERRED
    ) {
        marlin_app.create_window (location, real_mode (mode));
    }

    private void undo_actions_set_insensitive () {

    }

    private void update_undo_actions () {
        GLib.SimpleAction action;
        action = get_action ("undo");
        action.set_enabled (undo_manager.can_undo ());
        action = get_action ("redo");
        action.set_enabled (undo_manager.can_redo ());
    }

    private void action_edit_path () {
        top_menu.path_bar.mode = PathBarMode.ENTRY;
    }

    private void action_bookmark () {
        /* Note: Duplicate bookmarks will not be created by BookmarkList */
        if (current_view_widget == null) {
            return;
        }

        List<Files.File> selected_files = null;
        switch (current_view_widget.get_selected_files (out selected_files)) {
            case 0:
                // Bookmark the background folder
                sidebar.add_favorite_uri (current_container.uri);
                sidebar.sync_uri (current_container.uri);
                break;
            case 1:
                // Bookmark the selected file/folder
                sidebar.add_favorite_uri (selected_files.data.uri);
                break;
            default:
                break;
        }
    }

    private void action_rename () {
        if (sidebar.get_focus_child () != null) {
            sidebar.rename_selected_bookmark ();
            return;
        }

        if (current_view_widget == null) {
            return;
        }

        List<Files.File> selected_files = null;
        if (current_view_widget.get_selected_files (out selected_files) == 1) {
            var file = selected_files.data;
            current_view_widget.is_renaming = true; //Needed??

            var layout = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            var header = new Granite.HeaderLabel (_("Enter the new name")) {
                halign = Gtk.Align.CENTER
            };
            var name_entry = new Gtk.Entry () { //TODO Use a validated entry?
                text = file.basename,
                width_chars = int.min (file.basename.length + 6, 100)
            };
            layout.append (header);
            layout.append (name_entry);
            var rename_dialog = new Granite.Dialog () {
                modal = true
            };
            rename_dialog.get_content_area ().append (layout);
            rename_dialog.add_button ("Cancel", Gtk.ResponseType.CANCEL);

            var suggested_button = rename_dialog.add_button ("Rename", Gtk.ResponseType.ACCEPT);
            suggested_button.add_css_class ("suggested-action");
            name_entry.bind_property (
                "text",
                suggested_button,
                "sensitive",
                BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE,
                (binding, src, ref tgt) => {
                    unowned var text = src.get_string ();
                    bool sensitive = (
                        (text != "") &&
                        !(text.contains (Path.DIR_SEPARATOR_S)) &&
                        (text != file.basename)
                    );
                    tgt.set_boolean (sensitive);
                    return true;
                },
                null
            );

            name_entry.activate.connect (() => {
                rename_dialog.response (
                    suggested_button.sensitive ? Gtk.ResponseType.ACCEPT : Gtk.ResponseType.CANCEL
                );
            });

            rename_dialog.response.connect ((response_id) => {
                if (response_id == Gtk.ResponseType.ACCEPT) {
                    current_view_widget.select_after_add = true;
                    FileUtils.set_file_display_name.begin (
                        file.location,
                        name_entry.text,
                        null, //TODO Do we need a cancellable?
                        (obj, res) => {
                            try {
                                //For now assume new file will be added to view if no error
                                FileUtils.set_file_display_name.end (res);
                            } catch (Error e) {
                                current_view_widget.select_after_add = false;
                            }
                        }
                    );
                }

                rename_dialog.destroy ();
                current_view_widget.is_renaming = false;
            });
            rename_dialog.present ();
        }
    }

    private void action_find (GLib.SimpleAction action, GLib.Variant? param) {
        /* Do not initiate search while slot is frozen e.g. during loading */
        if (current_container == null) {
        // if (current_container == null || current_container.is_frozen) {
            return;
        }

        if (param != null) {
            top_menu.path_bar.search (param.get_string ());
        } else {
            top_menu.path_bar.search ("");
        }
    }

    private bool adding_window = false;
    private void action_new_window (GLib.SimpleAction action, GLib.Variant? param) {
        /* Limit rate of adding new windows using the keyboard */
        if (adding_window) {
            return;
        } else {
            adding_window = true;
            add_window ();
            GLib.Timeout.add (500, () => {
                adding_window = false;
                return GLib.Source.REMOVE;
            });
        }
    }

    private void action_new_folder () {
        if (current_view_widget == null) {
            return;
        }

        current_view_widget.rename_after_add = true;
        FileOperations.new_folder.begin (
            this, current_container.location, null, (obj, res) => {
            try {
                //For now assume file will be added to view if no error
                FileOperations.new_folder.end (res);
            } catch (Error e) {
                current_view_widget.rename_after_add = false;
                critical (e.message);
            }
        });
    }

    private void action_new_file () {
        if (current_view_widget == null) {
            return;
        }

        current_view_widget.rename_after_add = true;
        FileOperations.new_file.begin (
            this, current_container.uri, null, null, 0, null, (obj, res) => {
            try {
                //For now assume file will be added to view if no error
                FileOperations.new_folder.end (res);
            } catch (Error e) {
                current_view_widget.rename_after_add = false;
                critical (e.message);
            }
        });
    }

    private void action_copy_to_clipboard () {
        if (current_view_widget != null) {
            List<Files.File> selected_files = null;
            if (current_view_widget.get_selected_files (out selected_files) > 0) {
                ClipboardManager.get_instance ().copy_files (selected_files);
            }
        }
    }

    private void action_link_to_clipboard () {
        if (current_view_widget != null) {
            List<Files.File> selected_files = null;
            if (current_view_widget.get_selected_files (out selected_files) > 0) {
                ClipboardManager.get_instance ().copy_link_files (selected_files);
            }
        }
    }

    private void action_cut_to_clipboard () {
        if (current_view_widget != null) {
            List<Files.File> selected_files = null;
            if (current_view_widget.get_selected_files (out selected_files) > 0) {
                ClipboardManager.get_instance ().cut_files (selected_files);
                current_view_widget.refresh_visible_items ();
            }
        }
    }

    private void action_paste_from_clipboard () {
        if (current_view_widget != null) {
            ClipboardManager.get_instance ().paste_files.begin (
                current_container.location,
                current_view_widget,
                (obj, res) => {}
            );
        }
    }

    private void action_trash () {
        delete_selected_files (true);
    }

    private void action_delete () {
        delete_selected_files (false);
    }

    private void delete_selected_files (bool try_trash) {
        //TODO Warning/confirming dialog under some circumstances
        var file = current_container.file;
        if (file != null &&
            !(file.is_trashed () && try_trash) &&
            file.is_writable ()) {

                List<Files.File> selected_files = null;
                if (current_view_widget.get_selected_files (out selected_files) > 0) {

                GLib.List<GLib.File> locations = null;
                if (file.is_recent_uri_scheme ()) {
                    selected_files.@foreach ((f) => {
                        locations.prepend (GLib.File.new_for_uri (f.get_display_target_uri ()));
                    });
                    // Refresh view?
                } else {
                    selected_files.@foreach ((f) => {
                        locations.prepend (f.location);
                    });
                }

                // aslot.directory.block_monitor (); //Needed?
                FileOperations.@delete.begin (
                    locations,
                    this,
                    true, // Do not delete immediately
                    null,
                    (obj, res) => {
                        try {
                            FileOperations.@delete.end (res);
                        } catch (Error e) {
                            debug (e.message);
                        }

                        // aslot.directory.unblock_monitor ();
                    }
                );
            }
        }
    }

    private void action_quit (GLib.SimpleAction action, GLib.Variant? param) {
        close_request ();
    }

    private void action_reload () {
        /* avoid spawning reload when key kept pressed */
        if (((ViewContainer)(tab_view.selected_page.child)).working) {
            warning ("Too rapid reloading suppressed");
            return;
        }

        current_container.reload ();
    }

    private void action_focus_view () {
        current_view_widget.grab_focus ();
        top_menu.path_bar.mode = PathBarMode.CRUMBS;
    }

    private void action_focus_sidebar () {
        sidebar.focus_bookmarks ();
    }

    private void action_view_mode (GLib.SimpleAction action, GLib.Variant? param) {
        if (current_container == null) { // can occur during startup
            return;
        }

        var mode = (ViewMode)(param.get_uint32 ());
        set_current_location_and_mode (mode, current_container.location, OpenFlag.DEFAULT);
        /* ViewContainer takes care of changing appearance */
    }

    private void action_forward (GLib.SimpleAction action, GLib.Variant? param) {
        current_container.go_forward (param.get_int32 ());
    }

    private void action_back (GLib.SimpleAction action, GLib.Variant? param) {
        current_container.go_back (param.get_int32 ());
    }

    private void action_go_to (GLib.SimpleAction action, GLib.Variant? param) {
        switch (param.get_string ()) {
            case "RECENT":
                uri_path_change_request (Files.RECENT_URI, OpenFlag.DEFAULT);
                break;

            case "HOME":
                set_default_location_and_mode ();
                break;

            case "TRASH":
                uri_path_change_request (Files.TRASH_URI, OpenFlag.DEFAULT);
                break;

            case "ROOT":
                uri_path_change_request (Files.ROOT_FS_URI, OpenFlag.DEFAULT);
                break;

            case "NETWORK":
                uri_path_change_request (Files.NETWORK_URI, OpenFlag.DEFAULT);
                break;

            case "SERVER":
                connect_to_server ();
                break;

            case "UP":
                current_container.go_up ();
                break;

            case "FORWARD":
                current_container.go_forward (1);
                break;

            case "BACK":
                current_container.go_back (1);
                break;

            default:
                assert_not_reached ();
                // uri_path_change_request (param.get_string (), OpenFlag.DEFAULT);
                break;
        }
    }

    private void action_zoom (GLib.SimpleAction action, GLib.Variant? param) {
        if (current_container != null) {
            assert (current_container.slot != null);
            switch (param.get_string ()) {
                case "ZOOM_IN":
                    current_container.slot.zoom_in ();
                    break;

                case "ZOOM_OUT":
                    current_container.slot.zoom_out ();
                    break;

                case "ZOOM_NORMAL":
                    current_container.slot.zoom_normal ();
                    break;

                default:
                    break;
            }
        }
    }

    private void action_tab (GLib.SimpleAction action, GLib.Variant? param) {
        switch (param.get_string ()) {
            case "NEW":
                //TODO DRY adding default tab
                add_tab ();
                set_current_location_and_mode (
                    ViewMode.PREFERRED,
                    GLib.File.new_for_path (PF.UserUtils.get_real_user_home ()),
                    OpenFlag.DEFAULT
                );

                break;
            case "CLOSE":
                remove_tab (tab_view.selected_page);

                break;
            case "NEXT":
                tab_view.select_next_page ();

                break;
            case "PREVIOUS":
                tab_view.select_previous_page ();

                break;
            case "DUP":
                var current_location = current_container.location;
                var current_mode = current_container.view_mode;
                add_tab ();
                set_current_location_and_mode (current_mode, current_container.location, OpenFlag.DEFAULT);

                break;
            case "WINDOW": // Move tab to new window
                var new_window = marlin_app.create_empty_window ();
                tab_view.transfer_page (tab_view.selected_page, new_window.tab_view, 0);
                // "page-detached" handler will take care of creating new default tab if necessary
                break;
            default:
                break;
        }
    }

    private void action_open_selected (GLib.SimpleAction action, GLib.Variant? param) {
        if (current_view_widget == null) {
            return;
        }

        switch (param.get_string ()) {
            case "DEFAULT":
                current_view_widget.open_selected (Files.OpenFlag.DEFAULT);
                break;

            case "NEW_ROOT":
                current_view_widget.open_selected (Files.OpenFlag.NEW_ROOT);
                break;

            case "NEW_TAB":
                current_view_widget.open_selected (Files.OpenFlag.NEW_TAB);
                break;

            case "NEW_WINDOW":
                current_view_widget.open_selected (Files.OpenFlag.NEW_WINDOW);
                break;

            case "APP":
                current_view_widget.open_selected (Files.OpenFlag.APP);
                break;
        }
    }

    private void action_open_with (GLib.SimpleAction action, GLib.Variant? param) {
        if (current_view_widget == null) {
            return;
        }

        var commandline = param.get_string ();
        try {
            var appinfo = AppInfo.create_from_commandline (commandline, null, AppInfoCreateFlags.NONE);
            List<Files.File> selected_files;
            current_view_widget.get_selected_files (out selected_files);
            List<string> uris = null;
            foreach (var file in selected_files) {
                uris.append (file.uri);
            }
            appinfo.launch_uris_async.begin (uris, new AppLaunchContext (), null, (source, task) => {
                try {
                    appinfo.launch_uris_async.end (task);
                } catch (Error e) {
                    PF.Dialogs.show_error_dialog (
                        _("Could not open selected files with %s").printf (appinfo.get_name ()),
                        e.message,
                        this
                    );
                }
            });
        } catch (Error e) {
            warning ("Unable to create appinfo from commandline. %s", e.message);
        }
    }

    private void action_info (GLib.SimpleAction action, GLib.Variant? param) {
        switch (param.get_string ()) {
            case "HELP":
                show_app_help ();
                break;

            default:
                break;
        }
    }

    private void action_sort_type (GLib.SimpleAction action, GLib.Variant? param) {
        if (current_view_widget == null) {
            return;
        }

        switch (param.get_string ()) {
            case "FILENAME":
                current_view_widget.sort_type = Files.SortType.FILENAME;
                action.set_state ("FILENAME");
                break;
            case "SIZE":
                current_view_widget.sort_type = Files.SortType.SIZE;
                action.set_state ("SIZE");
                break;
            case "TYPE":
                current_view_widget.sort_type = Files.SortType.TYPE;
                action.set_state ("TYPE");
                break;
            case "MODIFIED":
                current_view_widget.sort_type = Files.SortType.MODIFIED;
                action.set_state ("MODIFIED");
                break;

            default:
                break;
        }
    }

    private void action_toggle_sidebar () {
        sidebar.visible = !sidebar.visible;
    }

    private void action_toggle_select_all () {
        if (current_view_widget != null) {
            if (current_view_widget.all_selected) {
                current_view_widget.unselect_all ();
            } else {
                current_view_widget.select_all ();
            }
        }
    }

    private void action_invert_selection () {
        if (current_view_widget != null) {
            current_view_widget.invert_selection ();
        }
    }

    private void action_context_menu () {
        if (current_view_widget != null) {
            current_view_widget.show_appropriate_context_menu ();
        }
    }

    private void action_undo (GLib.SimpleAction action, GLib.Variant? param) {
        if (doing_undo_redo) { /* Guard against rapid pressing of Ctrl-Z */
            return;
        }
        before_undo_redo ();
        undo_manager.undo.begin (this, null, (obj, res) => {
            try {
                undo_manager.undo.end (res);
                after_undo_redo ();
            } catch (Error e) {
                critical (e.message);
            }
        });
    }

    private void action_redo (GLib.SimpleAction action, GLib.Variant? param) {
        if (doing_undo_redo) { /* Guard against rapid pressing of Ctrl-Shift-Z */
            return;
        }
        before_undo_redo ();
        undo_manager.redo.begin (this, null, (obj, res) => {
            try {
                undo_manager.redo.end (res);
                after_undo_redo ();
            } catch (Error e) {
                critical (e.message);
            }
        });
    }

    private void action_remove_content (GLib.SimpleAction action, GLib.Variant? param) {
        var content_id = param.get_int32 ();
        //TODO Find and remove content
    }

    private void action_path_change_request (GLib.SimpleAction action, GLib.Variant? param) {
        string uri;
        uint32 flag;
        param.@get ("(su)", out uri, out flag);
        uri_path_change_request (uri, (OpenFlag)flag);
    }

    private void action_loading_uri (GLib.SimpleAction action, GLib.Variant? param) {
        var uri = param.get_string ();
        update_top_menu (uri);
        top_menu.working = true;
    }

    private void action_loading_finished () {
        if (restoring_tabs > 0) {
            restoring_tabs--;
        }

        update_top_menu ();
        top_menu.working = false;
        // top_menu.mode =
    }

    private void action_selection_changing () {
        current_container.selection_changing ();
    }

    private void action_update_selection () {
        List<Files.File> selected_files = null;
        current_view_widget.get_selected_files (out selected_files);
        current_container.update_selection (selected_files);
    }

    private void action_properties (GLib.SimpleAction action, GLib.Variant? param) {
        List<Files.File> selected_files = null;
        var path = param.get_string ();
        if (path == "") {
            current_view_widget.get_selected_files (out selected_files);
        } else {
            selected_files.append (Files.File.@get (GLib.File.new_for_path (path)));
        }

        var properties_window = new PropertiesWindow (selected_files, current_view_widget, this);
        properties_window.response.connect ((res) => {
            properties_window.destroy ();
        });
        properties_window.present ();
    }

    private void before_undo_redo () {
        doing_undo_redo = true;
        update_undo_actions ();
    }

    public void after_undo_redo () {
        if (current_container.slot.directory.is_recent) {
            current_container.reload ();
        }

        doing_undo_redo = false;
    }


    public void change_state_folders_before_files (GLib.SimpleAction action) {
        bool state = !action.state.get_boolean ();
        action.set_state (new GLib.Variant.boolean (state));
        Files.Preferences.get_default ().sort_directories_first = state;
    }
        
    public void change_state_show_hidden (GLib.SimpleAction action) {
        bool state = !action.state.get_boolean ();
        action.set_state (new GLib.Variant.boolean (state));
        prefs.show_hidden_files = state;
    }

    private void change_state_sort_directories_first (GLib.SimpleAction action) {
        bool state = !action.state.get_boolean ();
        action.set_state (new GLib.Variant.boolean (state));
        prefs.sort_directories_first = state;
    }

    public void change_state_sort_reversed (GLib.SimpleAction action) {
        bool state = !action.state.get_boolean ();
        action.set_state (new GLib.Variant.boolean (state));
        if (current_view_widget != null) {
            current_view_widget.sort_reversed = state; // This will persist setting in metadata
        }
    }

    public void change_state_show_remote_thumbnails (GLib.SimpleAction action) {
        bool state = !action.state.get_boolean ();
        action.set_state (new GLib.Variant.boolean (state));
        Files.app_settings.set_boolean ("show-remote-thumbnails", state);
    }

    public void change_state_show_local_thumbnails (GLib.SimpleAction action) {
        bool state = !action.state.get_boolean ();
        action.set_state (new GLib.Variant.boolean (state));
        Files.app_settings.set_boolean ("show-local-thumbnails", state);
    }

    public void change_state_single_click_select (GLib.SimpleAction action) {
        bool state = !action.state.get_boolean ();
        action.set_state (new GLib.Variant.boolean (state));
        Files.app_settings.set_boolean ("singleclick-select", state);
    }

    private void connect_to_server () {
        var dialog = new PF.ConnectServerDialog ((Gtk.Window) this);
        string server_uri = "";

        dialog.response.connect ((response_id) => {
            server_uri = dialog.server_uri;
            dialog.destroy ();
            if (response_id == Gtk.ResponseType.OK && server_uri != "") {
                uri_path_change_request (server_uri, OpenFlag.DEFAULT);
            }
        });

        dialog.show ();
    }

    void show_app_help () {
        AppInfo.launch_default_for_uri_async.begin (Files.HELP_URL, null, null, (obj, res) => {
            try {
                AppInfo.launch_default_for_uri_async.end (res);
            } catch (Error e) {
                warning ("Could not open help: %s", e.message);
            }
        });
    }

    public GLib.SimpleAction? get_action (string action_name) {
        return (GLib.SimpleAction?)(lookup_action (action_name));
    }

    private ViewMode real_mode (ViewMode mode) {
        switch (mode) {
            case ViewMode.ICON:
            case ViewMode.LIST:
            case ViewMode.MULTICOLUMN:
                return mode;

            case ViewMode.CURRENT:
                critical ("Do not use ViewMode CURRENT");
                return top_menu.view_switcher.get_mode ();
            case ViewMode.PREFERRED:
                return (ViewMode)(Files.app_settings.get_enum ("default-viewmode"));

            default:
                assert_not_reached ();
        }

        return (ViewMode)(Files.app_settings.get_enum ("default-viewmode"));
    }

    public void quit () {
        save_geometries ();
        save_tabs ();

        // top_menu.destroy (); /* stop unwanted signals if quit while pathbar in focus */

        tab_view.page_detached.disconnect (on_page_detached); /* Avoid infinite loop */

        for (uint i = 0; i < tab_view.n_pages; i++) {
            var tab_page = (Adw.TabPage)(tab_view.pages.get_item (i));
            ((ViewContainer)(tab_page.child)).close ();
        }

        this.destroy ();
    }

    private void save_geometries () {
        if (!is_first_window) {
            return; //TODO Save all windows
        }
        var sidebar_width = lside_pane.get_position ();
        var min_width = Files.app_settings.get_int ("minimum-sidebar-width");

        sidebar_width = int.max (sidebar_width, min_width);
        Files.app_settings.set_int ("sidebar-width", sidebar_width);

        int width, height, x, y;

        // Includes shadow for normal windows (but not maximized or tiled)
        // get_size (out width, out height);
        // get_position (out x, out y);
        var toplevel_state = ((Gdk.Toplevel)get_surface ()).get_state ();
        // If window is tiled, is it on left (start = true) or right (start = false)?
        // var rect = get_display ().get_monitor_at_point (x, y).get_geometry ();
        // var start = x + width < rect.width;

        Files.app_settings.set_enum (
            "window-state",
             Files.WindowState.from_gdk_toplevel_state (toplevel_state)
        );

        Files.app_settings.set ("window-size", "(ii)", get_width (), get_height ());
        // Files.app_settings.set ("window-position", "(ii)", x, y);
    }

    private void save_tabs () {
        if (!is_first_window) {
            return; //TODO Save all windows
        }

        if (!Files.Preferences.get_default ().remember_history) {
            return;  /* Do not clear existing settings if history is off */
        }

        VariantBuilder vb = new VariantBuilder (new VariantType ("a(uss)"));
        for (uint i = 0; i < tab_view.n_pages; i++) {
            var tab = (Adw.TabPage)(tab_view.pages.get_item (i));
            var view_container = (ViewContainer)(tab.child) ;

            /* Do not save if "File does not exist" or "Does not belong to you" */
            if (!view_container.can_show_folder) {
                continue;
            }
            /* ViewContainer is responsible for returning valid uris */
            vb.add ("(uss)",
                    view_container.view_mode,
                    view_container.get_root_uri () ?? PF.UserUtils.get_real_user_home (),
                    view_container.get_tip_uri () ?? ""
                   );
        }

        Files.app_settings.set_value ("tab-info-list", vb.end ());
        save_active_tab_position ();
    }

    private void save_active_tab_position () {
        Files.app_settings.set_int (
            "active-tab-position",
            tab_view.get_page_position (tab_view.selected_page)
        );
    }

    public uint restore_tabs () {
        /* Do not restore tabs if history off nor more than once */
        if (!Files.Preferences.get_default ().remember_history ||
            tabs_restored ||
            !is_first_window) { //TODO Restore all windows?
            return 0;
        } else {
            tabs_restored = true;
        }

        GLib.Variant tab_info_array = Files.app_settings.get_value ("tab-info-list");
        GLib.VariantIter iter = new GLib.VariantIter (tab_info_array);

        ViewMode mode = ViewMode.ICON;
        string? root_uri = null;
        string? tip_uri = null;

        /* Changes of view and rendering of location bar are avoided while restoring tabs > 0
         * as this causes all sorts of problems */
        restoring_tabs = 0;

        while (iter.next ("(uss)", out mode, out root_uri, out tip_uri)) {
            if (mode < 0 || mode >= ViewMode.INVALID ||
                root_uri == null || root_uri == "" || tip_uri == null) {

                continue;
            }

            /* We do not check valid location here because it may cause the interface to hang
             * before the window appears (e.g. if trying to connect to a server that has become unavailable)
             * Leave it to Files.Directory.Async to deal with invalid locations asynchronously.
             * Restored tabs with invalid locations are removed in the `loading` signal handler.
             */

            restoring_tabs++;
            // Capture ref to added container as we need it in closure
            var container = add_tab ();
            set_current_location_and_mode (mode, GLib.File.new_for_uri (root_uri), OpenFlag.DEFAULT);

            if (container != null && tip_uri != null && tip_uri != root_uri) {
                var tip = tip_uri; //Take local copy else will be overwritten
                Idle.add (() => { //Wait for initial view to complete construction
                    container.set_tip_uri (tip);
                    return Source.REMOVE;
                });
            }

            mode = ViewMode.ICON;
            root_uri = null;
            tip_uri = null;

            /* As loading is now asynchronous we do not need a delay here any longer */
        }

        /* We assume that the following code is reached before restoring tabs have finished loading. Tests
         * show this to be the case. */

        /* Don't attempt to set active tab position if no tabs were restored.*/
        if (restoring_tabs < 1) {
            return 0;
        }

        int active_tab_position = Files.app_settings.get_int ("active-tab-position");
        if (active_tab_position < 0 || active_tab_position >= restoring_tabs) {
            active_tab_position = 0;
        }

        tab_view.selected_page = tab_view.get_nth_page (active_tab_position);

        string path = "";
        if (current_container != null) {
            path = current_container.get_tip_uri ();

            if (path == null || path == "") {
                path = current_container.get_root_uri ();
            }
        }

        /* Render the final path in the location bar without animation */
        top_menu.update_path_bar (path, false);
        return restoring_tabs;
    }

    private void update_top_menu (string? uri = null) {
        if (restoring_tabs > 0 || (current_container == null && uri == null)) {
            return;
        }

        if (current_container == null) {
            top_menu.update_path_bar (uri);
            sidebar.sync_uri (uri);
            return;
        }

        top_menu.update_path_bar (current_container.display_uri);
        sidebar.sync_uri (current_container.uri);

        if (current_container.tab_name == null) {
            // Wait until container finished setting up and loading
            return;
        }

        set_title (current_container.tab_name); /* Not actually visible on elementaryos */
        /* Update browser buttons */
        top_menu.set_back_menu (current_container.get_go_back_path_list ());
        top_menu.set_forward_menu (current_container.get_go_forward_path_list ());
        top_menu.can_go_back = current_container.can_go_back;
        top_menu.can_go_forward = (current_container.can_show_folder &&
                                   current_container.can_go_forward);

        /* Update viewmode switch, action state and settings */
        var mode = current_container.view_mode;
        top_menu.view_switcher.set_mode (mode);
        get_action ("view-mode").change_state (new Variant.uint32 (mode));
        Files.app_settings.set_enum ("default-viewmode", mode);
    }

    public void mount_removed (Mount mount) {
        GLib.File root = mount.get_root ();
        for (uint i = 0; i < tab_view.pages.get_n_items (); i++) {
            var view_container = (ViewContainer)(((Adw.TabPage)(tab_view.pages.get_item (i))).child) ;
            assert (view_container != null);
            GLib.File? location = view_container.location;
            if (location == null || location.has_prefix (root) || location.equal (root)) {
                if (view_container == current_container) {
                    set_default_location_and_mode ();
                } else {
                    remove_content (view_container);
                }
            }
        }
    }

    private void uri_path_change_request (string p, OpenFlag flag) {
        /* Make a sanitized file from the uri */
        if (p == "") {
            return;
        }

        var file = get_file_from_uri (p);
        if (file != null) {
            switch (flag) {
                case Files.OpenFlag.NEW_TAB:
                    var mode = current_container.view_mode;
                    add_tab ();
                    set_current_location_and_mode (mode, file, flag);
                    break;
                case Files.OpenFlag.NEW_WINDOW:
                    add_window (file, current_container.view_mode);
                    break;
                default:
                    var mode = current_container.view_mode;
                    set_current_location_and_mode (mode, file, flag);
                    break;
            }
        } else {
            warning ("Cannot browse %s", p);
        }
    }

    private void set_current_location_and_mode (ViewMode mode, GLib.File loc, OpenFlag flag) {
        update_top_menu (loc.get_uri ());
        current_container.set_location_and_mode (real_mode (mode), loc, null, flag);
    }

    private void set_default_location_and_mode () {
        set_current_location_and_mode (
            current_container.view_mode,
            GLib.File.new_for_path (PF.UserUtils.get_real_user_home ()),
            OpenFlag.DEFAULT
        );
    }

    /** Use this function to standardise how locations are generated from uris **/
    private GLib.File? get_file_from_uri (string uri) {
        string? current_uri = null;
        if (current_container != null && current_container.location != null) {
            current_uri = current_container.uri;
        }

        string path = FileUtils.sanitize_path (uri, current_uri);
        if (path.length > 0) {
            return GLib.File.new_for_uri (FileUtils.escape_uri (path));
        } else {
            return null;
        }
    }

    public new void grab_focus () {
        if (current_container != null) {
            current_container.grab_focus ();
        }
    }

    private void show_tab_context_menu (double x, double y) {
        tab_popover.set_pointing_to ({(int)x, (int)y, 1, 1});
        // Need idle for menu to display properly
        Idle.add (() => {
            tab_popover.popup ();
            return Source.REMOVE;
        });
    }
}
