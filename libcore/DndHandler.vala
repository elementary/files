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
        static Gdk.DragAction? chosen = null;
        static List<GLib.File> drop_file_list = null;
        static Files.File? target_file = null;
        static Gdk.DragAction preferred_action = 0;
        static bool ask = false;

        public Files.DNDInterface dnd_widget { get; construct; } //Needs to have layout manager
        public Gtk.Widget? drag_widget { get; construct; }
        public Gtk.Widget? drop_widget { get; construct; }
        public DndHandler (Files.DNDInterface dnd_widget, Gtk.Widget? drag_widget, Gtk.Widget? drop_widget) {
            Object (
                dnd_widget: dnd_widget,
                drag_widget: drag_widget,
                drop_widget: drop_widget
            );
        }

        construct {
            assert (dnd_widget.get_layout_manager () != null);
            if (drag_widget != null) {
                //Set up drag source
                var drag_source = new Gtk.DragSource ();
                drag_source.set_actions (
                    Gdk.DragAction.COPY | Gdk.DragAction.MOVE | Gdk.DragAction.LINK | Gdk.DragAction.ASK
                );
                drag_widget.add_controller (drag_source);
                drag_source.prepare.connect ((x, y) => {
                    if (!dnd_widget.can_start_drags ()) {
                        return null;
                    }

                    //Provide both File and text type content
                    var val_text = Value (typeof (string));
                    var val_file = Value (typeof (GLib.File));
                    bool is_multiple;
                    Gdk.Paintable? paintable = null;
                    var drag_files = dnd_widget.get_file_list_for_drag (x, y, out paintable);
                    if (drag_files == null) {
                        return null;
                    }
                    //FIXME Need Gdk.FileList to box multiple files and constructors missing in .vapi
                    //Issue raised - for now just send clicked file
                    var drag_data_text = FileUtils.make_string_from_file_list (drag_files);
                    val_text.set_string (drag_data_text);
                    val_file.set_object (drag_files.first ().data.get_target_location ().dup ());
                    drag_source.set_icon (
                        paintable, paintable.get_intrinsic_width (), paintable.get_intrinsic_height ()
                    );
                    var cp_text = new Gdk.ContentProvider.for_value (val_text);
                    var cp_file = new Gdk.ContentProvider.for_value (val_file);
                    return new Gdk.ContentProvider.union ({cp_text, cp_file});
                });

                drag_source.drag_begin.connect ((drag) => {
                    //TODO May need to limit actions when dragging some files depending on permissions
                });
                drag_source.drag_end.connect ((drag) => {
                    drag_source.set_icon (null, 0, 0);
                });
                drag_source.drag_cancel.connect ((drag, reason) => {
                    return false;
                });
            }

            if (drop_widget != null) {
                //Setup as drop target
                var drop_target = new Gtk.DropTarget (
                    typeof (GLib.File), Gdk.DragAction.COPY | Gdk.DragAction.MOVE | Gdk.DragAction.LINK
                );
                drop_widget.add_controller (drop_target);
                drop_target.accept.connect ((drop) => {
                if (dnd_widget.can_accept_drops ()) {
                        target_file = null;
                        drop_file_list = null;
                        // Obtain file list
                        drop.read_value_async.begin (
                            typeof (GLib.File),
                            Priority.DEFAULT,
                            null,
                            (obj, res) => {
                                try {
                                    var content = drop.read_value_async.end (res);
                                    drop_file_list.append ((GLib.File)(content.get_object ()));
                                } catch (Error e) {
                                    warning ("Failed to get drop content as file");
                                }
                            }
                        );
                        return true;
                    } else {
                        return false;
                    }
                });
                drop_target.motion.connect ((x, y) => {
                    if (drop_file_list == null) {
                        return 0;
                    }

                    var previous_target_location = target_file != null ? target_file.location : null;


                    target_file = dnd_widget.get_target_file_for_drop (x, y);
                    if (previous_target_location == null ||
                        !(previous_target_location.equal (target_file.location))) {

                        preferred_action = 0;
                        var drop = drop_target.get_current_drop ();
                        ask = (drop.drag.actions & Gdk.DragAction.ASK) > 0;
                        var actions = Files.DndHandler.file_accepts_drop (
                            target_file,
                            drop_file_list,
                            drop,
                            out preferred_action
                        );
                        drop_target.actions = actions;
                    }

                    return preferred_action;
                });

                drop_target.on_drop.connect ((val, x, y) => {
                    if (target_file == null || drop_file_list == null) {
                        return false;
                    }

                    var performed = Files.DndHandler.handle_file_drop_actions (
                        dnd_widget,
                        x, y,
                        target_file,
                        drop_file_list,
                        drop_target.actions,
                        preferred_action,
                        ask
                    );
                    return true;
                });
            }
        }

        public static Gdk.DragAction handle_file_drop_actions (
            Gtk.Widget dest_widget,
            double x, double y,
            Files.File drop_target,
            GLib.List<GLib.File> drop_file_list,
            Gdk.DragAction possible_actions,
            Gdk.DragAction suggested_action,
            bool ask
        ) {
            bool success = false;
            Gdk.DragAction action = suggested_action;

            if (drop_file_list != null) {
                if (ask) {
                    action = drag_drop_action_ask (
                        dest_widget, x, y, possible_actions, suggested_action
                    );
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
            ask_popover.destroy ();
            popover_parent.insert_action_group ("dnd", null);
            return chosen;
        }

        private static bool dnd_perform (Gtk.Widget widget,
                                 Files.File drop_target,
                                 GLib.List<GLib.File> drop_file_list,
                                 Gdk.DragAction action)
        requires (drop_target != null && drop_file_list != null) {

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

    //Drag unmodified =selected_action = COPY or MOVE drag_actions = drop_target common actions
    //Drag with Ctrl - selected action == 0 drag actions = COPY
    //Drag with Shift - selected action = 0 drag_actions = MOVE
    //Drag with Alt - selected action == 0, drag actions includes ASK (Generates criticals)
    public static Gdk.DragAction file_accepts_drop (Files.File dest,
                                             GLib.List<GLib.File> drop_file_list, // read-only
                                             Gdk.Drop drop,
                                             out Gdk.DragAction preferred_action) {

        var target_location = dest.get_target_location ();
        Gdk.DragAction actions = drop.actions;
        preferred_action = 0;

        if (drop_file_list == null || drop_file_list.data == null) {
            return 0;
        }

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

        uint count = 0;
        if (Gdk.DragAction.COPY in drop.actions) { count++; }
        if (Gdk.DragAction.MOVE in drop.actions) { count++; }
        if (Gdk.DragAction.LINK in drop.actions) { count++; }

        //If there is only one drop/drag action (e.g. control pressed) do not override it
        if (count == 1) {
            preferred_action = drop.actions;
        }

        return actions;
    }

    private const uint MAX_FILES_CHECKED = 100; // Max checked copied from gof_file.c version
    private static Gdk.DragAction? valid_actions_for_file_list (GLib.File target_location,
                                                         GLib.List<GLib.File> drop_file_list,
                                                         out Gdk.DragAction preferred_action) {

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
