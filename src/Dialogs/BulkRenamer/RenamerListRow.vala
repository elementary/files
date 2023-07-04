/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2019-2023 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Vartan Belavejian <https://github.com/VartanBelavejian>
 *              Jeremy Wootten <jeremywootten@gmail.com>
 */

public class Files.RenamerListRow : Gtk.ListBoxRow {
    public string old_name { get; construct; }
    public Files.File file { get; construct; }

    public string new_name { get; set; }
    public string extension { get; set; default = ""; }
    public RenameStatus status { get; set; default = RenameStatus.VALID; }

    private static Gtk.SizeGroup size_group;

    public RenamerListRow (Files.File file) {
        Object (
            file: file,
            old_name: file.basename
        );
    }

    static construct {
        size_group = new Gtk.SizeGroup (HORIZONTAL);
    }

    construct {
        var oldname_label = new Gtk.Label (old_name) {
            wrap = true,
            xalign = 0
        };

        var newname_label = new Gtk.Label (new_name) {
            wrap = true,
            xalign = 0
        };

        size_group.add_widget (newname_label);
        size_group.add_widget (oldname_label);

        var arrow_image = new Gtk.Image.from_icon_name ("go-next-symbolic", Gtk.IconSize.MENU) {
            hexpand = true
        };

        var status_image = new Gtk.Image ();

        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            margin_top = 6,
            margin_end = 6,
            margin_bottom = 6,
            margin_start = 6
        };
        box.add (oldname_label);
        box.add (arrow_image);
        box.add (newname_label);
        box.add (status_image);

        child = box;
        show_all ();

        bind_property ("new-name", newname_label, "label");

        notify["status"].connect (() => {
            switch (status) {
                case RenameStatus.IGNORED:
                    status_image.icon_name = "radio-mixed-symbolic";
                    status_image.tooltip_markup = _("Ignored") + "\n" + Granite.TOOLTIP_SECONDARY_TEXT_MARKUP.printf (_("Name is not changed"));
                    break;
                case RenameStatus.INVALID:
                    status_image.icon_name = "process-error-symbolic";
                    status_image.tooltip_markup = _("Cannot rename") + "\n" + Granite.TOOLTIP_SECONDARY_TEXT_MARKUP.printf (_("Name is invalid or already exists"));
                    break;
                case RenameStatus.VALID:
                    status_image.icon_name = "process-completed-symbolic";
                    status_image.tooltip_text = _("Will be renamed");
                    break;
                default:
                    break;
            }
        });
    }
}
