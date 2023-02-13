namespace Files {
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
        RESTOREFROMTRASH,
        SETPERMISSIONS,
        RECURSIVESETPERMISSIONS,
        CHANGEOWNER,
        CHANGEGROUP;

        public unowned string to_action_string () {
            switch (this) {
                case COPY:
                    return _("Copy");
                case DUPLICATE:
                    return _("Duplicate");
                case MOVE:
                    return _("Move");
                case RENAME:
                    return _("Rename");
                case CREATEEMPTYFILE:
                    return _("Create Empty File");
                case CREATEFILEFROMTEMPLATE:
                    return _("Create File from Template");
                case CREATEFOLDER:
                    return _("Create Folder");
                case MOVETOTRASH:
                    return _("Move to Trash");
                case CREATELINK:
                    return _("Create Link");
                case RESTOREFROMTRASH:
                    return _("Restore from Trash");
                case SETPERMISSIONS:
                    return _("Set Permissions");
                case RECURSIVESETPERMISSIONS:
                    return _("Set Permissions Recursively");
                case CHANGEOWNER:
                    return _("Change Owner");
                case CHANGEGROUP:
                    return _("Change Group");
                default:
                    assert_not_reached ();
            }
        }
    }

    public class UndoActionData {
        /* Common stuff */
        public Files.UndoActionType action_type;
        public bool is_valid;                      /* False if action generated during undo/redo */
        public bool locked;                        /* True if the action is being undone/redone */
        public bool freed;                         /* True if the action must be freed after undo/redo */
        public uint count;                         /* Size of affected uris (count of items) */

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
        public string? template;
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

        public UndoActionData (Files.UndoActionType action_type, int items_count) {
            this.action_type = action_type;
            this.count = items_count;

            if (action_type == UndoActionType.MOVETOTRASH) {
                this.trashed = new HashTable<string, uint64?> (str_hash, str_equal);
            }

            is_valid = !Files.UndoManager.instance ().undo_redo_flag;
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
        }

        public void set_create_data (string target_uri, string? template) {
            this.template = template;
            this.target_uri = target_uri;
        }

        public void set_rename_information (GLib.File old_file, GLib.File new_file) {
            this.old_uri = old_file.get_uri ();
            this.new_uri = new_file.get_uri ();
        }

        public void add_trashed_file (GLib.File file, uint64 mtime) {
            trashed.insert (file.get_uri (), mtime);
        }

        // Pushes a recursive permission change data in an existing undo data container
        public void add_file_permissions (GLib.File file, uint32 permission) {
            original_permissions.insert (file.get_uri (), permission);
        }

        public void set_recursive_permissions (uint32 file_permissions, uint32 file_mask,
                                               uint32 dir_permissions, uint32 dir_mask) {
            this.file_permissions = file_permissions;
            this.file_mask = file_mask;
            this.dir_permissions = dir_permissions;
            this.dir_mask = dir_mask;
        }

        public void set_file_permissions (string uri, uint32 current_permissions, uint32 new_permissions) {
            target_uri = uri;

            this.current_permissions = current_permissions;
            this.new_permissions = new_permissions;
        }


        public void set_owner_change_information (string uri, string current_user, string new_user) {
            target_uri = uri;

            original_user_name_or_id = current_user;
            new_user_name_or_id = new_user;
        }

        public void set_group_change_information (string uri, string current_group, string new_group) {
            target_uri = uri;

            original_group_name_or_id = current_group;
            new_group_name_or_id = new_group;
        }

        internal GLib.HashTable<GLib.File, string>? retrieve_files_to_restore () {
            if (trashed.size () <= 0) {
                return null;
            }

            var to_restore = new GLib.HashTable<GLib.File, string> (direct_hash, direct_equal);
            var trash = GLib.File.new_for_uri ("trash:");
            try {
                var enumerator = trash.enumerate_children (GLib.FileAttribute.STANDARD_NAME + "," +
                                                           GLib.FileAttribute.TIME_MODIFIED + "," +
                                                           GLib.FileAttribute.TRASH_ORIG_PATH,
                                                           GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
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
                critical (e.message);
            }

            return to_restore;
        }
    }

    public class UndoManager : GLib.Object {
        private static UndoManager _instance;
        public static unowned UndoManager instance () {
            if (_instance == null)
                _instance = new UndoManager ();

            return _instance;
        }

        public signal void request_menu_update ();

        public uint undo_levels { get; construct set; default = 10; }
        public bool confirm_delete { get; construct set; default = false; }

        private GLib.Queue<Files.UndoActionData> stack;
        private uint index;
        public bool undo_redo_flag { get; private set; }

        construct {
            stack = new GLib.Queue<Files.UndoActionData> ();
        }

        public async bool undo (Gtk.Widget widget, GLib.Cancellable? cancellable = null) throws GLib.Error {
            Files.UndoActionData? action = null;
            lock (stack) {
                action = stack_scroll_right ();
                if (action != null) {
                    action.locked = true;
                }
            }

            request_menu_update ();
            if (action == null) {
                return true;
            }

            undo_redo_flag = true;
            switch (action.action_type) {
                case Files.UndoActionType.COPY:
                case Files.UndoActionType.DUPLICATE:
                case Files.UndoActionType.CREATELINK:
                    var uris = new GLib.List<GLib.File> ();
                    action.destinations.foreach ((uri) => uris.prepend (action.dest_dir.get_child (uri)));
                    uris.reverse (); // Deleting must be done in reverse
                    if (uris != null && confirm_delete) {
                        try {
                            yield Files.FileOperations.@delete (
                                      uris, widget.get_toplevel () as Gtk.Window, false, cancellable
                                  );
                        } catch (Error e) {
                            undo_redo_done_transfer (action);
                            throw e;
                        }
                    } else {
                        foreach (unowned GLib.File file in uris) {
                            yield file.delete_async (GLib.Priority.DEFAULT, cancellable);
                            Files.FileChanges.queue_file_removed (file);
                        }

                        Files.FileChanges.consume_changes (true);
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Files.UndoActionType.MOVE:
                    var uris = new GLib.List<GLib.File> ();
                    action.destinations.foreach ((uri) => uris.prepend (action.dest_dir.get_child (uri)));
                    if (uris != null) { /*Cancelled operation may result in empty list */
                        try {
                            yield Files.FileOperations.copy_move_link (
                                      uris, action.src_dir, Gdk.DragAction.MOVE, widget, cancellable
                                  );
                        } catch (Error e) {
                            undo_redo_done_transfer (action);
                            throw e;
                        }
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Files.UndoActionType.RENAME:
                    var file = FileUtils.get_file_for_path (action.new_uri);
                    var new_name = FileUtils.get_file_for_path (action.old_uri).get_basename ();
                    try {
                        yield FileUtils.set_file_display_name (file, new_name, cancellable);
                    } catch (Error e) {
                        undo_redo_done_transfer (action);
                        throw e;
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Files.UndoActionType.CREATEEMPTYFILE:
                case Files.UndoActionType.CREATEFOLDER:
                case Files.UndoActionType.CREATEFILEFROMTEMPLATE:
                    var uris = new GLib.List<GLib.File> ();
                    uris.prepend (GLib.File.new_for_uri (action.target_uri));
                    if (uris != null && confirm_delete) {
                        try {
                            yield Files.FileOperations.@delete (
                                      uris, widget.get_toplevel () as Gtk.Window, false, cancellable
                                  );
                        } catch (Error e) {
                            undo_redo_done_transfer (action);
                            throw e;
                        }
                    } else {
                        foreach (unowned GLib.File file in uris) {
                            yield file.delete_async (GLib.Priority.DEFAULT, cancellable);
                            Files.FileChanges.queue_file_removed (file);
                        }

                        Files.FileChanges.consume_changes (true);
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Files.UndoActionType.MOVETOTRASH:
                    GLib.HashTable<GLib.File, string>? files_to_restore = action.retrieve_files_to_restore ();
                    if (files_to_restore.size () > 0) {
                        files_to_restore.foreach ((key, val) => {
                            var dest = GLib.File.new_for_uri (val);
                            try {
                                key.move (dest, GLib.FileCopyFlags.NOFOLLOW_SYMLINKS, cancellable, null);
                                Files.FileChanges.queue_file_moved (key, dest);
                            } catch (Error e) {
                                critical (e.message);
                            }
                        });

                        Files.FileChanges.consume_changes (true);
                    } else {
                        PF.Dialogs.show_error_dialog (_("Original location could not be determined"),
                                                      _("Open trash folder and restore manually"),
                                                      widget.get_toplevel () as Gtk.Window);
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Files.UndoActionType.RESTOREFROMTRASH:
                    var uris = new GLib.List<GLib.File> ();
                    action.destinations.foreach ((uri) => uris.prepend (action.dest_dir.get_child (uri)));
                    if (uris != null ) {
                        try {
                            yield Files.FileOperations.@delete (
                                      uris, widget.get_toplevel () as Gtk.Window, true, cancellable
                                  );
                        } catch (Error e) {
                            undo_redo_done_transfer (action);
                            throw e;
                        }
                    }

                    undo_redo_done_transfer (action);
                    break;
                default:
                    warning ("Ignoring request to undo irreversible or unknown action %s",
                             action.action_type.to_string ());

                    undo_redo_flag = false;
                    break; /* We shouldn't be here */
            }

            return true;
        }

        public async bool redo (Gtk.Widget widget, GLib.Cancellable? cancellable = null) throws GLib.Error {
            Files.UndoActionData? action = null;
            lock (stack) {
                action = stack_scroll_left ();
                if (action != null) {
                    action.locked = true;
                }
            }

            request_menu_update ();
            if (action == null) {
                return true;
            }

            undo_redo_flag = true;
            switch (action.action_type) {
                case Files.UndoActionType.COPY:
                case Files.UndoActionType.DUPLICATE:
                    var uris = new GLib.List<GLib.File> ();
                    action.sources.foreach ((uri) => uris.prepend (action.src_dir.get_child (uri)));
                    if (uris != null) {
                        try {
                            yield Files.FileOperations.copy_move_link (
                                      uris, action.dest_dir, Gdk.DragAction.COPY, widget, cancellable
                                  );
                        } catch (Error e) {
                            undo_redo_done_transfer (action);
                            throw e;
                        }
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Files.UndoActionType.CREATELINK:
                    var uris = new GLib.List<GLib.File> ();
                    action.sources.foreach ((uri) => uris.prepend (action.src_dir.get_child (uri)));
                    if (uris != null) {
                        try {
                            yield Files.FileOperations.copy_move_link (
                                      uris, action.dest_dir, Gdk.DragAction.LINK, widget, cancellable
                                  );
                        } catch (Error e) {
                            undo_redo_done_transfer (action);
                            throw e;
                        }
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Files.UndoActionType.MOVE:
                case Files.UndoActionType.RESTOREFROMTRASH:
                    var uris = new GLib.List<GLib.File> ();
                    action.sources.foreach ((uri) => uris.prepend (action.src_dir.get_child (uri)));
                    if (uris != null) {
                        try {
                            yield Files.FileOperations.copy_move_link (
                                      uris, action.dest_dir, Gdk.DragAction.MOVE, widget, cancellable
                                  );
                        } catch (Error e) {
                            undo_redo_done_transfer (action);
                            throw e;
                        }
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Files.UndoActionType.RENAME:
                    var file = FileUtils.get_file_for_path (action.old_uri);
                    var new_name = FileUtils.get_file_for_path (action.new_uri).get_basename ();
                    try {
                        yield FileUtils.set_file_display_name (file, new_name, cancellable);
                    } catch (Error e) {
                        undo_redo_done_transfer (action);
                        throw e;
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Files.UndoActionType.CREATEEMPTYFILE:
                case Files.UndoActionType.CREATEFILEFROMTEMPLATE:
                    var p_uri = GLib.File.new_for_uri (action.target_uri).get_parent ().get_uri ();
                    var new_name = GLib.Path.get_basename (Uri.unescape_string (action.target_uri));
                    try {
                        yield Files.FileOperations.new_file (widget.get_toplevel () as Gtk.Window, p_uri,
                                                              new_name, action.template, 0, cancellable);
                    } catch (Error e) {
                        undo_redo_done_transfer (action);
                        throw e;
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Files.UndoActionType.CREATEFOLDER:
                    var fparent = GLib.File.new_for_uri (action.target_uri).get_parent ();
                    try {
                        yield Files.FileOperations.new_folder (
                                  widget.get_toplevel () as Gtk.Window, fparent, cancellable
                              );
                    } catch (Error e) {
                        undo_redo_done_transfer (action);
                        throw e;
                    }

                    undo_redo_done_transfer (action);
                    break;
                case Files.UndoActionType.MOVETOTRASH:
                    if (action.trashed.size () > 0) {
                        var uri_to_trash = action.trashed.get_keys ();
                        var uris = new GLib.List<GLib.File> ();
                        uri_to_trash.foreach ((uri) => uris.prepend (GLib.File.new_for_uri (uri)));

                        try {
                            yield Files.FileOperations.@delete (
                                      uris, widget.get_toplevel () as Gtk.Window, true, cancellable
                                  );
                        } catch (Error e) {
                            undo_redo_done_transfer (action);
                            throw e;
                        }
                    }

                    undo_redo_done_transfer (action);
                    break;
                default:
                    warning ("Ignoring request to redo irreversible or unknown action %s",
                             action.action_type.to_string ());

                    undo_redo_flag = false;
                    break; /* We shouldn't be here */
            }

            return true;
        }

        /* Action may be null, e.g. when redoing after undoing */
        public void add_action (owned Files.UndoActionData? action) {
            if (action == null || !action.is_valid) {
                return;
            }

            lock (stack) {
                stack_push_action ((owned) action);
            }

            request_menu_update ();
        }

        public void add_rename_action (GLib.File renamed_file, string original_name) {
            if (undo_redo_flag) {
                return;
            }
            /* The stored uris are escaped */
            var data = new Files.UndoActionData (Files.UndoActionType.RENAME, 1) {
                old_uri = renamed_file.get_parent ().get_child (original_name).get_uri (),
                new_uri = renamed_file.get_uri ()
            };

            add_action ((owned) data);
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

                    if (action.action_type == Files.UndoActionType.MOVETOTRASH) {
                        stack.remove (action);
                    }
                });
            }

            request_menu_update ();
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

        private void stack_push_action (owned Files.UndoActionData action) {
            clear_redo_actions ();

            stack.push_head ((owned) action);
            if (stack.get_length () > undo_levels) {
                stack_fix_size ();
            }
        }

        private unowned Files.UndoActionData? get_next_redo_action () {
            if (stack.is_empty ()) {
                return null;
            }

            if (index == 0) {
                /* ... no redo actions */
                return null;
            }

            unowned Files.UndoActionData action = stack.peek_nth (index - 1);
            if (action.locked) {
                return null;
            } else {
                return action;
            }
        }

        private unowned Files.UndoActionData? get_next_undo_action () {
            if (stack.is_empty ()) {
                return null;
            }

            if (index == stack.get_length ()) {
                /* ... no redo actions */
                return null;
            }

            unowned Files.UndoActionData action = stack.peek_nth (index);
            if (action.locked) {
                return null;
            } else {
                return action;
            }
        }

        public unowned string? get_next_undo_description () {
            unowned var action = get_next_undo_action ();
            if (action != null) {
                return action.action_type.to_action_string ();
            } else {
                return null;
            }
        }
        public string get_next_redo_description () {
            var action = get_next_redo_action ();
            if (action != null) {
                return action.action_type.to_string ();
            } else {
                return "";
            }
        }

        public bool can_undo () {
            return (get_next_undo_action () != null);
        }

        public bool can_redo () {
            return (get_next_redo_action () != null);
        }

        private unowned Files.UndoActionData? stack_scroll_right () {
            if (!can_undo ()) {
                return null;
            }

            unowned Files.UndoActionData? data = stack.peek_nth (index);
            if (index < stack.get_length ()) {
                index++;
            }

            return data;
        }

        private unowned Files.UndoActionData? stack_scroll_left () {
            if (!can_redo ()) {
                return null;
            }

            index--;
            return stack.peek_nth (index);
        }

        private void undo_redo_done_transfer (Files.UndoActionData action) {
            /* If the action needed to be freed but was locked, free now */
            action.locked = false;
            undo_redo_flag = false;

            /* Update menus */
            request_menu_update ();
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

        private static bool is_destination_uri_action_partof_trashed (GLib.List<unowned string> trash,
                                                                      GLib.List<GLib.File> g) {
            foreach (unowned string trash_item in trash) {
                foreach (unowned GLib.File g_item in g) {
                    if (g_item.get_uri () == trash_item) {
                        return true;
                    }
                }
            }

            return false;
        }
    }
}
