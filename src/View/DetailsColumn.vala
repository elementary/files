/*
 * SPDX-License-Identifier: GPL-2.0+
 * SPDX-FileCopyrightText: 2020-2025 elementary, Inc. (https://elementary.io)
 *
 * Authors : Andres Mendez <shiruken@gmail.com>
 */

public class Files.View.DetailsColumn : Gtk.Box {
    private Gtk.ScrolledWindow details_window;
    private Gtk.Box details_container;

    public new bool has_focus {
        get {
            return details_container.has_focus;
        }
    }

    public DetailsColumn (Files.File file) {
        var preview_box = new Gtk.Box (VERTICAL, 0) {
            vexpand = true
        };

        var details_box = new Gtk.Box (VERTICAL, 0) {
            vexpand = true
        };

        var title = new Gtk.Label (file.basename)  {
            hexpand = true,
            xalign = 0
        };

        details_box.add (title);


        details_container = new Gtk.Box (VERTICAL, 0) {
            vexpand = true
        };

        details_container.add (preview_box);
        details_container.add (details_box);

        details_window = new Gtk.ScrolledWindow (null, null) {
            child = details_container,
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };

        orientation = Gtk.Orientation.VERTICAL;
        width_request = Files.app_settings.get_int ("minimum-sidebar-width");
        get_style_context ().add_class (Gtk.STYLE_CLASS_SIDEBAR);
        add (details_window);

        show_all ();
    }

// REFS:
            // var style_context = get_style_context ();
            // // if (slot.directory.is_empty ()) {
            //     Pango.Layout layout = create_pango_layout (null);

            //     if (!style_context.has_class (Granite.STYLE_CLASS_H2_LABEL)) {
            //         style_context.add_class (Granite.STYLE_CLASS_H2_LABEL);
            //         style_context.add_class (Gtk.STYLE_CLASS_VIEW);
            //     }

            //     layout.set_markup (slot.get_empty_message (), -1);

            //     Pango.Rectangle? extents = null;
            //     layout.get_extents (null, out extents);

            //     double width = Pango.units_to_double (extents.width);
            //     double height = Pango.units_to_double (extents.height);

            //     double x = (double) get_allocated_width () / 2 - width / 2;
            //     double y = (double) get_allocated_height () / 2 - height / 2;

            // Gtk.Allocation alloc;
            // get_allocation (out alloc);
            // var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, alloc.width, alloc.height);
            // var cr = new Cairo.Context (surface);
            //     get_style_context ().render_layout (cr, x, y, layout);

                // return true;
            // } else if (style_context.has_class (Granite.STYLE_CLASS_H2_LABEL)) {
            //     style_context.remove_class (Granite.STYLE_CLASS_H2_LABEL);
            //     style_context.remove_class (Gtk.STYLE_CLASS_VIEW);
            // }

            // return false;

}
