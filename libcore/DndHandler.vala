/***
    Copyright (c) 2015-2018 elementary LLC <https://elementary.io>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, Inc.,; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
    MA 02110-1301, USA.

    Authors: Jeremy Wootten <jeremy@elementaryos.org>
***/

public class Files.DndHandler : GLib.Object {
    static Gdk.DragAction? chosen = null;
    static List<GLib.File> drop_file_list = null;
    public static Gdk.DragAction preferred_action = 0;
    static bool ask = false;

    public static Gdk.DragAction handle_file_drop_actions (
        Gtk.Widget dest_widget,
        double x, double y,
        Files.File drop_target,
        GLib.List<GLib.File> dropped_files,
        Gdk.DragAction possible_actions,
        Gdk.DragAction suggested_action,
        bool ask = true
    ) {
        bool success = false;
        Gdk.DragAction action = 0;
        if (dropped_files != null) {
            foreach (var file in dropped_files) {
                drop_file_list.prepend (file);
            }

            //Only ask if more than one possible action and <Alt> pressed
            if (ask && possible_actions != suggested_action) {
                action = drag_drop_action_ask (
                    dest_widget, x, y, possible_actions, suggested_action
                );
            } else {
                action = suggested_action;
            }

            if (action != 0) {
                success = dnd_perform (dest_widget,
                                       drop_target,
                                       drop_file_list,
                                       action);
            }
        } else {
            critical ("Attempt to drop null file list");
        }

        drop_file_list = null;
        return success ? action : 0;
    }

    public static Gdk.DragAction drag_drop_action_ask (
        Gtk.Widget popover_parent, //Needs to have a layout manager
        double x, double y,
        Gdk.DragAction possible_actions,
        Gdk.DragAction suggested_action
    ) {
        Gdk.DragAction chosen = 0;
        var action = new GLib.SimpleAction ("choice", GLib.VariantType.STRING);
        var dnd_actions = new SimpleActionGroup ();
        dnd_actions.add_action (action);
        popover_parent.insert_action_group ("dnd", dnd_actions);
        action.activate.connect ((source, param) => {
            switch (param.get_string ()) {
                case "COPY":
                    chosen = Gdk.DragAction.COPY;
                    break;
                case "MOVE":
                    chosen = Gdk.DragAction.MOVE;
                    break;
                case "LINK":
                    chosen = Gdk.DragAction.LINK;
                    break;
                case "CANCEL":
                default:
                    break;
            }
        });

        var ask_menu = new Menu ();
        if (Gdk.DragAction.COPY in possible_actions) {
            ask_menu.append (_("Copy"), "dnd.choice::COPY");
        }
        if (Gdk.DragAction.MOVE in possible_actions) {
            ask_menu.append (_("Move"), "dnd.choice::MOVE");
        }
        if (Gdk.DragAction.LINK in possible_actions) {
            ask_menu.append (_("Link"), "dnd.choice::LINK");
        }
        //Assume there will always be >=1 option
        var cancel_menu = new Menu ();
        cancel_menu.append (_("Cancel"), "dnd.choice::CANCEL");
        ask_menu.append_section (null, cancel_menu);
        var ask_popover = new Gtk.PopoverMenu.from_model (ask_menu) {
            has_arrow = false,
            pointing_to = {(int)x, (int)y, 1, 1}
        };
        ask_popover.set_parent (popover_parent);
        var loop = new GLib.MainLoop (null, false);
        ask_popover.activate_default.connect (() => {
            chosen = suggested_action;
        });
        ask_popover.closed.connect (() => {
            if (loop.is_running ()) {
                loop.quit ();
            }
        });
        ask_popover.popup ();
        loop.run ();
        popover_parent.insert_action_group ("dnd", null);
        ask_popover.destroy ();
        return chosen;
    }

    private static bool dnd_perform (
        Gtk.Widget widget,
        Files.File drop_target,
        GLib.List<GLib.File> drop_file_list,
        Gdk.DragAction action
        ) requires (drop_target != null && drop_file_list != null) {

        if (drop_target.is_folder ()) {
            Files.FileOperations.copy_move_link.begin (
                drop_file_list,
                drop_target.get_target_location () ?? drop_target.location,
                action,
                widget,
                null
            );

            return true;
        } else if (drop_target.is_executable ()) {
            try {
                drop_target.execute (drop_file_list);
                return true;
            } catch (Error e) {
                unowned string target_name = drop_target.get_display_name ();
                PF.Dialogs.show_error_dialog (_("Failed to execute \"%s\"").printf (target_name),
                                              e.message,
                                              null);
                return false;
            }
        }

        return false;
    }

    public static Gdk.DragAction file_accepts_drop (
        Files.File dest,
        GLib.List<GLib.File> drop_file_list, // read-only
        Gdk.Drop drop
    ) {
        var target_location = dest.get_target_location ();
        Gdk.DragAction actions = drop.actions;
        preferred_action = 0;

        if (drop_file_list == null || drop_file_list.data == null) {
            return 0;
        }

        // Cannot drop a file on itself
        if (dest.location.equal (drop_file_list.data)) {
            return 0;
        }

        if (dest.is_folder () && dest.is_writable ()) {
            actions = valid_actions_for_file_list (target_location, drop_file_list, out preferred_action);
        } else if (dest.is_executable ()) {
            //Always drop on executable and allow app to determine success
            actions &= Gdk.DragAction.COPY;
        }

        if (Files.FileUtils.location_is_in_trash (target_location)) { // cannot copy or link to trash
            actions &= ~(Gdk.DragAction.COPY | Gdk.DragAction.LINK);
        }

        if (Gdk.DragAction.COPY == drop.actions ||
            Gdk.DragAction.MOVE == drop.actions ||
            Gdk.DragAction.LINK == drop.actions) {

            //If there is only one drop/drag action (e.g. control pressed) do not override it
            preferred_action = drop.actions;
        }

        return actions;
    }

    private const uint MAX_FILES_CHECKED = 100; // Max checked copied from gof_file.c version
    private static Gdk.DragAction? valid_actions_for_file_list (
        GLib.File target_location,
        GLib.List<GLib.File> drop_file_list,
        out Gdk.DragAction preferred_action
    ) {

        var valid_actions = Gdk.DragAction.COPY |
                            Gdk.DragAction.MOVE |
                            Gdk.DragAction.LINK;

        /* Check the first MAX_FILES_CHECKED and let
         * the operation fail for file the same as target if it is
         * buried in a large selection.  We can normally assume that all source files
         * come from the same folder, but drops from outside Files could be from multiple
         * folders. Try to find valid and preferred actions common to all files.
         */
        uint count = 0;
        preferred_action = valid_actions;
        foreach (var drop_file in drop_file_list) {
            if (Files.FileUtils.location_is_in_trash (drop_file) &&
                Files.FileUtils.location_is_in_trash (target_location)) {

                valid_actions = 0; // No DnD within trash
                break;
            }

            var scheme = drop_file.get_uri_scheme ();
            var parent = drop_file.get_parent ();
            var remote = scheme == null || !scheme.has_prefix ("file");
            var same_location = (parent != null && parent.equal (target_location));
            var same_system = Files.FileUtils.same_file_system (drop_file, target_location);

            if (same_location) {
                valid_actions &= ~(Gdk.DragAction.MOVE); // Cannot move within same location
            }

            if (remote) {
                valid_actions &= ~(Gdk.DragAction.LINK); // Can only LINK local files
            }

            if (same_location && !remote) {
                preferred_action &= Gdk.DragAction.LINK;
            } else if (same_system && !same_location) {
                preferred_action &= Gdk.DragAction.MOVE;
            } else {
                preferred_action &= Gdk.DragAction.COPY;
            }

            if (++count > MAX_FILES_CHECKED ||
                valid_actions == 0) {
                break;
            }
        }

        if (Gdk.DragAction.LINK in preferred_action) {
            preferred_action = Gdk.DragAction.LINK;
        } else if (Gdk.DragAction.MOVE in preferred_action) {
            preferred_action = Gdk.DragAction.MOVE;
        } else {
            preferred_action = Gdk.DragAction.COPY;
        }

        return valid_actions;
    }
}
