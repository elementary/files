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


public class Files.GridFileItem : Gtk.Widget {
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

    public Files.File? file { get; set; default = null; }
    public Gtk.Image file_icon { get; construct; }
    public Gtk.CheckButton selection_helper { get; construct; }
    public Gtk.Label label { get; construct; }
    public Gtk.TextView text_view { get; construct; }
    public Gtk.Stack name_stack { get; construct; }
    public Gtk.GridView gridview { get; set construct; }
    public uint pos;

    private Gtk.Image[] emblems;
    private Gtk.Box emblem_box;

    public ZoomLevel zoom_level {
        set {
            var size = value.to_icon_size ();
            file_icon.pixel_size = size;
            update_pix ();
            file_icon.margin_start = size / 2;
            file_icon.margin_end = size / 2;
            file_icon.margin_top = size / 4;
            selection_helper.margin_start = size / 3;
            selection_helper.margin_end = size / 3;
            selection_helper.margin_top = size / 6;
            selection_helper.margin_bottom = size / 6;
        }
    }

    public bool selected { get; set; default = false; }
    public bool cut_pending { get; set; default = false; }

    construct {
        var lm = new Gtk.BoxLayout (Gtk.Orientation.VERTICAL);
        set_layout_manager (lm);

        get_style_context ().add_provider (
            fileitem_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        var icon_overlay = new Gtk.Overlay ();
        file_icon = new Gtk.Image () {
            icon_name = "image-missing",
        };
        icon_overlay.child = file_icon;

        selection_helper = new Gtk.CheckButton () {
            visible = false,
            halign = Gtk.Align.START,
            valign = Gtk.Align.START
        };
        icon_overlay.add_overlay (selection_helper);

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

        icon_overlay.add_overlay (emblem_box);

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

        text_view = new Gtk.TextView ();
        name_stack = new Gtk.Stack ();
        name_stack.add_child (label);
        name_stack.add_child (text_view);
        name_stack.visible_child = label;
        icon_overlay.set_parent (this);
        name_stack.set_parent (this);

        Thumbnailer.@get ().finished.connect ((req) => {
            if (req == thumbnail_request) {
                thumbnail_request = -1;
                update_pix ();
            }
        });

        notify["selected"].connect (() => {
            if (selected && !has_css_class ("selected")) {
                add_css_class ("selected");
                selection_helper.visible = true;
            } else if (!selected && has_css_class ("selected")) {
                remove_css_class ("selected");
                selection_helper.visible = false;
            }
        });

        var gesture_click = new Gtk.GestureClick () {
            button = 1
        };
        gesture_click.released.connect ((n_press, x, y) => {
            if (n_press == 1 && file.is_folder ()) {
                // Need to idle to allow selection to update
                Idle.add (() => {
                    gridview.activate (pos);
                    return Source.REMOVE;
                });
            }
        });
        file_icon.add_controller (gesture_click);

        var motion_controller = new Gtk.EventControllerMotion ();
        motion_controller.enter.connect (() => {
            selection_helper.visible = true;
        });
        motion_controller.leave.connect (() => {
            selection_helper.visible = selected;
        });
        add_controller (motion_controller);
        selection_helper.bind_property (
            "active", this, "selected", BindingFlags.BIDIRECTIONAL
        );
        selection_helper.toggled.connect (() => {
            if (selection_helper.active) {
                gridview.model.select_item (pos, false);
            } else {
                gridview.model.unselect_item (pos);
            }
        });
    }

    public void bind_file (Files.File? file) {
        this.file = file;
        if (file != null) {
            file.ensure_query_info ();
            label.label = file.custom_display_name ?? file.basename;
            if (file.pix == null) {
                file_icon.paintable = null;
                file.query_thumbnail_update (); // Ensure thumbstate up to date
                if (file.thumbstate == Files.File.ThumbState.UNKNOWN &&
                    (prefs.show_remote_thumbnails || !file.is_remote_uri_scheme ()) &&
                    !prefs.hide_local_thumbnails) { // Also hide remote if local hidden?

                        Thumbnailer.@get ().queue_file (
                            file, out thumbnail_request, file_icon.pixel_size > 128
                        );
                }

                if (file.icon != null) {
                    file_icon.gicon = file.icon;
                }
            }

            update_pix ();
            var cut_pending = ClipboardManager.get_instance ().has_cut_file (file);
            if (cut_pending && !has_css_class ("cut")) {
                add_css_class ("cut");
            } else if (!cut_pending && has_css_class ("cut")) {
                remove_css_class ("cut");
            }
        } else {
            label.label = "Unbound";
            file_icon.icon_name = "image-missing";
            thumbnail_request = -1;
        }
    }

    public void rebind () {
        bind_file (file);
    }

    private void update_pix () {
        if (file != null) {
            file.update_icon (file_icon.pixel_size, 1); //TODO Deal with scale
            foreach (var emblem in emblems) {
                emblem.visible = false;
            }
            int index = 0;
            foreach (string emblem in file.emblems_list) {
                emblems[index].icon_name = emblem;
                emblems[index].visible = true;
                index++;
            }
            if (file.pix != null) {
                file_icon.paintable = Gdk.Texture.for_pixbuf (file.pix);
                // queue_draw ();
            }
        }
    }

    public void get_color_tag () {

    }

    ~GridFileItem () {
        while (this.get_last_child () != null) {
            this.get_last_child ().unparent ();
        }
    }
}
