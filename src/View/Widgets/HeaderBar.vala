/*
* Copyright 2020 elementary, Inc. (https://elementary.io)
*           2010 mathijshenquet <mathijs.henquet@gmail.com>
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
* Authored by: mathijshenquet <mathijs.henquet@gmail.com>
*              ammonkey <am.monkeyd@gmail.com>
*/

public class Files.View.Chrome.HeaderBar : Hdy.HeaderBar {
    public signal void forward (int steps);
    public signal void back (int steps); /* TODO combine using negative step */
    public signal void focus_location_request (GLib.File? location);
    public signal void path_change_request (string path, Files.OpenFlag flag);
    public signal void escape ();
    public signal void reload_request ();

    public ViewSwitcher? view_switcher { get; construct; }
    public bool locked_focus { get; private set; default = false; }

    public bool working {
        set {
            location_bar.sensitive = !value;
        }
    }

    public bool can_go_back {
       set {
            button_back.sensitive = value;
        }
    }

    public bool can_go_forward {
       set {
            button_forward.sensitive = value;
        }
    }

    private LocationBar? location_bar;
    private Chrome.ButtonWithMenu button_forward;
    private Chrome.ButtonWithMenu button_back;
    private Gtk.Button zoom_default_button;
    private Gtk.Button zoom_in_button;
    private Gtk.Button zoom_out_button;
    private Gtk.Button undo_button;
    private Gtk.Button redo_button;
    private string[] undo_accels;
    private string[] redo_accels;
    private unowned UndoManager undo_manager;

    public HeaderBar (ViewSwitcher switcher) {
        Object (view_switcher: switcher);
    }

    construct {
        var app_instance = (Gtk.Application)(GLib.Application.get_default ());
        button_back = new View.Chrome.ButtonWithMenu.from_icon_name (
            "go-previous-symbolic", Gtk.IconSize.LARGE_TOOLBAR
        );

        button_back.tooltip_markup = Granite.markup_accel_tooltip ({"<Alt>Left"}, _("Previous"));
        button_back.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        button_forward = new View.Chrome.ButtonWithMenu.from_icon_name (
            "go-next-symbolic", Gtk.IconSize.LARGE_TOOLBAR
        );

        button_forward.tooltip_markup = Granite.markup_accel_tooltip ({"<Alt>Right"}, _("Next"));
        button_forward.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        view_switcher.margin_end = 20;

        location_bar = new LocationBar ();

        /**  AppMenu **/
        // Zoom controls
        zoom_out_button = new Gtk.Button.from_icon_name ("zoom-out-symbolic", Gtk.IconSize.MENU) {
            action_name = "win.zoom",
            action_target = "ZOOM_OUT"
        };
        zoom_out_button.tooltip_markup = Granite.markup_accel_tooltip (
            app_instance.get_accels_for_action ("win.zoom::ZOOM_OUT"),
            _("Zoom Out")
        );

        zoom_default_button = new Gtk.Button.with_label ("100%") {
            action_name = "win.zoom",
            action_target = "ZOOM_NORMAL"
        };
        zoom_default_button.tooltip_markup = Granite.markup_accel_tooltip (
            app_instance.get_accels_for_action ("win.zoom::ZOOM_NORMAL"),
            _("Zoom 1:1")
        );

        zoom_in_button = new Gtk.Button.from_icon_name ("zoom-in-symbolic", Gtk.IconSize.MENU) {
            action_name = "win.zoom",
            action_target = "ZOOM_IN"
        };
        zoom_in_button.tooltip_markup = Granite.markup_accel_tooltip (
            app_instance.get_accels_for_action ("win.zoom::ZOOM_IN"),
            _("Zoom In")
        );

        var icon_size_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            homogeneous = true,
            hexpand = true,
            margin_top = 12,
            margin_end = 12,
            margin_bottom = 6,
            margin_start = 12
        };
        icon_size_box.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        icon_size_box.add (zoom_out_button);
        icon_size_box.add (zoom_default_button);
        icon_size_box.add (zoom_in_button);

        var undo_redo_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            homogeneous = true,
            margin_end = 12,
            margin_bottom = 12,
            margin_start = 12
        };
        undo_redo_box.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);

        undo_button = new Gtk.Button.from_icon_name ("edit-undo-symbolic", Gtk.IconSize.MENU) {
            action_name = "win.undo"
        };

        redo_button = new Gtk.Button.from_icon_name ("edit-redo-symbolic", Gtk.IconSize.MENU) {
            action_name = "win.redo"
        };

        undo_redo_box.add (undo_button);
        undo_redo_box.add (redo_button);

        undo_accels = app_instance.get_accels_for_action ("win.undo");
        redo_accels = app_instance.get_accels_for_action ("win.redo");

        // Double-click option
        var double_click_button = new Granite.SwitchModelButton (_("Double-click to Navigate")) {
            description = _("Double-click on a folder opens it, single-click selects it"),
            action_name = "win.singleclick-select"
        };

        //Sort folders before files
        var foldes_before_files = new Granite.SwitchModelButton (_("Sort Folders before Files")) {
            action_name = "win.folders-before-files"
        };

        var show_header = new Granite.HeaderLabel (_("Show in View"));

        var show_hidden_button = new Gtk.CheckButton () {
            action_name = "win.show-hidden"
        };
        show_hidden_button.get_style_context ().add_class (Gtk.STYLE_CLASS_MENUITEM);
        show_hidden_button.add (new Granite.AccelLabel (
            _("Hidden Files"),
            "<Ctrl>h"
        ));

        var show_local_thumbnails = new Gtk.CheckButton.with_label (_("Local Thumbnails")) {
            action_name = "win.show-local-thumbnails"
        };
        show_local_thumbnails.get_style_context ().add_class (Gtk.STYLE_CLASS_MENUITEM);

        var show_remote_thumbnails = new Gtk.CheckButton.with_label (_("Remote Thumbnails")) {
            action_name = "win.show-remote-thumbnails"
        };
        show_remote_thumbnails.get_style_context ().add_class (Gtk.STYLE_CLASS_MENUITEM);

        // Popover menu
        var menu_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            margin_bottom = 6
        };
        menu_box.add (icon_size_box);
        menu_box.add (undo_redo_box);
        menu_box.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL) { margin_bottom = 3 });
        menu_box.add (double_click_button);
        menu_box.add (foldes_before_files);
        menu_box.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL) { margin_top = 3, margin_bottom = 3 });
        menu_box.add (show_header);
        menu_box.add (show_hidden_button);
        menu_box.add (show_local_thumbnails);
        menu_box.add (show_remote_thumbnails);
        menu_box.show_all ();

        var menu = new Gtk.Popover (null);
        menu.add (menu_box);

        // AppMenu button
        var app_menu = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR),
            popover = menu,
            tooltip_text = _("Menu")
        };

        pack_start (button_back);
        pack_start (button_forward);
        pack_start (view_switcher);
        pack_start (location_bar);
        pack_end (app_menu);
        show_all ();

        // Connect to all view settings rather than try to connect and disconnect
        // continuously to current view mode setting.
        Files.icon_view_settings.changed["zoom-level"].connect (on_zoom_setting_changed);
        Files.list_view_settings.changed["zoom-level"].connect (on_zoom_setting_changed);
        Files.column_view_settings.changed["zoom-level"].connect (on_zoom_setting_changed);

        view_switcher.action.activate.connect ((id) => {
            switch ((ViewMode)(id.get_uint32 ())) {
                case ViewMode.ICON:
                    on_zoom_setting_changed (Files.icon_view_settings, "zoom-level");
                    break;
                case ViewMode.LIST:
                    on_zoom_setting_changed (Files.list_view_settings, "zoom-level");
                    break;
                case ViewMode.MILLER_COLUMNS:
                    on_zoom_setting_changed (Files.column_view_settings, "zoom-level");
                    break;
            }
        });

        button_forward.slow_press.connect (() => {
            forward (1);
        });

        button_back.slow_press.connect (() => {
            back (1);
        });

        location_bar.reload_request.connect (() => {
            reload_request ();
        });

        location_bar.focus_file_request.connect ((file) => {
            focus_location_request (file);
        });

        location_bar.focus_in_event.connect ((event) => {
            locked_focus = true;
            return focus_in_event (event);
        });

        location_bar.focus_out_event.connect ((event) => {
            locked_focus = false;
            return focus_out_event (event);
        });

        location_bar.path_change_request.connect ((path, flag) => {
            path_change_request (path, flag);
        });

        location_bar.escape.connect (() => {escape ();});

        undo_manager = UndoManager.instance ();
        undo_manager.request_menu_update.connect (set_undo_redo_tooltips);
        set_undo_redo_tooltips ();
    }

    private void set_undo_redo_tooltips () {
        var undo_action_s = undo_manager.get_next_undo_description ();
        var redo_action_s = undo_manager.get_next_redo_description ();

        undo_button.tooltip_markup = Granite.markup_accel_tooltip (
            undo_accels,
            undo_action_s != "" ?
            ///TRANSLATORS %s is a placeholder for a file operation type such as "Move"
            _("Undo %s").printf (undo_action_s) :
            _("No operation to undo")
        );

        redo_button.tooltip_markup = Granite.markup_accel_tooltip (
            redo_accels,
            redo_action_s != "" ?
            ///TRANSLATORS %s is a placeholder for a file operation type such as "Move"
            _("Redo %s").printf (redo_action_s) :
            _("No operation to redo")
        );
    }

    private void on_zoom_setting_changed (Settings settings, string key) {
        if (settings == null) {
            critical ("Zoom string from settinggs: Null settings");
            zoom_default_button.label = "";
            return;
        }

        var default_zoom = (Files.ZoomLevel)(settings.get_enum ("default-zoom-level"));
        var zoom_level = (Files.ZoomLevel)(settings.get_enum ("zoom-level"));
        zoom_default_button.label = ("%.0f%%").printf ((double)(zoom_level.to_icon_size ()) / (double)(default_zoom.to_icon_size ()) * 100);

        var max_zoom = settings.get_enum ("maximum-zoom-level");
        var min_zoom = settings.get_enum ("minimum-zoom-level");

        zoom_in_button.sensitive = zoom_level < max_zoom;
        zoom_out_button.sensitive = zoom_level > min_zoom;
    }

    public bool enter_search_mode (string term = "") {
        return location_bar.enter_search_mode (term);
    }

    public bool enter_navigate_mode () {
        return location_bar.enter_navigate_mode ();
    }

    public void set_back_menu (Gee.List<string> path_list) {
        /* Clear the back menu and re-add the correct entries. */
        var back_menu = new Gtk.Menu ();
        var n = 1;
        foreach (string path in path_list) {
            int cn = n++; /* No i'm not mad, thats just how closures work in vala (and other langs).
                           * You see if I would just use back(n) the reference to n would be passed
                           * in the closure, resulting in a value of n which would always be n=1. So
                           * by introducting a new variable I can bypass this anoyance.
                           */
            var item = new Gtk.MenuItem.with_label (FileUtils.sanitize_path (path, null, false));
            item.activate.connect (() => {
                back (cn);
            });

            back_menu.insert (item, -1);
        }

        back_menu.show_all ();
        button_back.menu = back_menu;
    }

    public void set_forward_menu (Gee.List<string> path_list) {
        /* Same for the forward menu */
        var forward_menu = new Gtk.Menu ();
        var n = 1;
        foreach (string path in path_list) {
            int cn = n++; /* For explanation look up */
            var item = new Gtk.MenuItem.with_label (FileUtils.sanitize_path (path, null, false));
            item.activate.connect (() => {
                forward (cn);
            });

            forward_menu.insert (item, -1);
        }

        forward_menu.show_all ();
        button_forward.menu = forward_menu;
    }

    public void update_location_bar (string new_path, bool with_animation = true) {
        location_bar.with_animation = with_animation;
        location_bar.set_display_path (new_path);
        location_bar.with_animation = true;
    }

    public void cancel () {
        location_bar.cancel ();
    }
}
