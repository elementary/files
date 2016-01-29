/***
    Copyright (c) 2016 Elementary Developers

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at your option)
    any later version.

    This program is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
    FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
    more details.

    You should have received a copy of the GNU General Public License along with
    this program; if not, write to the Free Software Foundation, Inc., 59 Temple
    Place, Suite 330, Boston, MA  02111-1307  USA

    Authors : Jeremy Wootten <jeremy@elementaryos.org>

    Some convenience wrappers around libcanberra for using sounds within pantheon-files.
 
 ***/

namespace PF {
    public class Sounds : GLib.Object {
        private static Sounds? instance = null;
        public static Sounds get_instance () {
            if (instance == null) {
                instance = new Sounds ();
            }
            return instance;
        }

        unowned Canberra.Context ca_context;

        private Sounds () {
            ca_context = CanberraGtk.context_get ();
            ca_context.change_props (Canberra.PROP_APPLICATION_NAME, Marlin.APP_TITLE,
                                     Canberra.PROP_APPLICATION_ID, Marlin.APP_ID,
                                     Canberra.PROP_APPLICATION_ICON_NAME, Marlin.ICON_ABOUT_LOGO);
            ca_context.open ();
        }

        public void play_trash_sound () {
            ca_context.play (0, Canberra.PROP_EVENT_ID, Marlin.SOUND_TRASH);
        }
        public void play_delete_sound () {
            ca_context.play (0, Canberra.PROP_EVENT_ID, Marlin.SOUND_DELETE);
        }
        public void play_trash_empty_sound () {
            ca_context.play (0, Canberra.PROP_EVENT_ID, Marlin.SOUND_TRASH_EMPTY);
        }
        public void play_open_window_sound () {
            ca_context.play (0, Canberra.PROP_EVENT_ID, Marlin.SOUND_OPEN_WINDOW);
        }
        public void play_sound (string marlin_sound_id) {
            ca_context.play (0, Canberra.PROP_EVENT_ID, marlin_sound_id);
        }
    }
}
