/*-
 * Copyright (c) 2019 elementary, Inc. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

[DBus (name = "org.freedesktop.portal.FileChooser")]
public class FileChooser : Object {

    private int id = 0;
    private unowned DBusConnection conn;

    private Gee.HashMap<Request, uint> requests;

    construct {
        requests = new Gee.HashMap<Request, uint> (Request.hash);
    }

    public FileChooser (DBusConnection conn) {
        this.conn = conn;

        var mapp = new Marlin.Application ();
        mapp.initialize ();

        var app = new Application ("io.elementary.files-portal", ApplicationFlags.NON_UNIQUE);
        Application.set_default (app);
    }

    public ObjectPath open_file (string parent_window, string title, HashTable<string, Variant> options, BusName sender) throws Error {
        try {
            var req = register_request (sender, extract_token (options));
            show_dialog (req, parent_window, title, options);
            return req.handle;
        } catch (Error e) {
            warning (e.message);
            throw e;
        }
    }

    public ObjectPath save_file (string parent_window, string title, HashTable<string, Variant> options, BusName sender) throws Error {
        try {
            var req = register_request (sender, extract_token (options));
            show_dialog (req, parent_window, title, options);
            return req.handle;
        } catch (Error e) {
            warning (e.message);
            throw e;
        }
    }


    private static string? extract_token (HashTable<string, Variant> options) {
        var token = options["handle_token"];
        if (token == null) {
            return null;
        }

        return token.get_string ();
    }

    private Request register_request (owned string sender, owned string? token) throws Error {
        if (token == null) {
            token = id.to_string ();
            id++;
        }

        if (sender.has_prefix (":")) {
            sender = sender.substring (1);
        }

        sender = sender.replace (".", "_");

        string handle = "/org/fredesktop/portal/desktop/request/%s/%s".printf (sender, token);

        var req = new Request ((ObjectPath)handle);
        req.closed.connect (() => { 
            conn.unregister_object (requests[req]);
            requests.unset (req);
        });

        try {
            requests[req] = conn.register_object (handle, req);
        } catch (IOError e) {
            throw e;
        }

        return req;
    }

    private FileChooserDialog show_dialog (Request request, string parent_window, string title, HashTable<string, Variant> options) {
        var dialog = new FileChooserDialog (request, title);
        dialog.destroy.connect (on_dialog_destroyed);
        dialog.selected.connect (on_dialog_selected);

        request.closed.connect (() => on_dialog_closed (dialog, true));

        dialog.show_all ();
        return dialog;
    }

    private void on_dialog_selected (FileChooserDialog dialog, List<GOF.File> selection) {
        dialog.destroy.disconnect (on_dialog_destroyed);
        dialog.destroy ();

        Variant[] uris = {};
        foreach (var file in selection) {
            uris += new Variant.string (file.uri);
        }

        var uris_va = new Variant.array (VariantType.STRING, uris);
        var results = new HashTable<string, Variant> (str_hash, null);
        results["uris"] = uris_va;

        dialog.request.response (ResponseType.SUCCESS, results);
    }

    private void on_dialog_destroyed (Gtk.Widget dialog) {
        on_dialog_closed ((FileChooserDialog)dialog, false);
    }

    private void on_dialog_closed (FileChooserDialog dialog, bool was_request) {
        if (!was_request) {
            var uris_va = new Variant.array (VariantType.STRING, {});

            var results = new HashTable<string, Variant> (str_hash, null);
            results["uris"] = uris_va;
            dialog.request.response (ResponseType.CANCELLED, results);
        }

        if (!dialog.is_destroyed) {
            dialog.destroy ();
        }
    }
}
