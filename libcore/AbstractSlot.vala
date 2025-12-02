/*
 * SPDX-FileCopyrightText: 2015-2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors : Lucas Baudin <xapantu@gmail.com>
 *           Jeremy Wootten <jeremywootten@gmail.com>
 */

public abstract class Files.AbstractSlot : GLib.Object {
    private Files.Directory _directory;
    public Files.Directory? directory {
        get {
            AbstractSlot? current = get_current_slot ();
            if (current != null) {
                return current._directory;
            } else {
                return null;
            }
        }

        protected set { _directory = value; }
    }

    // Directory may be destroyed before the slot so handle case that it is null
    public Files.File? file {
        get { return directory != null ? directory.file : null; }
    }

    public GLib.File? location {
        get {
            return directory != null ? directory.location : null;
        }

        set construct {
            // if (value != null) {
                directory = Directory.from_gfile (value);

        }
    }

    public string uri {
        get { return directory != null ? directory.file.uri : ""; }
    }

    public virtual bool locked_focus {
      get { return false; }
    }

    public virtual bool is_frozen { get; set; default = true; }

    protected Gtk.Box extra_location_widgets;
    protected Gtk.Box extra_action_widgets;
    protected Gtk.Box content_box;
    public Gtk.Overlay overlay { get; protected set; }
    public int slot_number { get; protected set; }
    protected int width;

    public signal void active (bool scroll = true, bool animate = true);
    public signal void inactive ();
    public signal void path_changed ();
    public signal void new_container_request (GLib.File loc, Files.OpenFlag flag);
    public signal void selection_changed (GLib.List<Files.File> files);
    public signal void directory_loaded (Files.Directory dir);
    public signal void file_activated ();

    public void add_extra_widget (Gtk.Widget widget) {
        extra_location_widgets.add (widget);
    }

    public void add_extra_action_widget (Gtk.Widget widget) {
        extra_action_widgets.add (widget);
    }

    public void add_overlay (Gtk.Widget widget) {
        overlay = new Gtk.Overlay () {
            hexpand = true,
            vexpand = true,
            child = widget
        };
        content_box.add (overlay);
    }

    construct {
        content_box = new Gtk.Box (VERTICAL, 0) {
            vexpand = true,
            hexpand = true
        };

        extra_location_widgets = new Gtk.Box (VERTICAL, 0);
        content_box.add (extra_location_widgets);

        extra_action_widgets = new Gtk.Box (VERTICAL, 0);
        content_box.add (extra_action_widgets);
        slot_number = -1;
    }

    public abstract void initialize_directory ();
    public abstract unowned GLib.List<Files.File>? get_selected_files ();
    public abstract void set_active_state (bool set_active, bool animate = true);
    public abstract unowned AbstractSlot? get_current_slot ();
    public abstract void reload (bool non_local_only = false);
    public abstract void grab_focus ();
    public abstract void user_path_change_request (GLib.File loc, bool make_root = true);
    public abstract void focus_first_for_empty_selection (bool select);
    public abstract void select_glib_files (GLib.List<GLib.File> locations, GLib.File? focus_location);
    public abstract void close ();
    public abstract FileInfo? lookup_file_info (GLib.File loc);

    public virtual void zoom_out () {}
    public virtual void zoom_in () {}
    public virtual void zoom_normal () {}
    public virtual bool set_all_selected (bool all_selected) { return false; }
    public virtual Gtk.Widget get_content_box () { return content_box as Gtk.Widget; }
    public virtual string? get_root_uri () { return directory.file.uri; }
    public virtual string? get_tip_uri () { return null; }
    public virtual bool get_realized () { return content_box.get_realized (); }
}
