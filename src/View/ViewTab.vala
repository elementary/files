/***
    Copyright (c) 2017 elementary LLC (https://elementary.io)

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation, Inc.,.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/

namespace Marlin.View {
    public class ViewTab : Granite.Widgets.Tab {

        public ViewContainer content {
            get {
                return (ViewContainer)page;
            }
        }

        public string uri {
            get {
                return content.uri;
            }
        }

        public string basename {
            get {
                return content.tab_name;
            }
        }

        public Marlin.ViewMode mode {
            set {
                content.view_mode = value;
            }

            get {
                return content.view_mode;
            }
        }

        public GLib.File location {

            set {
                if (mode != Marlin.ViewMode.INVALID) {
                    content.location = value; /* Creates slot if necessary */
                }
            }

            get {
                return content.location;
            }
       }

        public signal void check_for_tab_with_same_name ();
        public signal void updated ();

        public ViewTab (Marlin.View.Window parent) {
            base ("", null, null);

            page = new  ViewContainer (parent);
            connect_content_signals ();
        }

        private void connect_content_signals () {
            content.tab_name_changed.connect (on_content_tab_name_change);
            content.loading.connect (on_content_loading);
            content.active.connect (on_content_active);
        }

        private void on_content_tab_name_change (string tab_name) {
            label = tab_name;
            check_for_tab_with_same_name (); /* Handle this to disambiguate name if required */
            this.set_tooltip_text (uri);
        }

        private void on_content_loading (bool is_loading) {
            working = is_loading;
            updated ();
        }

        private void on_content_active () {
            updated ();
        }

        public new void close () {
            content.close ();
            base.close ();
        }
    }
}
