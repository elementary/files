/*
* Copyright 2022 elementary, Inc. (https://elementary.io)
* SPDX-License-Identifier: LGPL-3.0-or-later
*/

// Replacement for Granite7 Placeholder widget in Gtk3
public class Files.Placeholder : Gtk.Bin {
    public string title { get; construct set; }
    public string description { get; set; }
    public Icon icon { get; set; }
    private Gtk.Box buttonbox;

    public Placeholder (string title) {
        Object (title: title);
    }

    construct {
        halign = Gtk.Align.CENTER;
        valign = Gtk.Align.CENTER;
        hexpand = true;
        vexpand = true;

        var image = new Gtk.Image () {
            valign = Gtk.Align.START
        };

        var title_label = new Gtk.Label (title) {
            max_width_chars = 30,
            wrap = true,
            xalign = 0
        };
        title_label.get_style_context ().add_class (Granite.STYLE_CLASS_H1_LABEL);

        var description_label = new Gtk.Label ("") {
            max_width_chars = 45,
            wrap = true,
            use_markup = true,
            xalign = 0
        };
        description_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

        buttonbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            visible = false
        };

        var grid = new Gtk.Grid ();
        grid.attach (image, 0, 0, 1, 2);
        grid.attach (title_label, 1, 0);
        grid.attach (description_label, 1, 1);
        grid.attach (buttonbox, 1, 2);
        add (grid);

        bind_property ("title", title_label, "label");
        bind_property ("description", description_label, "label");
        bind_property (
            "description",
            description_label, "visible",
            BindingFlags.SYNC_CREATE | BindingFlags.DEFAULT,
            (binding, srcval, ref targetval) => {
                targetval.set_boolean ((string) srcval != null && (string) srcval != "");
                return true;
            },
            null
        );

        bind_property ("icon", image, "gicon");
        bind_property (
            "icon",
            image, "visible",
            BindingFlags.SYNC_CREATE | BindingFlags.DEFAULT,
            (binding, srcval, ref targetval) => {
                targetval.set_boolean ((Icon) srcval != null);
                return true;
            },
            null
        );

        show_all ();
    }

    public Gtk.Button append_button (Icon icon, string label, string description) {
        var image = new Gtk.Image.from_gicon (icon, Gtk.IconSize.DIALOG);
        var label_widget = new Gtk.Label (label) {
            wrap = true,
            xalign = 0
        };
        label_widget.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        var description_widget = new Gtk.Label (description) {
            wrap = true,
            xalign = 0
        };

        var grid = new Gtk.Grid ();
        grid.attach (image, 0, 0, 1, 2);
        grid.attach (label_widget, 1, 0);
        grid.attach (description_widget, 1, 1);

        var button = new Gtk.Button () {
            child = grid
        };
        button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        buttonbox.add (button);
        buttonbox.show ();

        return button;
    }
}
