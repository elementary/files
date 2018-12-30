/***
    Copyright (c) 2015-2018 elementary LLC <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/

namespace Marlin {
    public class ViewDndDestination : GLib.Object {
        public unowned FM.AbstractDirectoryView abstract_view { get; construct; }
        public unowned Gtk.Widget real_view { get; construct; }
        public Gdk.DragAction current_suggested_action = Gdk.DragAction.DEFAULT;
        public Gdk.DragAction current_actions = Gdk.DragAction.DEFAULT;
        public GOF.File? drop_target_file { get; set; default = null; }

        private Marlin.DndHandler dnd_handler;
        private bool drag_in_progress = false;
        private bool drag_data_ready = false; /* whether the drag data was received already */
        private bool drop_occurred = false; /* whether the data was dropped */
        private void* drag_data;
        private GLib.List<GLib.File> drag_file_list = null; /* the list of URIs that are contained in the drag data */
        private Gdk.Atom current_target_type;

        const Gtk.TargetEntry[] drop_targets = {
            {XDND_DIRECT_SAVE, Gtk.TargetFlags.OTHER_APP, Marlin.TargetType.XDND_DIRECT_SAVE},
            {NETSCAPE_URL, Gtk.TargetFlags.OTHER_APP, Marlin.TargetType.NETSCAPE_URL},
            {RAW, Gtk.TargetFlags.OTHER_APP, Marlin.TargetType.RAW},
            {TEXT_URI_LIST, Gtk.TargetFlags.SAME_APP, Marlin.TargetType.TEXT_URI_LIST},
            {TEXT_URI_LIST, Gtk.TargetFlags.OTHER_APP, Marlin.TargetType.TEXT_URI_LIST},
            {TEXT_PLAIN, Gtk.TargetFlags.SAME_APP, Marlin.TargetType.TEXT_PLAIN},
            {TEXT_PLAIN, Gtk.TargetFlags.OTHER_APP, Marlin.TargetType.TEXT_PLAIN}
        };

        const Gdk.DragAction file_drag_actions = (Gdk.DragAction.COPY | Gdk.DragAction.MOVE | Gdk.DragAction.LINK);

        public signal void leave ();
        public signal void dropped ();

        construct {
            dnd_handler = new Marlin.DndHandler ();
            /* Set up as drop site */
            Gtk.drag_dest_set (real_view, Gtk.DestDefaults.MOTION, drop_targets, Gdk.DragAction.ASK | file_drag_actions);
            real_view.drag_motion.connect (on_drag_motion);
            real_view.drag_drop.connect (on_drag_drop);
            real_view.drag_data_received.connect (on_drag_data_received);
            real_view.drag_leave.connect (on_drag_leave);

            current_suggested_action = Gdk.DragAction.DEFAULT;
            current_actions = Gdk.DragAction.DEFAULT;
        }

        public ViewDndDestination (FM.AbstractDirectoryView adv, Gtk.Widget view) {
            Object (
                abstract_view: adv,
                real_view: view
            );
        }

        private bool on_drag_motion (Gdk.DragContext context,
                                     int x,
                                     int y,
                                     uint timestamp) {

            drag_in_progress = true;

            if (!drag_data_ready && !get_drag_data (context, x, y, timestamp)) {
                /* We don't have drag data already ... */
                return false;
            } else {
                /* We have the drag data - check whether we can drop here*/
                check_destination_actions_and_target_file (context, x, y, timestamp);
            }

            if (drag_scroll_timer_id == 0) {
                start_drag_scroll_timer (context);
            }

            Gdk.drag_status (context, current_suggested_action, timestamp);

            return true;

        }

        private bool on_drag_drop (Gdk.DragContext context,
                                   int x,
                                   int y,
                                   uint timestamp) {

            string? uri = null;
            bool ok_to_drop = false;

            Gdk.Atom target = Gtk.drag_dest_find_target (real_view, context, null);

            if (target == dnd_handler.XDND_DIRECT_SAVE_ATOM) {
                GOF.File? target_file = abstract_view.get_file_at_pos (x, y, null);
                if (target_file != null) {
                    /* get XdndDirectSave file name from DnD source window */
                    string? filename = dnd_handler.get_xdnd_property_data (context);
                    if (filename != null) {
                        /* Get uri of source file when dropped */
                        uri = target_file.get_target_location ().resolve_relative_path (filename).get_uri ();
                        /* Setup the XdndDirectSave property on the source window */
                        dnd_handler.set_source_uri (context, uri);
                        ok_to_drop = true;
                    } else {
                        PF.Dialogs.show_error_dialog (_("Cannot drop this file"),
                                                      _("Invalid file name provided"), abstract_view.window);
                    }
                }

                ok_to_drop = true;
            } else {
                ok_to_drop = (target != Gdk.Atom.NONE);
            }

            if (ok_to_drop) {
                drop_occurred = true;
                /* request the drag data from the source (initiates
                 * saving in case of XdndDirectSave).*/
                Gtk.drag_get_data (real_view, context, target, timestamp);
            }

            return ok_to_drop;

        }

        Gtk.SelectionData sdata_copy;
        private void on_drag_data_received (Gdk.DragContext context,
                                            int x,
                                            int y,
                                            Gtk.SelectionData selection_data,
                                            uint info,
                                            uint timestamp
                                            ) {
            bool success = false;
            bool finished = true;

            if (!drag_data_ready) {
                drag_data_ready = true;
                sdata_copy = selection_data.copy ();
                /* extract uri list from selection data (XDndDirectSave etc set drag_data_ready true already) */
                string? text;
                if (Marlin.DndHandler.selection_data_is_uri_list (sdata_copy, info, out text)) {
                    drag_file_list = PF.FileUtils.files_from_uris (text);
                }
                /* May need to deal with other data types here? */
            }

            if (!drop_occurred) {
                return;
            }

            if (current_actions != Gdk.DragAction.DEFAULT) {
                switch (info) {
                    case Marlin.TargetType.XDND_DIRECT_SAVE:
                        debug ("XDND data received");
                        /* If XDndDirectSave fails need to fallback to another type so set finished false */
                        finished = dnd_handler.handle_xdnddirectsave (context,
                                                                     drop_target_file,
                                                                     selection_data,
                                                                     timestamp,
                                                                     real_view);
                        success = true;
                        break;

                    case Marlin.TargetType.RAW:
                        debug ("RAW data received");
                        success = dnd_handler.handle_raw_dnd_data (context,
                                                                   drop_target_file,
                                                                   selection_data,
                                                                   timestamp,
                                                                   real_view,
                                                                   null);
                        break;

                    case Marlin.TargetType.NETSCAPE_URL:
                        warning ("NETSCAPE_URL data received");
                        success = dnd_handler.handle_netscape_url (context,
                                                                   drop_target_file,
                                                                   selection_data,
                                                                   timestamp,
                                                                   real_view,
                                                                   current_actions,
                                                                   current_suggested_action);
                        break;

                    case Marlin.TargetType.TEXT_URI_LIST:
                        debug ("TEXT_URI_LIST data received");
                        if ((current_actions & file_drag_actions) != 0) {
                            dropped ();
                            success = dnd_handler.handle_file_drag_actions (real_view,
                                                                            abstract_view.window,
                                                                            context,
                                                                            drop_target_file,
                                                                            drag_file_list,
                                                                            current_actions,
                                                                            current_suggested_action,
                                                                            timestamp);
                        }

                        break;

                    case Marlin.TargetType.TEXT_PLAIN:
                        warning ("TEXT PLAIN data received");
                        success = dnd_handler.handle_plain_text (context,
                                                                 drop_target_file,
                                                                 selection_data,
                                                                 timestamp,
                                                                 real_view,
                                                                 abstract_view.create_file_done);
                        break;

                    default:
                        warning ("UNKNOWN data received - ignoring");
                        break;
                }
            }

            if (finished) {
                Gtk.drag_finish (context, success, false, timestamp);
                drop_occurred = false;
                drag_in_progress = false;
                on_drag_leave ();
            }
        }

        private void on_drag_leave () {
            /* Ignore if still dragging (signal emited when view location automatically changes during drag) */
            if (drag_in_progress) {
                return;
            }

            abstract_view.highlight_drop_file (drop_target_file, Gdk.DragAction.DEFAULT, null);
            drop_target_file = null;
            drag_file_list = null;
            drag_data_ready = false;
            current_suggested_action = Gdk.DragAction.DEFAULT;
            current_actions = Gdk.DragAction.DEFAULT;
        }

        private bool get_drag_data (Gdk.DragContext context, int x, int y, uint timestamp) {
            Gdk.Atom target = Gtk.drag_dest_find_target (real_view, context, null);
            bool result = false;
            current_target_type = target;
            /* Check if we can handle it yet */
            if (target == dnd_handler.XDND_DIRECT_SAVE_ATOM ||
                target == dnd_handler.NETSCAPE_URL_ATOM ||
                target == dnd_handler.RAW_ATOM) {

                /* Determine file at current position (if any) */
                Gtk.TreePath? path = null;
                GOF.File? file = abstract_view.get_file_at_pos (x, y, out path);

                if (file != null &&
                    file.is_folder () &&
                    file.is_writable ()) {

                    abstract_view.highlight_drop_file (file, current_suggested_action, path);
                    drag_data_ready = true;
                    result = true;
                } else {
                    debug ("cannot drop here");
                }
            } else if (target != Gdk.Atom.NONE && drag_data == null) {
                /* request the drag data from the source */
                Gtk.drag_get_data (real_view, context, target, timestamp);
            }

            return result;
        }

        private uint drag_enter_timer_id = 0;
        private void check_destination_actions_and_target_file (Gdk.DragContext context, int x, int y, uint timestamp) {
            Gtk.TreePath? path;
            unowned GOF.File? file = abstract_view.get_file_at_pos (x, y, out path);
            string uri = file != null ? file.uri : "";
            string current_uri = drop_target_file != null ? drop_target_file.uri : "";

            if (file != null) {
                if (drag_enter_timer_id > 0) {
                    Source.remove (drag_enter_timer_id);
                    drag_enter_timer_id = 0;
                }

                drop_target_file = file;
                current_actions = Gdk.DragAction.DEFAULT;
                current_suggested_action = Gdk.DragAction.DEFAULT;

                if (file != null) {
                    if (current_target_type == dnd_handler.XDND_DIRECT_SAVE_ATOM ||
                        current_target_type == dnd_handler.RAW_ATOM ||
                        current_target_type == dnd_handler.TEXT_PLAIN_ATOM) {

                        current_suggested_action = Gdk.DragAction.COPY;
                        current_actions = current_suggested_action;
                    } else if (current_target_type == dnd_handler.NETSCAPE_URL_ATOM) {

                        current_suggested_action = Gdk.DragAction.LINK;
                        current_actions = current_suggested_action;
                    } else {
                        current_actions = PF.FileUtils.file_accepts_drop (drop_target_file,
                                                                          drag_file_list,
                                                                          context,
                                                                          out current_suggested_action);
                    }

                    abstract_view.highlight_drop_file (drop_target_file, current_actions, path);

                    if (file.is_folder () && is_valid_drop_folder (file)) {
                        /* open the target folder after a short delay */
                        drag_enter_timer_id = GLib.Timeout.add_full (GLib.Priority.LOW,
                                                                     1000,
                                                                     () => {
                            if (drag_in_progress) { /* drag could end during timeout */
                                abstract_view.load_location (file.get_target_location ());
                            }

                            drag_enter_timer_id = 0;
                            return Source.REMOVE;
                        });
                    }
                }
            }
        }

        private bool is_valid_drop_folder (GOF.File file) {
            /* Cannot drop a file onto its parent or onto itself */
            if (file.uri != abstract_view.slot.uri &&
                drag_file_list != null &&
                drag_file_list.index (file.location) < 0) {

                return true;
            } else {
                return false;
            }
        }

        private uint drag_scroll_timer_id = 0;
        public void start_drag_scroll_timer (Gdk.DragContext context) {
            drag_scroll_timer_id = GLib.Timeout.add_full (GLib.Priority.LOW,
                                                          50,
                                                          () => {

                Gdk.Device pointer = context.get_device ();
                Gdk.Window? window = real_view != null ? real_view.get_window () : null;
                int x, y;

                if (window != null && pointer != null) {
                    window.get_device_position (pointer, out x, out y, null);
                    abstract_view.scroll_window_near_edge (window, x, y);
                }

                if (drag_in_progress) {
                    return Source.CONTINUE;
                } else {
                    drag_scroll_timer_id = 0;
                    return Source.REMOVE;
                }
            });
        }
    }
}
