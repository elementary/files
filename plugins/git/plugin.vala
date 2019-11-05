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
    public GLib.HashTable<GLib.File, Ggit.Repository> repo_map;

    public Git () {
        repo_map = new GLib.HashTable<GLib.File, Ggit.Repository> (GLib.File.hash, GLib.File.equal);
    }

    public override void directory_loaded (Gtk.ApplicationWindow window, GOF.AbstractSlot view, GOF.File directory) {
        try {
            var key = directory.location;
            var gitdir = Ggit.Repository.discover (key);
            var git_repo = Ggit.Repository.open (gitdir);
            if (git_repo != null && !(repo_map.contains (key))) {
                repo_map.insert (key, (owned)git_repo);
            }
        } catch (Error e) {
            /* An error is normal if the directory is not a git repo */
            debug ("Error opening git repository at %s - %s", directory.uri, e.message);
        }
    }

    public override void update_file_info (GOF.File file) {
        /* Ignore e.g. .git and .githib folders, but include e.g. .travis.yml file */
        if (file.is_hidden && file.is_directory) {
            return;
        }

        Ggit.Repository git_repo = repo_map.lookup (file.directory);

        if (git_repo != null) {
            string file_path = file.location.get_path ();
            /* Ignore other files specified by .gitignore */
            try {
                if (git_repo.path_is_ignored (file_path)) {
                    return;
                }
            } catch (GLib.Error e) {
                return; /* If this fails then unlikely to be able to get git_status */
            }

            Ggit.StatusFlags new_flag = Ggit.StatusFlags.CURRENT;
            try {
                if (file.is_directory) {
                    var pathspec = "*".concat (file.basename, "*");
                    git_repo.file_status_foreach (new Ggit.StatusOptions (0, Ggit.StatusShow.WORKDIR_ONLY, {pathspec}), (path, status_flags) => {
                        switch (status_flags) {
                            case Ggit.StatusFlags.WORKING_TREE_NEW:
                            case Ggit.StatusFlags.WORKING_TREE_MODIFIED:
                                if (new_flag != Ggit.StatusFlags.WORKING_TREE_NEW) {
                                    new_flag = Ggit.StatusFlags.WORKING_TREE_MODIFIED;
                                }
                                return 0;
                            default:
                                if (new_flag != Ggit.StatusFlags.WORKING_TREE_NEW &&
                                    new_flag != Ggit.StatusFlags.WORKING_TREE_MODIFIED) {
                                    new_flag = status_flags;
                                }

                                return 0;
                        }
                    });
                } else {
                    new_flag = git_repo.file_status (file.location);
                }
            } catch (Error e) {
                critical ("Error getting git status for %s: %s", file.location.get_path (), e.message);
            }

            switch (new_flag) {
                case Ggit.StatusFlags.CURRENT:
                    break;

                case Ggit.StatusFlags.INDEX_MODIFIED:
                case Ggit.StatusFlags.WORKING_TREE_MODIFIED:
                    file.add_emblem ("user-away");
                    break;

                case Ggit.StatusFlags.WORKING_TREE_NEW:
                    file.add_emblem ("user-available");
                    break;

                default:
                    break;
            }
        }
    }
}

public Marlin.Plugins.Base module_init () {
    Ggit.init ();
    var plug = new Marlin.Plugins.Git ();
    return plug;
}
