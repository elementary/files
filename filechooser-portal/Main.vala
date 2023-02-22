/*-
 * Copyright 2020-2023 elementary, Inc. (https://elementary.io)
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

[DBus (name = "org.freedesktop.impl.portal.FileChooser")]
public class Files.FileChooserPortal : Object {
    private static bool opt_replace = false;
    private static bool show_version = false;

    private HashTable<string, FileChooserDialog> dialogs;
    private DBusConnection connection;

    private const OptionEntry[] ENTRIES = {
        { "replace", 'r', 0, OptionArg.NONE, ref opt_replace, "Replace a running instance", null },
        { "version", 0, 0, OptionArg.NONE, ref show_version, "Show program version.", null },
        { null }
    };

    public FileChooserPortal (DBusConnection connection) {
        this.connection = connection;
        dialogs = new HashTable<string, FileChooserDialog> (str_hash, str_equal);
    }

    /**
     * Requests the user for a URI.
     *
     * The URI should point to a file, if "multiple" is true, more than one URI
     * can be chosen by the user. If "directory" is true, the URI should point
     * to a folder instead.
     *
     * A filter can be specified with "current_filter", or "filters", if more
     * than one filter could be used. Application specific options can be added
     * to the dialog with "choices" and a label to the select button set with
     * "accept_label".
     *
     * @param handle
     *    Object path where the request should be exported
     * @param app_id
     *    Application originating the call (not used)
     * @param parent_window
     *    Transient parent handle, in format "type:handle". if type is "x11",
     *    handle should be a XID in hexadecimal format, if type is "wayland",
     *    handle should be a xdg_foreign handle. Other types aren't supported.
     * @param title
     *    title for the file chooser dialog
     * @param options
     *    Dictionary of extra options. valid keys are: "accept_label",
     *    "choices", "current_filter", "directory", "filters", "multiple"
     *    and "modal".
     * @param response
     *    User response, 0 on success, 1 if cancelled, 2 on fail.
     * @param results
     *    Dictionary with the user choices, possible keys are: "uris",
     *    "choices", "writable" and "current_filter".
     */
    public async void open_file (
        ObjectPath handle,
        string app_id,
        string parent_window,
        string title,
        HashTable<string, Variant> options,
        out uint response,
        out HashTable<string, Variant> results
    ) throws DBusError, IOError {
        if (parent_window in dialogs) {
            results = new HashTable<string, Variant> (null, null);
            response = 2;
            return;
        }

        var directory = "directory" in options && options["directory"].get_boolean ();

        var dialog = new FileChooserDialog (
            directory ? Gtk.FileChooserAction.SELECT_FOLDER : Gtk.FileChooserAction.OPEN,
            parent_window,
            title
        );

        if ("modal" in options) {
            dialog.modal = options["modal"].get_boolean ();
        }

        if ("multiple" in options) {
            dialog.select_multiple = options["multiple"].get_boolean ();
        }

        if ("accept_label" in options) {
            dialog.accept_label = options["accept_label"].get_string ();
        } else {
            dialog.accept_label = dialog.select_multiple ? _("Select") : _("Open");
        }

        if ("filters" in options) {
            var filters = options["filters"].iterator ();
            Variant filter_variant;

            while ((filter_variant = filters.next_value ()) != null) {
                var filter = new Gtk.FileFilter.from_gvariant (filter_variant);
                dialog.add_filter (filter);
            }
        }

        if ("current_filter" in options) {
            dialog.filter = new Gtk.FileFilter.from_gvariant (options["current_filter"]);
        }

        if ("choices" in options) {
            var choices = options["choices"].iterator ();
            Variant choice_variant;

            while ((choice_variant = choices.next_value ()) != null) {
                var choice = new FileChooserChoice.from_variant (choice_variant);
                dialog.add_choice (choice);
            }
        }

        dialog.register_object (connection, handle);

        var _results = new HashTable<string, Variant> (str_hash, str_equal);
        uint _response = 2;

        dialog.response.connect ((id) => {
            switch (id) {
                case Gtk.ResponseType.OK:
                    _results["uris"] = dialog.get_uris ();
                    _results["choices"] = dialog.get_choices ();
                    _results["writable"] = !dialog.read_only;
                    if (dialog.filter != null) {
                        _results["current_filter"] = dialog.filter.to_gvariant ();
                    }

                    _response = 0;
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

        dialogs[parent_window] = dialog;
        dialog.show_all ();
        yield;

        dialogs.remove (parent_window);
        dialog.destroy ();

        response = _response;
        results = _results;
    }

    /**
     * Requests the user for a URI, with intent to write to it.
     *
     * The URI should point to a file, if the URI is already existent,
     * permission is asked for it usage. "current_folder", "current_name" and
     * "current_file" can be used to pre-select a file.
     *
     * A filter can be specified with "current_filter" option, or "filters",
     * if more than one filter could be used. Application specific options
     * can be added to the dialog with "choices" and a label to the select
     * button set with "accept_label".
     *
     * @param handle
     *     Object path where the request should be exported
     * @param app_id
     *     Application originating the call (not used)
     * @param parent_window
     *     Transient parent handle, in format "type:handle". if type is "x11",
     *     handle should be a XID in hexadecimal format, if type is "wayland",
     *     handle should be a xdg_foreign handle. Other types aren't supported.
     * @param title
     *     title for the file chooser dialog
     * @param options
     *     Dictionary of extra options. valid keys are: "accept_label",
     *     "choices", "current_file", "current_filter", "current_folder",
     *     "current_name", "filters" and "modal".
     * @param response
     *     User response, 0 on success, 1 if cancelled, 2 on fail.
     * @param results
     *     Dictionary with the user choices, possible keys are: "uris",
     *     "choices", and "current_filter".
     */
    public async void save_file (
        ObjectPath handle,
        string app_id,
        string parent_window,
        string title,
        HashTable<string, Variant> options,
        out uint response,
        out HashTable<string, Variant> results
    ) throws DBusError, IOError {
        if (parent_window in dialogs) {
            results = new HashTable<string, Variant> (null, null);
            response = 2;
            return;
        }

        var dialog = new FileChooserDialog (Gtk.FileChooserAction.SAVE, parent_window, title) {
            accept_label = "accept_label" in options ? options["accept_label"].get_string () : _("Save")
        };

        if ("modal" in options) {
            dialog.modal = options["modal"].get_boolean ();
        }

        if ("current_name" in options) {
            dialog.set_current_name (options["current_name"].get_string ());
        }

        if ("current_folder" in options) {
            dialog.set_current_folder (FileUtils.sanitize_path (options["current_folder"].get_bytestring ()));
        }

        var supplied_uri = "";
        if ("current_file" in options) {
            supplied_uri = FileUtils.sanitize_path (
                options["current_file"].get_bytestring (), Environment.get_home_dir ()
            );

            if (supplied_uri != "") {
                dialog.set_uri (supplied_uri);
            }
        }

        if ("filters" in options) {
            var filters = options["filters"].iterator ();
            Variant filter_variant;

            while ((filter_variant = filters.next_value ()) != null) {
                var filter = new Gtk.FileFilter.from_gvariant (filter_variant);
                dialog.add_filter (filter);
            }
        }

        if ("current_filter" in options) {
            dialog.filter = new Gtk.FileFilter.from_gvariant (options["current_filter"]);
        }

        if ("choices" in options) {
            var choices = options["choices"].iterator ();
            Variant choice_variant;

            while ((choice_variant = choices.next_value ()) != null) {
                var choice = new FileChooserChoice.from_variant (choice_variant);
                dialog.add_choice (choice);
            }
        }

        dialog.register_object (connection, handle); // Dialog will unregister itself when disposed

        var _results = new HashTable<string, Variant> (str_hash, str_equal);
        uint _response = 2;

        dialog.response.connect ((id) => {
            switch (id) {
                case Gtk.ResponseType.OK:
                    _results["uris"] = dialog.get_uris ();
                    _results["choices"] = dialog.get_choices ();
                    if (dialog.filter != null) {
                        _results["current_filter"] = dialog.filter.to_gvariant ();
                    }

                   _response = 0;

                    var chosen_file = dialog.get_file ();
                    if (!chosen_file.query_exists () || chosen_file.get_uri () == supplied_uri) {
                        break; // No need to check full uri supplied by calling app
                    }

                    var overwrite_dialog = create_overwrite_dialog (dialog, chosen_file);
                    overwrite_dialog.response.connect ((response) => {
                        overwrite_dialog.destroy ();
                        if (response == Gtk.ResponseType.YES) {
                            save_file.callback ();
                        } else {
                            _results.remove_all ();
                            _response = 2;
                        }


                    });
                    overwrite_dialog.present ();
                    return; // Continue showing dialog until check completes
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

        dialogs[parent_window] = dialog;
        dialog.show_all ();
        yield;

        dialogs.remove (parent_window);
        dialog.destroy ();

        response = _response;
        results = _results;
    }

    /**
     * Requests the user for a URI, with the intent to write files inside it.
     *
     * Filenames are specified via the "files" option, a folder can be
     * pre-selected with "current_folder". If a file with the same name as one
     * in the "files" list exists, it's replaced.
     *
     * Application specific options can be added to the dialog with "choices"
     * and a label to the select button set with "accept_label".
     *
     * @param handle
     *     Object path where the request should be exported
     * @param app_id
     *     Application originating the call (not used)
     * @param parent_window
     *     Transient parent handle, in format "type:handle". if type is "x11",
     *     handle should be a XID in hexadecimal format. if type is "wayland",
     *     handle should be a xdg_foreign handle. Other types aren't supported.
     * @param title
     *     title for the file chooser dialog
     * @param options
     *     Dictionary of extra options. valid keys are: "accept_label",
     *     "choices", "current_folder", "files" and "modal".
     * @param response
     *     User response, 0 on success, 1 if cancelled, 2 on fail.
     * @param results
     *     Dictionary with the user choices, possible keys are: "uris" and
     *     "choices".
     */
    public async void save_files (
        ObjectPath handle,
        string app_id,
        string parent_window,
        string title,
        HashTable<string, Variant> options,
        out uint response,
        out HashTable<string, Variant> results
    ) throws DBusError, IOError {
        if (parent_window in dialogs) {
            results = new HashTable<string, Variant> (null, null);
            response = 2;
            return;
        }

        var dialog = new Files.FileChooserDialog (Gtk.FileChooserAction.SELECT_FOLDER, parent_window, title) {
            accept_label = "accept_label" in options ? options["accept_label"].get_string () : _("Save")
        };

        if ("modal" in options) {
            dialog.modal = options["modal"].get_boolean ();
        }

        if ("current_folder" in options) {
            dialog.set_current_folder (FileUtils.sanitize_path (options["current_folder"].get_bytestring ()));
        }

        if ("choices" in options) {
            var choices = options["choices"].iterator ();
            Variant choice_variant;

            while ((choice_variant = choices.next_value ()) != null) {
                var choice = new FileChooserChoice.from_variant (choice_variant);
                dialog.add_choice (choice);
            }
        }

        //TODO Handle failed registration?
        dialog.register_object (connection, handle); // Dialog will unregister itself when disposed

        var _results = new HashTable<string, Variant> (str_hash, str_equal);
        uint _response = 2;

        dialog.response.connect ((id) => {
            switch (id) {
                case Gtk.ResponseType.OK:
                    string[] uris = {};

                    if ("files" in options) {
                        var files = options["files"].get_bytestring_array ();
                        var folder = GLib.File.new_for_uri (dialog.get_uri ());

                        foreach (unowned string file in files) {
                            uris += folder.get_child (Path.get_basename (file)).get_uri ();
                        }
                    }

                    _results["uris"] = uris;
                    _results["choices"] = dialog.get_choices ();
                    _response = 0;
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

        dialogs[parent_window] = dialog;
        dialog.show_all ();
        yield;

        dialogs.remove (parent_window);
        dialog.destroy ();

        response = _response;
        results = _results;
    }

    private Gtk.Dialog create_overwrite_dialog (Gtk.Window parent, GLib.File file) {
        string primary, secondary;
        if (file.query_file_type (FileQueryInfoFlags.NOFOLLOW_SYMLINKS) == FileType.SYMBOLIC_LINK) {
            try {
                var info = file.query_info (FileAttribute.STANDARD_SYMLINK_TARGET, FileQueryInfoFlags.NONE);
                primary = _("This file is a link to “%s”").printf (info.get_symlink_target ());
            } catch (Error e) {
                warning ("Could not get info for %s", file.get_uri ());
                primary = _("This file is a link.");
            }

            secondary = _("Replacing a link will overwrite the target's contents. The link will remain");
        } else {
            primary = _("Replace “%s”?").printf (file.get_basename ());
            secondary = _("Replacing this file will overwrite its current contents");
        }

        var replace_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                primary,
                secondary,
                "dialog-warning",
                Gtk.ButtonsType.CANCEL
            ) {
                modal = true,
                transient_for = parent
            };

        var replace_button = replace_dialog.add_button ("Replace", Gtk.ResponseType.YES);
        replace_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

        return replace_dialog;
    }

    private static void on_bus_acquired (DBusConnection connection, string name) {
        try {
            connection.register_object ("/org/freedesktop/portal/desktop", new FileChooserPortal (connection));
        } catch (Error e) {
            critical ("Unable to register the object: %s", e.message);
        }
    }

    public static int main (string[] args) {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (Config.GETTEXT_PACKAGE);
        Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALE_DIR);

        /* Avoid pointless and confusing recursion */
        Environment.unset_variable ("GTK_USE_PORTAL");

        Gtk.init (ref args);

        var context = new OptionContext ("- FileChooser portal");
        context.add_main_entries (ENTRIES, null);
        try {
            context.parse (ref args);
        } catch (Error e) {
            printerr ("%s: %s", Environment.get_application_name (), e.message);
            printerr ("\n");
            printerr ("Try \"%s --help\" for more information.", Environment.get_prgname ());
            printerr ("\n");
            return 1;
        }

        if (show_version) {
          print ("0.0 \n");
          return 0;
        }

        var loop = new MainLoop (null, false);
        try {
            var session_bus = Bus.get_sync (BusType.SESSION);
            var owner_id = Bus.own_name (
                BusType.SESSION,
                "org.freedesktop.impl.portal.desktop.elementary.files",
                BusNameOwnerFlags.ALLOW_REPLACEMENT | (opt_replace ? BusNameOwnerFlags.REPLACE : 0),
                on_bus_acquired,
                () => debug ("org.freedesktop.impl.portal.desktop.elementary.files acquired"),
                () => loop.quit ()
            );
            loop.run ();
            Bus.unown_name (owner_id);
        } catch (Error e) {
            printerr ("No session bus: %s\n", e.message);
            return 2;
        }

        return 0;
    }
}
