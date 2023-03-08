/* Copyright (c) 2023 elementary LLC (https://elementary.io)
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
    private Gtk.CssProvider label_provider;
    private string tag_color = "";
    private Gtk.CheckButton selection_helper;
    private Gtk.Image[] emblems;
    private Gtk.Box emblem_box;
    private Gtk.Overlay icon_overlay;

    public Files.File? file { get; set; default = null; }
    public bool is_dummy { get; set; default = false; }

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
        var is_multicolumn = view.slot.view_mode != ViewMode.ICON;
        var lm = new Gtk.BoxLayout (
            is_multicolumn ? Gtk.Orientation.HORIZONTAL : Gtk.Orientation.VERTICAL
        );
        set_layout_manager (lm);
        can_target = true;
        get_style_context ().add_provider (
            fileitem_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
        if (is_multicolumn) {
            hexpand = true;
            vexpand = true;
            file_icon = new Gtk.Image () {
                margin_end = 8,
                margin_start = 8,
                valign = Gtk.Align.CENTER,
                icon_name = "image-missing" // Shouldnt see this
            };
            label = new Gtk.Label ("Unbound") {
                wrap = false,
                ellipsize = Pango.EllipsizeMode.END,
                lines = 1,
                margin_start = 3,
                margin_end = 3,
                vexpand = true,
                hexpand = false
            };
            emblem_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                halign = Gtk.Align.END,
                valign = Gtk.Align.CENTER,
                hexpand = true,
                vexpand = false
            };
        } else {
            file_icon = new Gtk.Image () {
                margin_end = 8,
                margin_start = 16,
                halign = Gtk.Align.CENTER,
                icon_name = "image-missing" // Shouldnt see this
            };
            label = new Gtk.Label ("Unbound") {
                wrap = true,
                wrap_mode = Pango.WrapMode.WORD_CHAR,
                ellipsize = Pango.EllipsizeMode.END,
                lines = 5,
                margin_start = 3,
                margin_end = 3,
                margin_top = 3,
                margin_bottom = 3,
            };
            emblem_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                halign = Gtk.Align.END,
                valign = Gtk.Align.END,
                vexpand = true
            };
        }

        label.get_style_context ().add_provider (
            fileitem_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
        );

        //TODO Apply CSS to selection_helper to get look/size right
        selection_helper = new Gtk.CheckButton () {
            visible = false,
            halign = Gtk.Align.START,
            valign = Gtk.Align.START
        };
        selection_helper.set_css_name ("selection-helper");
        selection_helper.toggled.connect (() => {
            // Only synchronise view focus when manually toggled
            // not when changes due to binding to "selected"
            if (file != null && selection_helper.active != selected) {
                if (selection_helper.active) {
                    view.select_and_focus_position (pos, true, false);
                } else {
                    view.unselect_item (pos);
                }
            }
        });

        icon_overlay = new Gtk.Overlay ();
        icon_overlay.child = file_icon;
        icon_overlay.add_overlay (selection_helper);

        emblems = new Gtk.Image[4];
        for (int i = 0; i < 4; i++) {
            emblems[i] = new Gtk.Image () {
                pixel_size = 16,
                visible = false
            };
            emblem_box.prepend (emblems[i]);
        }

        icon_overlay.set_parent (this);
        label.set_parent (this);
        if (is_multicolumn) {
            emblem_box.set_parent (this);
        } else {
            icon_overlay.add_overlay (emblem_box);
        }

        Thumbnailer.@get ().finished.connect (handle_thumbnailer_finished);

        bind_property ("selected", selection_helper, "active", BindingFlags.DEFAULT);
        bind_property ("selected", selection_helper, "visible", BindingFlags.DEFAULT,
            (binding, src_val, ref tgt_val) => {
                tgt_val.set_boolean ((bool)src_val && !is_dummy);
            },
            null
        );
        notify["selected"].connect (() => {
            if (is_dummy) {
                remove_css_class ("selected");
                return;
            }

            if (selected && !has_css_class ("selected")) {
                add_css_class ("selected");
            } else if (!selected && has_css_class ("selected")) {
                remove_css_class ("selected");
            }
        });

        var motion_controller = new Gtk.EventControllerMotion ();
        add_controller (motion_controller);
        motion_controller.enter.connect (() => {
            selection_helper.visible = !is_dummy;
        });
        motion_controller.leave.connect (() => {
            selection_helper.visible = !is_dummy && selected;
        });

        //Handle focus events to change appearance when has focus (but not selected)
        focusable = true;
        var focus_controller = new Gtk.EventControllerFocus ();
        add_controller (focus_controller);
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
    }

    ~GridFileItem () {
        Thumbnailer.@get ().finished.disconnect (handle_thumbnailer_finished);
        while (this.get_last_child () != null) {
            this.get_last_child ().unparent ();
        }
    }

    public void bind_file (Files.File? new_file) {
        var old_file = file;
        file = new_file;
        is_dummy = file.is_dummy;
        file.pix_size = file_icon.pixel_size;
        can_focus = !is_dummy;

        if (is_dummy) {
            label.label = _("(Empty folder)");
            file_icon.paintable = null;
            //Masqerade as parent folder item
            file = new_file.get_data<Files.File> ("parent");
            return;
        }

        file.pix_size = file_icon.pixel_size;
        //Assume that item will not be bound without being unbound first
        if (file == null) {
            label.label = "Unbound";
            file_icon.paintable = null;
            file_icon.set_from_icon_name ("image-missing");
            thumbnail_request = -1;
            drop_pending = false;
            selected = false;
            cut_pending = false;
            old_file.icon_changed.disconnect (update_pix);
            return;
        }

        file.ensure_query_info ();
        label.label = file.custom_display_name ?? file.basename;
        file.icon_changed.connect (update_pix);
        if (file.paintable == null) {
            if (file.thumbstate == Files.File.ThumbState.UNKNOWN &&
                (prefs.show_remote_thumbnails || !file.is_remote_uri_scheme ()) &&
                prefs.show_local_thumbnails) { // Also hide remote if local hidden?
                    Thumbnailer.@get ().queue_file (
                        file, out thumbnail_request, file_icon.pixel_size > 128
                    );
            }

            if (plugins != null) {
                plugins.update_file_info (file);
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
        if (is_dummy) {
            return;
        }

        // If file is local and not hiding local, or file is remote and showing remote,
        // display a thumbnail have one.
        if (file.paintable != null &&
            ((prefs.show_local_thumbnails && view.slot.directory.is_local) ||
            (prefs.show_remote_thumbnails && !view.slot.directory.is_local))) {

            file_icon.set_from_paintable (file.paintable);
        } else if (file.gicon != null) {
            file_icon.set_from_gicon (file.gicon);
        } else {
            critical ("File %s has neither paintable nor gicon", file.uri);
            file_icon.set_from_icon_name ("dialog-error");
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

        if (file.color >= 0 && file.color < Preferences.TAGS_COLORS.length) {
            if (tag_color != "" && label.has_css_class (tag_color)) {
                label.remove_css_class (tag_color);
            }

            label.add_css_class (Preferences.TAGS_COLORS[file.color]);
            tag_color = Preferences.TAGS_COLORS[file.color];
        }

        file_icon.queue_draw ();
        label.queue_draw ();
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

    public bool is_draggable_point (double view_x, double view_y) {
        if (is_dummy) {
            return false;
        }

        Graphene.Point target_point;
        var target = view.pick (view_x, view_y, Gtk.PickFlags.DEFAULT);
        view.compute_point (target, {(float)view_x, (float)view_y}, out target_point);
        if (target is Gtk.Image) {
            Graphene.Point image_origin = {(float)(file_icon.margin_start), (float)(file_icon.margin_top)};
            Graphene.Size image_size = {(float)(file_icon.pixel_size), (float)(file_icon.pixel_size)};
            Graphene.Rect image_rect = {image_origin, image_size};
            return image_rect.contains_point (target_point); // Rubberband on margins, else drag
        } else if (target is Gtk.Label) {
            return true; // Drag on Label
        }

        return false; // Rubberband on background or helper
    }
}
