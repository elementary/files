/***
  Copyright (C) 2014 elementary Developers and Jeremy Wootten

  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE. See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program. If not, see <http://www.gnu.org/licenses/>.

 Authors : Lucas Baudin <xapantu@gmail.com>
           Jeremy Wootten <jeremywootten@gmail.com>
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
            EJECT,
            NO_EJECT,
            BOOKMARK,
            TOOLTIP,
            EJECT_ICON,
            SHOW_SPINNER,
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
                                        typeof (bool),              /* eject */
                                        typeof (bool),              /* no eject */
                                        typeof (bool),              /* is bookmark */
                                        typeof (string),            /* tool tip */
                                        typeof (Icon),              /* Action icon (e.g. eject button) */
                                        typeof (bool),              /* Show spinner */
                                        typeof (uint),              /* Spinner pulse */
                                        typeof (uint64),            /* Free space */
                                        typeof (uint64),             /* For disks, total size */
                                        typeof (Marlin.PluginCallbackFunc)
                                        );

            content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            this.add (content_box);
            content_box.show_all ();
        }

        public void add_extra_item (string text) {
            Gtk.TreeIter iter;
            store.append (out iter, null);
            store.set (iter,
                       Column.ICON, null,
                       Column.NAME, text,
                       Column.URI, "test://",
                       -1);

        }

        public void add_extra_network_item (string text, Icon? icon, Marlin.PluginCallbackFunc? cb) {
            Gtk.TreeIter iter;
            store.get_iter (out iter, network_category_reference.get_path ());
            iter = add_place (PlaceType.PLUGIN_ITEM,
                             iter,
                             _("Connect server"),
                             icon,
                             null,
                             null,
                             null,
                             null,
                             0,
                             _("Connect to a network file server"));
            if (cb != null)
                store.@set (iter, Column.PLUGIN_CALLBACK, cb);

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
                                                  string tooltip) ;
    }
}
