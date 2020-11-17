/*-
 * Copyright 2020 elementary LLC <https://elementary.io>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
 * Boston, MA 02110-1335 USA.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

[DBus (name = "org.freedesktop.impl.portal.Request")]
public class Files.FileChooserDialog : Gtk.FileChooserDialog {
    private GLib.DBusConnection connection;
    private uint registration_id;
    private LegacyFileChooserDialog legacy_dialog;
    public GLib.HashTable<unowned string, string> choices { public get; private set; }
    public bool read_only { get; set; default = false; }

    public FileChooserDialog (GLib.DBusConnection connection, GLib.ObjectPath handle, string app_id, string parent_window, string title, GLib.HashTable<string, GLib.Variant> options) {
        this.connection = connection;
        try {
            registration_id = connection.register_object<FileChooserDialog> (handle, this);
        } catch (Error e) {
            critical (e.message);
        }

        legacy_dialog = new LegacyFileChooserDialog (this);
    }

    construct {
        choices = new GLib.HashTable<unowned string, string> (str_hash, str_equal);
        add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
        set_default_response (Gtk.ResponseType.OK);
        response.connect_after (() => {
            destroy ();
        });

        destroy.connect (() => {
            if (registration_id != 0) {
                connection.unregister_object (registration_id);
                registration_id = 0;
            }
        });
    }

    [DBus (visible = false)]
    public Gtk.Widget deserialize_choice (GLib.Variant choice) {
        unowned string choice_id;
        unowned string label;
        unowned string selected;
        GLib.Variant choices_variant;
        choice.get ("(&s&s@a(ss)&s)", out choice_id, out label, out choices_variant, out selected);

        if (choices_variant.n_children () > 0) {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            box.add (new Gtk.Label (label));
            var combo = new Gtk.ComboBoxText ();
            combo.set_data<string> ("choice-id", choice_id);
            box.add (combo);

            for (size_t i = 0; i < choices_variant.n_children (); i++) {
                unowned string id;
                unowned string text;
                choices_variant.get_child (i, "(&s&s)", out id, out text);
                combo.append (id, text);
            }

            if (selected == "") {
                choices_variant.get_child (0, "(&s&s)", out selected, null);
            }

            combo.changed.connect (() => {
                choices.set (combo.get_data<string> ("choice-id"), combo.active_id);
            });

            combo.active_id = selected;
            choices.set (combo.get_data<string> ("choice-id"), selected);
            box.show_all ();
            return box;
        } else {
            var check = new Gtk.CheckButton.with_label (label);
            check.set_data<string> ("choice-id", choice_id);
            check.toggled.connect (() => {
                choices.set (check.get_data<string> ("choice-id"), check.active ? "true" : "false");
            });

            check.active = selected == "true";
            choices.set (check.get_data<string> ("choice-id"), selected);
            check.show_all ();
            return check;
        }
    }

    [DBus (name = "Close")]
    public void on_close () throws GLib.DBusError, GLib.IOError {
        response (Gtk.ResponseType.DELETE_EVENT);
    }
}
