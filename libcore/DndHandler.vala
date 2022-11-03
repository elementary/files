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

namespace Files {
    public class DndHandler : GLib.Object {
        // static Gdk.DragAction? chosen = null;
        static Files.DndHandler? instance = null;
        //Since can only be one DnD operation in progress at a time, we can use a singleton
        public static Files.DndHandler get_default () {
            if (instance == null) {
                instance = new DndHandler ();
            }

            return instance;
        }

        protected DndHandler () {}

        public Gdk.DragAction handle_file_drop_actions (
            Gtk.Widget dest_widget,
            double x, double y,
            Files.File drop_target,
            GLib.List<GLib.File> drop_file_list,
            Gdk.DragAction possible_actions,
            Gdk.DragAction suggested_action
        ) {
            bool success = false;
            Gdk.DragAction action = suggested_action;

            if (drop_file_list != null) {
                if (suggested_action == Gdk.DragAction.ASK) {
                    action = drag_drop_action_ask (dest_widget, x, y, possible_actions);
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

warning ("finish handling");
            return success ? action : 0;
        }

        public Gdk.DragAction drag_drop_action_ask (Gtk.Widget dest_widget,
                                                    double x, double y,
                                                    Gdk.DragAction possible_actions) {

            Gdk.DragAction chosen = 0;

            var action = new GLib.SimpleAction ("choice", GLib.VariantType.STRING);
            var dnd_actions = new SimpleActionGroup ();
            dnd_actions.add_action (action);
            dest_widget.insert_action_group ("dnd", dnd_actions);
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
                    default:
                        // Drop will be cancelled
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
            ask_popover.set_parent (dest_widget);

            var loop = new GLib.MainLoop (null, false);
            ask_popover.closed.connect (() => {
                if (loop.is_running ()) {
                    loop.quit ();
                }
            });
            ask_popover.popup ();
            loop.run ();
            ask_popover.destroy ();
            dest_widget.insert_action_group ("dnd", null);
warning ("finish ask");
            return chosen;
        }

        private bool dnd_perform (Gtk.Widget widget,
                                 Files.File drop_target,
                                 GLib.List<GLib.File> drop_file_list,
                                 Gdk.DragAction action)
        requires (drop_target != null && drop_file_list != null) {

warning ("dnd perform");
            if (drop_target.is_folder ()) {
                Files.FileOperations.copy_move_link.begin (
                    drop_file_list,
                    drop_target.get_target_location (),
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


        // public bool handle_xdnddirectsave (Gdk.DragContext context,
        //                                    Files.File drop_target,
        //                                    Gtk.SelectionData selection) {
        //     bool success = false;

        //     if (selection != null &&
        //         selection.get_length () == 1 && //No other way to get length?
        //         selection.get_format () == 8) {
        //         uchar result = selection.get_data ()[0];

        //         switch (result) {
        //             case 'F':
        //                 /* No fallback for XdndDirectSave stage (3), result "F" ("Failed") yet */
        //                 break;
        //             case 'E':
        //                 /* No fallback for XdndDirectSave stage (3), result "E" ("Error") yet.
        //                  * Note this result may be obtained even if the file was successfully saved */
        //                 success = true;
        //                 break;
        //             case 'S':
        //                 /* XdndDirectSave "Success" */
        //                 success = true;
        //                 break;
        //             default:
        //                 warning ("Unhandled XdndDirectSave result %s", result.to_string ());
        //                 break;
        //         }
        //     }

        //     if (!success) {
        //         set_source_uri (context, "");
        //     }

        //     return success;
        // }

        // public bool handle_netscape_url (Gdk.DragContext context, Files.File drop_target, Gtk.SelectionData selection) {
        //     string [] parts = (selection.get_text ()).split ("\n");

        //     /* _NETSCAPE_URL looks like this: "$URL\n$TITLE" - should be 2 parts */
        //     if (parts.length != 2) {
        //         return false;
        //     }

        //     /* NETSCAPE URLs are not currently handled.  No current bug reports */
        //     return false;
        // }


        // private static void set_stringbuilder_from_file_list (GLib.StringBuilder sb,
        //                                                       GLib.List<Files.File> file_list,
        //                                                       string prefix,
        //                                                      bool sanitize_path = false) {

        //     if (file_list != null && file_list.data != null && file_list.data is Files.File) {
        //         bool in_recent = file_list.data.is_recent_uri_scheme ();

        //         file_list.@foreach ((file) => {
        //             var target = in_recent ? file.get_display_target_uri () : file.get_target_location ().get_uri ();
        //             if (sanitize_path) {
        //                 target = FileUtils.sanitize_path (target, null, false);
        //             }

        //             sb.append (target);
        //             sb.append ("\r\n"); /* Drop onto Filezilla does not work without the "\r" */
        //         });
        //     } else {
        //         warning ("Invalid file list for drag and drop ignored");
        //     }
        // }
    }
}
