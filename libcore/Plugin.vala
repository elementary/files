/* Copyright (c) 2015-2018 elementary LLC <https://elementary.io>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, Inc.,; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

public abstract class Files.Plugins.Base {
    public virtual void directory_loaded (Files.SlotContainerInterface multi_slot, Files.File directory) { }
    public virtual void context_menu (Gtk.Widget widget, List<Files.File> files) { }
    public virtual void sidebar_loaded (Gtk.Widget widget) { }
    public virtual void update_sidebar (Gtk.Widget widget) { }
    public virtual void update_file_info (Files.File file) { }

    public Gtk.Widget window;

    public void interface_loaded (Gtk.Widget widget) {
        window = widget;
    }
}
