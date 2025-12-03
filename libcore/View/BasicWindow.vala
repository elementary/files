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

public class Files.BasicWindow : Gtk.Box {
    // static uint window_id = 0;

    // const GLib.ActionEntry [] WIN_ENTRIES = {
    //     // {"new-window", action_new_window},
    //     // {"refresh", action_reload},
    //     // {"undo", action_undo},
    //     // {"redo", action_redo},
    //     {"bookmark", action_bookmark},
    //     // {"find", action_find, "s"},
    //     {"edit-path", action_edit_path},
    //     // {"tab", action_tab, "s"},
    //     {"go-to", action_go_to, "s"},
    //     {"zoom", action_zoom, "s"},
        // {"view-mode", action_view_mode, "u", "0" },
    //     {"show-hidden", null, null, "false", change_state_show_hidden},
    //     {"singleclick-select", null, null, "false", change_state_single_click_select},
    //     {"show-remote-thumbnails", null, null, "true", change_state_show_remote_thumbnails},
    //     {"show-local-thumbnails", null, null, "false", change_state_show_local_thumbnails},
    //     // {"tabhistory-restore", action_tabhistory_restore, "s" },
    //     {"folders-before-files", null, null, "true", change_state_folders_before_files},
    //     // {"restore-tabs-on-startup", null, null, "true", change_state_restore_tabs_on_startup},
        // {"forward", action_forward, "i"},
        // {"back", action_back, "i"},
    //     {"focus-sidebar", action_focus_sidebar}
    // };

    // public uint window_number { get; construct; }

    // public bool is_first_window {
    //     get {
    //         return (window_number == 0);
    //     }
    // }
    //TODO Introduce BrowserManager?
    private BasicBrowser _browser;
    public BasicBrowser browser {
        get {
            return _browser;
        }
    }

    public string title { get; private set; default = "";}
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

    // public GLib.File? location { get; default = null; }
    // public Gtk.Builder ui;
    // public Files.Application marlin_app { get; construct; }
    // private unowned UndoManager undo_manager;
    public Files.BasicHeaderBar headerbar;
    // public Hdy.HeaderBar headerbar;
    // public ViewSwitcher view_switcher;
    // public Hdy.TabView tab_view;
    // public Hdy.TabBar tab_bar;
    private Gtk.Paned lside_pane;
    public SidebarInterface sidebar;
    public BasicSlot slot { get; construct; }
    public Gtk.SelectionMode selection_mode {
        get {
            return slot.dir_view.get_selection_mode ();
        }

        set {
            slot.dir_view.set_selection_mode (value);
        }
    }

    public Files.ViewMode view_mode {
        get {
            return slot.mode;
        }
    }

    public Gtk.FileFilter filter {
        get {
            return slot.dir_view.filter;
        }

        set {
            slot.dir_view.filter = value;
        }
    }

    public List<Files.File> selected_files {
        get {
            return slot.dir_view.get_selected_files ();
        }
    }

    public string uri { // The current displayed uri
        get {
            return slot.uri;
        }
    }

    public GLib.File? location { // The currently displayed folder
        get {
            return slot.location;
        }
    }

    // private ButtonWithMenu button_forward;
    // private ButtonWithMenu button_back;
    // private BasicLocationBar? location_bar;
    private Gtk.Box extra_widget_box;
    // private Gtk.MenuButton tab_history_button;

    private bool locked_focus { get; set; default = false; }
    // private bool tabs_restored = false;
    // private int restoring_tabs = 0;
    // private bool doing_undo_redo = false;

    private Gtk.EventControllerKey key_controller; //[Gtk3] Does not work unless we keep this ref

    // public signal void loading_uri (string location);
    public signal void folder_deleted (GLib.File location);
    public signal void free_space_change ();
    public signal void file_activated ();

    // public BasicWindow (GLib.File? initial_location = null) {
    //     create_content.begin (initial_location, default_mode);
    // }
    // public Window (Files.Application _application) {
    //     Object (
    //         application: (Gtk.Application)_application,
    //         marlin_app: _application,
    //         window_number: Files.View.Window.window_id++
    //     );
    // }

    // static construct {
    //     Hdy.init ();
    // }

    construct {
        _browser = new BasicBrowser ();
        // height_request = 300;
        // width_request = 500;
        // icon_name = "system-file-manager";
        // title = _("Elementary File Browser Widget");

        // add_action_entries (WIN_ENTRIES, this);
        // undo_actions_set_insensitive ();

        // undo_manager = UndoManager.instance ();

        // Setting accels on `application` does not work in construct clause
        // Must set before building window so ViewSwitcher can lookup the accels for tooltips
        // if (is_first_window) {
        //     marlin_app.set_accels_for_action ("win.new-window", {"<Ctrl>N"});
        //     marlin_app.set_accels_for_action ("win.undo", {"<Ctrl>Z"});
        //     marlin_app.set_accels_for_action ("win.redo", {"<Ctrl><Shift>Z"});
        //     marlin_app.set_accels_for_action ("win.bookmark", {"<Ctrl>D"});
        //     marlin_app.set_accels_for_action ("win.find::", {"<Ctrl>F"});
        //     marlin_app.set_accels_for_action ("win.edit-path", {"<Ctrl>L"});
        //     marlin_app.set_accels_for_action ("win.tab::NEW", {"<Ctrl>T"});
        //     marlin_app.set_accels_for_action ("win.tab::CLOSE", {"<Ctrl>W"});
        //     marlin_app.set_accels_for_action ("win.tab::NEXT", {"<Ctrl>Page_Down", "<Ctrl>Tab"});
        //     marlin_app.set_accels_for_action ("win.tab::PREVIOUS", {"<Ctrl>Page_Up", "<Shift><Ctrl>Tab"});
        //     marlin_app.set_accels_for_action (
        //         GLib.Action.print_detailed_name ("win.view-mode", new Variant.uint32 (0)), {"<Ctrl>1"}
        //     );
        //     marlin_app.set_accels_for_action (
        //         GLib.Action.print_detailed_name ("win.view-mode", new Variant.uint32 (1)), {"<Ctrl>2"}
        //     );
        //     marlin_app.set_accels_for_action (
        //         GLib.Action.print_detailed_name ("win.view-mode", new Variant.uint32 (2)), {"<Ctrl>3"}
        //     );
        //     marlin_app.set_accels_for_action ("win.zoom::ZOOM_IN", {"<Ctrl>plus", "<Ctrl>equal"});
        //     marlin_app.set_accels_for_action ("win.zoom::ZOOM_OUT", {"<Ctrl>minus"});
        //     marlin_app.set_accels_for_action ("win.zoom::ZOOM_NORMAL", {"<Ctrl>0"});
        //     marlin_app.set_accels_for_action ("win.show-hidden", {"<Ctrl>H"});
        //     marlin_app.set_accels_for_action ("win.refresh", {"<Ctrl>R", "F5"});
        //     marlin_app.set_accels_for_action ("win.go-to::HOME", {"<Alt>Home"});
        //     marlin_app.set_accels_for_action ("win.go-to::RECENT", {"<Alt>R"});
        //     marlin_app.set_accels_for_action ("win.go-to::TRASH", {"<Alt>T"});
        //     marlin_app.set_accels_for_action ("win.go-to::ROOT", {"<Alt>slash"});
        //     marlin_app.set_accels_for_action ("win.go-to::NETWORK", {"<Alt>N"});
        //     marlin_app.set_accels_for_action ("win.go-to::SERVER", {"<Alt>C"});
        //     marlin_app.set_accels_for_action ("win.go-to::UP", {"<Alt>Up"});
        //     marlin_app.set_accels_for_action ("win.forward(1)", {"<Alt>Right", "XF86Forward"});
        //     marlin_app.set_accels_for_action ("win.back(1)", {"<Alt>Left", "XF86Back"});
        //     marlin_app.set_accels_for_action ("win.tab::TAB", {"<Shift><Ctrl>K"});
        //     marlin_app.set_accels_for_action ("win.tab::WINDOW", {"<Ctrl><Alt>N"});
        //     marlin_app.set_accels_for_action ("win.focus-sidebar", {"<Ctrl>Left"});
        // }

        // build_window ();
        headerbar = new Files.BasicHeaderBar ();
        sidebar = new Sidebar.BasicSidebarWindow ();
        // free_space_change.connect (sidebar.on_free_space_change);
        // content = new BasicViewContainer ();
        slot = new BasicSlot (default_location, LIST);
        slot.file_activated.connect (() => {
            file_activated ();
        });
        lside_pane = new Gtk.Paned (Gtk.Orientation.HORIZONTAL) {
            expand = true,
            position = Files.app_settings.get_int ("sidebar-width")
        };
        lside_pane.pack1 (sidebar, false, false);
        lside_pane.pack2 (slot.get_content_box (), true, true);
        // lside_pane.pack2 (content, true, true);

        // extra_widget_box = new Gtk.Box (HORIZONTAL, 0);
        // main_grid = new Gtk.Grid ();
        // main_grid.attach (headerbar, 0, 0, 1, 1);
        // main_grid.attach (lside_pane, 0, 1, 1, 1);
        // // main_grid.attach (extra_widget_box, 0, 2, 1, 1);
        // main_grid.show_all ();

        add (lside_pane);

        /** Apply preferences */
        var prefs = Files.Preferences.get_default (); // Bound to settings schema by Application

        // headerbar.path_change_request.connect (content.on_path_change_request);
        headerbar.path_change_request.connect (slot.on_path_change_request);

        sidebar.request_focus.connect (() => {
            // return !content.locked_focus && !locked_focus; //NOT USED???
        });

        sidebar.sync_needed.connect (() => {
            // loading_uri (content.uri);  // NOT USED????
        });

        // sidebar.path_change_request.connect (content.on_path_change_request);
        sidebar.path_change_request.connect (slot.on_path_change_request);

        headerbar.go_back.connect ((steps) => {
            string? path = browser.go_back (steps);
            if (path != null) {
                path_change (GLib.File.new_for_commandline_arg (path));
            }
        });
        headerbar.go_forward.connect ((steps) => {
            string? path = browser.go_forward (steps);
            if (path != null) {
                path_change (GLib.File.new_for_commandline_arg (path));
            }
        });
        // connect_content_signals (content);
        // int width, height;
        // Files.app_settings.get ("window-size", "(ii)", out width, out height);
        // default_width = width;
        // default_height = height;

        // if (is_first_window) {
        //     Files.app_settings.bind ("sidebar-width", lside_pane,
        //                                "position", SettingsBindFlags.DEFAULT);

        //     var state = (Files.WindowState)(Files.app_settings.get_enum ("window-state"));
        //     if (state == Files.WindowState.MAXIMIZED) {
        //         maximize ();
        //     }
        // }

        realize.connect (() => {
            Timeout.add (1000, () => {
                headerbar.update_location_bar (uri, false);
                return Source.REMOVE;
            });
        });

        // present ();
        show_all ();
    }

    // public unowned Gtk.Widget remove_headerbar () {
    //     main_grid.remove (headbar);
    //     return headbar;
    // }

    private void build_window () {
        // button_back = new ButtonWithMenu ("go-previous-symbolic");

        // button_back.tooltip_markup = Granite.markup_accel_tooltip ({"<Alt>Left"}, _("Previous"));
        // button_back.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        // button_forward = new ButtonWithMenu ("go-next-symbolic");

        // button_forward.tooltip_markup = Granite.markup_accel_tooltip ({"<Alt>Right"}, _("Next"));
        // button_forward.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        // view_switcher = new ViewSwitcher ((SimpleAction)lookup_action ("view-mode")) {
        //     margin_end = 20
        // };
        // view_switcher.set_mode (Files.app_settings.get_enum ("default-viewmode"));

        // location_bar = new BasicLocationBar ();

        // var app_menu = new AppMenu ();

        // var menu_button = new Gtk.MenuButton () {
        //     image = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR),
        //     popover = app_menu,
        //     tooltip_text = _("Menu")
        // };

        // var title = new Gtk.Box (HORIZONTAL, 0) { hexpand = false };
        // headerbar = new Files.HeaderBar ();
        // headerbar = new Hdy.HeaderBar () {
        //     show_close_button = true,
        //     custom_title = location_bar,
        //     centering_policy = LOOSE
        // };

        // headerbar.pack_start (button_back);
        // headerbar.pack_start (button_forward);
        // headerbar.pack_start (view_switcher);
        // headerbar.pack_start (location_bar);
        // headerbar.pack_end (menu_button);

        // tab_view = new Hdy.TabView () {
        //     menu_model = new Menu ()
        // };

        // var app_instance = (Gtk.Application)(GLib.Application.get_default ());

        // var new_tab_button = new Gtk.Button.from_icon_name ("list-add-symbolic") {
        //     action_name = "win.tab",
        //     action_target = new Variant.string ("NEW")
        // };
        // new_tab_button.tooltip_markup = Granite.markup_accel_tooltip (
        //     app_instance.get_accels_for_action ("win.tab::NEW"),
        //     _("New Tab")
        // );

        // tab_history_button = new Gtk.MenuButton () {
        //     image = new Gtk.Image.from_icon_name ("document-open-recent-symbolic", MENU),
        //     tooltip_text = _("Closed Tabs"),
        //     use_popover = false
        // };

        // tab_bar = new Hdy.TabBar () {
        //     autohide = false,
        //     expand_tabs = false,
        //     inverted = true,
        //     start_action_widget = new_tab_button,
        //     end_action_widget = tab_history_button,
        //     view = tab_view
        // };

        // var tab_box = new Gtk.Box (VERTICAL, 0);
        // tab_box.add (tab_bar);
        // tab_box.add (tab_view);

        // sidebar = new Sidebar.BasicSidebarWindow ();
        // free_space_change.connect (sidebar.on_free_space_change);

        // content = new BasicViewContainer ();
        // content.add_view (LIST, default_location);
        // content.window = this;

        // lside_pane = new Gtk.Paned (Gtk.Orientation.HORIZONTAL) {
        //     expand = true,
        //     position = Files.app_settings.get_int ("sidebar-width")
        // };
        // lside_pane.pack1 (sidebar, false, false);
        // lside_pane.pack2 (content, true, true);

        // extra_widget_box = new Gtk.Box (HORIZONTAL, 0);
        // var main_grid = new Gtk.Grid ();
        // main_grid.attach (headerbar, 0, 0, 1, 1);
        // main_grid.attach (lside_pane, 0, 1, 1, 1);
        // main_grid.attach (extra_widget_box, 0, 2, 1, 1);
        // main_grid.show_all ();

        // add (main_grid);

        /** Apply preferences */
        // var prefs = Files.Preferences.get_default (); // Bound to settings schema by Application
        // get_action ("show-hidden").set_state (prefs.show_hidden_files);
        // get_action ("show-local-thumbnails").set_state (prefs.show_local_thumbnails);
        // get_action ("show-remote-thumbnails").set_state (prefs.show_remote_thumbnails);
        // get_action ("singleclick-select").set_state (prefs.singleclick_select);
        // get_action ("folders-before-files").set_state (prefs.sort_directories_first);
        // get_action ("restore-tabs-on-startup").set_state (app_settings.get_boolean ("restore-tabs"));

        // /*/
        // /* Connect and abstract signals to local ones
        // /*/
        // view_switcher.action.activate.connect ((id) => {
        //     switch ((ViewMode)(id.get_uint32 ())) {
        //         case ViewMode.ICON:
        //             app_menu.on_zoom_setting_changed (Files.icon_view_settings, "zoom-level");
        //             break;
        //         case ViewMode.LIST:
        //             app_menu.on_zoom_setting_changed (Files.list_view_settings, "zoom-level");
        //             break;
        //         case ViewMode.MILLER_COLUMNS:
        //             app_menu.on_zoom_setting_changed (Files.column_view_settings, "zoom-level");
        //             break;
        //         case ViewMode.PREFERRED:
        //         case ViewMode.CURRENT:
        //         case ViewMode.INVALID:
        //             assert_not_reached (); //The switcher should not generate these modes
        //     }
        // });


        // button_forward.slow_press.connect (() => {
        //     get_action_group ("win").activate_action ("forward", new Variant.int32 (1));
        // });

        // button_back.slow_press.connect (() => {
        //     get_action_group ("win").activate_action ("back", new Variant.int32 (1));
        // });

        // location_bar.escape.connect (grab_focus);

        // location_bar.path_change_request.connect ((path, flag) => {
        //     content.is_frozen = false;
        //     // Put in an Idle so that any resulting authentication dialog
        //     // is able to grab focus *after* the view does
        //     Idle.add (() => {
        //         uri_path_change_request (path, flag);
        //         return Source.REMOVE;
        //     });
        // });

        // location_bar.path_change_request.connect ((path) => {
        //     content.focus_location_if_in_current_directory (GLib.File.new_for_path (path), true);
        // });

        // headerbar.focus_in_event.connect ((event) => {
        //     locked_focus = true;
        //     return focus_in_event (event);
        // });

        // headerbar.focus_out_event.connect ((event) => {
        //     locked_focus = false;
        //     return focus_out_event (event);
        // });

        // headerbar.uri_path_change_reuest.connect (content.on_path_change_request);
        // undo_manager.request_menu_update.connect (update_undo_actions);

        // key_controller = new Gtk.EventControllerKey (this) {
        //     propagation_phase = CAPTURE
        // };

        // key_controller.key_pressed.connect ((keyval, keycode, state) => {
        //     // Handle key press events when directoryview has focus except when it must retain
        //     // focus because e.g.renaming
        //     var focus_widget = get_focus ();
        //     if (content != null && !content.locked_focus &&
        //         focus_widget != null && focus_widget.is_ancestor (content)) {

        //         var mods = state & Gtk.accelerator_get_default_mod_mask ();
        //         /* Use find function instead of view interactive search */
        //         if (mods == 0 || mods == Gdk.ModifierType.SHIFT_MASK) {
        //             /* Use printable characters (except space) to initiate search */
        //             /* Space is handled by directory view to open file items */
        //             var uc = (unichar)(Gdk.keyval_to_unicode (keyval));
        //             if (uc.isprint () && !uc.isspace ()) {
        //                 activate_action ("find", uc.to_string ());
        //                 return Gdk.EVENT_STOP;
        //             }
        //         }
        //     }

        //     return Gdk.EVENT_PROPAGATE;
        // });

        // //TODO Rewrite for Gtk4
        // window_state_event.connect ((event) => {
        //     if (Gdk.WindowState.ICONIFIED in event.changed_mask) {
        //         location_bar.cancel (); /* Cancel any ongoing search query else interface may freeze on uniconifying */
        //     }

        //     return false;
        // });

        // delete_event.connect (() => {
        //     quit ();
        //     return false;
        // });

        // tab_view.setup_menu.connect (tab_view_setup_menu);

        // tab_view.close_page.connect (tab_view_close_page);

        // tab_view.notify["selected-page"].connect (change_tab);

        // tab_view.create_window.connect (() => {
        //     return new Window (marlin_app).tab_view;
        // });

        // tab_view.page_attached.connect ((tab, pos) => {
        //     var view_container = (BasicViewContainer) tab.child;
        //     view_container.window = this;
        // });


        // sidebar.request_focus.connect (() => {
        //     return !content.locked_focus && !locked_focus;
        // });

        // sidebar.sync_needed.connect (() => {
        //     loading_uri (content.uri);
        // });

        // sidebar.path_change_request.connect (content.on_path_change_request);
    }

    // public void add_extra_widget (Gtk.Widget widget) {
    //     extra_widget_box.add (widget);
    //     extra_widget_box.show_all ();
    // }

    // private bool tab_view_close_page (Hdy.TabPage page) {
    //     var view_container = (BasicViewContainer) page.child;

    //     if (tab_history_button.menu_model == null) {
    //         tab_history_button.menu_model = new Menu ();
    //     }

    //     var path = view_container.location.get_uri ();
    //     var path_in_menu = false;
    //     var menu = (Menu) tab_history_button.menu_model;
    //     for (var i = 0; i < menu.get_n_items (); i++) {
    //         if (path == menu.get_item_attribute_value (i, Menu.ATTRIBUTE_TARGET, VariantType.STRING).get_string ()) {
    //             path_in_menu = true;
    //             break;
    //         }
    //     }

    //     if (!path_in_menu) {
    //         menu.append (
    //             FileUtils.sanitize_path (path, null, false),
    //             "win.tabhistory-restore::%s".printf (path)
    //         );
    //     }

    //     view_container.close ();
    //     tab_view.close_page_finish (page, true);

    //     if (tab_view.n_pages == 0) {
    //         add_tab.begin (default_location, default_mode, false);
    //     }

    //     return Gdk.EVENT_STOP;
    // }

    // private void tab_view_setup_menu (Hdy.TabPage? page) {
        // if (page == null) {
        //     return;
        // }

        // var action_close = new SimpleAction ("tabmenu-close", null);
        // var action_close_end = new SimpleAction ("tabmenu-close-end", null);
        // var action_close_others = new SimpleAction ("tabmenu-close-others", null);
        // var action_duplicate = new SimpleAction ("tabmenu-duplicate", null);
        // var action_move_to_new_window = new SimpleAction ("tabmenu-move-to-window", null);

        // add_action (action_close);
        // add_action (action_close_end);
        // add_action (action_close_others);
        // add_action (action_duplicate);
        // add_action (action_move_to_new_window);

        // marlin_app.set_accels_for_action ("win.tabmenu-close", {"<Ctrl>W"});
        // marlin_app.set_accels_for_action ("win.tabmenu-duplicate", {"<Shift><Ctrl>K"});
        // marlin_app.set_accels_for_action ("win.tabmenu-move-to-window", {"<Ctrl><Alt>N"});

        // var tab_menu = (Menu) tab_view.menu_model;
        // tab_menu.remove_all ();

        // var open_tab_section = new Menu ();
        // open_tab_section.append (_("Open in New Window"), "win.tabmenu-move-to-window");
        // open_tab_section.append (_("Duplicate Tab"), "win.tabmenu-duplicate");

        // var close_tab_section = new Menu ();
        // /// TRANSLATORS: For RTL this should be "to the left"
        // close_tab_section.append (_("Close Tabs to the Right"), "win.tabmenu-close-end");
        // close_tab_section.append (_("Close Other Tabs"), "win.tabmenu-close-others");
        // close_tab_section.append (_("Close Tab"), "win.tabmenu-close");

        // tab_menu.append_section (null, open_tab_section);
        // tab_menu.append_section (null, close_tab_section);

        // action_close.activate.connect (() => {
        //     remove_tab (page);
        // });

        // var tab_position = tab_view.get_page_position (page) + 1;
        // if (tab_position == tab_view.n_pages) {
        //     action_close_end.set_enabled (false);
        // } else {
        //     action_close_end.activate.connect (() => {
        //         for (var i = tab_position; i < tab_view.n_pages; i++) {
        //             remove_tab (tab_view.get_nth_page (i));
        //         }
        //     });
        // }

        // if (tab_view.n_pages == 1) {
        //     action_close_others.set_enabled (false);
        // } else {
        //     action_close_others.activate.connect (() => {
        //         for (var i = 0; i < tab_view.n_pages; i++) {
        //             if (tab_view.get_nth_page (i) == page) {
        //                 continue;
        //             }

        //             remove_tab (tab_view.get_nth_page (i));
        //         }
        //     });
        // }

        // action_duplicate.activate.connect (() => {
        //     var view_container = (BasicViewContainer) page.child;
        //     add_tab.begin (view_container.location, view_container.view_mode, false);
        // });

        // action_move_to_new_window.activate.connect (() => {
        //     var view_container = (BasicViewContainer) page.child;
        //     move_content_to_new_window (view_container);
        // });
    // }

    // public void set_title (string title) {
    //     this.title = title;
    // }

    // private void change_tab () {
    //     //Ignore if some restored tabs still loading
    //     if (restoring_tabs > 0) {
    //         return;
    //     }

    //     loading_uri (content.uri);
    //     content.set_active_state (true, false); /* changing tab should not cause animated scrolling */
    //     sidebar.sync_uri (content.uri);
    //     save_active_tab_position ();
    // }

    // public async void open_tabs (
    //     owned GLib.File[]? files,
    //     ViewMode mode = default_mode,
    //     bool ignore_duplicate
    // ) {
    //     // Always try to restore tabs
    //     var n_tabs_restored = yield restore_tabs ();
    //     if (n_tabs_restored < 1 &&
    //         (files == null || files.length == 0 || files[0] == null)
    //     ) {
    //         // Open a tab pointing at the default location if no tabs restored and none provided
    //         // Duplicates are not ignored
    //         add_tab.begin (default_location, mode, false, () => {
    //             // We can assume adding default tab always succeeds
    //             // Ensure default tab's slot is active so it can be focused
    //             content.set_active_state (true, false);
    //         });

    //     } else {
    //         /* Open tabs at each requested location */
    //         /* As files may be derived from commandline, we use a new sanitized one */
    //         foreach (var file in files) {
    //             add_tab.begin (get_file_from_uri (file.get_uri ()), mode, ignore_duplicate);
    //         }
    //     }
    // }

    // private async bool add_tab_by_uri (string uri, ViewMode mode = default_mode) {
    //     var file = get_file_from_uri (uri);
    //     if (file != null) {
    //         return yield add_tab (file, mode, false);
    //     } else {
    //         return yield add_tab (default_location, mode, false);
    //     }
    // }

    // public bool set_initial_location (GLib.File initial_location) {
    //     assert (content != null && content.dir_view == null);
    //     if (set_location (initial_location, default_mode)) {
    //         connect_content_signals (content);
    //     }
    // }

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

            // if (!location.equal (_location)) {
            //     content.add_view (mode, location, {_location});
            // } else {
            //     content.add_view (mode, location);
            // }
            path_change (location);
            return true;
    }

    public void path_change (GLib.File loc) {
        slot.user_path_change_request (loc, true);
    }

    public void set_selected_location (GLib.File loc) {
        List<GLib.File> list = null;
        list.append (loc);
        slot.select_glib_files (list, loc);
    }

    // public  async bool add_tab (
    //     GLib.File _location = default_location,
    //     ViewMode mode = default_mode,
    //     bool ignore_duplicate
    // ) {

    // warning ("WINDOW: Add tab");
        // Do not try to restore locations that we cannot determine the filetype. This will
        // include deleted and other non-existent locations.  Note however, that disconnected remote
        // location may still give correct result, presumably due to caching by gvfs, so such
        // locations will still attempt to load.  Files.Directory must handle that.

        // GLib.File location;
        // GLib.FileType ftype;
        // // For simplicity we do not use cancellable. If issues arise may need to do this.
        // try {
        //     var info = yield _location.query_info_async (
        //         FileAttribute.STANDARD_TYPE,
        //         FileQueryInfoFlags.NONE
        //     );

        //     ftype = info.get_file_type ();
        // } catch (Error e) {
        //     debug ("No info for requested location - abandon loading");
        //     return false;
        // }


        // if (ftype == FileType.REGULAR) {
        //     location = _location.get_parent ();
        // } else {
        //     location = _location.dup ();
        // }

        // if (ignore_duplicate) {
        //     bool is_child;
        //     var existing_tab_position = location_is_duplicate (
        //         location,
        //         ftype == FileType.DIRECTORY,
        //         out is_child
        //     );

        //     if (existing_tab_position >= 0) {
        //         tab_view.selected_page = tab_view.get_nth_page (existing_tab_position);
        //         if (is_child) {
        //             /* Select the child  */
        //             content.focus_location_if_in_current_directory (_location);
        //         }

        //         return false;
        //     }
        // }

        // mode = real_mode (mode);
        // var content = new View.BasicViewContainer ();

        // if (!location.equal (_location)) {
        //     content.add_view (mode, location, {_location});
        // } else {
        //     content.add_view (mode, location);
        // }

        // var page = tab_view.append (content);
        // tab_view.selected_page = page;

    //     return true;
    // }

    // Called by content when associated with tab view.
    // public void connect_content_signals (BasicViewContainer content) {
    public void connect_content_signals (BasicSlot slot) {
        // content.tab_name_changed.connect (check_for_tabs_with_same_name);
        // if (content == null) {
        //     critical ("WINDOW: connect to null content");
        // }
        // content.loading.connect (update_labels);
        warning ("connected loading");
        // slot.directory_loaded.connect (on_content_loading);
        slot.directory_loaded.connect (on_directory_loaded);
        // content.loading.connect (on_content_loading);

        // content.active.connect (update_headerbar);
    }

    // public void disconnect_content_signals (BasicViewContainer content) {
        // content.tab_name_changed.disconnect (check_for_tabs_with_same_name);
        // content.loading.disconnect (on_content_loading);
        // content.active.disconnect (update_headerbar);
    // }

    // private void on_content_loading (BasicViewContainer content, string uri, bool is_loading) {
        // if (restoring_tabs > 0 && !is_loading) {
        //     restoring_tabs--;
        //     /* Each restored tab must signal with is_loading false once */
        //     assert (restoring_tabs >= 0);
        //     if (!content.can_show_folder) {
        //         warning ("Cannot restore %s, ignoring", content.uri);
        //         /* remove_tab function uses Idle loop to close tab */
        //         remove_content (content);
        //     }
        // }

        // tab_view.get_page (content).loading = is_loading;

        // check_for_tabs_with_same_name ();
        // warning  ("on content loading %s", is_loading.to_string ());
        // if (!is_loading) {
        //     // update_headerbar ();
        //     headerbar.set_back_menu (content.get_go_back_path_list (), content.can_go_back);
        //     headerbar.set_forward_menu (content.get_go_forward_path_list (), content.can_go_forward);
        //     headerbar.update_location_bar (uri, true);
        // }

        // if (restoring_tabs == 0 && !is_loading) {
        //     save_tabs ();
        // }
    // }

    private void on_directory_loaded () {
        headerbar.set_back_menu (browser.go_back_list (), browser.can_go_back);
        headerbar.set_forward_menu (browser.go_forward_list (), browser.can_go_forward);
        headerbar.update_location_bar (uri, true);

        //TODO Handle dir cannot load
    }
    // private int location_is_duplicate (GLib.File location, bool is_folder, out bool is_child) {
    //     is_child = false;
    //     string parent_path = "";
    //     string uri = location.get_uri ();
    //     /* Ensures consistent format of protocol and path */
    //     parent_path = FileUtils.get_parent_path_from_path (location.get_path ());
    //     int existing_position = 0;

    //     for (int i = 0; i < tab_view.n_pages; i++) {
    //         var tab = (Hdy.TabPage) tab_view.get_nth_page (i);
    //         var tab_location = ((BasicViewContainer) tab.child).location;
    //         string tab_uri = tab_location.get_uri ();

    //         if (FileUtils.same_location (uri, tab_uri)) {
    //             is_child = !is_folder;
    //             return existing_position;
    //         }

    //         existing_position++;
    //     }

    //     return -1;
    // }

    // /** Compare every tab label with every other and resolve ambiguities **/
    // private void check_for_tabs_with_same_name () {
    //     for (int i = 0; i < tab_view.n_pages; i++) {
    //         var tab = (Hdy.TabPage) tab_view.get_nth_page (i);
    //         unowned var content = (BasicViewContainer) tab.child;
    //         if (content.tab_name == Files.INVALID_TAB_NAME) {
    //             set_tab_label (content.tab_name, tab, content.tab_name);
    //             continue;
    //         }

    //         var path = content.location.get_path ();
    //         if (path == null) { // e.g. for uris like network://
    //             set_tab_label (content.tab_name, tab, content.tab_name);
    //             continue;
    //         }
    //         var basename = Path.get_basename (path);

    //         // Ignore content not named from the path
    //         if (!content.tab_name.has_suffix (basename)) {
    //             set_tab_label (content.tab_name, tab, content.tab_name);
    //             continue;
    //         }

    //         // Tab label defaults to the basename.
    //         set_tab_label (basename, tab, content.tab_name);

    //         // Compare with every other tab for same label
    //         for (int j = 0; j < tab_view.n_pages; j++) {
    //             var tab2 = (Hdy.TabPage) tab_view.get_nth_page (j);
    //             unowned var content2 = (BasicViewContainer) tab2.child;
    //             if (content2 == content || content2.tab_name == Files.INVALID_TAB_NAME) {
    //                 continue;
    //             }

    //             var path2 = content2.location.get_path ();
    //             if (path2 == null) { // e.g. for uris like network://
    //                 continue;
    //             }
    //             var basename2 = Path.get_basename (path2);

    //             // Ignore content not named from the path
    //             if (!content2.tab_name.has_suffix (basename2)) {
    //                 continue;
    //             }

    //             if (basename2 == basename && path2 != path) {
    //                 set_tab_label (FileUtils.disambiguate_uri (path2, path), tab2, content2.tab_name);
    //                 set_tab_label (FileUtils.disambiguate_uri (path, path2), tab, content.tab_name);
    //             }
    //         }
    //     }

    //     return;
    // }

    // /* Just to append "as Administrator" when appropriate */
    // private void set_tab_label (string label, Hdy.TabPage tab, string? tooltip = null) {

    //     string lab = label;
    //     // if (Files.is_admin ()) {
    //     //     lab += (" " + _("(as Administrator)"));
    //     // }

    //     tab.title = lab;

    //     /* Needs change to Granite to allow (visible) tooltip amendment.
    //      * This compiles because tab is a widget but the tootip is overridden by that set internally */
    //     if (tooltip != null) {
    //         var tt = tooltip;
    //         // if (Files.is_admin ()) {
    //         //     tt += (" " + _("(as Administrator)"));
    //         // }

    //         tab.tooltip = tt;
    //     }
    // }

    public void bookmark_uri (string uri, string custom_name = "") {
        sidebar.add_favorite_uri (uri, custom_name);
    }

    public bool can_bookmark_uri (string uri) {
        return !sidebar.has_favorite_uri (uri);
    }

    // private void move_content_to_new_window (BasicViewContainer view_container) {
    //     add_window (view_container.location, view_container.view_mode);
    //     remove_content (view_container);
    // }

    // public void remove_content (BasicViewContainer view_container) {
        // for (int n = 0; n < tab_view.n_pages; n++) {
        //     var tab = tab_view.get_nth_page (n);
        //     if (tab.get_child () == view_container) {
        //         remove_tab (tab);
        //         return;
        //     }
        // }

        //TODO Cancel the FileChooser (close window)
        // assert_not_reached ();
    // }

    // private void remove_tab (Hdy.TabPage? tab) {
    //     if (tab != null) {
    //         /* Use Idle in case of rapid closing of multiple tabs during restore */
    //         Idle.add_full (Priority.LOW, () => {
    //             tab_view.close_page (tab);
    //             return GLib.Source.REMOVE;
    //         });
    //     }
    // }

    // private void add_window (GLib.File location = default_location, ViewMode mode = default_mode) {
    //     var new_window = new Window (marlin_app);
    //     new_window.add_tab.begin (location, real_mode (mode), false);
    //     new_window.present ();
    // }

    // private void undo_actions_set_insensitive () {
    //     GLib.SimpleAction action;
    //     action = get_action ("undo");
    //     action.set_enabled (false);
    //     action = get_action ("redo");
    //     action.set_enabled (false);
    // }

    // private void update_undo_actions () {
    //     GLib.SimpleAction action;
    //     action = get_action ("undo");
    //     action.set_enabled (undo_manager.can_undo ());
    //     action = get_action ("redo");
    //     action.set_enabled (undo_manager.can_redo ());
    // }

    // private void action_edit_path () {
    //     location_bar.enter_navigate_mode ();
    // }

    // private void action_bookmark (GLib.SimpleAction action, GLib.Variant? param) {
    //     /* Note: Duplicate bookmarks will not be created by BookmarkList */
    //     unowned var selected_files = content.view.get_selected_files ();
    //     if (selected_files == null) {
    //         sidebar.add_favorite_uri (content.location.get_uri ());
    //     } else if (selected_files.first ().next == null) {
    //         sidebar.add_favorite_uri (selected_files.first ().data.uri);
    //     } // Ignore if more than one item selected
    // }

    // private void action_find (GLib.SimpleAction action, GLib.Variant? param) {
    //     /* Do not initiate search while slot is frozen e.g. during loading */
    //     if (content == null || content.is_frozen) {
    //         return;
    //     }

    //     if (param == null) {
    //         location_bar.enter_search_mode ("");
    //     } else {
    //         location_bar.enter_search_mode (param.get_string ());
    //     }
    // }

    // private bool adding_window = false;
    // private void action_new_window (GLib.SimpleAction action, GLib.Variant? param) {
    //     /* Limit rate of adding new windows using the keyboard */
    //     if (adding_window) {
    //         return;
    //     } else {
    //         adding_window = true;
    //         add_window ();
    //         GLib.Timeout.add (500, () => {
    //             adding_window = false;
    //             return GLib.Source.REMOVE;
    //         });
    //     }
    // }

    // private void action_reload () {
    //     /* avoid spawning reload when key kept pressed */
    //     if (tab_view.selected_page.loading) {
    //         warning ("Too rapid reloading suppressed");
    //         return;
    //     }

    //     var slot = content.prepare_reload ();
    //     if (slot != null) {
    //         slot.reload (); // Initial reload request - will propagate to all alots showing same location
    //     }

    //     sidebar.reload ();
    // }

    // private void action_tabhistory_restore (SimpleAction action, GLib.Variant? parameter) {
    //     add_tab_by_uri.begin (parameter.get_string ());

    //     var menu = (Menu) tab_history_button.menu_model;
    //     for (var i = 0; i < menu.get_n_items (); i++) {
    //         if (parameter == menu.get_item_attribute_value (i, Menu.ATTRIBUTE_TARGET, VariantType.STRING)) {
    //             menu.remove (i);
    //             break;
    //         }
    //     }

    //     if (menu.get_n_items () == 0) {
    //         tab_history_button.menu_model = null;
    //     }
    // }

    private void action_view_mode (GLib.SimpleAction action, GLib.Variant? param) {
        // if (tab_view == null || content == null) { // can occur during startup
        // if (content == null) { // can occur during startup
        //     return;
        // }

        // ViewMode mode = real_mode ((ViewMode)(param.get_uint32 ()));
        // ViewMode mode = (ViewMode)(param.get_uint32 ());
        // content.change_view_mode (mode);
        /* BasicViewContainer takes care of changing appearance */
    }

    // private void action_back (SimpleAction action, Variant? param) {
    //     content.go_back (param.get_int32 ());
    // }

    // private void action_forward (SimpleAction action, Variant? param) {
    //     content.go_forward (param.get_int32 ());
    // }

    // private void action_go_to (GLib.SimpleAction action, GLib.Variant? param) {
    //     switch (param.get_string ()) {
    //         case "RECENT":
    //             uri_path_change_request (Files.RECENT_URI);
    //             break;

    //         case "HOME":
    //             uri_path_change_request ("file://" + PF.UserUtils.get_real_user_home ());
    //             break;

    //         case "TRASH":
    //             uri_path_change_request (Files.TRASH_URI);
    //             break;

    //         case "ROOT":
    //             uri_path_change_request (Files.ROOT_FS_URI);
    //             break;

    //         case "NETWORK":
    //             uri_path_change_request (Files.NETWORK_URI);
    //             break;

    //         case "SERVER":
    //             connect_to_server ();
    //             break;

    //         case "UP":
    //             content.go_up ();
    //             break;

    //         default:
    //             break;
    //     }
    // }

    // private void action_zoom (GLib.SimpleAction action, GLib.Variant? param) {
    //     if (content != null) {
    //         assert (content.view != null);
    //         switch (param.get_string ()) {
    //             case "ZOOM_IN":
    //                 content.view.zoom_in ();
    //                 break;

    //             case "ZOOM_OUT":
    //                 content.view.zoom_out ();
    //                 break;

    //             case "ZOOM_NORMAL":
    //                 content.view.zoom_normal ();
    //                 break;

    //             default:
    //                 break;
    //         }
    //     }
    // }

    // private void action_tab (GLib.SimpleAction action, GLib.Variant? param) {
    //     switch (param.get_string ()) {
    //         case "NEW":
    //             add_tab.begin (default_location, default_mode, false);
    //             break;

    //         case "CLOSE":
    //             remove_tab (tab_view.selected_page);
    //             break;

    //         case "NEXT":
    //             tab_view.select_next_page ();
    //             break;

    //         case "PREVIOUS":
    //             tab_view.select_previous_page ();
    //             break;

    //         case "TAB":
    //             add_tab.begin (content.location, content.view_mode, false);
    //             break;

    //         case "WINDOW":
    //             //Move current tab to a new window
    //             move_content_to_new_window (content);
    //             break;

    //         default:
    //             break;
    //     }
    // }



    // private void action_undo (GLib.SimpleAction action, GLib.Variant? param) {
    //     if (doing_undo_redo) { /* Guard against rapid pressing of Ctrl-Z */
    //         return;
    //     }
    //     before_undo_redo ();
    //     undo_manager.undo.begin (this, null, (obj, res) => {
    //         try {
    //             undo_manager.undo.end (res);
    //             after_undo_redo ();
    //         } catch (Error e) {
    //             critical (e.message);
    //         }
    //     });
    // }

    // private void action_redo (GLib.SimpleAction action, GLib.Variant? param) {
    //     if (doing_undo_redo) { /* Guard against rapid pressing of Ctrl-Shift-Z */
    //         return;
    //     }
    //     before_undo_redo ();
    //     undo_manager.redo.begin (this, null, (obj, res) => {
    //         try {
    //             undo_manager.redo.end (res);
    //             after_undo_redo ();
    //         } catch (Error e) {
    //             critical (e.message);
    //         }
    //     });
    // }

    private void action_focus_sidebar () {
        sidebar.focus ();
    }

    // private void before_undo_redo () {
    //     doing_undo_redo = true;
    //     update_undo_actions ();
    // }

    // public void after_undo_redo () {
    //     if (content.slot.directory.is_recent) {
    //         get_action_group ("win").activate_action ("refresh", null);
    //     }

    //     doing_undo_redo = false;
    // }

    public void change_state_show_hidden (GLib.SimpleAction action) {
        bool state = !action.state.get_boolean ();
        action.set_state (new GLib.Variant.boolean (state));
        // Files.app_settings.set_boolean ("show-hiddenfiles", state);
    }

    public void change_state_single_click_select (GLib.SimpleAction action) {
        bool state = !action.state.get_boolean ();
        action.set_state (new GLib.Variant.boolean (state));
        Files.Preferences.get_default ().singleclick_select = state;
    }

    public void change_state_show_remote_thumbnails (GLib.SimpleAction action) {
        bool state = !action.state.get_boolean ();
        action.set_state (new GLib.Variant.boolean (state));
        // Files.app_settings.set_boolean ("show-remote-thumbnails", state);
    }

    public void change_state_show_local_thumbnails (GLib.SimpleAction action) {
        bool state = !action.state.get_boolean ();
        action.set_state (new GLib.Variant.boolean (state));
        // Files.app_settings.set_boolean ("show-local-thumbnails", state);
    }

    public void change_state_folders_before_files (GLib.SimpleAction action) {
        bool state = !action.state.get_boolean ();
        action.set_state (new GLib.Variant.boolean (state));
        // Files.Preferences.get_default ().sort_directories_first = state;
    }

    // public void change_state_restore_tabs_on_startup (GLib.SimpleAction action) {
    //     bool state = !action.state.get_boolean ();
    //     action.set_state (new GLib.Variant.boolean (state));
    //     Files.app_settings.set_boolean ("restore-tabs", state);
    // }

    // private void connect_to_server () {
    //     var dialog = new PF.ConnectServerDialog ((Gtk.Window) this);
    //     string server_uri = "";

    //     dialog.response.connect ((res) => {
    //         if (res == Gtk.ResponseType.OK) {
    //             server_uri = dialog.server_uri;
    //             if (server_uri != "") {
    //                 uri_path_change_request (dialog.server_uri, Files.OpenFlag.DEFAULT);
    //             }
    //         }

    //         dialog.destroy ();
    //     });

    //     dialog.present ();
    // }


    // public GLib.SimpleAction? get_action (string action_name) {
    //     return (GLib.SimpleAction?)(lookup_action (action_name));
    // }

    // private ViewMode real_mode (ViewMode mode) {
    //     switch (mode) {
    //         case ViewMode.ICON:
    //         case ViewMode.LIST:
    //         case ViewMode.MILLER_COLUMNS:
    //             return mode;

    //         case ViewMode.CURRENT:
    //             return content.view_mode;

    //         default:
    //             break;
    //     }

    //     return (ViewMode)(Files.app_settings.get_enum ("default-viewmode"));
    // }

    public virtual void quit () {
        // save_geometries ();
        // save_tabs ();

        headerbar.destroy (); /* stop unwanted signals if quit while pathbar in focus */
        slot.close ();
        // content.close ();
        // Prevent saved focused tab changing
        // tab_view.notify["selected-page"].disconnect (change_tab);

        // for (int i = 0; i < tab_view.n_pages; i++) {
        //     var tab_page = (Hdy.TabPage) tab_view.get_nth_page (i);
        //     ((BasicViewContainer) tab_page.child).close ();
        // }

        this.destroy ();
    }

    // private void save_geometries () {
    //     if (!is_first_window) {
    //         return; //TODO Save all windows
    //     }
    //     var sidebar_width = lside_pane.get_position ();
    //     var min_width = Files.app_settings.get_int ("minimum-sidebar-width");

    //     sidebar_width = int.max (sidebar_width, min_width);
    //     Files.app_settings.set_int ("sidebar-width", sidebar_width);

    //     var state = get_window ().get_state ();
    //     // TODO: replace with Gtk.Window.fullscreened in Gtk4
    //     if (is_maximized || Gdk.WindowState.FULLSCREEN in state) {
    //         Files.app_settings.set_enum (
    //             "window-state", Files.WindowState.MAXIMIZED
    //         );
    //     } else {
    //         Files.app_settings.set_enum (
    //             "window-state", Files.WindowState.NORMAL
    //         );

    //         if (!(Gdk.WindowState.TILED in state)) {
    //             int width, height;
    //             // Includes shadow for normal windows (but not maximized or tiled)
    //             get_size (out width, out height);
    //             Files.app_settings.set ("window-size", "(ii)", width, height);
    //         }
    //     }
    // }

    // private void save_tabs () {
        // /* Do not overwrite existing settings if history or restore-tabs is off
        //  * or is admin window */
        // if (
        //     !Files.Preferences.get_default ().remember_history ||
        //     !Files.app_settings.get_boolean ("restore-tabs") ||
        //     Files.is_admin ()
        // ) {
        //     return;
        // }

        // VariantBuilder vb = new VariantBuilder (new VariantType ("a(uss)"));
        // for (int i = 0; i < tab_view.n_pages; i++) {
        //     var tab = (Hdy.TabPage) tab_view.get_nth_page (i);
        //     var view_container = (BasicViewContainer) tab.child;

        //     /* Do not save if "File does not exist" or "Does not belong to you" */
        //     if (!view_container.can_show_folder) {
        //         continue;
        //     }
        //     /* BasicViewContainer is responsible for returning valid uris */
        //     vb.add ("(uss)",
        //             view_container.view_mode,
        //             view_container.get_root_uri () ?? PF.UserUtils.get_real_user_home (),
        //             view_container.get_tip_uri () ?? ""
        //            );
        // }

        // Files.app_settings.set_value ("tab-info-list", vb.end ());
        // save_active_tab_position ();
    // }

    // private void save_active_tab_position () {
    //     if (tab_view.selected_page == null) {
    //         return;
    //     }

    //     Files.app_settings.set_int (
    //         "active-tab-position",
    //         tab_view.get_page_position (tab_view.selected_page)
    //     );
    // }

    // private async uint restore_tabs () {
    //     /* Do not restore tabs more than once or if various conditions not met */
    //     if (
    //         tabs_restored ||
    //         !is_first_window ||
    //         !Files.Preferences.get_default ().remember_history ||
    //         !Files.app_settings.get_boolean ("restore-tabs") ||
    //         Files.is_admin ()
    //     ) {
    //         return 0;
    //     } else {
    //         tabs_restored = true;
    //     }

    //     GLib.Variant tab_info_array = Files.app_settings.get_value ("tab-info-list");
    //     GLib.VariantIter iter = new GLib.VariantIter (tab_info_array);

    //     ViewMode mode = ViewMode.INVALID;
    //     string? root_uri = null;
    //     string? tip_uri = null;

    //     /* Changes of view and rendering of location bar are avoided while restoring tabs > 0
    //      * as this causes all sorts of problems */
    //     restoring_tabs = 0;

    //     while (iter.next ("(uss)", out mode, out root_uri, out tip_uri)) {
    //         if (mode < 0 || mode >= ViewMode.INVALID ||
    //             root_uri == null || root_uri == "" || tip_uri == null) {

    //             continue;
    //         }

    //         if (yield add_tab_by_uri (root_uri, mode)) {
    //             restoring_tabs++;
    //             var tab = tab_view.selected_page;
    //             if (tab != null &&
    //                 tab.child != null &&
    //                 tip_uri != root_uri) {

    //                 var view = ((BasicViewContainer)(tab.child)).view;
    //                 // if (view != null && view is Miller) {
    //                 //     expand_miller_view ((Miller)view, tip_uri, root_uri);
    //                 // }
    //             }
    //         } else {
    //             debug ("Failed to restore tab %s", root_uri);
    //         }

    //         mode = ViewMode.INVALID;
    //         root_uri = null;
    //         tip_uri = null;

    //         /* As loading is now asynchronous we do not need a delay here any longer */
    //     }

    //     /* We assume that the following code is reached before restoring tabs have finished loading. Tests
    //      * show this to be the case. */

    //     /* Don't attempt to set active tab position if no tabs were restored.*/
    //     if (restoring_tabs < 1) {
    //         return 0;
    //     }

    //     int active_tab_position = Files.app_settings.get_int ("active-tab-position");
    //     if (active_tab_position < 0 || active_tab_position >= restoring_tabs) {
    //         active_tab_position = 0;
    //     }

    //     string path = "";
    //     if (content != null) {
    //         path = content.get_tip_uri ();

    //         if (path == null || path == "") {
    //             path = content.get_root_uri ();
    //         }
    //     }

    //     /* Render the final path in the location bar without animation */
    //     update_location_bar (path, false);
    //     return restoring_tabs;
    // }

    // private void expand_miller_view (Miller miller_view, string tip_uri, string unescaped_root_uri) {
    //     /* It might be more elegant for Miller.vala to handle this */
    //     var unescaped_tip_uri = FileUtils.sanitize_path (tip_uri, null, true);

    //     if (unescaped_tip_uri == null) {
    //         warning ("Invalid tip uri for Miller View");
    //         return;
    //     }

    //     var tip_location = FileUtils.get_file_for_path (unescaped_tip_uri);
    //     var root_location = FileUtils.get_file_for_path (unescaped_root_uri);

    //     // If the root location no longer exists do not show the tab at all
    //     if (!root_location.query_exists ()) {
    //         warning ("Invalid root uri for Miller View");
    //         return;
    //     }

    //     // If the tip location no longer exists search up the tree for existing folder
    //     while (!tip_location.equal (root_location) && !tip_location.query_exists ()) {
    //         tip_location = tip_location.get_parent ();
    //         warning ("Invalid tip uri for Miller View - trying parent");
    //         if (tip_location == null) {
    //             tip_location = root_location.dup ();
    //         }
    //     }

    //     var relative_path = root_location.get_relative_path (tip_location);
    //     GLib.File gfile;

    //     if (relative_path != null) {
    //         string [] dirs = relative_path.split (GLib.Path.DIR_SEPARATOR_S);
    //         string uri = root_location.get_uri ();

    //         foreach (string dir in dirs) {
    //             uri += (GLib.Path.DIR_SEPARATOR_S + dir);
    //             gfile = get_file_from_uri (uri);

    //             miller_view.add_location (gfile, miller_view.current_slot); // MillerView can deal with multiple scroll requests
    //         }
    //     } else {
    //         warning ("Invalid tip uri for Miller View %s", unescaped_tip_uri);
    //     }
    // }

    private void update_headerbar () {
        // if (restoring_tabs > 0 || content == null) {
        // if (content == null) {
            // return;
        // }

        /* Update browser buttons */
        // headerbar.set_back_menu (content.get_go_back_path_list (), content.can_go_back);
        // headerbar.set_forward_menu (content.get_go_forward_path_list (), content.can_go_forward);
        // headerbar.button_back.sensitive = content.can_go_back;
        // headerbar.button_forward.sensitive = (content.can_show_folder && content.can_go_forward);

        /* Update viewmode switch, action state and settings */
        // var mode = content.view_mode;
        // view_switcher.set_mode (mode);
        // view_switcher.sensitive = content.can_show_folder;
        // get_action ("view-mode").change_state (new Variant.uint32 (mode));
        // Files.app_settings.set_enum ("default-viewmode", mode);
    }

    // private void set_back_menu (Gee.List<string> path_list) {
    //     /* Clear the back menu and re-add the correct entries. */
    //     var back_menu = new Menu ();
    //     for (int i = 0; i < path_list.size; i++) {
    //         var path = path_list.@get (i);
    //         var item = new MenuItem (
    //             FileUtils.sanitize_path (path, null, false),
    //             Action.print_detailed_name ("win.back", new Variant.int32 (i + 1))
    //         );
    //         back_menu.append_item (item);
    //     }

    //     button_back.menu = back_menu;
    // }

    // private void set_forward_menu (Gee.List<string> path_list) {
    //     /* Same for the forward menu */
    //     var forward_menu = new Menu ();
    //     for (int i = 0; i < path_list.size; i++) {
    //         var path = path_list.@get (i);
    //         var item = new MenuItem (
    //             FileUtils.sanitize_path (path, null, false),
    //             Action.print_detailed_name ("win.forward", new Variant.int32 (i + 1))
    //         );
    //         forward_menu.append_item (item);
    //     }

    //     button_forward.menu = forward_menu;
    // }

    // private void update_location_bar (string new_path, bool with_animation = true) {
    //     location_bar.with_animation = with_animation;
    //     location_bar.set_display_path (new_path);
    //     location_bar.with_animation = true;
    // }

    private void update_labels (string uri) {
    // private void update_labels (string uri, bool is_loading) {
    // private void update_labels (string uri) {
        // if (content != null) { /* Can happen during restore */
        // if (is_loading) {
            // this.title = content.tab_name; /* Not actually visible on elementaryos */
            headerbar.update_location_bar (uri);
            sidebar.sync_uri (uri);
        // }
        // }
    }

    // public void mount_removed (Mount mount) {
    //     debug ("Mount %s removed", mount.get_name ());
    //     GLib.File root = mount.get_root ();

    //     for (int i = 0; i < tab_view.n_pages; i++) {
    //         var view_container = (View.BasicViewContainer) (tab_view.get_nth_page (i).child);
    //         GLib.File location = view_container.location;

    //         if (location == null || location.has_prefix (root) || location.equal (root)) {
    //             if (view_container == content) {
    //                 view_container.focus_location (GLib.File.new_for_path (PF.UserUtils.get_real_user_home ()));
    //             } else {
    //                 remove_content (view_container);
    //             }
    //         }
    //     }
    // }

    // public void on_uri_path_change_request (string p, Files.OpenFlag flag = Files.OpenFlag.DEFAULT) {
    // public void on_path_change_request (string p, Files.OpenFlag flag = Files.OpenFlag.DEFAULT) {
    //     /* Make a sanitized file from the uri */
    //     var file = get_file_from_uri (p);
    //     if (file != null) {
    //         // switch (flag) {
    //             // case Files.OpenFlag.NEW_TAB:
    //                 // add_tab.begin (file, content.view_mode, false);
    //                 // break;
    //             // case Files.OpenFlag.NEW_WINDOW:
    //                 // add_window (file, content.view_mode);
    //                 // break;
    //             // default:
    //                 // grab_focus ();
    //                 content.focus_location (file);
    //                 // break;
    //         // }
    //     } else {
    //         warning ("Cannot browse %s", p);
    //     }
    // }

    /** Use this function to standardise how locations are generated from uris **/
    private GLib.File? get_file_from_uri (string _uri) {
        // string? current_uri = null;
        // if (content != null && content.location != null) {
            // current_uri = content.location.get_uri ();
        // }

        string path = FileUtils.sanitize_path (_uri, this.uri, true);
        if (path.length > 0) {
            return GLib.File.new_for_uri (FileUtils.escape_uri (_uri));
        } else {
            return null;
        }
    }

    public new void grab_focus () {
        // if (content == null) {
        //     return;
        // }

        // content.grab_focus ();
        slot.grab_focus ();
    }
}
