/* Copyright (c) 2022 elementary LLC (https://elementary.io)
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


public class Files.GridFileItem : Gtk.Widget, Files.FileItemInterface {
    private static Gtk.CssProvider fileitem_provider;
    private static Files.Preferences prefs;

    static construct {
        set_layout_manager_type (typeof (Gtk.BoxLayout));
        set_css_name ("fileitem");
        fileitem_provider = new Gtk.CssProvider ();
        fileitem_provider.load_from_resource ("/io/elementary/files/GridViewFileItem.css");
        prefs = Files.Preferences.get_default ();

    }

    private int thumbnail_request = -1;
    private Gtk.Image file_icon;
    private Gtk.Label label;
    private Gtk.CheckButton selection_helper;
    private Gtk.Image[] emblems;
    private Gtk.Box emblem_box;
    private Gtk.Overlay icon_overlay;

    public Files.File? file { get; set; default = null; }
    public ViewInterface view { get; construct; }
    public uint pos { get; set; default = 0; }

    public ZoomLevel zoom_level {
        set {
            var size = value.to_icon_size ();
            file_icon.pixel_size = size;
            if (file != null) {
                update_pix ();
            }
        }
    }

    public bool selected { get; set; default = false; }
    public bool cut_pending { get; set; default = false; }
    public bool drop_pending {
        get {
            return file != null ? file.drop_pending : false;
        }

        set {
            if (file != null) {
                file.drop_pending = value;
                update_pix ();
            }
        }
    }

    public GridFileItem (ViewInterface view) {
        Object (
            view: view
        );
    }

    construct {
        var lm = new Gtk.BoxLayout (
            view.slot.view_mode == ViewMode.MULTICOLUMN ?
            Gtk.Orientation.HORIZONTAL :
            Gtk.Orientation.VERTICAL
        );
        set_layout_manager (lm);
        can_target = true;
        get_style_context ().add_provider (
            fileitem_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        if (view.slot.view_mode == ViewMode.ICON) {
            file_icon = new Gtk.Image () {
                margin_end = 8,
                margin_start = 8,
                icon_name = "image-missing" // Shouldnt see this
            };
        } else {
            file_icon = new Gtk.Image () {
                margin_end = 8,
                margin_start = 16,
                icon_name = "image-missing" // Shouldnt see this
            };
        }

        //TODO Apply CSS to selection_helper to get look/size right
        selection_helper = new Gtk.CheckButton () {
            visible = false,
            halign = Gtk.Align.START,
            valign = Gtk.Align.START
        };

        selection_helper.set_css_name ("selection-helper");

        emblems = new Gtk.Image[4];
        emblem_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            halign = Gtk.Align.END,
            valign = Gtk.Align.END
        };
        for (int i = 0; i < 4; i++) {
            emblems[i] = new Gtk.Image () {
                pixel_size = 16,
                visible = false
            };
            emblem_box.prepend (emblems[i]);
        }

        // Spread grid items out a little more than native GridView
        icon_overlay = new Gtk.Overlay () {
            // margin_start = 12,
            // margin_end = 12,
            // margin_bottom = 8
        };
        icon_overlay.child = file_icon;
        icon_overlay.add_overlay (selection_helper);
        icon_overlay.add_overlay (emblem_box);
        icon_overlay.set_parent (this);

        if (view.slot.view_mode == ViewMode.ICON) {
            label = new Gtk.Label ("Unbound") {
                wrap = true,
                wrap_mode = Pango.WrapMode.WORD_CHAR,
                ellipsize = Pango.EllipsizeMode.END,
                lines = 5,
                margin_top = 3,
                margin_bottom = 3,
                margin_start = 3,
                margin_end = 3,
            };
        } else {
            label = new Gtk.Label ("Unbound") {
                wrap = false,
                ellipsize = Pango.EllipsizeMode.END,
                lines = 1,
                margin_top = 3,
                margin_bottom = 3,
                // margin_start = 3,
                // margin_end = 3,
            };
        }
        label.set_parent (this);

        Thumbnailer.@get ().finished.connect (handle_thumbnailer_finished);

        bind_property ("selected", selection_helper, "active", BindingFlags.BIDIRECTIONAL);
        bind_property ("selected", selection_helper, "visible", BindingFlags.DEFAULT);
        notify["selected"].connect (() => {
            if (selected && !has_css_class ("selected")) {
                add_css_class ("selected");
            } else if (!selected && has_css_class ("selected")) {
                remove_css_class ("selected");
            }

            if (file != null) {
                view.show_and_select_file (file, selection_helper.active, false, false);
            }

        });

        var motion_controller = new Gtk.EventControllerMotion ();
        motion_controller.enter.connect (() => {
            selection_helper.visible = true;
        });
        motion_controller.leave.connect (() => {
            selection_helper.visible = selected;
        });
        add_controller (motion_controller);

        //Handle focus events to change appearance when has focus (but not selected)
        focusable = true;
        var focus_controller = new Gtk.EventControllerFocus ();
        focus_controller.enter.connect (() => {
            if (!has_css_class ("focussed")) {
                add_css_class ("focussed");
            }
        });
        focus_controller.leave.connect (() => {
            if (has_css_class ("focussed")) {
                remove_css_class ("focussed");
            }
        });
        add_controller (focus_controller);
    }

    public void bind_file (Files.File? new_file) {
        var old_file = file;
        file = new_file;
        //Assume that item will not be bound without being unbound first
        if (file == null) {
            label.label = "Unbound";
            file_icon.paintable = null;
            file_icon.set_from_icon_name ("image-missing");
            thumbnail_request = -1;
            drop_pending = false;
            selected = false;
            cut_pending = false;

            return;
        }

        file.ensure_query_info ();
        label.label = file.custom_display_name ?? file.basename;
        if (file.paintable == null) {
            if (file.thumbstate == Files.File.ThumbState.UNKNOWN &&
                (prefs.show_remote_thumbnails || !file.is_remote_uri_scheme ()) &&
                !prefs.hide_local_thumbnails) { // Also hide remote if local hidden?
                    Thumbnailer.@get ().queue_file (
                        file, out thumbnail_request, file_icon.pixel_size > 128
                    );
            }
        }

        var cut_pending = ClipboardManager.get_instance ().has_cut_file (file);
        if (cut_pending && !has_css_class ("cut")) {
            add_css_class ("cut");
        } else if (!cut_pending && has_css_class ("cut")) {
            remove_css_class ("cut");
        }

        update_pix ();
    }

    private void update_pix () requires (file != null) {
        file.update_gicon_and_paintable ();
        if (file.paintable != null) {
            file_icon.set_from_paintable (file.paintable);
        } else {
            if (file.gicon != null) {
                file_icon.set_from_gicon (file.gicon);
            } else {
                critical ("File %s has neither paintable nor gicon", file.uri);
                file_icon.set_from_icon_name ("dialog-error");
            }
        }

        foreach (var emblem in emblems) {
            emblem.visible = false;
        }
        int index = 0;
        foreach (string emblem in file.emblems_list) {
            emblems[index].icon_name = emblem;
            emblems[index].visible = true;
            index++;
        }

        file_icon.queue_draw ();
    }

    private void handle_thumbnailer_finished (uint req) {
        if (req == thumbnail_request && file != null) {
            // Thumbnailer has already updated the file thumbnail path and state
            thumbnail_request = -1;
            bind_file (file);
        }
    }

    public Gdk.Paintable get_paintable_for_drag () {
        return new Gtk.WidgetPaintable (file_icon);
    }

    ~GridFileItem () {
        Thumbnailer.@get ().finished.disconnect (handle_thumbnailer_finished);
        while (this.get_last_child () != null) {
            this.get_last_child ().unparent ();
        }
    }
}
