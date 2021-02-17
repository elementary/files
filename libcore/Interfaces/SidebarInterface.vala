/***
    Copyright 2020 elementary Inc. <https://elementary.io>

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
    [CCode (has_target = false)]
    public delegate void SidebarCallbackFunc (Gtk.Widget widget);

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
}

public interface Marlin.SidebarInterface : Gtk.Widget {
        /* Plugin interface */
        public abstract uint32 add_plugin_item (Marlin.SidebarPluginItem item, Marlin.PlaceType category);
        public abstract bool update_plugin_item (Marlin.SidebarPluginItem item, uint32 item_id);
        public abstract bool remove_item_by_id (uint32 item_id); //Returns true if successfully removed
        /* Window interface */
        public signal void request_update ();
        public signal bool request_focus ();
        public signal void sync_needed ();
        public signal void path_change_request (string uri, Marlin.OpenFlag flag);
        public signal void connect_server_request ();
        public abstract void add_favorite_uri (string uri, string? label = null);
        public abstract bool has_favorite_uri (string uri);
        public abstract void sync_uri (string uri);
        public abstract void reload ();
        public abstract void on_free_space_change ();
}
