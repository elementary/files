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

public class Files.View.Chrome.HeaderBar : Gtk.Box {
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

    private Adw.HeaderBar headerbar;
    private LocationBar? location_bar;
    private Chrome.ButtonWithMenu button_forward;
    private Chrome.ButtonWithMenu button_back;

    construct {
        headerbar = new Adw.HeaderBar () {
            hexpand = true,
        };
        headerbar.set_centering_policy (Adw.CenteringPolicy.LOOSE);
        append (headerbar);

        button_back = new View.Chrome.ButtonWithMenu.from_icon_name ("go-previous-symbolic");
        button_back.tooltip_markup = Granite.markup_accel_tooltip ({"<Alt>Left"}, _("Previous"));
        button_back.add_css_class ("flat");

        button_forward = new View.Chrome.ButtonWithMenu.from_icon_name ("go-next-symbolic");
        button_forward.tooltip_markup = Granite.markup_accel_tooltip ({"<Alt>Right"}, _("Next"));
        button_forward.add_css_class ("flat");

        location_bar = new LocationBar () {
            hexpand = true
        };

        view_switcher = new Chrome.ViewSwitcher ("win.view-mode");
        view_switcher.set_mode (Files.app_settings.get_enum ("default-viewmode"));
        headerbar.pack_start (button_back);
        headerbar.pack_start (button_forward);
        headerbar.pack_end (view_switcher);
        headerbar.set_title_widget (location_bar);

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

        //TODO Implement focus tracking for Gtk4 if required
        // location_bar.focus_in_event.connect ((event) => {
        //     locked_focus = true;
        //     return focus_in_event (event);
        // });

        // location_bar.focus_out_event.connect ((event) => {
        //     locked_focus = false;
        //     return focus_out_event (event);
        // });

        location_bar.path_change_request.connect ((path, flag) => {
            path_change_request (path, flag);
        });

        location_bar.escape.connect (() => {escape ();});
    }

    public bool enter_search_mode (string term = "") {
        return location_bar.enter_search_mode (term);
    }

    public bool enter_navigate_mode () {
        return location_bar.enter_navigate_mode ();
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

    public void update_location_bar (string new_path, bool with_animation = true) {
        location_bar.with_animation = with_animation;
        location_bar.set_display_path (new_path);
        location_bar.with_animation = true;
    }

    public void cancel () {
        location_bar.cancel ();
    }
}
