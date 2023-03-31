/*
* Copyright 2022 elementary, Inc. (https://elementary.io)
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

public class Files.HeaderBar : Gtk.Box {
    public signal void focus_location_request (GLib.File? location);
    public signal void escape ();
    public signal void reload_request ();

    public bool locked_focus { get; private set; default = false; }

    public bool working {
        set {
            path_bar.sensitive = !value;
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

    public Adw.HeaderBar headerbar { get; construct; }
    public PathBar path_bar { get; construct; }
    public ViewSwitcher view_switcher { get; construct; }
    private ButtonWithMenu button_forward;
    private ButtonWithMenu button_back;

    private Gtk.Button zoom_in_button;
    private Gtk.Button zoom_out_button;
    private Gtk.Button zoom_default_button;
    private Gtk.Button undo_button;
    private Gtk.Button redo_button;
    private string[] undo_accels;
    private string[] redo_accels;
    private unowned UndoManager undo_manager;

    construct {
        var app_instance = (Gtk.Application)(GLib.Application.get_default ());
        orientation = Gtk.Orientation.HORIZONTAL;
        headerbar = new Adw.HeaderBar () {
            hexpand = true,
            focusable = false
        };
        headerbar.set_centering_policy (Adw.CenteringPolicy.LOOSE);
        headerbar.set_parent (this);
        button_back = new ButtonWithMenu ("go-previous-symbolic");
        button_back.tooltip_markup = Granite.markup_accel_tooltip ({"<Alt>Left"}, _("Previous"));
        button_back.add_css_class ("flat");

        button_forward = new ButtonWithMenu ("go-next-symbolic");
        button_forward.tooltip_markup = Granite.markup_accel_tooltip ({"<Alt>Right"}, _("Next"));
        button_forward.add_css_class ("flat");

        path_bar = new PathBar () {
            hexpand = true
        };

        view_switcher = new ViewSwitcher ("win.view-mode");
        view_switcher.set_mode (Files.app_settings.get_enum ("default-viewmode"));


        /**  AppMenu **/
        // Zoom controls
        zoom_out_button = new Gtk.Button.from_icon_name ("zoom-out-symbolic") {
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

        zoom_in_button = new Gtk.Button.from_icon_name ("zoom-in-symbolic") {
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
        icon_size_box.append (zoom_out_button);
        icon_size_box.append (zoom_default_button);
        icon_size_box.append (zoom_in_button);

        var undo_redo_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            homogeneous = true,
            margin_end = 12,
            margin_bottom = 12,
            margin_start = 12
        };

        undo_button = new Gtk.Button.from_icon_name ("edit-undo-symbolic") {
            action_name = "win.undo"
        };

        redo_button = new Gtk.Button.from_icon_name ("edit-redo-symbolic") {
            action_name = "win.redo"
        };

        undo_redo_box.append (undo_button);
        undo_redo_box.append (redo_button);

        undo_accels = app_instance.get_accels_for_action ("win.undo");
        redo_accels = app_instance.get_accels_for_action ("win.redo");

        // Double-click option
        var double_click_button = new Granite.SwitchModelButton (_("Double-click to Navigate")) {
            description = _("Double-click on a folder opens it, single-click selects it"),
            action_name = "win.singleclick-select"
        };

        //Sort folders before files
        var folders_before_files = new Granite.SwitchModelButton (_("Sort Folders before Files")) {
            action_name = "win.folders-before-files"
        };

        var show_header = new Granite.HeaderLabel (_("Show in View"));

        var show_hidden_button = new Gtk.CheckButton () {
            action_name = "win.show-hidden"
        };
        //TODO Show accel in CheckButton.
        var accel_label = new Granite.AccelLabel (
            _("Hidden Files"),
            "<Ctrl>h"
        );
        accel_label.set_parent (show_hidden_button);

        var show_local_thumbnails = new Gtk.CheckButton.with_label (_("Local Thumbnails")) {
            action_name = "win.show-local-thumbnails"
        };

        var show_remote_thumbnails = new Gtk.CheckButton.with_label (_("Remote Thumbnails")) {
            action_name = "win.show-remote-thumbnails"
        };

        // Popover menu
        var menu_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            margin_bottom = 6
        };
        menu_box.append (icon_size_box);
        menu_box.append (undo_redo_box);
        menu_box.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL) { margin_bottom = 3 });
        menu_box.append (double_click_button);
        menu_box.append (folders_before_files);
        menu_box.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL) { margin_top = 3, margin_bottom = 3 });
        menu_box.append (show_header);
        menu_box.append (show_hidden_button);
        menu_box.append (show_local_thumbnails);
        menu_box.append (show_remote_thumbnails);

        var menu = new Gtk.Popover ();
        menu.child = menu_box;

        // AppMenu button
        var app_menu = new Gtk.MenuButton () {
            // image = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR),
            icon_name = "open-menu",
            popover = menu,
            tooltip_text = _("Menu")
        };

        headerbar.pack_start (button_back);
        headerbar.pack_start (button_forward);

        headerbar.pack_end (app_menu);
        headerbar.pack_end (view_switcher);
        headerbar.set_title_widget (path_bar);

        button_forward.activated.connect (() => {
            path_bar.activate_action ("win.forward", "i", 1);
        });

        button_back.activated.connect (() => {
            path_bar.activate_action ("win.back", "i", 1);
        });

        path_bar.focus_file_request.connect ((file) => {
            focus_location_request (file);
        });
    }

    public void set_back_menu (Gee.List<string> path_list) {
        /* Clear the back menu and re-add the correct entries. */
        var back_menu = new Menu ();
        for (int i = 0; i < path_list.size; i++) {
            var path = path_list.@get (i);
            var item = new MenuItem (
                FileUtils.sanitize_path (path, null, false),
                Action.print_detailed_name ("win.back", new Variant.int32 (i))
            );
            back_menu.append_item (item);
        }

        button_back.menu = back_menu;
    }

    public void set_forward_menu (Gee.List<string> path_list) {
        /* Same for the forward menu */
        var forward_menu = new Menu ();
        for (int i = 0; i < path_list.size; i++) {
            var path = path_list.@get (i);
            var item = new MenuItem (
                FileUtils.sanitize_path (path, null, false),
                Action.print_detailed_name ("win.forward", new Variant.int32 (i))
            );
            forward_menu.append_item (item);
        }

        button_forward.menu = forward_menu;
    }

    public void update_path_bar (string new_path, bool with_animation = true) {
        path_bar.mode = PathBarMode.CRUMBS;
        path_bar.with_animation = with_animation;
        path_bar.display_uri = new_path;
        path_bar.with_animation = true;
    }

    public void cancel () {
        path_bar.cancel ();
    }
}
