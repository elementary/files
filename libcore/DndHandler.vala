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
        Gdk.DragAction? chosen = null;

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

            add_action (win);
            //TODO Rework for GLib.Menu or Popover
            // var ask_menu = build_menu (possible_actions);
            // ask_menu.set_screen (dest_widget.get_screen ());
            // ask_menu.show_all ();
            // var loop = new GLib.MainLoop (null, false);

            // ask_menu.deactivate.connect (() => {
            //     if (loop.is_running ()) {
            //         loop.quit ();
            //     }

            //     remove_action ((Gtk.ApplicationWindow)win);
            // });

            // ask_menu.popup_at_pointer (null);
            // loop.run ();
            // Gtk.grab_remove (ask_menu);

            return null;
        }

        private void add_action (Gtk.ApplicationWindow win) {
            var action = new GLib.SimpleAction ("choice", GLib.VariantType.STRING);
            action.activate.connect (this.on_choice);

            win.add_action (action);
        }

        private void remove_action (Gtk.ApplicationWindow win) {
            win.remove_action ("choice");
        }

        // private Gtk.Menu build_menu (Gdk.DragAction possible_actions) {
        //     var menu = new Gtk.Menu ();

        //     build_and_append_menu_item (menu, _("Move Here"), Gdk.DragAction.MOVE, possible_actions);
        //     build_and_append_menu_item (menu, _("Copy Here"), Gdk.DragAction.COPY, possible_actions);
        //     build_and_append_menu_item (menu, _("Link Here"), Gdk.DragAction.LINK, possible_actions);

        //     menu.append (new Gtk.SeparatorMenuItem ());
        //     menu.append (new Gtk.MenuItem.with_label (_("Cancel")));

        //     return menu;
        // }

        // private void build_and_append_menu_item (Gtk.Menu menu, string label, Gdk.DragAction? action,
        //                                          Gdk.DragAction possible_actions) {

        //     if ((possible_actions & action) != 0) {
        //         var item = new Gtk.MenuItem.with_label (label);

        //         item.activate.connect (() => {
        //             this.chosen = action;
        //         });

        //         menu.append (item);
        //     }
        // }

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
                    this.chosen = null;
                    break;
            }
        }

        // public string? get_source_filename (Gdk.DragContext context) {
        //     uchar []? data = null;
        //     Gdk.Atom property_name = Gdk.Atom.intern_static_string ("XdndDirectSave0");
        //     Gdk.Atom property_type = Gdk.Atom.intern_static_string ("text/plain");

        //     bool exists = Gdk.property_get (context.get_source_window (),
        //                                     property_name,
        //                                     property_type,
        //                                     0, /* offset into property to start getting */
        //                                     1024, /* max bytes of data to retrieve */
        //                                     0, /* do not delete after retrieving */
        //                                     null, null, /* actual property type and format got disregarded */
        //                                     out data
        //                                    );

        //     if (exists && data != null) {
        //         string name = DndHandler.data_to_string (data);
        //         if (GLib.Path.DIR_SEPARATOR.to_string () in name) {
        //             warning ("invalid source filename");
        //             return null; /* not a valid filename */
        //         } else {
        //             return name;
        //         }
        //     } else {
        //         warning ("source file does not exist");
        //         return null;
        //     }
        // }

        // public void set_source_uri (Gdk.DragContext context, string uri) {
        //     debug ("DNDHANDLER: set source uri to %s", uri);
        //     Gdk.Atom property_name = Gdk.Atom.intern_static_string ("XdndDirectSave0");
        //     Gdk.Atom property_type = Gdk.Atom.intern_static_string ("text/plain");
        //     Gdk.property_change (context.get_source_window (),
        //                          property_name,
        //                          property_type,
        //                          8,
        //                          Gdk.PropMode.REPLACE,
        //                          uri.data,
        //                          uri.length);
        // }

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

        // public bool handle_file_drag_actions (Gtk.Widget dest_widget,
        //                                       Gdk.DragContext context,
        //                                       Files.File drop_target,
        //                                       GLib.List<GLib.File> drop_file_list,
        //                                       Gdk.DragAction possible_actions,
        //                                       Gdk.DragAction suggested_action,
        //                                       Gtk.ApplicationWindow win,
        //                                       uint32 timestamp) {

        //     bool success = false;
        //     Gdk.DragAction action = suggested_action;

        //     if (drop_file_list != null) {
        //         if ((possible_actions & Gdk.DragAction.ASK) != 0) {
        //             action = drag_drop_action_ask (dest_widget, win, possible_actions);
        //         }

        //         if (action != Gdk.DragAction.DEFAULT) {
        //             success = dnd_perform (dest_widget,
        //                                    drop_target,
        //                                    drop_file_list,
        //                                    action);
        //         }

        //     } else {
        //         critical ("Attempt to drop null file list");
        //     }

        //     return success;
        // }


        public static bool selection_data_is_uri_list (
            Gdk.ContentProvider cp, uint info, out string? text) {
            text = null;

            if (info == Files.TargetType.TEXT_URI_LIST &&
                cp != null) {
                // cp.contain_gtype (typeof string)) {
                // selection_data.get_length () > 0 && //No other way to get length?
                // selection_data.get_format () == 8) {

                /* selection_data.get_data () does not work for some reason (returns nothing) */
                // text = DndHandler.data_to_string (selection_data.get_data_with_length ());
                var string_val = Value (typeof (string));
                try {
                    if (cp.get_value (out string_val)) { //FIXME Valadoc has ref instead of out
                        text = string_val.get_string ();
                    }
                } catch (Error e) {
                    warning ("Could not get string from Value. %s", e.message);
                }
            }

            debug ("DNDHANDLER selection data is uri list returning %s", (text != null).to_string ());
            return (text != null);
        }

        // public static string data_to_string (uchar [] cdata) {
        //     var sb = new StringBuilder ("");

        //     foreach (uchar u in cdata) {
        //         sb.append_c ((char)u);
        //     }

        //     return sb.str;
        // }

        // public static void set_selection_data_from_file_list (Gtk.SelectionData selection_data,
        //                                                       GLib.List<Files.File> file_list,
        //                                                       string prefix = "") {

        //     GLib.StringBuilder sb = new GLib.StringBuilder (prefix);
        //     set_stringbuilder_from_file_list (sb, file_list, prefix, false);  /* Use escaped paths */
        //     selection_data.@set (selection_data.get_target (),
        //                          8,
        //                          sb.data);

        // }

        // public static void set_selection_text_from_file_list (Gtk.SelectionData selection_data,
        //                                                       GLib.List<Files.File> file_list,
        //                                                       string prefix = "") {

        //     GLib.StringBuilder sb = new GLib.StringBuilder (prefix);
        //     set_stringbuilder_from_file_list (sb, file_list, prefix, true); /* Use sanitized paths */
        //     sb.truncate (sb.len - 2);  /* Do not want "\r\n" at end when pasting into text*/
        //     selection_data.set_text (sb.str, (int)(sb.len));
        // }

        private static void set_stringbuilder_from_file_list (GLib.StringBuilder sb,
                                                              GLib.List<Files.File> file_list,
                                                              string prefix,
                                                              bool sanitize_path = false) {

            if (file_list != null && file_list.data != null && file_list.data is Files.File) {
                bool in_recent = file_list.data.is_recent_uri_scheme ();

                file_list.@foreach ((file) => {
                    var target = in_recent ? file.get_display_target_uri () : file.get_target_location ().get_uri ();
                    if (sanitize_path) {
                        target = FileUtils.sanitize_path (target, null, false);
                    }

                    sb.append (target);
                    sb.append ("\r\n"); /* Drop onto Filezilla does not work without the "\r" */
                });
            } else {
                warning ("Invalid file list for drag and drop ignored");
            }
        }
    }
}
