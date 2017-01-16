/*
* Copyright (c) 2016 elementary LLC. (http://launchpad.net/pantheon-files)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 59 Temple Place - Suite 330,
* Boston, MA 02111-1307, USA.
*/

public class HeaderLabel : Gtk.Label {
    public HeaderLabel (string label) {
        Object (halign: Gtk.Align.START, label: label);
    }

    construct {
        get_style_context ().add_class ("h4");
    }
}

public class KeyLabel : Gtk.Label {
    public KeyLabel (string label) {
        Object (halign: Gtk.Align.END, label: label, margin_start: 12);
    }
}

public class ValueLabel : Gtk.Label {
    public ValueLabel (string label) {
        Object (can_focus: true,
                halign: Gtk.Align.START,
                label: label, selectable: true,
                use_markup: true
        );
    }
}
