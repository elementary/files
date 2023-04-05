/***
    Copyright (c) 2016-2018 elementary LLC <https://elementary.io>

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at your option)
    any later version.

    This program is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
    FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
    more details.

    You should have received a copy of the GNU General Public License along with
    this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street,
    Fifth Floor Boston, MA 02110-1335 USA.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>

    Some convenience wrappers around libcanberra for using sounds within io.elementary.files.

 ***/

namespace PF {

    public class SoundManager : GLib.Object {
        private static SoundManager? instance = null;
        private static Settings sound_settings;
        public static unowned SoundManager get_instance () {
            if (instance == null) {
                instance = new SoundManager ();
            }

            return instance;
        }

        Canberra.Context? ca_context;

        static construct {
            sound_settings = new Settings ("org.gnome.desktop.sound");
        }

        private SoundManager () {
            ca_context = null;
            Canberra.Context.create (out ca_context);
            if (ca_context != null) {
                ca_context.change_props (Canberra.PROP_APPLICATION_NAME, _(PF.Sound.APP_TITLE),
                                         Canberra.PROP_APPLICATION_ID, PF.Sound.APP_ID,
                                         Canberra.PROP_APPLICATION_ICON_NAME, PF.Sound.APP_LOGO);
                ca_context.open ();
            }
        }

        public void play_delete_sound () {
            play_sound (PF.Sound.DELETE);
        }
        public void play_empty_trash_sound () {
            play_sound (PF.Sound.EMPTY_TRASH);
        }
        public void play_sound (string pf_sound_id) {
            if (ca_context == null) {
                return;
            }

            if (sound_settings.get_boolean ("event-sounds")) {
                ca_context.play (0, Canberra.PROP_EVENT_ID, pf_sound_id);
            }
        }
    }

    namespace Sound {
        const string APP_TITLE = "Files";
        const string APP_ID = "io.elementary.files4";
        const string APP_LOGO = "system-file-manager";
        public const string THEME = "freedesktop";
        public const string DELETE = "trash-empty";
        public const string EMPTY_TRASH = "trash-empty";
    }
}
