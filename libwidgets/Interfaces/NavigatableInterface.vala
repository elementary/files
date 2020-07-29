/***
    Copyright (c) 2015-2018 elementary LLC <https://elementary.io>

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
namespace Marlin.View.Chrome {
    /* Interface implemented by BasicBreadcrumbsEntry and BreadCrumbsEntry */
    public interface Navigatable : Gtk.Widget {
        public abstract string? action_icon_name { get; set; }
        public abstract bool hide_breadcrumbs { get; set; default = false; }

        public signal void entry_text_changed (string txt);
        public signal void activate_path (string path, Marlin.OpenFlag flag = Marlin.OpenFlag.DEFAULT);
        public signal void action_icon_press ();
        public signal void primary_icon_press ();

        public abstract void set_breadcrumbs_path (string newpath);
        public abstract string get_breadcrumbs_path (bool include_file_protocol = true);

        public abstract void set_action_icon_tooltip (string? tip);
        public abstract void hide_action_icon ();

        public abstract void set_entry_text (string? txt);
        public abstract void reset ();

        public virtual void set_animation_visible (bool visible) {}
        /*Note: This is not the same as the Gtk.Entry placeholder_text */
        public abstract void set_placeholder (string placeholder);
        public abstract void show_default_action_icon ();
        public abstract void set_default_action_icon_tooltip ();

        public abstract string get_entry_text ();
        public abstract int get_minimum_width ();

        protected abstract void set_default_entry_tooltip ();
    }
}
