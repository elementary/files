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

namespace Files {
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

public interface Files.SidebarInterface : Gtk.Widget {
        /* Plugin interface */
        public abstract uint32 add_plugin_item (Files.SidebarPluginItem item, Files.PlaceType category);
        public abstract bool update_plugin_item (Files.SidebarPluginItem item, uint32 item_id);
        /* Window interface */
        public signal bool request_focus ();
        public signal void sync_needed ();
        public signal void path_change_request (string uri, Files.OpenFlag flag);
        public abstract void add_favorite_uri (string uri, string custom_name = "");
        public abstract bool has_favorite_uri (string uri);
        public abstract void sync_uri (string uri);
        public abstract void reload ();
        public abstract void on_free_space_change ();
        public abstract void focus ();
}
