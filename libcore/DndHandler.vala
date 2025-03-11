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

    Authors: Jeremy Wootten <jeremywootten@gmail.com>
***/

namespace Files {
    public class DndHandler : GLib.Object {
        Gdk.DragAction chosen = Gdk.DragAction.DEFAULT;

        public DndHandler () {}

        public bool dnd_perform (Gtk.Widget widget,
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

        public Gdk.DragAction? drag_drop_action_ask (Gtk.Widget dest_widget,
                                                     Gtk.ApplicationWindow win,
                                                     Gdk.DragAction possible_actions) {

            this.chosen = Gdk.DragAction.DEFAULT;
            add_action (win);
            var ask_menu = build_menu (possible_actions);
            ask_menu.set_screen (dest_widget.get_screen ());
            ask_menu.show_all ();
            var loop = new GLib.MainLoop (null, false);

            ask_menu.deactivate.connect (() => {
                if (loop.is_running ()) {
                    loop.quit ();
                }

                remove_action ((Gtk.ApplicationWindow)win);
            });

            ask_menu.popup_at_pointer (null);
            loop.run ();
            Gtk.grab_remove (ask_menu);

            return this.chosen;
        }

        private void add_action (Gtk.ApplicationWindow win) {
            var action = new GLib.SimpleAction ("choice", GLib.VariantType.STRING);
            action.activate.connect (this.on_choice);

            win.add_action (action);
        }

        private void remove_action (Gtk.ApplicationWindow win) {
            win.remove_action ("choice");
        }

        private Gtk.Menu build_menu (Gdk.DragAction possible_actions) {
            var menu = new Gtk.Menu ();

            build_and_append_menu_item (menu, _("Move Here"), Gdk.DragAction.MOVE, possible_actions);
            build_and_append_menu_item (menu, _("Copy Here"), Gdk.DragAction.COPY, possible_actions);
            build_and_append_menu_item (menu, _("Link Here"), Gdk.DragAction.LINK, possible_actions);

            menu.append (new Gtk.SeparatorMenuItem ());
            menu.append (new Gtk.MenuItem.with_label (_("Cancel")));

            return menu;
        }

        private void build_and_append_menu_item (Gtk.Menu menu, string label, Gdk.DragAction? action,
                                                 Gdk.DragAction possible_actions) {

            if ((possible_actions & action) != 0) {
                var item = new Gtk.MenuItem.with_label (label);

                item.activate.connect (() => {
                    this.chosen = action;
                });

                menu.append (item);
            }
        }

        public void on_choice (GLib.Variant? param) {
            if (param == null || !param.is_of_type (GLib.VariantType.STRING)) {
                critical ("Invalid variant type in DndHandler Menu");
                return;
            }

            string choice = param.get_string ();

            switch (choice) {
                case "move":
                    this.chosen = Gdk.DragAction.MOVE;
                    break;
                case "copy":
                    this.chosen = Gdk.DragAction.COPY;
                    break;
                case "link":
                    this.chosen = Gdk.DragAction.LINK;
                    break;
                case "background": /* not implemented yet */
                case "cancel":
                default:
                    this.chosen = Gdk.DragAction.DEFAULT;
                    break;
            }
        }

        public string? get_source_filename (Gdk.Window source_window) {
            uchar []? data = null;
            Gdk.Atom property_name = Gdk.Atom.intern_static_string ("XdndDirectSave0");
            Gdk.Atom property_type = Gdk.Atom.intern_static_string ("text/plain");

            bool exists = Gdk.property_get (source_window,
                                            property_name,
                                            property_type,
                                            0, /* offset into property to start getting */
                                            1024, /* max bytes of data to retrieve */
                                            0, /* do not delete after retrieving */
                                            null, null, /* actual property type and format got disregarded */
                                            out data
                                           );

            if (exists && data != null) {
                string name = DndHandler.data_to_string (data);
                if (GLib.Path.DIR_SEPARATOR.to_string () in name) {
                    warning ("invalid source filename");
                    return null; /* not a valid filename */
                } else {
                    return name;
                }
            } else {
                warning ("source file does not exist");
                return null;
            }
        }

        public void set_source_uri (Gdk.Window source_window, string uri) {
            debug ("DNDHANDLER: set source uri to %s", uri);
            Gdk.Atom property_name = Gdk.Atom.intern_static_string ("XdndDirectSave0");
            Gdk.Atom property_type = Gdk.Atom.intern_static_string ("text/plain");
            Gdk.property_change (source_window,
                                 property_name,
                                 property_type,
                                 8,
                                 Gdk.PropMode.REPLACE,
                                 uri.data,
                                 uri.length);
        }

        public bool handle_xdnddirectsave (Gdk.Window source_window,
                                           Files.File drop_target,
                                           Gtk.SelectionData selection) {
            bool success = false;

            if (selection != null &&
                selection.get_length () == 1 && //No other way to get length?
                selection.get_format () == 8) {
                uchar result = selection.get_data ()[0];

                switch (result) {
                    case 'F':
                        /* No fallback for XdndDirectSave stage (3), result "F" ("Failed") yet */
                        break;
                    case 'E':
                        /* No fallback for XdndDirectSave stage (3), result "E" ("Error") yet.
                         * Note this result may be obtained even if the file was successfully saved */
                        success = true;
                        break;
                    case 'S':
                        /* XdndDirectSave "Success" */
                        success = true;
                        break;
                    default:
                        warning ("Unhandled XdndDirectSave result %s", result.to_string ());
                        break;
                }
            }

            if (!success) {
                set_source_uri (source_window, "");
            }

            return success;
        }

        public bool handle_netscape_url (Gdk.Window source_window, Files.File drop_target, Gtk.SelectionData selection) {
            string [] parts = (selection.get_text ()).split ("\n");

            /* _NETSCAPE_URL looks like this: "$URL\n$TITLE" - should be 2 parts */
            if (parts.length != 2) {
                return false;
            }

            /* NETSCAPE URLs are not currently handled.  No current bug reports */
            return false;
        }

        public bool handle_file_drag_actions (Gtk.Widget dest_widget,
                                              Files.File drop_target,
                                              GLib.List<GLib.File> drop_file_list,
                                              Gdk.DragAction possible_actions,
                                              Gdk.DragAction suggested_action,
                                              Gtk.ApplicationWindow win,
                                              uint32 timestamp) {

            bool success = false;
            Gdk.DragAction action = suggested_action;

            if (drop_file_list != null) {
                if ((possible_actions & Gdk.DragAction.ASK) != 0) {
                    action = drag_drop_action_ask (dest_widget, win, possible_actions);
                }

                if (action != Gdk.DragAction.DEFAULT) {
                    success = dnd_perform (dest_widget,
                                           drop_target,
                                           drop_file_list,
                                           action);
                }

            } else {
                critical ("Attempt to drop null file list");
            }

            return success;
        }


        public static bool selection_data_is_uri_list (Gtk.SelectionData selection_data, uint info, out string? text) {
            text = null;

            if (info == Files.TargetType.TEXT_URI_LIST &&
                selection_data != null &&
                selection_data.get_length () > 0 && //No other way to get length?
                selection_data.get_format () == 8) {

                /* selection_data.get_data () does not work for some reason (returns nothing) */
                text = DndHandler.data_to_string (selection_data.get_data_with_length ());
            }

            debug ("DNDHANDLER selection data is uri list returning %s", (text != null).to_string ());
            return (text != null);
        }

        public static string data_to_string (uchar [] cdata) {
            var sb = new StringBuilder ("");

            foreach (uchar u in cdata) {
                sb.append_c ((char)u);
            }

            return sb.str;
        }

        // Used when dragging a file item
        public static void set_selection_data_from_file_list (Gtk.SelectionData selection_data,
                                                              GLib.List<Files.File> file_list,
                                                              string prefix = "") {

            GLib.StringBuilder sb = new GLib.StringBuilder (prefix);
            set_stringbuilder_from_file_list (sb, file_list, prefix, false); // This will keep the "file://" protocol
            selection_data.@set (selection_data.get_target (),
                                 8,
                                 sb.data);

        }

        // Used when copying a file item
        public static void set_selection_text_from_file_list (Gtk.SelectionData selection_data,
                                                              GLib.List<Files.File> file_list,
                                                              string prefix = "") {

            GLib.StringBuilder sb = new GLib.StringBuilder (prefix);
            set_stringbuilder_from_file_list (sb, file_list, prefix, true); // This will remove the "file://" protocol
            sb.truncate (sb.len - 2);  /* Do not want "\r\n" at end when pasting into text*/
            selection_data.set_text (sb.str, (int)(sb.len));
        }

        private static void set_stringbuilder_from_file_list (GLib.StringBuilder sb,
                                                              GLib.List<Files.File> file_list,
                                                              string prefix,
                                                              bool sanitize_path) {

            if (file_list != null && file_list.data != null && file_list.data is Files.File) {
                bool in_recent = file_list.data.is_recent_uri_scheme ();

                file_list.@foreach ((file) => {
                    var target = in_recent ? file.get_display_target_uri () : file.get_target_location ().get_uri ();
                    if (sanitize_path) {
                        target = FileUtils.sanitize_path (target, null, false);
                    }

                    sb.append (Shell.quote (target)); //Alway quote urls
                    sb.append ("\r\n"); /* Drop onto Filezilla does not work without the "\r" */
                });
            } else {
                warning ("Invalid file list for drag and drop ignored");
            }
        }

        public static Gdk.DragAction file_accepts_drop (Files.File dest,
                                                 GLib.List<GLib.File> drop_file_list, // read-only
                                                 Gdk.DragAction selected_action,
                                                 Gdk.DragAction possible_actions,
                                                 out Gdk.DragAction suggested_action_return) {

            var actions = possible_actions;
            var suggested_action = selected_action;
            var target_location = dest.get_target_location ();
            suggested_action_return = Gdk.DragAction.PRIVATE;

            if (drop_file_list == null || drop_file_list.data == null) {
                return Gdk.DragAction.DEFAULT;
            }

            if (dest.is_folder ()) {
                if (!dest.is_writable ()) {
                    actions = Gdk.DragAction.DEFAULT;
                } else {
                    /* Modify actions and suggested_action according to source files */
                    actions &= valid_actions_for_file_list (target_location,
                                                            drop_file_list,
                                                            ref suggested_action);
                }
            } else if (dest.is_executable ()) {
                actions |= (Gdk.DragAction.COPY |
                           Gdk.DragAction.MOVE |
                           Gdk.DragAction.LINK |
                           Gdk.DragAction.PRIVATE);
            } else {
                actions = Gdk.DragAction.DEFAULT;
            }

            if (actions == Gdk.DragAction.DEFAULT) { // No point asking if no other valid actions
                return Gdk.DragAction.DEFAULT;
            } else if (FileUtils.location_is_in_trash (target_location)) { // cannot copy or link to trash
                actions &= ~(Gdk.DragAction.COPY | Gdk.DragAction.LINK);
            }

            if (suggested_action in actions) {
                suggested_action_return = suggested_action;
            } else if (Gdk.DragAction.ASK in actions) {
                suggested_action_return = Gdk.DragAction.ASK;
            } else if (Gdk.DragAction.COPY in actions) {
                suggested_action_return = Gdk.DragAction.COPY;
            } else if (Gdk.DragAction.LINK in actions) {
                suggested_action_return = Gdk.DragAction.LINK;
            } else if (Gdk.DragAction.MOVE in actions) {
                suggested_action_return = Gdk.DragAction.MOVE;
            }

            return actions;
        }

        private const uint MAX_FILES_CHECKED = 100; // Max checked copied from gof_file.c version
        private static Gdk.DragAction valid_actions_for_file_list (GLib.File target_location,
                                                            GLib.List<GLib.File> drop_file_list,
                                                            ref Gdk.DragAction suggested_action) {

            var valid_actions = Gdk.DragAction.DEFAULT |
                                Gdk.DragAction.COPY |
                                Gdk.DragAction.MOVE |
                                Gdk.DragAction.LINK;

            /* Check the first MAX_FILES_CHECKED and let
             * the operation fail for file the same as target if it is
             * buried in a large selection.  We can normally assume that all source files
             * come from the same folder, but drops from outside Files could be from multiple
             * folders. The valid actions are the lowest common denominator.
             */
            uint count = 0;
            bool from_trash = false;

            foreach (var drop_file in drop_file_list) {
                if (FileUtils.location_is_in_trash (drop_file)) {
                    from_trash = true;

                    if (FileUtils.location_is_in_trash (target_location)) {
                        valid_actions = Gdk.DragAction.DEFAULT; // No DnD within trash
                    }
                }

                var parent = drop_file.get_parent ();

                if (parent != null && parent.equal (target_location)) {
                    valid_actions &= Gdk.DragAction.LINK; // Only LINK is valid
                }

                var scheme = drop_file.get_uri_scheme ();
                if (scheme == null || !scheme.has_prefix ("file")) {
                    valid_actions &= ~(Gdk.DragAction.LINK); // Can only LINK local files
                }

                if (++count > MAX_FILES_CHECKED ||
                    valid_actions == Gdk.DragAction.DEFAULT) {

                    break;
                }
            }

            /* Modify Gtk suggested COPY action to MOVE if source is trash or dest is in
             * same filesystem and if MOVE is a valid action.  We assume that it is not possible
             * to drop files both from remote and local filesystems simultaneously
             */
            if ((Gdk.DragAction.COPY in valid_actions && Gdk.DragAction.MOVE in valid_actions) &&
                 suggested_action == Gdk.DragAction.COPY &&
                 (from_trash || FileUtils.same_file_system (drop_file_list.first ().data, target_location))) {

                suggested_action = Gdk.DragAction.MOVE;
            }

            if (valid_actions != Gdk.DragAction.DEFAULT) {
                valid_actions |= Gdk.DragAction.ASK; // Allow ASK if there is a possible action
            }

            return valid_actions;
        }
    }
}
