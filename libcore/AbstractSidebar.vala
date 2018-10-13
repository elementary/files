/***
    Copyright (c) 2015-2018 elementary LLC <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation, Inc.,.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Lucas Baudin <xapantu@gmail.com>
              Jeremy Wootten <jeremy@elementaryos.org>
***/

namespace Marlin {

    public delegate void PluginCallbackFunc (Gtk.Widget widget);
    public enum PlaceType {
        BUILT_IN,
        MOUNTED_VOLUME,
        BOOKMARK,
        BOOKMARKS_CATEGORY,
        PERSONAL_CATEGORY,
        STORAGE_CATEGORY,
        NETWORK_CATEGORY,
        PLUGIN_ITEM
    }

    public abstract class AbstractSidebar : Gtk.ScrolledWindow {
        public enum Column {
            NAME,
            URI,
            DRIVE,
            VOLUME,
            MOUNT,
            ROW_TYPE,
            ICON,
            INDEX,
            CAN_EJECT,
            NO_EJECT,
            BOOKMARK,
            IS_CATEGORY,
            NOT_CATEGORY,
            TOOLTIP,
            ACTION_ICON,
            SHOW_SPINNER,
            SHOW_EJECT,
            SPINNER_PULSE,
            FREE_SPACE,
            DISK_SIZE,
            PLUGIN_CALLBACK,
            COUNT
        }

        protected Gtk.TreeStore store;
        protected Gtk.TreeRowReference network_category_reference;
        protected Gtk.Box content_box;

        protected void init () {
            store = new Gtk.TreeStore (((int)Column.COUNT),
                                        typeof (string),            /* name */
                                        typeof (string),            /* uri */
                                        typeof (Drive),
                                        typeof (Volume),
                                        typeof (Mount),
                                        typeof (int),               /* row type*/
                                        typeof (Icon),              /* Primary icon */
                                        typeof (uint),              /* index*/
                                        typeof (bool),              /* can eject */
                                        typeof (bool),              /* cannot eject */
                                        typeof (bool),              /* is bookmark */
                                        typeof (bool),              /* is category */
                                        typeof (bool),              /* is not category */
                                        typeof (string),            /* tool tip */
                                        typeof (Icon),              /* Action icon (e.g. eject button) */
                                        typeof (bool),              /* Show spinner (not eject button) */
                                        typeof (bool),              /* Show eject button (not spinner) */
                                        typeof (uint),              /* Spinner pulse */
                                        typeof (uint64),            /* Free space */
                                        typeof (uint64),            /* For disks, total size */
                                        typeof (Marlin.PluginCallbackFunc)
                                        );

            content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            this.add (content_box);
            content_box.show_all ();
        }

        public void add_extra_network_item (string text, string tooltip,
                                            Icon? icon, Marlin.PluginCallbackFunc? cb) {

            add_extra_item (network_category_reference, text, tooltip, icon, cb);
        }


        public void add_extra_item (Gtk.TreeRowReference category, string text, string tooltip, Icon? icon,
                                    Marlin.PluginCallbackFunc? cb, Icon? action_icon = null) {
            Gtk.TreeIter iter;
            store.get_iter (out iter, category.get_path ());
            iter = add_place (PlaceType.PLUGIN_ITEM,
                             iter,
                             text,
                             icon,
                             null,
                             null,
                             null,
                             null,
                             0,
                             tooltip,
                             action_icon);
            if (cb != null) {
                store.@set (iter, Column.PLUGIN_CALLBACK, cb);
            }
        }

       protected abstract Gtk.TreeIter add_place (Marlin.PlaceType place_type,
                                                  Gtk.TreeIter? parent,
                                                  string name,
                                                  Icon? icon,
                                                  string? uri,
                                                  Drive? drive,
                                                  Volume? volume,
                                                  Mount? mount,
                                                  uint index,
                                                  string? tooltip = null,
                                                  Icon? action_icon = null) ;
    }
}
