/***
    Authors:
      Lucas Baudin <xapantu@gmail.com>
      ammonkey <am.monkeyd@gmail.com>
      Victor Martinez <victoreduardm@gmail.com>

    Copyright (c) Lucas Baudin 2011 <xapantu@gmail.com>
    Copyright (c) 2013-2018 elementary LLC <https://elementary.io>

    Marlin is free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the
    Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Marlin is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
    See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program.  If not, see <http://www.gnu.org/licenses/>.
***/

public class Files.Plugins.ContractMenuItem : Gtk.MenuItem {
    private Granite.Services.Contract contract;
    private GLib.File[] files;

    public ContractMenuItem (Granite.Services.Contract contract, GLib.File[] files) {
        this.contract = contract;
        this.files = files;

        label = contract.get_display_name ();
    }

    public override void activate () {
        try {
            contract.execute_with_files (files);
        } catch (Error err) {
            warning (err.message);
        }
    }
}

public class Files.Plugins.Contractor : Files.Plugins.Base {
    private Gtk.Menu menu;
    private Files.File current_directory = null;

    public Contractor () {
    }

    public override void context_menu (Gtk.Widget widget, List<Files.File> gof_files) {
        menu = widget as Gtk.Menu;

        GLib.File[] files = null;
        Gee.List<Granite.Services.Contract> contracts = null;

        try {
            if (gof_files == null) {
                if (current_directory == null) {
                    return;
                }

                files = new GLib.File[0];
                files += current_directory.location;

                string? mimetype = current_directory.get_ftype ();

                if (mimetype == null) {
                    return;
                }

                contracts = Granite.Services.ContractorProxy.get_contracts_by_mime (mimetype);
            } else {
                files = get_file_array (gof_files);
                var mimetypes = get_mimetypes (gof_files);
                if (mimetypes.length > 0) {
                    contracts = Granite.Services.ContractorProxy.get_contracts_by_mimelist (mimetypes);
                }
            }

            assert (files != null);

            if (contracts == null) {
                return;
            }

            for (int i = 0; i < contracts.size; i++) {
                var contract = contracts.get (i);
                Gtk.MenuItem menu_item;

                // insert separator if we got at least 1 contract
                if (i == 0) {
                    menu_item = new Gtk.SeparatorMenuItem ();
                    add_menuitem (menu, menu_item);
                }

                menu_item = new ContractMenuItem (contract, files);
                add_menuitem (menu, menu_item);
            }
        } catch (Error e) {
            warning (e.message);
        }
    }

    public override void directory_loaded (Gtk.ApplicationWindow window, Files.AbstractSlot view, Files.File directory) {
        current_directory = directory;
    }

    private void add_menuitem (Gtk.Menu menu, Gtk.MenuItem menu_item) {
        menu.append (menu_item);
        menu_item.show ();
        plugins.menuitem_references.add (menu_item);
    }

    private static string[] get_mimetypes (List<Files.File> files) {
        string[] mimetypes = new string[0];

        foreach (unowned Files.File file in files) {
            var ftype = file.get_ftype ();

            if (ftype != null) {
                mimetypes += ftype;
            }
        }

        return mimetypes;
    }

    private static GLib.File[] get_file_array (List<Files.File> files) {
        GLib.File[] file_array = new GLib.File[0];

        foreach (unowned Files.File file in files) {
            if (file.location != null) {
                if (file.location.get_uri_scheme () == "recent") {
                    file_array += GLib.File.new_for_uri (file.get_display_target_uri ());
                } else {
                    file_array += file.location;
                }
            }
        }

        return file_array;
    }
}

public Files.Plugins.Base module_init () {
    return new Files.Plugins.Contractor ();
}
