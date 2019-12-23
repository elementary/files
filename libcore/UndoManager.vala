namespace Marlin {
    [CCode (cprefix = "MARLIN_UNDO_")]
    public enum UndoActionType {
        COPY,
        DUPLICATE,
        MOVE,
        RENAME,
        CREATEEMPTYFILE,
        CREATEFILEFROMTEMPLATE,
        CREATEFOLDER,
        MOVETOTRASH,
        CREATELINK,
        DELETE,
        RESTOREFROMTRASH,
        SETPERMISSIONS,
        RECURSIVESETPERMISSIONS,
        CHANGEOWNER,
        CHANGEGROUP
    }

    public class UndoMenuData {
        public unowned string undo_label;
        public unowned string undo_description;
        public unowned string redo_label;
        public unowned string redo_description;
    }

    public class UndoActionData {
        /* Common stuff */
        public Marlin.UndoActionType action_type;
        public bool is_valid;
        public bool locked;                        /* True if the action is being undone/redone */
        public bool freed;                         /* True if the action must be freed after undo/redo */
        public uint count;                         /* Size of affected uris (count of items) */
        public unowned Marlin.UndoManager manager; /* Pointer to the manager */

        /* Copy / Move stuff */
        public GLib.File src_dir;
        public GLib.File dest_dir;
        public GLib.List<string> sources;      /* Relative to src_dir */
        public GLib.List<string> destinations; /* Relative to dest_dir */

        /* Cached labels/descriptions */
        public string undo_label;
        public string undo_description;
        public string redo_label;
        public string redo_description;

        /* Create new file/folder stuff/set permissions */
        public string template;
        public string target_uri;

        /* Rename stuff */
        public string old_uri;
        public string new_uri;

        /* Trash stuff */
        public GLib.HashTable<string, uint64?> trashed;

        /* Recursive change permissions stuff */
        public GLib.HashTable<string, uint32?> original_permissions;
        public uint32 dir_mask;
        public uint32 dir_permissions;
        public uint32 file_mask;
        public uint32 file_permissions;

        /* Single file change permissions stuff */
        public uint32 current_permissions;
        public uint32 new_permissions;

        /* Group */
        public string original_group_name_or_id;
        public string new_group_name_or_id;

        /* Owner */
        public string original_user_name_or_id;
        public string new_user_name_or_id;

        public UndoActionData (Marlin.UndoActionType action_type, int items_count) {
            this.action_type = action_type;
            this.count = items_count;

            if (action_type == UndoActionType.MOVETOTRASH) {
                this.trashed = new HashTable<string, uint64?> (str_hash, str_equal);
            }
        }

        public void set_src_dir (GLib.File src) {
            this.src_dir = src;
        }

        public void set_dest_dir (GLib.File dest) {
            this.dest_dir = dest;
        }

        public void add_origin_target_pair (GLib.File origin, GLib.File target) {
            sources.prepend (src_dir.get_relative_path (origin));
            destinations.prepend (dest_dir.get_relative_path (target));

            is_valid = true;
        }

        public void set_create_data (string target_uri, string template) {
            this.template = template;
            this.target_uri = target_uri;

            is_valid = true;
        }

        public void set_rename_information (GLib.File old_file, GLib.File new_file) {
            this.old_uri = old_file.get_uri ();
            this.new_uri = new_file.get_uri ();

            is_valid = true;
        }

        public void add_trashed_file (GLib.File file, uint64 mtime) {
            trashed.insert (file.get_uri (), mtime);
            is_valid = true;
        }

        // Pushes a recursive permission change data in an existing undo data container
        public void add_file_permissions (GLib.File file, uint32 permission) {
            original_permissions.insert (file.get_uri (), permission);
            is_valid = true;
        }

        public void set_recursive_permissions (uint32 file_permissions, uint32 file_mask,
                                               uint32 dir_permissions, uint32 dir_mask) {
            this.file_permissions = file_permissions;
            this.file_mask = file_mask;
            this.dir_permissions = dir_permissions;
            this.dir_mask = dir_mask;

            is_valid = true;
        }

        public void set_file_permissions (string uri, uint32 current_permissions, uint32 new_permissions) {
            target_uri = uri;

            this.current_permissions = current_permissions;
            this.new_permissions = new_permissions;

            is_valid = true;
        }


        public void set_owner_change_information (string uri, string current_user, string new_user) {
            target_uri = uri;

            original_user_name_or_id = current_user;
            new_user_name_or_id = new_user;

            is_valid = true;
        }

        public void set_group_change_information (string uri, string current_group, string new_group) {
            target_uri = uri;

            original_group_name_or_id = current_group;
            new_group_name_or_id = new_group;

            is_valid = true;
        }

        internal GLib.HashTable<GLib.File, string>? retrieve_files_to_restore () {
            if (trashed.size () <= 0) {
                return null;
            }

            var to_restore = new GLib.HashTable<GLib.File, string> (direct_hash, direct_equal);
            var trash = GLib.File.new_for_uri ("trash:");
            try {
                var enumerator = trash.enumerate_children (GLib.FileAttribute.STANDARD_NAME + "," + GLib.FileAttribute.TIME_MODIFIED + "," + GLib.FileAttribute.TRASH_ORIG_PATH, GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                GLib.FileInfo? info = null;
                while ((info = enumerator.next_file ()) != null) {
                    unowned string? origpath = info.get_attribute_byte_string (GLib.FileAttribute.TRASH_ORIG_PATH);
                    if (origpath != null) {
                        var origfile = GLib.File.new_for_path (origpath);
                        var origuri = origfile.get_uri ();
                        uint64? mtime = trashed.lookup (origuri);
                        if (mtime != null) {
                            uint64 mtime_item = info.get_attribute_uint64 (GLib.FileAttribute.TIME_MODIFIED);
                            if (mtime == mtime_item) {
                                to_restore.insert (trash.get_child (info.get_name ()), origuri);
                            }
                        }
                    }
                }
            } catch (Error e) {
                critical ("%s", e.message);
            }

            return to_restore;
        }

        public unowned string get_first_target_short_name () {
            return destinations.first ().data;
        }

        public unowned string get_undo_description () {
            if (undo_description != null) {
                return undo_description;
            }

            switch (action_type) {
                case Marlin.UndoActionType.COPY:
                    if (count == 1) {
                        undo_description = _("Delete '%s'").printf (get_first_target_short_name ());
                    } else {
                        undo_description = _("Delete %u copied items").printf (count);
                    }
                    break;
                case Marlin.UndoActionType.DUPLICATE:
                    if (count == 1) {
                        undo_description = _("Delete '%s'").printf (get_first_target_short_name ());
                    } else {
                        undo_description = _("Delete %u duplicated items").printf (count);
                    }
                    break;
                case Marlin.UndoActionType.MOVE:
                    var source = src_dir.get_path ();
                    if (count == 1) {
                        undo_description = _("Move '%s' back to '%s'").printf (get_first_target_short_name (), source);
                    } else {
                        undo_description = _("Move %u items back to '%s'").printf (count, source);
                    }
                    break;
                case Marlin.UndoActionType.RENAME:
                    var from_name = GLib.Path.get_basename (new_uri);
                    var to_name = GLib.Path.get_basename (old_uri);
                    undo_description = _("Rename '%s' as '%s'").printf (from_name, to_name);
                    break;
                case Marlin.UndoActionType.CREATEEMPTYFILE:
                case Marlin.UndoActionType.CREATEFOLDER:
                    undo_description = _("Delete '%s'").printf (GLib.Path.get_basename (target_uri));
                    break;
                case Marlin.UndoActionType.MOVETOTRASH:
                    if (trashed.size () == 1) {
                        unowned string item = trashed.get_keys ().data;
                        var name = GLib.Path.get_basename (item);
                        var orig_path = PF.FileUtils.get_parent_path_from_path (item);
                        undo_description = _("Restore '%s' to '%s'").printf (name, orig_path);
                    } else {
                        undo_description = _("Restore %u items from trash").printf (count);
                    }
                    break;
                case Marlin.UndoActionType.RESTOREFROMTRASH:
                    if (count == 1) {
                        undo_description = _("Move '%s' back to trash").printf (get_first_target_short_name ());
                    } else {
                        undo_description = _("Move %u items back to trash").printf (count);
                    }
                    break;
                case Marlin.UndoActionType.CREATELINK:
                    if (count == 1) {
                        undo_description = _("Delete link to '%s'").printf (get_first_target_short_name ());
                    } else {
                        undo_description = _("Delete links to %u items").printf (count);
                    }
                    break;
                case Marlin.UndoActionType.RECURSIVESETPERMISSIONS:
                    undo_description = _("Restore original permissions of items enclosed in '%s'").printf (dest_dir.get_path ());
                    break;
                case Marlin.UndoActionType.SETPERMISSIONS:
                    undo_description = _("Restore original permissions of '%s'").printf (GLib.Path.get_basename (target_uri));
                    break;
                case Marlin.UndoActionType.CHANGEGROUP:
                    undo_description = _("Restore group of '%s' to '%s'").printf (GLib.Path.get_basename (target_uri), original_group_name_or_id);
                    break;
                case Marlin.UndoActionType.CHANGEOWNER:
                    undo_description = _("Restore owner of '%s' to '%s'").printf (GLib.Path.get_basename (target_uri), original_user_name_or_id);
                    break;
                default:
                    critical ("Unhandled undo action: %s", action_type.to_string ());
                    break;
            }

            return undo_description;
        }

        public unowned string get_redo_description () {
            if (redo_description != null) {
                return redo_description;
            }

            switch (action_type) {
                case Marlin.UndoActionType.COPY:
                    var destination = dest_dir.get_path ();
                    if (count == 1) {
                        redo_description = _("Copy '%s' to '%s'").printf (get_first_target_short_name (), destination);
                    } else {
                        redo_description = _("Copy %u items to '%s'").printf (count, destination);
                    }
                    break;
                case Marlin.UndoActionType.DUPLICATE:
                    var destination = dest_dir.get_path ();
                    if (count == 1) {
                        redo_description = _("Duplicate '%s' in '%s'").printf (get_first_target_short_name (), destination);
                    } else {
                        redo_description = _("Duplicate of %u items in '%s'").printf (count, destination);
                    }
                    break;
                case Marlin.UndoActionType.MOVE:
                    var destination = dest_dir.get_path ();
                    if (count == 1) {
                        redo_description = _("Move '%s' to '%s'").printf (get_first_target_short_name (), destination);
                    } else {
                        redo_description = _("Move %u items to '%s'").printf (count, destination);
                    }
                    break;
                case Marlin.UndoActionType.RENAME:
                    var from_name = GLib.Path.get_basename (old_uri);
                    var to_name = GLib.Path.get_basename (new_uri);
                    redo_description = _("Rename '%s' as '%s'").printf (from_name, to_name);
                    break;
                case Marlin.UndoActionType.CREATEFILEFROMTEMPLATE:
                    redo_description = _("Create new file '%s' from template ").printf (GLib.Path.get_basename (target_uri));
                    break;
                case Marlin.UndoActionType.CREATEEMPTYFILE:
                    redo_description = _("Create an empty file '%s'").printf (GLib.Path.get_basename (target_uri));
                    break;
                case Marlin.UndoActionType.CREATEFOLDER:
                    redo_description = _("Create a new folder '%s'").printf (GLib.Path.get_basename (target_uri));
                    break;
                case Marlin.UndoActionType.MOVETOTRASH:
                    if (trashed.size () == 1) {
                        unowned string item = trashed.get_keys ().data;
                        var name = GLib.Path.get_basename (item);
                        redo_description = _("Move '%s' to trash").printf (name);
                    } else {
                        redo_description = _("Move %u items to trash").printf (count);
                    }
                    break;
                case Marlin.UndoActionType.RESTOREFROMTRASH:
                    if (count == 1) {
                        redo_description = _("Restore '%s' from trash").printf (get_first_target_short_name ());
                    } else {
                        redo_description = _("Restore %u items from trash").printf (count);
                    }
                    break;
                case Marlin.UndoActionType.CREATELINK:
                    if (count == 1) {
                        redo_description = _("Create link to '%s'").printf (get_first_target_short_name ());
                    } else {
                        redo_description = _("Create links to %u items").printf (count);
                    }
                    break;
                case Marlin.UndoActionType.RECURSIVESETPERMISSIONS:
                    redo_description = _("Set permissions of items enclosed in '%s'").printf (dest_dir.get_path ());
                    break;
                case Marlin.UndoActionType.SETPERMISSIONS:
                    redo_description = _("Set permissions of '%s'").printf (GLib.Path.get_basename (target_uri));
                    break;
                case Marlin.UndoActionType.CHANGEGROUP:
                    redo_description = _("Set group of '%s' to '%s'").printf (GLib.Path.get_basename (target_uri), new_group_name_or_id);
                    break;
                case Marlin.UndoActionType.CHANGEOWNER:
                    redo_description = _("Set owner of '%s' to '%s'").printf (GLib.Path.get_basename (target_uri), new_user_name_or_id);
                    break;
                default:
                    critical ("Unhandled redo action: %s", action_type.to_string ());
                    break;
            }

            return redo_description;
        }

        public unowned string get_undo_label () {
            if (undo_label != null) {
                return undo_label;
            }

            switch (action_type) {
                case Marlin.UndoActionType.COPY:
                    undo_label = ngettext ("_Undo copy of %u item",
                                           "_Undo copy of %u items", count).printf (count);
                    break;
                case Marlin.UndoActionType.DUPLICATE:
                    undo_label = ngettext ("_Undo duplicate of %u item",
                                           "_Undo duplicate of %u items", count).printf (count);
                    break;
                case Marlin.UndoActionType.MOVE:
                    undo_label = ngettext ("_Undo move of %u item",
                                           "_Undo move of %u items", count).printf (count);
                    break;
                case Marlin.UndoActionType.RENAME:
                    undo_label = ngettext ("_Undo rename of %u item",
                                           "_Undo rename of %u items", count).printf (count);
                    break;
                case Marlin.UndoActionType.CREATEFILEFROMTEMPLATE:
                    undo_label = _("_Undo creation of a file from template");
                    break;
                case Marlin.UndoActionType.CREATEEMPTYFILE:
                    undo_label = _("_Undo creation of an empty file");
                    break;
                case Marlin.UndoActionType.CREATEFOLDER:
                    undo_label = ngettext ("_Undo creation of %u folder",
                                           "_Undo creation of %u folders", count).printf (count);
                    break;
                case Marlin.UndoActionType.MOVETOTRASH:
                    undo_label = ngettext ("_Undo move to trash of %u item",
                                           "_Undo move to trash of %u items", count).printf (count);
                    break;
                case Marlin.UndoActionType.RESTOREFROMTRASH:
                    undo_label = ngettext ("_Undo restore from trash of %u item",
                                           "_Undo restore from trash of %u items", count).printf (count);
                    break;
                case Marlin.UndoActionType.CREATELINK:
                    undo_label = ngettext ("_Undo create link to %u item",
                                           "_Undo create link to %u items", count).printf (count);
                    break;
                case Marlin.UndoActionType.DELETE:
                    undo_label = ngettext ("_Undo delete of %u item",
                                           "_Undo delete of %u items", count).printf (count);
                    break;
                case Marlin.UndoActionType.RECURSIVESETPERMISSIONS:
                    undo_label = ngettext ("Undo recursive change permissions of %u item",
                                           "Undo recursive change permissions of %u items", count).printf (count);
                    break;
                case Marlin.UndoActionType.SETPERMISSIONS:
                    undo_label = ngettext ("Undo change permissions of %u item",
                                           "Undo change permissions of %u items", count).printf (count);
                    break;
                case Marlin.UndoActionType.CHANGEGROUP:
                    undo_label = ngettext ("Undo change group of %u item",
                                           "Undo change group of %u items", count).printf (count);
                    break;
                case Marlin.UndoActionType.CHANGEOWNER:
                    undo_label = ngettext ("Undo change owner of %u item",
                                           "Undo change owner of %u items", count).printf (count);
                    break;
                default:
                    critical ("Unhandled undo action: %s", action_type.to_string ());
                    break;
            }

            return undo_label;
        }

        public unowned string get_redo_label () {
            if (redo_label != null) {
                return redo_label;
            }

            switch (action_type) {
                case Marlin.UndoActionType.COPY:
                    redo_label = ngettext ("_Redo copy of %u item",
                                           "_Redo copy of %u items", count).printf (count);
                    break;
                case Marlin.UndoActionType.DUPLICATE:
                    redo_label = ngettext ("_Redo duplicate of %u item",
                                           "_Redo duplicate of %u items", count).printf (count);
                    break;
                case Marlin.UndoActionType.MOVE:
                    redo_label = ngettext ("_Redo move of %u item",
                                           "_Redo move of %u items", count).printf (count);
                    break;
                case Marlin.UndoActionType.RENAME:
                    redo_label = ngettext ("_Redo rename of %u item",
                                           "_Redo rename of %u items", count).printf (count);
                    break;
                case Marlin.UndoActionType.CREATEFILEFROMTEMPLATE:
                    redo_label = _("_Redo creation of a file from template");
                    break;
                case Marlin.UndoActionType.CREATEEMPTYFILE:
                    redo_label = _("_Redo creation of an empty file");
                    break;
                case Marlin.UndoActionType.CREATEFOLDER:
                    redo_label = ngettext ("_Redo creation of %u folder",
                                           "_Redo creation of %u folders", count).printf (count);
                    break;
                case Marlin.UndoActionType.MOVETOTRASH:
                    redo_label = ngettext ("_Redo move to trash of %u item",
                                           "_Redo move to trash of %u items", count).printf (count);
                    break;
                case Marlin.UndoActionType.RESTOREFROMTRASH:
                    redo_label = ngettext ("_Redo restore from trash of %u item",
                                           "_Redo restore from trash of %u items", count).printf (count);
                    break;
                case Marlin.UndoActionType.CREATELINK:
                    redo_label = ngettext ("_Redo create link to %u item",
                                           "_Redo create link to %u items", count).printf (count);
                    break;
                case Marlin.UndoActionType.DELETE:
                    redo_label = ngettext ("_Redo delete of %u item",
                                           "_Redo delete of %u items", count).printf (count);
                    break;
                case Marlin.UndoActionType.RECURSIVESETPERMISSIONS:
                    redo_label = ngettext ("Redo recursive change permissions of %u item",
                                           "Redo recursive change permissions of %u items", count).printf (count);
                    break;
                case Marlin.UndoActionType.SETPERMISSIONS:
                    redo_label = ngettext ("Redo change permissions of %u item",
                                           "Redo change permissions of %u items", count).printf (count);
                    break;
                case Marlin.UndoActionType.CHANGEGROUP:
                    redo_label = ngettext ("Redo change group of %u item",
                                           "Redo change group of %u items", count).printf (count);
                    break;
                case Marlin.UndoActionType.CHANGEOWNER:
                    redo_label = ngettext ("Redo change owner of %u item",
                                           "Redo change owner of %u items", count).printf (count);
                    break;
                default:
                    critical ("Unhandled undo action: %s", action_type.to_string ());
                    break;
            }

            return undo_label;
        }
    }

    public class UndoManager : GLib.Object {
        private static UndoManager _instance;
        public static unowned UndoManager instance () {
            if (_instance == null)
                _instance = new UndoManager ();

            return _instance;
        }

        public signal void request_menu_update (UndoMenuData data);

        public uint undo_levels { get; construct set; default = 10; }
        public bool confirm_delete { get; construct set; default = false; }

        private GLib.Queue<Marlin.UndoActionData> stack;
        private uint index;
        private bool undo_redo_flag;

        construct {
            stack = new GLib.Queue<Marlin.UndoActionData> ();
        }

        public async bool undo (Gtk.Widget widget, GLib.Cancellable? cancellable = null) throws GLib.Error {
            Marlin.UndoActionData? action = null;
            lock (stack) {
                action = stack_scroll_right ();
                if (action != null) {
                    action.locked = true;
                }
            }

            do_menu_update ();
            if (action == null) {
                return true;
            }

            undo_redo_flag = true;
            switch (action.action_type) {
                case Marlin.UndoActionType.COPY:
                case Marlin.UndoActionType.DUPLICATE:
                case Marlin.UndoActionType.CREATELINK:
                    var uris = new GLib.List<GLib.File> ();
                    action.destinations.foreach ((uri) => uris.prepend (action.dest_dir.get_child (uri)));
                    uris.reverse (); // Deleting must be done in reverse
                    if (confirm_delete) {
                        try {
                            yield Marlin.FileOperations.@delete (uris, widget.get_toplevel () as Gtk.Window, false, cancellable);
                        } catch (Error e) {
                            undo_redo_done_transfer (action);
                            throw e;
                        }
                    } else {
                        foreach (unowned GLib.File file in uris) {
                            yield file.delete_async (GLib.Priority.DEFAULT, cancellable);
                            Marlin.FileChanges.queue_file_removed (file);
                        }

                        Marlin.FileChanges.consume_changes (true);
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Marlin.UndoActionType.MOVE:
                    var uris = new GLib.List<GLib.File> ();
                    action.destinations.foreach ((uri) => uris.prepend (action.dest_dir.get_child (uri)));
                    try {
                        yield Marlin.FileOperations.copy_move_link (uris, null, action.src_dir, Gdk.DragAction.MOVE, widget, cancellable);
                    } catch (Error e) {
                        undo_redo_done_transfer (action);
                        throw e;
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Marlin.UndoActionType.RENAME:
                    var file = GLib.File.new_for_uri (action.new_uri);
                    var new_name = GLib.Path.get_basename (action.old_uri);
                    try {
                        yield PF.FileUtils.set_file_display_name (file, new_name, cancellable);
                    } catch (Error e) {
                        undo_redo_done_transfer (action);
                        throw e;
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Marlin.UndoActionType.CREATEEMPTYFILE:
                case Marlin.UndoActionType.CREATEFOLDER:
                    var uris = new GLib.List<GLib.File> ();
                    uris.prepend (GLib.File.new_for_uri (action.target_uri));
                    if (confirm_delete) {
                        try {
                            yield Marlin.FileOperations.@delete (uris, widget.get_toplevel () as Gtk.Window, false, cancellable);
                        } catch (Error e) {
                            undo_redo_done_transfer (action);
                            throw e;
                        }
                    } else {
                        foreach (unowned GLib.File file in uris) {
                            yield file.delete_async (GLib.Priority.DEFAULT, cancellable);
                            Marlin.FileChanges.queue_file_removed (file);
                        }

                        Marlin.FileChanges.consume_changes (true);
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Marlin.UndoActionType.MOVETOTRASH:
                    GLib.HashTable<GLib.File, string>? files_to_restore = action.retrieve_files_to_restore ();
                    if (files_to_restore.size () > 0) {
                        files_to_restore.foreach ((key, val) => {
                            var dest = GLib.File.new_for_uri (val);
                            try {
                                key.move (dest, GLib.FileCopyFlags.NOFOLLOW_SYMLINKS, cancellable, null);
                                Marlin.FileChanges.queue_file_moved (key, dest);
                            } catch (Error e) {
                                critical (e.message);
                            }
                        });

                        Marlin.FileChanges.consume_changes (true);
                    } else {
                        PF.Dialogs.show_error_dialog (_("Original location could not be determined"),
                                                      _("Open trash folder and restore manually"),
                                                      widget.get_toplevel () as Gtk.Window);
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Marlin.UndoActionType.RESTOREFROMTRASH:
                    var uris = new GLib.List<GLib.File> ();
                    action.destinations.foreach ((uri) => uris.prepend (action.dest_dir.get_child (uri)));
                    try {
                        yield Marlin.FileOperations.@delete (uris, widget.get_toplevel () as Gtk.Window, false, cancellable);
                    } catch (Error e) {
                        undo_redo_done_transfer (action);
                        throw e;
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Marlin.UndoActionType.DELETE:
                    undo_redo_flag = false;
                    break; /* We shouldn't be here */
            }

            return true;
        }

        public async bool redo (Gtk.Widget widget, GLib.Cancellable? cancellable = null) throws GLib.Error {
            Marlin.UndoActionData? action = null;
            lock (stack) {
                action = stack_scroll_left ();
                if (action != null) {
                    action.locked = true;
                }
            }

            do_menu_update ();
            if (action == null) {
                return true;
            }

            undo_redo_flag = true;
            switch (action.action_type) {
                case Marlin.UndoActionType.COPY:
                case Marlin.UndoActionType.DUPLICATE:
                    var uris = new GLib.List<GLib.File> ();
                    action.sources.foreach ((uri) => uris.prepend (action.src_dir.get_child (uri)));
                    try {
                        yield Marlin.FileOperations.copy_move_link (uris, null, action.dest_dir, Gdk.DragAction.COPY, widget, cancellable);
                    } catch (Error e) {
                        undo_redo_done_transfer (action);
                        throw e;
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Marlin.UndoActionType.CREATELINK:
                    var uris = new GLib.List<GLib.File> ();
                    action.sources.foreach ((uri) => uris.prepend (action.src_dir.get_child (uri)));
                    try {
                        yield Marlin.FileOperations.copy_move_link (uris, null, action.dest_dir, Gdk.DragAction.LINK, widget, cancellable);
                    } catch (Error e) {
                        undo_redo_done_transfer (action);
                        throw e;
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Marlin.UndoActionType.MOVE:
                case Marlin.UndoActionType.RESTOREFROMTRASH:
                    var uris = new GLib.List<GLib.File> ();
                    action.sources.foreach ((uri) => uris.prepend (action.src_dir.get_child (uri)));
                    try {
                        yield Marlin.FileOperations.copy_move_link (uris, null, action.dest_dir, Gdk.DragAction.MOVE, widget, cancellable);
                    } catch (Error e) {
                        undo_redo_done_transfer (action);
                        throw e;
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Marlin.UndoActionType.RENAME:
                    var file = GLib.File.new_for_uri (action.new_uri);
                    var new_name = GLib.Path.get_basename (action.old_uri);
                    try {
                        yield PF.FileUtils.set_file_display_name (file, new_name, cancellable);
                    } catch (Error e) {
                        undo_redo_done_transfer (action);
                        throw e;
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Marlin.UndoActionType.CREATEEMPTYFILE:
                    var p_uri = GLib.File.new_for_uri (action.target_uri).get_parent ().get_uri ();
                    var new_name = GLib.Path.get_basename (action.target_uri);
                    try {
                        yield Marlin.FileOperations.new_file (widget.get_toplevel () as Gtk.Window, null, p_uri, new_name, action.template, 0, cancellable);
                    } catch (Error e) {
                        undo_redo_done_transfer (action);
                        throw e;
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Marlin.UndoActionType.CREATEFOLDER:
                    var fparent = GLib.File.new_for_uri (action.target_uri).get_parent ();
                    try {
                        yield Marlin.FileOperations.new_folder (widget.get_toplevel () as Gtk.Window, null, fparent, cancellable);
                    } catch (Error e) {
                        undo_redo_done_transfer (action);
                        throw e;
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Marlin.UndoActionType.MOVETOTRASH:
                    if (action.trashed.size () > 0) {
                        var uri_to_trash = action.trashed.get_keys ();
                        var uris = new GLib.List<GLib.File> ();
                        uri_to_trash.foreach ((uri) => uris.prepend (GLib.File.new_for_uri (uri)));
                        undo_redo_flag = true;
                        try {
                            yield Marlin.FileOperations.@delete (uris, widget.get_toplevel () as Gtk.Window, true, cancellable);
                        } catch (Error e) {
                            undo_redo_done_transfer (action);
                            throw e;
                        }
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Marlin.UndoActionType.DELETE:
                    undo_redo_flag = false;
                    break; /* We shouldn't be here */
            }

            return true;
        }

        public void add_action (owned Marlin.UndoActionData action) {
            if (!action.is_valid) {
                return;
            }

            action.manager = this;

            lock (stack) {
                stack_push_action ((owned) action);
            }

            do_menu_update ();
        }

        public void add_rename_action (GLib.File renamed_file, string original_name) {
            var data = new Marlin.UndoActionData (Marlin.UndoActionType.RENAME, 1);
            data.old_uri = renamed_file.get_parent ().get_child (original_name).get_uri ();
            data.new_uri = renamed_file.get_uri ();
            data.is_valid = true;

            add_action ((owned) data);
        }

        public bool is_undo_redo () {
            return undo_redo_flag;
        }

        public void trash_has_emptied () {
            lock (stack) {
                clear_redo_actions ();
                GLib.List<unowned string> trash = get_all_trashed_items ();
                stack.head.copy ().foreach ((action) => {
                    if (action.destinations != null && action.dest_dir != null) {
                        /* what a pain rebuild again and again an uri
                        ** TODO change the struct add uri elements */
                        var g = new GLib.List<GLib.File> ();
                        action.destinations.foreach ((uri) => g.prepend (action.dest_dir.get_child (uri)));
                        /* remove action for trashed item uris == destination action */
                        if (is_destination_uri_action_partof_trashed (trash, g)) {
                            stack.remove (action);
                            return;
                        }
                    }

                    if (action.action_type == Marlin.UndoActionType.MOVETOTRASH) {
                        stack.remove (action);
                    }
                });
            }

            do_menu_update ();
        }

        private void clear_redo_actions () {
            while (index > 0) {
                stack.pop_head ();
                index--;
            }
        }

        private void stack_clear_n_oldest (uint n) {
            for (uint i = 0; i < n; i++) {
                stack.pop_tail ();
            }
        }

        private void stack_fix_size () {
            uint length = stack.get_length ();
            if (length > undo_levels) {
                if (index > (undo_levels + 1)) {
                    /* If the index will fall off the stack
                     * move it back to the maximum position */
                    index = undo_levels + 1;
                }

                stack_clear_n_oldest (length - undo_levels);
            }
        }

        private void stack_push_action (owned Marlin.UndoActionData action) {
            clear_redo_actions ();

            stack.push_head ((owned) action);
            if (stack.get_length () > undo_levels) {
                stack_fix_size ();
            }
        }

        private unowned Marlin.UndoActionData? get_next_redo_action () {
            if (stack.is_empty ()) {
                return null;
            }

            if (index == 0) {
                /* ... no redo actions */
                return null;
            }

            unowned Marlin.UndoActionData action = stack.peek_nth (index - 1);
            if (action.locked) {
                return null;
            } else {
                return action;
            }
        }

        private unowned Marlin.UndoActionData? get_next_undo_action () {
            if (stack.is_empty ()) {
                return null;
            }

            if (index == stack.get_length ()) {
                /* ... no redo actions */
                return null;
            }

            unowned Marlin.UndoActionData action = stack.peek_nth (index);
            if (action.locked) {
                return null;
            } else {
                return action;
            }
        }

        private bool can_undo () {
            return (get_next_undo_action () != null);
        }

        private bool can_redo () {
            return (get_next_redo_action () != null);
        }

        private unowned Marlin.UndoActionData? stack_scroll_right () {
            if (!can_undo ()) {
                return null;
            }

            unowned Marlin.UndoActionData? data = stack.peek_nth (index);
            if (index < stack.get_length ()) {
                index++;
            }

            return data;
        }

        private unowned Marlin.UndoActionData? stack_scroll_left () {
            if (!can_redo ()) {
                return null;
            }

            index--;
            return stack.peek_nth (index);
        }

        private void undo_redo_done_transfer (Marlin.UndoActionData action) {
            /* If the action needed to be freed but was locked, free now */
            action.locked = false;
            undo_redo_flag = false;

            /* Update menus */
            do_menu_update ();
        }

        private GLib.List<unowned string> get_all_trashed_items () {
            var trash = new GLib.List<unowned string> ();
            stack.head.foreach ((action) => {
                if (action.trashed != null) {
                    trash.concat (action.trashed.get_keys ());
                }
            });

            return (owned) trash;
        }

        private static bool is_destination_uri_action_partof_trashed (GLib.List<unowned string> trash, GLib.List<GLib.File> g) {
            foreach (unowned string trash_item in trash) {
                foreach (unowned GLib.File g_item in g) {
                    if (g_item.get_uri () == trash_item) {
                        return true;
                    }
                }
            }

            return false;
        }

        private void do_menu_update () {
            var data = new UndoMenuData ();

            lock (stack) {
                Marlin.UndoActionData? action = get_next_undo_action ();
                if (action != null) {
                    data.undo_label = action.get_undo_label ();
                    data.undo_description = action.get_undo_description ();
                }

                action = get_next_redo_action ();
                if (action != null) {
                    data.redo_label = action.get_redo_label ();
                    data.redo_description = action.get_redo_description ();
                }
            }

            request_menu_update (data);
        }
    }
}
