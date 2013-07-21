/*
 * Copyright (C) 2011 Elementary Developers
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
 *
 * Author: ammonkey <am.monkeyd@gmail.com>
 */

/* Just a workarround Gtk.Entry which got a minimum fixed prefered width.
   With XsEntry we can set the exact width we want */
public class Granite.Widgets.XsEntry : Gtk.Entry {
    public int m_default_with = 25;

    public XsEntry () {
        width_request = m_default_with;
    }

    public override void get_preferred_width (out int minimum_width, out int natural_width) {
        if (width_request >= m_default_with)
            minimum_width = natural_width = width_request;
        else
            minimum_width = natural_width = m_default_with;
    }
}
