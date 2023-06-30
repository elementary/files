/***
    Copyright (c) 2015-2022 elementary LLC <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation, Inc.,.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Lucas Baudin <xapantu@gmail.com>
              Jeremy Wootten <jeremy@elementaryos.org>
***/

namespace Files {
    public abstract class AbstractSlot : GLib.Object {
        Files.Directory _directory;
        public Files.Directory? directory {
            get {
                AbstractSlot? current = get_current_slot ();
                if (current != null) {
                    return current._directory;
                } else {
                    return null;
                }
            }

            protected set {_directory = value;}
        }

        // Directory may be destroyed before the slot so handle case that it is null
        public Files.File? file {
            get { return directory != null ? directory.file : null;}
        }
        public GLib.File? location {
            get { return directory != null ? directory.location : null;}
        }
        public string uri {
            get { return directory != null ? directory.file.uri : ""; }
        }

        public virtual bool locked_focus {
            get {
                return false;
            }
        }

        public virtual bool is_frozen {get; set; default = true;}

        protected Gtk.Box extra_location_widgets;
        protected Gtk.Box extra_action_widgets;
        protected Gtk.Box content_box;
        public Gtk.Overlay overlay {get; protected set;}
        public int slot_number { get; protected set; }
        protected int width;

        public signal void active (bool scroll = true, bool animate = true);
        public signal void inactive ();
        public signal void path_changed ();
        public signal void new_container_request (GLib.File loc, Files.OpenFlag flag);
        public signal void selection_changed (GLib.List<Files.File> files);
        public signal void directory_loaded (Files.Directory dir);

        public void add_extra_widget (Gtk.Widget widget) {
            extra_location_widgets.prepend (widget);
        }

        public void add_extra_action_widget (Gtk.Widget widget) {
            extra_action_widgets.prepend (widget);
        }

        public void add_overlay (Gtk.Widget widget) {
            overlay = new Gtk.Overlay () {
                child = widget
            };
            content_box.prepend (overlay);
            overlay.child = widget;
        }

        construct {
            content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                vexpand = true,
                hexpand = true
            };

            extra_location_widgets = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content_box.prepend (extra_location_widgets);

            extra_action_widgets = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content_box.append (extra_action_widgets);
            slot_number = -1;
        }

        public abstract void initialize_directory ();
        public abstract unowned GLib.List<Files.File>? get_selected_files ();
        public abstract void set_active_state (bool set_active, bool animate = true);
        public abstract unowned AbstractSlot? get_current_slot ();
        public abstract void reload (bool non_local_only = false);
        public abstract void grab_focus ();
        public abstract void user_path_change_request (GLib.File loc, bool make_root);

        public abstract void focus_first_for_empty_selection (bool select);
        public abstract void select_glib_files (GLib.List<GLib.File> locations, GLib.File? focus_location);
        protected abstract void make_view ();
        public abstract void close ();
        public abstract FileInfo? lookup_file_info (GLib.File loc);

        public virtual void zoom_out () {}
        public virtual void zoom_in () {}
        public virtual void zoom_normal () {}
        public virtual bool set_all_selected (bool all_selected) {return false;}
        public virtual Gtk.Widget get_content_box () {
            return content_box as Gtk.Widget;
        }
        public virtual string? get_root_uri () {return directory.file.uri;}
        public virtual string? get_tip_uri () {return null;}
        public virtual bool get_realized () {return content_box.get_realized ();}

    }
}
