/*  
 * Copyright (C) 2011 ammonkey <am.monkeyd@gmail.com>
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */ 

namespace Varka {

    public static IconFactory? icon_factory = null;

    public class IconFactory : GLib.Object {

        private Gtk.IconTheme icon_theme;

        public class IconFactory () {
            icon_theme = Gtk.IconTheme.get_default ();
        }

        public static IconFactory get_default () {
            if (icon_factory != null)
                return icon_factory;

            icon_factory = new IconFactory ();
            return icon_factory;
        }

        public Gdk.Pixbuf? load_symbolic_icon (Gtk.StyleContext style, string iconname, int size) {
            Gdk.Pixbuf px = null;

            ThemedIcon themed_icon = new ThemedIcon.with_default_fallbacks (iconname);
            Gtk.IconInfo icon_info = icon_theme.lookup_by_gicon ((GLib.Icon) themed_icon, size, Gtk.IconLookupFlags.GENERIC_FALLBACK);
            try {
                px = icon_info.load_symbolic_for_context (style);
            } catch (Error err) {
                stderr.printf ("Unable to load symbolic icon: %s", err.message);
            }

            return px;
        }
    
    }
}
