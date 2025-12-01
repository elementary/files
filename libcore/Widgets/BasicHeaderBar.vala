/***
    // Copyright (c) 2010 mathijshenquet
    // Copyright (c) 2011 Lucas Baudin <xapantu@gmail.com>

    Marlin is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License as
    published by the Free Software Foundation; either version 2 of the
    License, or (at your option) any later version.

    Marlin is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    General Public License for more details.

    You should have received a copy of the GNU General Public
    License along with this program; see the file COPYING.  If not,
    write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
    Boston, MA 02110-1335 USA.

***/

public class Files.BasicHeaderBar : Hdy.HeaderBar {
    public BasicLocationBar location_bar { get; construct; }
    public ButtonWithMenu button_back { get; construct; }
    public ButtonWithMenu button_forward { get; construct; }

    public signal void path_change_request (string uri, Files.OpenFlag flag);
    public signal void go_back (int steps);
    public signal void go_forward (int steps);

    public BasicHeaderBar () {
        Object ();
    }

    construct {
        button_back = new ButtonWithMenu ("go-previous-symbolic");

        button_back.tooltip_markup = Granite.markup_accel_tooltip ({"<Alt>Left"}, _("Previous"));
        button_back.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        button_forward = new ButtonWithMenu ("go-next-symbolic");

        button_forward.tooltip_markup = Granite.markup_accel_tooltip ({"<Alt>Right"}, _("Next"));
        button_forward.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        location_bar = new BasicLocationBar ();
        warning ("setting custom title");
        custom_title = location_bar;
        warning ("done");
        centering_policy = LOOSE;
        show_close_button = true;

        pack_start (button_back);
        pack_start (button_forward);

        location_bar.path_change_request.connect ((path, flag) => {
            // content.is_frozen = false;
            // Put in an Idle so that any resulting authentication dialog
            // is able to grab focus *after* the view does
            Idle.add (() => {
                path_change_request (path, flag);
                return Source.REMOVE;
            });
        });
    }

    public void set_back_menu (Gee.List<string> path_list, bool can_go_back) {
        /* Clear the back menu and re-add the correct entries. */
        var back_menu = new Menu ();
        for (int i = 0; i < path_list.size; i++) {
            var path = path_list.@get (i);
            var item = new MenuItem (
                FileUtils.sanitize_path (path, null, false),
                Action.print_detailed_name ("header.back", new Variant.int32 (i + 1))
            );
            back_menu.append_item (item);
        }

        button_back.menu = back_menu;
        button_back.sensitive = can_go_back;
    }

    public void set_forward_menu (Gee.List<string> path_list, bool can_go_forward) {
        /* Same for the forward menu */
        var forward_menu = new Menu ();
        for (int i = 0; i < path_list.size; i++) {
            var path = path_list.@get (i);
            var item = new MenuItem (
                FileUtils.sanitize_path (path, null, false),
                Action.print_detailed_name ("header.forward", new Variant.int32 (i + 1))
            );
            forward_menu.append_item (item);
        }

        button_forward.menu = forward_menu;
        button_forward.sensitive = can_go_forward;
    }

    private void action_back (SimpleAction action, Variant? param) {
        go_back (param.get_int32 ());
    }

    private void action_forward (SimpleAction action, Variant? param) {
        go_forward (param.get_int32 ());
    }

    private void action_edit_path () {
        location_bar.enter_navigate_mode ();
    }

    public void update_location_bar (string new_path, bool with_animation = true) {
        warning ("update location bar path %s", new_path);
        location_bar.with_animation = with_animation;
        location_bar.set_display_path (new_path);
        location_bar.with_animation = true;
    }


}
