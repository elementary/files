/***
    Copyright (c) 2019 elementary LLC <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/

public class Marlin.Plugins.Git : Marlin.Plugins.Base {
    public override void update_file_info (GOF.File file) {
        Ggit.Repository? git_repo;
        /* Ignore e.g. .git and .githib folders, but include e.g. .travis.yml file */
        if (file.is_hidden && file.is_directory) {
            return;
        }

        if (file.is_in_git_repo (out git_repo)) {
            file.git_status = update_git_status (file.location, git_repo, file.is_directory);
        }
    }

    private Ggit.StatusFlags update_git_status (GLib.File location, Ggit.Repository git_repo, bool is_directory) {
        Ggit.StatusFlags status = Ggit.StatusFlags.CURRENT;
        if (!is_directory) {
            try {
                status = git_repo.file_status (location);
            } catch (Error e) {
                critical ("Error getting git status for %s: %s", location.get_path (), e.message);
            }
        } else {
            bool modified = false;
            bool ignored = true;
            bool new_file = false;

            GLib.FileInfo? child_info = null;
            try {
                var e = location.enumerate_children ("standard*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);
                child_info = e.next_file ();
                while (child_info != null) {

                    var child = location.get_child (child_info.get_name ());
                    var child_status = update_git_status (child, git_repo, (child_info.get_file_type () == GLib.FileType.DIRECTORY));

                    switch (child_status) {
                        case Ggit.StatusFlags.INDEX_MODIFIED:
                        case Ggit.StatusFlags.WORKING_TREE_MODIFIED:
                            return Ggit.StatusFlags.WORKING_TREE_MODIFIED;

                        case Ggit.StatusFlags.WORKING_TREE_NEW:
                            new_file = true;
                            break;

                        case Ggit.StatusFlags.IGNORED:
                            break;

                        default:
                            ignored = false;
                            break;
                    }

                    child_info = e.next_file ();
                }
            } catch (Error e) {
                warning ("Error enumerating %s", e.message);
            }

            if (modified) {
                status = Ggit.StatusFlags.WORKING_TREE_MODIFIED;
            } else if (new_file) {
                status = Ggit.StatusFlags.WORKING_TREE_NEW;
            } else if (ignored) {
                status = Ggit.StatusFlags.IGNORED;
            }
        }

        return status;
    }

    public override void context_menu (Gtk.Widget? widget, GLib.List<GOF.File> selected_files) {
        if (selected_files.length () != 1) {
            return;
        }

        var gof = selected_files.data;
        Ggit.Repository? git_repo = null;

        if ((gof.is_hidden && gof.is_directory) || !gof.is_in_git_repo (out git_repo)) {
            return;
        }

        var menu = widget as Gtk.Menu;
        var git_menu_item = new Gtk.MenuItem.with_label ("Git Information");
        git_menu_item.activate.connect (show_git_info);

        add_menuitem (menu, new Gtk.SeparatorMenuItem ());
        add_menuitem (menu, git_menu_item);
    }

    private void add_menuitem (Gtk.Menu menu, Gtk.MenuItem menu_item) {
        menu.append (menu_item);
        menu_item.show ();
    }

    private void show_git_info () {
warning ("Show git info");
    }
}

public Marlin.Plugins.Base module_init () {
    return new Marlin.Plugins.Git ();
}
