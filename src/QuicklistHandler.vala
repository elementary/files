/***
    Copyright (c) 2012 Canonical
    Copyright (c) 2013 Julián Unrrein <junrrein@gmail.com>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.
***/

namespace Marlin {

#if HAVE_UNITY
    public class LauncherEntry : Object {
        public Unity.LauncherEntry entry;
        public List<Dbusmenu.Menuitem> bookmark_quicklists = null;
        public List<Dbusmenu.Menuitem> progress_quicklists = null;
    }

    private QuicklistHandler quicklisthandler_singleton = null;

    public class QuicklistHandler : Object {

        public List<Marlin.LauncherEntry> launcher_entries = null;

        private QuicklistHandler () {
            this.entry_add (Marlin.APP_DESKTOP);

            if (this.launcher_entries.length () == 0) { //Can be assumed to be limited in length.
                error ("Couldn't find a valid Unity launcher entry.");
            } else {
                var bookmarks = Marlin.BookmarkList.get_instance ();

                bookmarks.contents_changed.connect (() => {
                    debug ("Refreshing Unity dynamic bookmarks.");
                    this.remove_bookmark_quicklists ();
                    this.load_bookmarks (bookmarks);
                });
            }
        }

        public static unowned QuicklistHandler get_singleton () {
            if (quicklisthandler_singleton == null) {
                quicklisthandler_singleton = new QuicklistHandler ();
            }

            return quicklisthandler_singleton;
        }

        private void entry_add (string entry_id) {
            var unity_lentry = Unity.LauncherEntry.get_for_desktop_id (entry_id);

            if (unity_lentry != null) {
                var marlin_lentry = new Marlin.LauncherEntry ();
                marlin_lentry.entry = unity_lentry;

                this.launcher_entries.prepend (marlin_lentry);

                /* Ensure dynamic quicklist exists */
                Dbusmenu.Menuitem ql = unity_lentry.quicklist;

                if (ql == null) {
                    ql = new Dbusmenu.Menuitem ();
                    unity_lentry.quicklist = ql;
                }
            }
        }

        private void remove_bookmark_quicklists () {
            foreach (var marlin_lentry in this.launcher_entries) {
                var unity_lentry = marlin_lentry.entry;
                Dbusmenu.Menuitem ql = unity_lentry.quicklist;

                if (ql == null) {
                    break;
                }

                foreach (var menuitem in marlin_lentry.bookmark_quicklists) {
                    ql.child_delete (menuitem);
                }

                marlin_lentry.bookmark_quicklists = null;
            }
        }

        private void load_bookmarks (Marlin.BookmarkList bookmarks) {
            var bookmark_count = bookmarks.length (); //Can be assumed to be limited in length

            for (int index = 0; index < bookmark_count; index++) {
                var bookmark = bookmarks.item_at (index);

                if (bookmark.uri_known_not_to_exist ()) {
                    continue;
                }

                foreach (var marlin_lentry in this.launcher_entries) {
                    var unity_lentry = marlin_lentry.entry;
                    Dbusmenu.Menuitem ql = unity_lentry.quicklist;
                    var menuitem = new Dbusmenu.Menuitem ();

                    menuitem.property_set ("label", bookmark.label);
                    menuitem.item_activated.connect (() => {
                        var location = bookmark.get_location ();
                        var app = (Marlin.Application)(GLib.Application.get_default ());
                        app.create_window (location);
                    });

                    ql.child_add_position (menuitem, index);
                    marlin_lentry.bookmark_quicklists.prepend (menuitem);
                }
            }
        }

    }
#endif /* HAVE_UNITY */
}
