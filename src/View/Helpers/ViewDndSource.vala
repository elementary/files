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
    public class ViewDndSource : GLib.Object {
        public unowned FM.AbstractDirectoryView abstract_view { get; construct; }
        public unowned Gtk.Widget real_view { get; construct; }
        public Marlin.DndHandler dnd_handler { get; construct; }


        private bool drag_has_begun = false;
        private bool drop_occurred  = false;
        private GLib.List<GOF.File> drag_file_list = null;

        const Gtk.TargetEntry [] drag_targets = {
            {TEXT_PLAIN, Gtk.TargetFlags.SAME_APP, Marlin.TargetType.TEXT_PLAIN},
            {TEXT_URI_LIST, Gtk.TargetFlags.SAME_APP, Marlin.TargetType.TEXT_URI_LIST}
        };

        const Gdk.DragAction file_drag_actions = (Gdk.DragAction.COPY | Gdk.DragAction.MOVE | Gdk.DragAction.LINK);

        public signal void timed_out ();

        construct {
            dnd_handler = new Marlin.DndHandler ();
            /* Set up as drag source */
            Gtk.drag_source_set (real_view, Gdk.ModifierType.BUTTON1_MASK, drag_targets, file_drag_actions);
            real_view.drag_begin.connect (on_drag_begin);
            real_view.drag_data_get.connect (on_drag_data_get);
            real_view.drag_data_delete.connect (on_drag_data_delete);
            real_view.drag_end.connect (on_drag_end);
        }

        public ViewDndSource (FM.AbstractDirectoryView adv, Gtk.Widget view) {
            Object (
                abstract_view: adv,
                real_view: view
            );
        }

        public void begin_drag (int drag_button, Gdk.Event event) {
warning ("gegin drag");
                var target_list = new Gtk.TargetList (drag_targets);
                var actions = file_drag_actions;

                if (drag_button == Gdk.BUTTON_SECONDARY) {
                    actions |= Gdk.DragAction.ASK;
                }

                Gtk.drag_begin_with_coordinates (real_view,
                                                 target_list,
                                                 actions,
                                                 drag_button,
                                                 event,
                                                 -1, -1);
        }

        private void on_drag_begin (Gdk.DragContext context) {
warning ("on drag begin");
        }

        private void on_drag_data_get (Gdk.DragContext context,
                                       Gtk.SelectionData selection_data,
                                       uint info,
                                       uint timestamp) {

            /* get file list only once in case view changes location automatically
             * while dragging (which loses file selection).
             */

            if (drag_file_list == null) {
                foreach (GOF.File gof in abstract_view.get_selected_files ()) {
                    drag_file_list.prepend (gof);
                }

                if (drag_file_list == null) {
                    return;
                }
            }


            GOF.File file = drag_file_list.first ().data;

            if (file != null && file.pix != null) {
                Gtk.drag_set_icon_gicon (context, file.pix, 0, 0);
            } else {
                Gtk.drag_set_icon_name (context, "stock-file", 0, 0);
            }

warning ("setting selection data");
            Marlin.DndHandler.set_selection_data_from_file_list (selection_data, drag_file_list);
        }

        private void on_drag_data_delete (Gdk.DragContext  context) {
warning ("source on drag fata delete");
        }

        private void on_drag_end (Gdk.DragContext  context) {
warning ("drag end");
//            on_drag_leave ();
            drag_has_begun = false;
            drop_occurred = false;
        }


    }
}
