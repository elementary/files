/*
* Copyright 2013-2020 elementary, Inc. <https://elementary.io>
*           2007, 2011 Red Hat, Inc.
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU Lesser General Public
* License as published by the Free Software Foundation.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1335 USA.
*
* Authors: Alexander Larsson <alexl@redhat.com>
*          Cosimo Cecchi <cosimoc@redhat.com>
*          Julián Unrrein <junrrein@gmail.com>
*/

public class Files.Progress.InfoWidget : Gtk.Grid {
    public unowned PF.Progress.Info info { get; construct; }

    private Gtk.Label status;
    private Gtk.Label details;
    private Gtk.ProgressBar progress_bar;

    // public signal void cancelled (PF.Progress.Info info);

    public InfoWidget (PF.Progress.Info info) {
        Object (info: info);
    }

    construct {
        status = new Gtk.Label (info.status) {
            use_markup = true,
            max_width_chars = 50,
            selectable = true,
            width_chars = 50,
            wrap = true,
            xalign = 0
        };

        progress_bar = new Gtk.ProgressBar () {
            hexpand = true,
            pulse_step = 0.05,
            show_text = false,
            valign = Gtk.Align.CENTER
        };

        details = new Gtk.Label ("details") {
            use_markup = true,
            selectable = true,
            max_width_chars = 50,
            wrap = true,
            xalign = 0
        };

        var button = new Gtk.Button.from_icon_name ("process-stop-symbolic", Gtk.IconSize.BUTTON) {
            tooltip_text = _("Cancel")
        };

        button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        column_spacing = 6;
        attach (status, 0, 0, 2);
        attach (progress_bar, 0, 1);
        attach (button, 1, 1);
        attach (details, 0, 2, 2);

        show_all ();

        update_data ();
        update_progress ();

        info.changed.connect (update_data);
        info.progress_changed.connect (update_progress);

        info.finished.connect (() => {
        warning ("WIDGET info finished");
            destroy ();
        });

        button.clicked.connect (() => {
            if (info != null) {
                info.finished ();
            } else {
                destroy ();
            }
        });
    }

    private void update_data () {
        status.set_markup (
            Markup.printf_escaped ("<span font-features='tnum'>%s</span>", info.status)
        );
        details.set_markup (
            Markup.printf_escaped ("<span size='small' font-features='tnum'>%s</span>", info.details)
        );
    }

    private void update_progress () {
        double progress = info.progress;

        if (progress < 0) {
            progress_bar.pulse ();
        } else {
            progress_bar.set_fraction (progress);
        }
    }
}
