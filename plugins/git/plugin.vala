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
                warning ("Error getting status %s", e.message);
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

    public struct CloneData {
        string origin_uri;
        GLib.File target;
        string result;
    }

    public class GitCloner : Object {
        public string origin_uri {get; construct;}
        public GLib.File target {get; construct;}
        public Cancellable cancellable {get; construct;}
        public string status {get; private set; default = _("Ready");}

        construct {
            cancellable = new Cancellable ();
        }

        public GitCloner (string uri, GLib.File location) {
            Object (origin_uri: uri, target: location);
        }

        public async void clone (AsyncReadyCallback cb) {
            var clone_task = new Task (this, cancellable, cb);

            CloneData clone_data = {origin_uri, target};

            clone_task.set_task_data (&clone_data, null);
            clone_task.set_return_on_cancel (true);
            clone_task.run_in_thread (task_thread_func);
            yield;
        }

        static void task_thread_func (Task task, Object source, CloneData* clone_data, Cancellable? cancellable = null) {
            try {
                clone_data.result = _("Cloning cancelled");
                Ggit.Repository.clone (clone_data.origin_uri, clone_data.target, null);
                clone_data.result = _("Cloning succeeded");
                task.return_boolean (true);
            } catch (Error err) {
                clone_data.result = _("Cloning failed: %s").printf (err.message);
                task.return_error (err);
            }
        }
    }

public class Marlin.Plugins.Git : Marlin.Plugins.Base {
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
            debug ("Error opening git repository at %s - %s", directory.uri, e.message);
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

    public override void context_menu (Gtk.Widget? widget, List<GOF.File> files, GOF.AbstractSlot? slot = null) {
        unowned Gtk.Menu? menu = (Gtk.Menu)widget;
        if (slot == null || menu == null) {
            return;
        }

        /* Need a single folder selected for cloning into */
        if (files.first == null || files.next != null) {
            return;
        }

        GOF.File target = files.first ().data;
        if (!target.is_directory) {
            return;
        }

        var target_uri = Uri.unescape_string (target.uri);

        /* Clipboard must contain a single git url */
        var clipboard = Gtk.Clipboard.get_default (Gdk.Display.get_default ());

        string? uri = clipboard.wait_for_text ();

        if (uri == null || !uri.has_suffix (".git")) {
            return;
        }

        add_menuitem (menu, new Gtk.SeparatorMenuItem ());

        var clone_item = new Gtk.MenuItem.with_label (_("Clone into folder"));
        add_menuitem (menu, clone_item);

        clone_item.activate.connect (() => {
            var cloner = new GitCloner (uri, target.location);
            var info_bar = new Gtk.InfoBar ();
            info_bar.set_message_type (Gtk.MessageType.OTHER);
            //TODO Set correct styling
            var info_message_label = new Gtk.Label (_("Cloning - please wait"));
            info_message_label.set_ellipsize (Pango.EllipsizeMode.END);
            info_message_label.max_width_chars = 50;
            info_message_label.hexpand = true;
            var spinner = new Gtk.Spinner ();
            var message_grid = new Gtk.Grid ();
            message_grid.orientation = Gtk.Orientation.HORIZONTAL;
            message_grid.column_spacing = 12;
            message_grid.column_homogeneous = false;
            message_grid.add (info_message_label);
            message_grid.add (spinner);
            message_grid.halign = Gtk.Align.START;

            var cancel_button = new Gtk.Button.with_label (_("Cancel"));
            cancel_button.vexpand = false;
            cancel_button.halign = Gtk.Align.END;
            cancel_button.clicked.connect (() => {
                if (!cloner.cancellable.is_cancelled ()) {
                    cloner.cancellable.cancel ();
                }
            });

            info_bar.get_content_area ().add (message_grid);
            info_bar.get_content_area ().add (cancel_button);
            info_bar.show_all ();
            slot.add_extra_widget (info_bar);
            spinner.start ();

            cloner.clone.begin ((obj, res) => {
                spinner.stop ();
                spinner.hide ();
                var task = (Task)res;
                CloneData* task_data = task.get_task_data ();
                info_message_label.label = cloner.cancellable.is_cancelled () ? _("Cancelled") : task_data.result;
                cancel_button.label = _("Close");
                cancel_button.clicked.connect (() => {
                    info_bar.destroy ();
                });

                if (cloner.cancellable.is_cancelled ()) {
                    var git_file = File.new_for_uri (string.join (Path.DIR_SEPARATOR_S, target_uri, ".git"));
                    try {
                        git_file.trash (null);
                    } catch (Error e) {
                        warning ("Error trying to trash git folder %s", e.message);
                    }
                }

                if (!task.had_error ()) {
                    //TODO Animation
                    Timeout.add_seconds (2, () => {info_bar.destroy (); return Source.REMOVE;});
                } else {
                    info_bar.message_type = Gtk.MessageType.WARNING;
                }
            });
        });
    }

    private void add_menuitem (Gtk.Menu menu, Gtk.MenuItem menu_item) {
        menu.append (menu_item);
        menu_item.show ();
        plugins.menuitem_references.add (menu_item);
    }
}

public Marlin.Plugins.Base module_init () {
    Ggit.init ();
    var plug = new Marlin.Plugins.Git ();
    return plug;
}
