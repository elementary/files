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

private static bool opt_replace = false;
private static bool show_version = false;

private static GLib.MainLoop loop;

private const GLib.OptionEntry[] ENTRIES = {
    { "replace", 'r', 0, OptionArg.NONE, ref opt_replace, "Replace a running instance", null },
    { "version", 0, 0, OptionArg.NONE, ref show_version, "Show program version.", null },
    { null }
};

[DBus (name = "org.freedesktop.impl.portal.FileChooser")]
public class Files.FileChooser : GLib.Object {
    private GLib.DBusConnection connection;

    public FileChooser (GLib.DBusConnection connection) {
        this.connection = connection;
    }

    public async void open_file (GLib.ObjectPath handle, string app_id, string parent_window, string title, GLib.HashTable<string, GLib.Variant> options, out uint response, out GLib.HashTable<string, GLib.Variant> results) throws GLib.DBusError, GLib.IOError {
        var _results = new GLib.HashTable<string, GLib.Variant> (str_hash, str_equal);
        var dialog = new Files.FileChooserDialog (connection, handle, app_id, parent_window, title, options);

        unowned GLib.Variant? directory_variant = options["directory"];
        bool directory = false;
        if (directory_variant != null && directory_variant.is_of_type (GLib.VariantType.BOOLEAN)) {
            directory = directory_variant.get_boolean ();
        }
        dialog.action = directory ? Gtk.FileChooserAction.SELECT_FOLDER : Gtk.FileChooserAction.OPEN;

        unowned GLib.Variant? multiple_variant = options["multiple"];
        bool multiple = false;
        if (multiple_variant != null && multiple_variant.is_of_type (GLib.VariantType.BOOLEAN)) {
            multiple = multiple_variant.get_boolean ();
        }

        dialog.select_multiple = multiple;
        unowned GLib.Variant? accept_label = options["accept_label"];
        if (accept_label != null && accept_label.is_of_type (GLib.VariantType.STRING)) {
            dialog.add_button (accept_label.get_string (), Gtk.ResponseType.OK);
        } else {
            dialog.add_button (multiple ? _("Open") : _("Select"), Gtk.ResponseType.OK);
        }

        unowned GLib.Variant? modal_variant = options["modal"];
        bool modal = true;
        if (modal_variant != null && modal_variant.is_of_type (GLib.VariantType.BOOLEAN)) {
            modal = modal_variant.get_boolean ();
        }

        dialog.modal = modal;

        handle_filters (dialog, options["filters"], options["current_filter"]);

        unowned GLib.Variant? choices_variant = options["choices"];
        if (choices_variant != null && choices_variant.is_of_type (new GLib.VariantType ("a(ssa(ss)s)"))) {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            for (size_t i = 0; i < choices_variant.n_children (); i++) {
                var choice = choices_variant.get_child_value (i);
                box.add (dialog.deserialize_choice (choice));
            }

            dialog.set_extra_widget (box);
        }

        uint _response = 2;
        dialog.response.connect ((id) => {
            switch ((Gtk.ResponseType) id) {
                case Gtk.ResponseType.OK:
                    _response = 0;
                    _results["choices"] = dialog.choices;
                    var builder = new GLib.VariantBuilder (GLib.VariantType.STRING_ARRAY);
                    dialog.get_uris ().foreach ((uri) => {
                        builder.add ("s", uri);
                    });

                    _results["uris"] = builder.end ();
                    _results["writable"] = !dialog.read_only;
                    break;
                case Gtk.ResponseType.CANCEL:
                    _response = 1;
                    break;
                case Gtk.ResponseType.DELETE_EVENT:
                default:
                    _response = 2;
                    break;
            }

            open_file.callback ();
        });

        var granite_settings = Granite.Settings.get_default ();
        var gtk_settings = Gtk.Settings.get_default ();

        gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;

        granite_settings.notify["prefers-color-scheme"].connect (() => {
            gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
        });

        dialog.show_all ();
        yield;
        response = _response;
        results = _results;
    }

    private void handle_filters (Files.FileChooserDialog dialog, GLib.Variant? filters_variant, GLib.Variant? current_filter_variant) {
        var filters = new GLib.GenericArray<Gtk.FileFilter> ();

        if (filters_variant != null && filters_variant.is_of_type (new GLib.VariantType ("a(sa(us))"))) {
            var iter = filters_variant.iterator ();
            GLib.Variant variant;
            while (iter.next ("@(sa(us))", out variant)) {
                var filter = new Gtk.FileFilter.from_gvariant (variant);
                dialog.add_filter (filter);
                filters.add ((owned) filter);
            }
        }

        if (current_filter_variant != null && current_filter_variant.is_of_type (new GLib.VariantType ("(sa(us))"))) {
            var filter = new Gtk.FileFilter.from_gvariant (current_filter_variant);

            if (filters.length == 0) {
              /* We are setting a single, unchangeable filter. */
              dialog.set_filter (filter);
            } else {
                uint index;
                if (filters.find_with_equal_func (
                        filter,
                        (a, b) => {
                            return a.get_filter_name () == b.get_filter_name ();
                        },
                        out index
                    )) {
                    unowned Gtk.FileFilter f = filters.get (index);
                    dialog.set_filter (f);
                } else {
                    warning ("current file filter must be present in filters list when list is nonempty");
                }
            }
        }
    }

    public async void save_file (GLib.ObjectPath handle, string app_id, string parent_window, string title, GLib.HashTable<string, GLib.Variant> options, out uint response, out GLib.HashTable<string, GLib.Variant> results) throws GLib.DBusError, GLib.IOError {
        var _results = new GLib.HashTable<string, GLib.Variant> (str_hash, str_equal);
        var dialog = new Files.FileChooserDialog (connection, handle, app_id, parent_window, title, options);
        dialog.action = Gtk.FileChooserAction.SAVE;

        unowned GLib.Variant? modal_variant = options["modal"];
        bool modal = true;
        if (modal_variant != null && modal_variant.is_of_type (GLib.VariantType.BOOLEAN)) {
            modal = modal_variant.get_boolean ();
        }
        dialog.modal = modal;

        handle_filters (dialog, options["filters"], options["current_filter"]);

        unowned GLib.Variant? choices_variant = options["choices"];
        if (choices_variant != null && choices_variant.is_of_type (new GLib.VariantType ("a(ssa(ss)s)"))) {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            for (size_t i = 0; i < choices_variant.n_children (); i++) {
                var choice = choices_variant.get_child_value (i);
                box.add (dialog.deserialize_choice (choice));
            }

            dialog.set_extra_widget (box);
        }

        unowned GLib.Variant? current_name_variant = options["current_name"];
        if (current_name_variant != null && current_name_variant.is_of_type (GLib.VariantType.STRING)) {
            dialog.set_current_name (current_name_variant.get_string ());
        }

        unowned GLib.Variant? current_folder_variant = options["current_folder"];
        if (current_folder_variant != null && current_folder_variant.is_of_type (GLib.VariantType.BYTESTRING)) {
            dialog.set_current_folder (current_folder_variant.get_bytestring ());
        }

        unowned GLib.Variant? current_file_variant = options["current_file"];
        if (current_file_variant != null && current_file_variant.is_of_type (GLib.VariantType.BYTESTRING)) {
            dialog.select_filename (current_file_variant.get_bytestring ());
        }

        unowned GLib.Variant? accept_label = options["accept_label"];
        if (accept_label != null && accept_label.is_of_type (GLib.VariantType.STRING)) {
            dialog.add_button (accept_label.get_string (), Gtk.ResponseType.OK);
        } else {
            dialog.add_button (_("Save"), Gtk.ResponseType.OK);
        }

        dialog.show_all ();
        uint _response = 2;
        dialog.response.connect ((id) => {
            switch ((Gtk.ResponseType) id) {
                case Gtk.ResponseType.OK:
                    _response = 0;
                    _results["choices"] = dialog.choices;
                    var builder = new GLib.VariantBuilder (GLib.VariantType.STRING_ARRAY);
                    dialog.get_uris ().foreach ((uri) => {
                        builder.add ("s", uri);
                    });

                    _results["uris"] = builder.end ();
                    break;
                case Gtk.ResponseType.CANCEL:
                    _response = 1;
                    break;
                case Gtk.ResponseType.DELETE_EVENT:
                default:
                    _response = 2;
                    break;
            }

            save_file.callback ();
        });

        dialog.show_all ();
        yield;
        response = _response;
        results = _results;
    }

    public async void save_files (GLib.ObjectPath handle, string app_id, string parent_window, string title, GLib.HashTable<string, GLib.Variant> options, out uint response, out GLib.HashTable<string, GLib.Variant> results) throws GLib.DBusError, GLib.IOError {
        var _results = new GLib.HashTable<string, GLib.Variant> (str_hash, str_equal);
        var dialog = new Files.FileChooserDialog (connection, handle, app_id, parent_window, title, options);
        dialog.action = Gtk.FileChooserAction.SELECT_FOLDER;

        unowned GLib.Variant? modal_variant = options["modal"];
        bool modal = true;
        if (modal_variant != null && modal_variant.is_of_type (GLib.VariantType.BOOLEAN)) {
            modal = modal_variant.get_boolean ();
        }
        dialog.modal = modal;

        unowned GLib.Variant? choices_variant = options["choices"];
        if (choices_variant != null && choices_variant.is_of_type (new GLib.VariantType ("a(ssa(ss)s)"))) {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            for (size_t i = 0; i < choices_variant.n_children (); i++) {
                var choice = choices_variant.get_child_value (i);
                box.add (dialog.deserialize_choice (choice));
            }

            dialog.set_extra_widget (box);
        }

        unowned GLib.Variant? current_folder_variant = options["current_folder"];
        if (current_folder_variant != null && current_folder_variant.is_of_type (GLib.VariantType.BYTESTRING)) {
            dialog.set_current_folder (current_folder_variant.get_bytestring ());
        }

        unowned GLib.Variant? accept_label = options["accept_label"];
        if (accept_label != null && accept_label.is_of_type (GLib.VariantType.STRING)) {
            dialog.add_button (accept_label.get_string (), Gtk.ResponseType.OK);
        } else {
            dialog.add_button (_("Save"), Gtk.ResponseType.OK);
        }

        unowned GLib.Variant? files_variant = options["files"];
        if (files_variant != null && files_variant.is_of_type (GLib.VariantType.BYTESTRING_ARRAY)) {
            var files = files_variant.get_bytestring_array ();
            dialog.set_data<string[]> ("files", files);
        }

        uint _response = 2;
        dialog.response.connect ((id) => {
            switch ((Gtk.ResponseType) id) {
                case Gtk.ResponseType.OK:
                    _response = 0;
                    _results["choices"] = dialog.choices;
                    var builder = new GLib.VariantBuilder (GLib.VariantType.STRING_ARRAY);
                    var uri = GLib.File.new_for_uri (dialog.get_uri ());
                    unowned string[]? files = dialog.get_data<string[]> ("files");
                    if (files != null) {
                        foreach (unowned string file in files) {
                            builder.add ("s", uri.get_child (GLib.Path.get_basename (file)).get_uri ());
                        }
                    }

                    _results["uris"] = builder.end ();
                    break;
                case Gtk.ResponseType.CANCEL:
                    _response = 1;
                    break;
                case Gtk.ResponseType.DELETE_EVENT:
                default:
                    _response = 2;
                    break;
            }

            save_files.callback ();
        });

        dialog.show_all ();
        yield;
        response = _response;
        results = _results;
    }
}

private void on_bus_acquired (GLib.DBusConnection connection, string name) {
    try {
        connection.register_object ("/org/freedesktop/portal/desktop", new Files.FileChooser (connection));
    } catch (GLib.Error e) {
        critical ("Unable to register the object: %s", e.message);
    }
}

public int main (string[] args) {
    GLib.Intl.setlocale (GLib.LocaleCategory.ALL, "");
    GLib.Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
    GLib.Intl.textdomain (Config.GETTEXT_PACKAGE);
    GLib.Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALE_DIR);

    /* Avoid pointless and confusing recursion */
    GLib.Environment.unset_variable ("GTK_USE_PORTAL");

    Gtk.init (ref args);

    var context = new GLib.OptionContext ("- FileChooser portal");
    context.add_main_entries (ENTRIES, null);
    try {
        context.parse (ref args);
    } catch (Error e) {
        printerr ("%s: %s", Environment.get_application_name (), e.message);
        printerr ("\n");
        printerr ("Try \"%s --help\" for more information.", GLib.Environment.get_prgname ());
        printerr ("\n");
        return 1;
    }

    if (show_version) {
      print ("0.0 \n");
      return 0;
    }

    loop = new GLib.MainLoop (null, false);

    try {
        var session_bus = GLib.Bus.get_sync (GLib.BusType.SESSION);
        var owner_id = GLib.Bus.own_name (
            GLib.BusType.SESSION,
            "org.freedesktop.impl.portal.desktop.elementary.files",
            GLib.BusNameOwnerFlags.ALLOW_REPLACEMENT | (opt_replace ? GLib.BusNameOwnerFlags.REPLACE : 0),
            on_bus_acquired,
            () => { debug ("org.freedesktop.impl.portal.desktop.elementary.files acquired"); },
            () => { loop.quit (); }
        );
        loop.run ();
        GLib.Bus.unown_name (owner_id);
    } catch (Error e) {
        printerr ("No session bus: %s\n", e.message);
        return 2;
    }

    return 0;

}
