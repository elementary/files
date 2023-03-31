/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later

 * Authored by: Jeremy Wootten <jeremy@elementaryos.org>
*/

namespace Files {
    /* Interface implemented by BasicBreadcrumbsEntry and BreadCrumbsEntry */
    public interface Navigatable : Gtk.Widget {
        public abstract string? action_icon_name { get; set; }
        public abstract bool hide_breadcrumbs { get; set; default = false; }

        public signal void entry_text_changed (string txt);
        public signal void activate_path (string path, Files.OpenFlag flag = Files.OpenFlag.DEFAULT);
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
