/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2020-2023 elementary, Inc. (https://elementary.io)
 */

public class Files.AppMenu : Gtk.Popover {
    private Gtk.Button redo_button;
    private Gtk.Button undo_button;
    private Gtk.Button zoom_default_button;
    private Gtk.Button zoom_in_button;
    private Gtk.Button zoom_out_button;
    private string[] redo_accels;
    private string[] undo_accels;
    private unowned UndoManager undo_manager;

    construct {
        var app_instance = (Gtk.Application)(GLib.Application.get_default ());

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

        var double_click_button = new Granite.SwitchModelButton (_("Double-click to Navigate")) {
            description = _("Double-click on a folder opens it, single-click selects it"),
            action_name = "win.singleclick-select"
        };

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

        var menu_box = new Gtk.Box (VERTICAL, 0) {
            margin_bottom = 6
        };
        menu_box.add (icon_size_box);
        menu_box.add (undo_redo_box);
        menu_box.add (new Gtk.Separator (HORIZONTAL) { margin_bottom = 3 });
        menu_box.add (double_click_button);
        menu_box.add (foldes_before_files);
        menu_box.add (new Gtk.Separator (HORIZONTAL) { margin_top = 3, margin_bottom = 3 });
        menu_box.add (show_header);
        menu_box.add (show_hidden_button);
        menu_box.add (show_local_thumbnails);
        menu_box.add (show_remote_thumbnails);
        menu_box.show_all ();

        child = menu_box;

        undo_manager = UndoManager.instance ();
        undo_manager.request_menu_update.connect (set_undo_redo_tooltips);
        set_undo_redo_tooltips ();

        // Connect to all view settings rather than try to connect and disconnect
        // continuously to current view mode setting.
        Files.icon_view_settings.changed["zoom-level"].connect (on_zoom_setting_changed);
        Files.list_view_settings.changed["zoom-level"].connect (on_zoom_setting_changed);
        Files.column_view_settings.changed["zoom-level"].connect (on_zoom_setting_changed);
    }

    private void set_undo_redo_tooltips () {
        unowned var undo_action_s = undo_manager.get_next_undo_description ();
        unowned var redo_action_s = undo_manager.get_next_redo_description ();

        undo_button.tooltip_markup = Granite.markup_accel_tooltip (
            undo_accels,
            undo_action_s != null ?
            undo_action_s :
            _("No operation to undo")
        );

        redo_button.tooltip_markup = Granite.markup_accel_tooltip (
            redo_accels,
            redo_action_s != null ?
            redo_action_s :
            _("No operation to redo")
        );
    }

    public void on_zoom_setting_changed (Settings settings, string key) {
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
}
