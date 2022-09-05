/***
    Copyright (c) 2015-2018 elementary LLC <https://elementary.io>

    Marlin is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License as
    published by the Free Software Foundation; either version 2 of the
    License, or (at your option) any later version.

    Marlin is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    General Public License for more details.

    You should have received a copy of the GNU General Public
    License along with this program; see the file COPYING.  If not,
    write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
    Boston, MA 02110-1335 USA.

    Author(s):  Jeremy Wootten <jeremy@elementaryos.org>

***/

namespace Files.View {
    public class Welcome : Granite.Placeholder {
        //TODO Rework for Granite.Placeholder
        public Welcome (string title, string secondary) {
            base (title);
            // base (primary, secondary);
            // this.button_press_event.connect (on_button_press_event);
            // show_all ();
        }

        //TODO Use EventControllers
        // public bool on_button_press_event (Gdk.EventButton event) {
        //     /* Pass Back and Forward button events to toplevel window */
        //     uint button;
        //     event.get_button (out button);
        //     switch (button) {
        //         case 6:
        //         case 7:
        //         case 8:
        //         case 9:
        //             return get_toplevel ().button_press_event (event);
        //         default:
        //             return base.button_press_event (event);
        //     }
        // }
    }
}
