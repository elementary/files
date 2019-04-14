/*-
 * Copyright (c) 2017-2018 elementary LLC (http://launchpad.net/elementary)
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
 * Boston, MA 02110-1335 USA.
 *
 * Authored by: Adam Bieńkowski <donadigos159@gmail.com>
 */

public class FileChooserDialog : Gtk.Dialog {
    public bool is_destroyed { get; set; default = false; }
    public Request request { get; construct; }
    public signal void selected (List<GOF.File> selection);

    private Marlin.View.ViewContainer view_container;
    private Marlin.View.Chrome.TopMenu top_menu;
    private SimpleAction view_mode_action;

    private static Settings? settings;
    static construct {
        settings = new Settings ("io.elementary.files.preferences");
    }

    construct {
        var home_file = File.new_for_path (Environment.get_home_dir ());

        view_container = new Marlin.View.ViewContainer (null);
        view_container.expand = true;
        view_container.add_view (Marlin.ViewMode.ICON, home_file);
        view_container.loading.connect ((is_loading) => {
            update_top_menu ();
        });

        view_container.active.connect (() => {
            update_top_menu ();
        });

        view_container.slot.handle_activate_selected_items.connect (handle_activate_selected_items);

        view_mode_action = new SimpleAction ("view-mode", VariantType.STRING);
        view_mode_action.activate.connect (action_view_mode);

        var view_switcher = new Marlin.View.Chrome.ViewSwitcher (view_mode_action);
        view_switcher.mode = settings.get_enum ("default-viewmode");

        top_menu = new Marlin.View.Chrome.TopMenu (view_switcher);
        top_menu.location_bar.set_display_path (home_file.get_path ());
        top_menu.location_bar.path_change_request.connect ((path, flag) => {
            uri_path_change_request (path, flag);
        });

        top_menu.forward.connect (() => {view_container.go_forward ();});
        top_menu.back.connect (() => {view_container.go_back ();});
        //  top_menu.escape.connect (grab_focus);
        top_menu.path_change_request.connect ((loc, flag) => {
            view_container.is_frozen = false;
            uri_path_change_request (loc, flag);
        });
        //  top_menu.reload_request.connect (action_reload);
        top_menu.focus_location_request.connect ((loc) => {
            view_container.focus_location_if_in_current_directory (loc, true);
        });
        top_menu.focus_in_event.connect (() => {
            view_container.is_frozen = true;
            return true;
        });
        top_menu.focus_out_event.connect (() => {
            view_container.is_frozen = false;
            return true;
        });

        var folder_button = new Gtk.Button.from_icon_name ("folder-new", Gtk.IconSize.LARGE_TOOLBAR);
        folder_button.clicked.connect (() => {
            view_container.slot.new_folder ();
        });

        unowned Gtk.Box content_area = get_content_area ();


        var sidebar = new Marlin.Places.Sidebar (null, false);
        sidebar.path_change_request.connect (uri_path_change_request);

        var lside_pane = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        lside_pane.position = settings.get_int ("sidebar-width");
        lside_pane.show ();
        lside_pane.pack1 (sidebar, false, false);
        lside_pane.pack2 (view_container, true, false);

        content_area.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        content_area.add (lside_pane);
        content_area.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));

        var open_button = new Gtk.Button.with_label ("Open");
        open_button.clicked.connect (on_open_button_clicked);

        var cancel_button = new Gtk.Button.with_label ("Cancel");
        cancel_button.clicked.connect (() => destroy ());

        var bottom_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
        bottom_box.spacing = 6;
        bottom_box.margin = 6;
        bottom_box.halign = Gtk.Align.END;
        bottom_box.pack_end (cancel_button);
        bottom_box.pack_end (open_button);

        content_area.add (bottom_box);
        top_menu.pack_end (folder_button);

        set_titlebar (top_menu);
        set_default_size (700, 450);
    }

    public FileChooserDialog (Request request, string title) {
        Object (request: request, title: title, use_header_bar: 1);
    }

    public override void destroy () {
        is_destroyed = true;
        base.destroy ();
    }

    private void uri_path_change_request (string uri, Marlin.OpenFlag flag = Marlin.OpenFlag.DEFAULT) {
        string path = PF.FileUtils.sanitize_path (uri, null);
        if (path.length > 0) {
            var f = File.new_for_uri (PF.FileUtils.escape_uri (path));
            view_container.focus_location (f);
            top_menu.update_location_bar (uri);
        }
    }

    private void update_top_menu () {
        top_menu.set_back_menu (view_container.get_go_back_path_list ());
        top_menu.set_forward_menu (view_container.get_go_forward_path_list ());
        top_menu.can_go_back = view_container.can_go_back;
        top_menu.can_go_forward = (view_container.can_show_folder && view_container.can_go_forward);
        top_menu.working = view_container.is_loading;
    
        top_menu.update_location_bar (view_container.location.get_uri ());    
    }

    private void action_view_mode (GLib.Variant? param) {
        string mode_string = param.get_string ();
        Marlin.ViewMode mode = Marlin.ViewMode.MILLER_COLUMNS;
        switch (mode_string) {
            case "ICON":
                mode = Marlin.ViewMode.ICON;
                break;

            case "LIST":
                mode = Marlin.ViewMode.LIST;
                break;

            case "MILLER":
                mode = Marlin.ViewMode.MILLER_COLUMNS;
                break;

            default:
                break;
        }

        // We change the view and the slot gets recreated, therefore
        // ww have to reconnect to it

        view_container.slot.handle_activate_selected_items.disconnect (handle_activate_selected_items);
        view_container.change_view_mode (mode);
        view_container.slot.handle_activate_selected_items.connect (handle_activate_selected_items);
    }

    private void on_open_button_clicked () {
        unowned List<GOF.File> selected = view_container.slot.get_selected_files ();
        handle_activate_selected_items (selected);
    }

    private bool handle_activate_selected_items (List<GOF.File> selection) {
        foreach (GOF.File file in selection) {
            if (!file.is_folder ()) {
                selected (selection);
                return true;
            }
        }

        return false;
    }
}