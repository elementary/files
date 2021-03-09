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

    public class Marlin.GitRepoInfo : Object {
        public Ggit.Repository repo { get; construct; }
        public HashTable<string, Ggit.StatusFlags> status_map { get; construct; }
        static Ggit.StatusOptions status_options;

        static construct {
            status_options = new Ggit.StatusOptions (Ggit.StatusOption.DEFAULT,
                                                     Ggit.StatusShow.INDEX_AND_WORKDIR,
                                                     {});
        }

        construct {
            status_map = new HashTable<string, Ggit.StatusFlags> (str_hash, str_equal);
            get_status_list ();
        }

        public GitRepoInfo (Ggit.Repository _repo) {
            Object (repo: _repo);

        }

        public bool get_status_list () {
            status_map.remove_all ();

            try {
                repo.file_status_foreach (status_options,
                                          (path, status_flags) => {

                    status_map.insert (path, status_flags);
                    return 0;
                });
            } catch (Error e) {
                warning ("Error getting status: %s", e.message);
                return false;
            }

            return true;
        }

        public Ggit.StatusFlags? lookup_status (string path) {
            var result = Ggit.StatusFlags.CURRENT;
            status_map.@foreach ((k, v) => {
                if (k.has_prefix (path)) {
                    result = v;
                }
            });

            return result;
        }
    }

    public struct Marlin.GitRepoChildInfo {
         string repo_uri;
         string rel_path;
    }


public class Marlin.Plugins.Git : Marlin.Plugins.Base {
    private const string EXCLUDED_FS_TYPES = "fuse"; // Filesystems such sshfs and ntfs return this type
    private HashTable<string, Marlin.GitRepoInfo?> repo_map;
    private HashTable<string, Marlin.GitRepoChildInfo?> child_map;

    public Git () {
        repo_map = new GLib.HashTable<string, Marlin.GitRepoInfo?> (str_hash, str_equal);
        child_map = new HashTable<string, Marlin.GitRepoChildInfo?> (str_hash, str_equal);
    }

    public override void directory_loaded (Gtk.ApplicationWindow window, GOF.AbstractSlot view, GOF.File directory) {

        if (!view.directory.is_local) {
            debug ("Git plugin ignoring non-local folder");
            return;
        }

        FileInfo info;
        try {
            info = directory.get_target_location ().query_filesystem_info (FileAttribute.FILESYSTEM_TYPE);
            if (!info.has_attribute (FileAttribute.FILESYSTEM_TYPE)) {
                debug ("GIT PLUGIN: no filesystem type info - ignoring");
                return;
            }

            unowned string fs_type = info.get_attribute_string (FileAttribute.FILESYSTEM_TYPE);
            if (EXCLUDED_FS_TYPES.contains (fs_type)) {
                warning ("GIT PLUGIN: excluded filesystem type %s", fs_type);
                return;
            }
        } catch (GLib.Error error) {
            if (!(error is IOError.CANCELLED)) {
                warning ("GIT PLUGIN: Error querying %s filesystem info: %s", directory.uri, error.message);
            }

            return;
        }

        if (info == null || !info.has_attribute (FileAttribute.FILESYSTEM_TYPE)) {
            debug ("GIT PLUGIN: no filesystem type info - ignoring");
            return;
        }

        unowned string fs_type = info.get_attribute_string (FileAttribute.FILESYSTEM_TYPE);
        if (EXCLUDED_FS_TYPES.contains (fs_type)) {
            warning ("GIT PLUGIN: excluded filesystem type %s", fs_type);
            return;
        }

        var dir_uri = directory.uri;
        var repo_uri = "";

        try {
            var key = directory.location;
            if (key.get_path () == null) { //e.g. for network://
                return;
            }

            var gitdir = Ggit.Repository.discover (key);
            if (gitdir != null) {
                repo_uri = gitdir.get_uri ();
                Marlin.GitRepoInfo? repo_info = repo_map.lookup (repo_uri);
                if (repo_info == null) {
                    var git_repo = Ggit.Repository.open (gitdir);
                    repo_info = new Marlin.GitRepoInfo (git_repo);
                    repo_map.insert (repo_uri, repo_info);
                } else {
                }

                if (!child_map.contains (dir_uri)) {
                    var rel_path = repo_info.repo.location.get_parent ().get_relative_path (directory.location);
                    if (rel_path != null) {
                        rel_path = rel_path + Path.DIR_SEPARATOR_S;
                    } else {
                        rel_path = "";
                    }
                    Marlin.GitRepoChildInfo child_info = { repo_uri, rel_path };
                    child_map.insert (dir_uri, child_info);
                } else {
                }
            }
        } catch (Error e) {
            /* An error is normal if the directory is not a git repo */
            debug ("Error opening git repository at %s: %s", directory.uri, e.message);
        }
    }

    public override void update_file_info (GOF.File gof) {
        /* Ignore e.g. .git and .githib folders, but include e.g. .travis.yml file */
        if (gof.is_hidden && gof.is_directory) {
            return;
        }

        var child_info = child_map.lookup (gof.directory.get_uri ());
        if (child_info == null) {
            return;
        }

        Marlin.GitRepoInfo? repo_info = repo_map.lookup (child_info.repo_uri);

        if (repo_info != null) {
            var rel_path = child_info.rel_path + gof.basename;
            if (rel_path != null) {
                var git_status = repo_info.lookup_status (rel_path);
                if (git_status != null) {
                    switch (git_status) {
                        case Ggit.StatusFlags.CURRENT:
                            break;

                        case Ggit.StatusFlags.INDEX_MODIFIED:
                        case Ggit.StatusFlags.WORKING_TREE_MODIFIED:
                            gof.add_emblem ("user-away");
                            break;

                        case Ggit.StatusFlags.WORKING_TREE_NEW:
                            gof.add_emblem ("user-available");
                            break;

                        default:
                            break;
                    }
                }
            } else {
                critical ("Relative path is null");
            }
        }
    }
}

public Marlin.Plugins.Base module_init () {
    Ggit.init ();
    var plug = new Marlin.Plugins.Git ();
    return plug;
}
