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

    //TODO Make private so layout fixed?
    protected Gtk.Box extra_location_widgets;
    protected Gtk.Box extra_action_widgets;
    protected Gtk.Grid content_box;
    protected Gtk.Paned side_widget_box;

    public Gtk.Overlay overlay { get; protected set; }
    public int slot_number { get; protected set; }
    protected int width;

    public signal void active (bool scroll = true, bool animate = true);
    public signal void inactive ();
    public signal void path_changed ();
    public signal void new_container_request (GLib.File loc, Files.OpenFlag flag);
    public signal void selection_changed (GLib.List<Files.File> files);
    public signal void directory_loaded (Files.Directory dir);

    public void add_extra_widget (Gtk.Widget widget) {
        extra_location_widgets.add (widget);
    }

    public void add_extra_action_widget (Gtk.Widget widget) {
        // Used for e.g. trash plugin actionbar
        extra_action_widgets.add (widget);
    }

    public void add_overlay_widget (Gtk.Widget widget) {
        overlay.child = widget;
    }

    protected void add_side_widget (Gtk.Widget widget, bool resize, bool shrink) {
        side_widget_box.pack2 (widget, resize, shrink);
    }

    construct {
        content_box = new Gtk.Grid () {
            vexpand = true,
            hexpand = true
        };

        overlay = new Gtk.Overlay () {
            hexpand = true,
            vexpand = true,
        };

        side_widget_box = new Gtk.Paned (HORIZONTAL);

        extra_action_widgets = new Gtk.Box (VERTICAL, 0);
        content_box.attach (extra_action_widgets, 0, 0);
        content_box.attach (overlay, 0, 1);

        side_widget_box.pack1 (content_box, true, true);
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
    public abstract void close ();
    public abstract FileInfo? lookup_file_info (GLib.File loc);

    public virtual void zoom_out () {}
    public virtual void zoom_in () {}
    public virtual void zoom_normal () {}
    public virtual bool set_all_selected (bool all_selected) { return false; }
    public virtual Gtk.Widget get_content_box () { return side_widget_box as Gtk.Widget; }
    public virtual string? get_root_uri () { return directory.file.uri; }
    public virtual string? get_tip_uri () { return null; }
    public virtual bool get_realized () { return side_widget_box.get_realized (); }
}
