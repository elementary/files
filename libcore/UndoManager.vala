public struct Marlin.UndoMenuData {
    unowned string undo_label;
    unowned string undo_description;
    unowned string redo_label;
    unowned string redo_description;
}

public delegate void Marlin.UndoFinishCallback ();

public enum Marlin.UndoActionType {
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

public class Marlin.UndoManagerData {
    /* Common stuff */
    public Marlin.UndoActionType type;
    public bool is_valid;
    public bool locked;              /* True if the action is being undone/redone */
    public bool freed;               /* True if the action must be freed after undo/redo */
    public uint count;                  /* Size of affected uris (count of items) */
    public unowned Marlin.UndoManager manager;    /* Pointer to the manager */

    /* Copy / Move stuff */
    public GLib.File src_dir;
    public GLib.File dest_dir;
    public GLib.List<string> sources;               /* Relative to src_dir */
    public GLib.List<string> destinations;          /* Relative to dest_dir */

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

    public UndoManagerData (Marlin.UndoActionType type, int items_count) {
        this.type = type;
        this.count = items_count;

        if (type == Marlin.UndoActionType.MOVETOTRASH) {
            trashed = new GLib.HashTable<string, uint64?> (str_hash, str_equal);
        }

        sources = new GLib.List<string> ();
        destinations = new GLib.List<string> ();
    }

    public void set_src_dir (GLib.File src) {
        src_dir = src;
    }

    public void set_dest_dir (GLib.File dest) {
        dest_dir = dest;
    }

    public void add_origin_target_pair (GLib.File origin, GLib.File target) {
        var src_relative = src_dir.get_relative_path (origin);
        sources.prepend (src_relative);
        var dest_relative = dest_dir.get_relative_path (target);
        destinations.prepend (dest_relative);

        is_valid = true;
    }

    public void add_trashed_file (GLib.File file, uint64 mtime) {
        trashed.insert (file.get_uri (), mtime);

        is_valid = true;
    }

    public void set_create_data (string target_uri, string template) {
        this.template = template;
        this.target_uri = target_uri;

        is_valid = true;
    }

    public void set_rename_information (GLib.File old_file, GLib.File new_file) {
        old_uri = old_file.get_uri ();
        new_uri = new_file.get_uri ();

        is_valid = true;
    }

    public void add_file_permissions (GLib.File file, uint32 permission) {
        original_permissions.insert (file.get_uri (), permission);

        is_valid = true;
    }

    public void set_recursive_permissions (uint32 file_permissions, uint32 file_mask, uint32 dir_permissions, uint32 dir_mask) {
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

    private unowned string get_first_target_short_name () {
        return destinations.first ().data;
    }

    private string get_uri_parent_path (string uri) {
        return GLib.File.new_for_uri (uri).get_parent ().get_path ();
    }

    public unowned string get_undo_description () {
        if (undo_description != null) {
            return undo_description;
        }

        switch (type) {
            case Marlin.UndoActionType.COPY:
                if (count != 1) {
                    undo_description = _("Delete %u copied items").printf (count);
                } else {
                    undo_description = _("Delete '%s'").printf (get_first_target_short_name ());
                }

                break;
            case Marlin.UndoActionType.DUPLICATE:
                if (count != 1) {
                    undo_description = _("Delete %u duplicated items").printf (count);
                } else {
                    undo_description = _("Delete '%s'").printf (get_first_target_short_name ());
                }

                break;
            case Marlin.UndoActionType.MOVE:
                var source = src_dir.get_path ();
                if (count != 1) {
                    undo_description = _("Move %u items back to '%s'").printf (count, source);
                } else {
                    undo_description = _("Move '%s' back to '%s'").printf (get_first_target_short_name (), source);
                }

                break;
            case Marlin.UndoActionType.RENAME:
                string from_name = GLib.Path.get_basename (new_uri);
                string to_name = GLib.Path.get_basename (old_uri);
                undo_description = _("Rename '%s' as '%s'").printf (from_name, to_name);

                break;
            case Marlin.UndoActionType.CREATEEMPTYFILE:
            case Marlin.UndoActionType.CREATEFOLDER:
                string name = GLib.Path.get_basename (target_uri);
                undo_description = _("Delete '%s'").printf (name);

                break;
            case Marlin.UndoActionType.MOVETOTRASH:
                if (count != 1) {
                    undo_description = _("Restore %u items from trash").printf (count);
                } else {
                    unowned string first_item = trashed.get_keys ().first ().data;
                    string name = GLib.Path.get_basename (first_item);
                    string orig_path = get_uri_parent_path (first_item);
                    undo_description = _("Restore '%s' to '%s'").printf (name, orig_path);
                }

                break;
            case Marlin.UndoActionType.RESTOREFROMTRASH:
                if (count != 1) {
                    undo_description = _("Move %u items back to trash").printf (count);
                } else {
                    undo_description = _("Move '%s' back to trash").printf (get_first_target_short_name ());
                }

                break;
            case Marlin.UndoActionType.CREATELINK:
                if (count != 1) {
                    undo_description = _("Delete links to %u items").printf (count);
                } else {
                    undo_description = _("Delete link to '%s'").printf (get_first_target_short_name ());
                }

                break;
            case Marlin.UndoActionType.RECURSIVESETPERMISSIONS:
                string name = dest_dir.get_path ();
                undo_description = _("Restore original permissions of items enclosed in '%s'").printf (name);

                break;
            case Marlin.UndoActionType.SETPERMISSIONS:
                string name = GLib.Path.get_basename (target_uri);
                undo_description = _("Restore original permissions of '%s'").printf (name);

                break;
            case Marlin.UndoActionType.CHANGEGROUP:
                string name = GLib.Path.get_basename (target_uri);
                undo_description = _("Restore group of '%s' to '%s'").printf (name, original_group_name_or_id);

                break;
            case Marlin.UndoActionType.CHANGEOWNER:
                string name = GLib.Path.get_basename (target_uri);
                undo_description = _("Restore owner of '%s' to '%s'").printf (name, original_user_name_or_id);

                break;
        }

        return undo_description;
    }

    public unowned string get_redo_description () {
        if (redo_description != null) {
            return redo_description;
        }

        switch (type) {
            case Marlin.UndoActionType.COPY:
                var destination = dest_dir.get_path ();
                if (count != 1) {
                    redo_description = _("Copy %u items to '%s'").printf (count, destination);
                } else {
                    redo_description = _("Copy '%s' to '%s'").printf (get_first_target_short_name (), destination);
                }

                break;
            case Marlin.UndoActionType.DUPLICATE:
                var destination = dest_dir.get_path ();
                if (count != 1) {
                    redo_description = _("Duplicate of %u items in '%s'").printf (count, destination);
                } else {
                    redo_description = _("Duplicate '%s' in '%s'").printf (get_first_target_short_name (), destination);
                }

                break;
            case Marlin.UndoActionType.MOVE:
                var destination = dest_dir.get_path ();
                if (count != 1) {
                    redo_description = _("Move %u items to '%s'").printf (count, destination);
                } else {
                    redo_description = _("Move '%s' to '%s'").printf (get_first_target_short_name (), destination);
                }

                break;
            case Marlin.UndoActionType.RENAME:
                string from_name = GLib.Path.get_basename (old_uri);
                string to_name = GLib.Path.get_basename (new_uri);
                redo_description = _("Rename '%s' as '%s'").printf (from_name, to_name);

                break;
            case Marlin.UndoActionType.CREATEFILEFROMTEMPLATE:
                string name = GLib.Path.get_basename (target_uri);
                redo_description = _("Create new file '%s' from template ").printf (name);

                break;
            case Marlin.UndoActionType.CREATEEMPTYFILE:
                string name = GLib.Path.get_basename (target_uri);
                redo_description = _("Create an empty file '%s'").printf (name);

                break;
            case Marlin.UndoActionType.CREATEFOLDER:
                string name = GLib.Path.get_basename (target_uri);
                redo_description = _("Create a new folder '%s'").printf (name);

                break;
            case Marlin.UndoActionType.MOVETOTRASH:
                var trashed_items = trashed.size ();
                if (trashed_items != 1) {
                    redo_description = _("Move %u items to trash").printf (trashed_items);
                } else {
                    unowned string first_item = trashed.get_keys ().first ().data;
                    string name = GLib.Path.get_basename (first_item);
                    undo_description = _("Move '%s' to trash").printf (name);
                }

                break;
            case Marlin.UndoActionType.RESTOREFROMTRASH:
                if (count != 1) {
                    redo_description = _("Restore %u items from trash").printf (count);
                } else {
                    redo_description = _("Restore '%s' from trash").printf (get_first_target_short_name ());
                }

                break;
            case Marlin.UndoActionType.CREATELINK:
                if (count != 1) {
                    redo_description = _("Create links to %u items").printf (count);
                } else {
                    redo_description = _("Create link to '%s'").printf (get_first_target_short_name ());
                }

                break;
            case Marlin.UndoActionType.RECURSIVESETPERMISSIONS:
                redo_description = _("Set permissions of items enclosed in '%s'").printf (dest_dir.get_path ());
                break;
            case Marlin.UndoActionType.SETPERMISSIONS:
                string name = GLib.Path.get_basename (target_uri);
                redo_description = _("Set permissions of '%s'").printf (name);
                break;
            case Marlin.UndoActionType.CHANGEGROUP:
                string name = GLib.Path.get_basename (target_uri);
                redo_description = _("Set group of '%s' to '%s'").printf (name, new_group_name_or_id);
                break;
            case Marlin.UndoActionType.CHANGEOWNER:
                string name = GLib.Path.get_basename (target_uri);
                redo_description = _("Set owner of '%s' to '%s'").printf (name, new_user_name_or_id);
                break;
        }

        return redo_description;
    }

    public unowned string get_undo_label () {
        if (undo_label != null) {
            return undo_label;
        }

        switch (type) {
            case Marlin.UndoActionType.COPY:
                undo_label = ngettext ("_Undo copy of %u item", "_Undo copy of %u items", count).printf (count);
                break;
            case Marlin.UndoActionType.DUPLICATE:
                undo_label = ngettext ("_Undo duplicate of %u item", "_Undo duplicate of %u items", count).printf (count);
                break;
            case Marlin.UndoActionType.MOVE:
                undo_label = ngettext ("_Undo move of %u item", "_Undo move of %u items", count).printf (count);
                break;
            case Marlin.UndoActionType.RENAME:
                undo_label = ngettext ("_Undo rename of %u item", "_Undo rename of %u items", count).printf (count);
                break;
            case Marlin.UndoActionType.CREATEEMPTYFILE:
                undo_label = _("_Undo creation of an empty file");
                break;
            case Marlin.UndoActionType.CREATEFILEFROMTEMPLATE:
                undo_label = _("_Undo creation of a file from template");
                break;
            case Marlin.UndoActionType.CREATEFOLDER:
                undo_label = ngettext ("_Undo creation of %u folder", "_Undo creation of %u folders", count).printf (count);
                break;
            case Marlin.UndoActionType.MOVETOTRASH:
                undo_label = ngettext ("_Undo move to trash of %u item", "_Undo move to trash of %u items", count).printf (count);
                break;
            case Marlin.UndoActionType.RESTOREFROMTRASH:
                undo_label = ngettext ("_Undo restore from trash of %u item", "_Undo restore from trash of %u items", count).printf (count);
                break;
            case Marlin.UndoActionType.CREATELINK:
                undo_label = ngettext ("_Undo create link to %u item", "_Undo create link to %u items", count).printf (count);
                break;
            case Marlin.UndoActionType.DELETE:
                undo_label = ngettext ("_Undo delete of %u item", "_Undo delete of %u items", count).printf (count);
                break;
            case Marlin.UndoActionType.RECURSIVESETPERMISSIONS:
                undo_label = ngettext ("Undo recursive change permissions of %u item", "Undo recursive change permissions of %u items", count).printf (count);
                break;
            case Marlin.UndoActionType.SETPERMISSIONS:
                undo_label = ngettext ("Undo change permissions of %u item", "Undo change permissions of %u items", count).printf (count);
                break;
            case Marlin.UndoActionType.CHANGEGROUP:
                undo_label = ngettext ("Undo change group of %u item", "Undo change group of %u items", count).printf (count);
                break;
            case Marlin.UndoActionType.CHANGEOWNER:
                undo_label = ngettext ("Undo change owner of %u item", "Undo change owner of %u items", count).printf (count);
                break;
        }

        return undo_label;
    }

    public unowned string get_redo_label () {
        if (redo_label != null) {
            return redo_label;
        }

        switch (type) {
            case Marlin.UndoActionType.COPY:
                redo_label = ngettext ("_Redo copy of %u item", "_Redo copy of %u items", count).printf (count);
                break;
            case Marlin.UndoActionType.DUPLICATE:
                redo_label = ngettext ("_Redo duplicate of %u item", "_Redo duplicate of %u items", count).printf (count);
                break;
            case Marlin.UndoActionType.MOVE:
                redo_label = ngettext ("_Redo move of %u item", "_Redo move of %u items", count).printf (count);
                break;
            case Marlin.UndoActionType.RENAME:
                redo_label = ngettext ("_Redo rename of %u item", "_Redo rename of %u items", count).printf (count);
                break;
            case Marlin.UndoActionType.CREATEEMPTYFILE:
                redo_label = _("_Redo creation of an empty file");
                break;
            case Marlin.UndoActionType.CREATEFILEFROMTEMPLATE:
                redo_label = _("_Redo creation of a file from template");
                break;
            case Marlin.UndoActionType.CREATEFOLDER:
                redo_label = ngettext ("_Redo creation of %u folder", "_Redo creation of %u folders", count).printf (count);
                break;
            case Marlin.UndoActionType.MOVETOTRASH:
                redo_label = ngettext ("_Redo move to trash of %u item", "_Redo move to trash of %u items", count).printf (count);
                break;
            case Marlin.UndoActionType.RESTOREFROMTRASH:
                redo_label = ngettext ("_Redo restore from trash of %u item", "_Redo restore from trash of %u items", count).printf (count);
                break;
            case Marlin.UndoActionType.CREATELINK:
                redo_label = ngettext ("_Redo create link to %u item", "_Redo create link to %u items", count).printf (count);
                break;
            case Marlin.UndoActionType.DELETE:
                redo_label = ngettext ("_Redo delete of %u item", "_Redo delete of %u items", count).printf (count);
                break;
            case Marlin.UndoActionType.RECURSIVESETPERMISSIONS:
                redo_label = ngettext ("Redo recursive change permissions of %u item", "Redo recursive change permissions of %u items", count).printf (count);
                break;
            case Marlin.UndoActionType.SETPERMISSIONS:
                redo_label = ngettext ("Redo change permissions of %u item", "Redo change permissions of %u items", count).printf (count);
                break;
            case Marlin.UndoActionType.CHANGEGROUP:
                redo_label = ngettext ("Redo change group of %u item", "Redo change group of %u items", count).printf (count);
                break;
            case Marlin.UndoActionType.CHANGEOWNER:
                redo_label = ngettext ("Redo change owner of %u item", "Redo change owner of %u items", count).printf (count);
                break;
        }

        return redo_label;
    }
}


public class Marlin.UndoManager : GLib.Object {
    // Number of undo levels to be stored
    public uint undo_levels { get; set; default = 30; }
    public bool confirm_delete { get; set; default = false; }
    private GLib.Queue<Marlin.UndoManagerData> stack;
    private uint index = 0;
    private GLib.Mutex mutex;                /* Used to protect access to stack (because of async file ops) */
    private bool undo_redo_flag = false;

    public signal void request_menu_update (UndoMenuData data);

    private static UndoManager _instance;
    public static unowned UndoManager instance () {
        if (_instance == null) {
            _instance = new UndoManager ();
        }

        return _instance;
    }

    construct {
        stack = new GLib.Queue<Marlin.UndoManagerData> ();
        mutex = GLib.Mutex ();
    }

    public void add_action (owned Marlin.UndoManagerData action) {
        if (!action.is_valid) {
            return;
        }

        action.manager = this;
        mutex.lock ();
        stack_push_action ((owned) action);
        mutex.unlock ();

        do_menu_update ();
    }

    public void add_rename_action (GLib.File new_file, string original_name) {
        var data = new Marlin.UndoManagerData (Marlin.UndoActionType.RENAME, 1);
        data.new_uri = new_file.get_uri ();
        data.old_uri = GLib.Path.build_filename (GLib.Path.get_dirname (data.new_uri), original_name);
        data.is_valid = true;

        add_action ((owned) data);
    }

    public async void undo (Gtk.Widget widget, GLib.Cancellable? cancellable = null) throws GLib.Error {
        mutex.lock ();
        weak Marlin.UndoManagerData? action = stack_scroll_right ();
        if (action != null) {
            action.locked = true;
        }

        mutex.unlock ();
        do_menu_update ();

        if (action != null) {
            undo_redo_flag = true;
            GLib.List<GLib.File> uris = null;
            switch (action.type) {
                case Marlin.UndoActionType.CREATEEMPTYFILE:
                case Marlin.UndoActionType.CREATEFOLDER:
                    uris = gfile_list_from_uri (action.target_uri);
                    if (uris == null) {
                        uris = gfile_list_from_folder (action.destinations, action.dest_dir);
                    }

                    if (confirm_delete) {
                        Marlin.FileOperations.@delete (uris, null, false, () => {undo_redo_done_transfer_callback (action);});
                    } else {
                        foreach (unowned GLib.File file in uris) {
                            try {
                                yield file.delete_async (GLib.Priority.DEFAULT, cancellable);
                                Marlin.FileChanges.queue_file_removed (file);
                            } catch (Error e) {
                                throw e;
                            }
                        }

                        Marlin.FileChanges.consume_changes (true);
                        undo_redo_done_transfer_callback (action);
                    }

                    break;
                case Marlin.UndoActionType.COPY:
                case Marlin.UndoActionType.DUPLICATE:
                case Marlin.UndoActionType.CREATELINK:
                    uris = gfile_list_from_folder (action.destinations, action.dest_dir);

                    if (confirm_delete) {
                        Marlin.FileOperations.@delete (uris, null, true, () => {undo_redo_done_transfer_callback (action);});
                    } else {
                        foreach (unowned GLib.File file in uris) {
                            try {
                                yield file.delete_async (GLib.Priority.DEFAULT, cancellable);
                                Marlin.FileChanges.queue_file_removed (file);
                            } catch (Error e) {
                                throw e;
                            }
                        }

                        Marlin.FileChanges.consume_changes (true);
                        undo_redo_done_transfer_callback (action);
                    }

                    break;
                case Marlin.UndoActionType.RESTOREFROMTRASH:
                    uris = gfile_list_from_folder (action.destinations, action.dest_dir);
                    Marlin.FileOperations.@delete (uris, null, true, () => {undo_redo_done_transfer_callback (action);});
                    break;
                case Marlin.UndoActionType.MOVETOTRASH:
                    var files_to_restore = retrieve_files_to_restore (action.trashed);
                    if (files_to_restore.size () > 0) {
                        GLib.List<weak GLib.File> gfiles_in_trash = files_to_restore.get_keys ();
                        foreach (unowned GLib.File item in gfiles_in_trash) {
                            unowned string val = files_to_restore.lookup (item);
                            var dest = GLib.File.new_for_uri (val);
                            try {
                                item.move (dest, GLib.FileCopyFlags.NOFOLLOW_SYMLINKS);
                                Marlin.FileChanges.queue_file_moved (item, dest);
                            } catch (Error e) {
                                throw e;
                            }
                        }

                        Marlin.FileChanges.consume_changes (true);
                    } else {
                        PF.Dialogs.show_error_dialog (_("Original location could not be determined"),
                                                      _("Open trash folder and restore manually"),
                                                      widget.get_toplevel () as Gtk.Window);
                    }

                    undo_redo_done_transfer_callback (action);
                    break;
                case Marlin.UndoActionType.MOVE:
                    uris = gfile_list_from_folder (action.destinations, action.dest_dir);
                    Marlin.FileOperations.copy_move_link (uris, null, action.src_dir, Gdk.DragAction.MOVE, null, () => {undo_redo_done_transfer_callback (action);});
                    break;
                case Marlin.UndoActionType.RENAME:
                    var file = GLib.File.new_for_uri (action.new_uri);
                    var new_name = GLib.Path.get_basename (action.old_uri);
                    try {
                        yield PF.FileUtils.set_file_display_name (file, new_name, cancellable);
                        undo_redo_done_transfer_callback (action);
                    } catch (Error e) {
                        throw e;
                    }
                    break;
                case Marlin.UndoActionType.DELETE:
                    undo_redo_flag = false;
                    break;
            }
        }
    }

    public async void redo (Gtk.Widget widget, GLib.Cancellable? cancellable = null) throws GLib.Error {
    
    }

    public bool is_undo_redo () {
        return undo_redo_flag;
    }

    private void clear_redo_actions () {
        while (index > 0) {
            stack.pop_head ();
            index--;
        }
    }

    /* TODO use GOFFile we shouldn't have to query_info we already know all of this */
    public static uint64 get_file_modification_time (GLib.File file) {
        try {
            var info = file.query_info (GLib.FileAttribute.TIME_MODIFIED, GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
            return info.get_attribute_uint64 (GLib.FileAttribute.TIME_MODIFIED);
        } catch (Error e) {
            debug (e.message);
            return -1;
        }
    }

    private GLib.List<weak string>? get_all_trashed_items () {
        GLib.Queue<weak Marlin.UndoManagerData> tmp_stack = stack.copy ();
        GLib.List<weak string>? trash = null;
        unowned Marlin.UndoManagerData? action;
        while ((action = tmp_stack.pop_tail ()) != null) {
            if (action.trashed != null) {
                trash.concat (action.trashed.get_keys ());
            }
        }
  
        return trash;
    }

    private static bool is_destination_uri_action_partof_trashed (GLib.List<weak string> trash, GLib.List<GLib.File> g) {
        foreach (unowned GLib.File file in g) {
            if (trash.find_custom (file.get_uri (), GLib.strcmp) != null) {
                return true;
            }
        }

        return false;
    }

    public void trash_has_emptied () {
        /* Clear actions from the oldest to the newest move to trash */
        mutex.lock ();
        clear_redo_actions ();

        GLib.List<weak string>? trashed = get_all_trashed_items ();
        GLib.Queue<weak Marlin.UndoManagerData> tmp_stack = stack.copy ();
        unowned Marlin.UndoManagerData? action;
        while ((action = tmp_stack.pop_tail ()) != null) {
            if (action.destinations != null && action.dest_dir != null) {
                /* what a pain rebuild again and again an uri
                ** TODO change the struct add uri elements */
                var g = gfile_list_from_folder (action.destinations, action.dest_dir);
                /* remove action for trashed item uris == destination action */
                if (is_destination_uri_action_partof_trashed (trashed, g)) {
                    stack.remove (action);
                    continue;
                }
            }

            if (action.type == Marlin.UndoActionType.MOVETOTRASH) {
                stack.remove (action);
            }
        }

        mutex.unlock ();

        do_menu_update ();
    }

    private static void stack_clear_n_oldest (GLib.Queue<Marlin.UndoManagerData> stack, uint n) {
        Marlin.UndoManagerData action;

        for (uint i = 0; i < n; i++) {
            if ((action = stack.pop_tail ()) == null)
                break;

            if (action.locked) {
                action.freed = true;
            }
        }
    }

    private void stack_fix_size () {
        uint length = stack.length;

        if (length > undo_levels) {
            if (index > (undo_levels + 1)) {
                /* If the index will fall off the stack
                 * move it back to the maximum position */
                index = undo_levels + 1;
            }

            stack_clear_n_oldest (stack, length - undo_levels);
        }
    }

    private void stack_push_action (owned Marlin.UndoManagerData action) {
        clear_redo_actions ();

        stack.push_head ((owned) action);
        uint length = stack.length;

        if (length > undo_levels) {
            stack_fix_size ();
        }
    }

    private unowned Marlin.UndoManagerData? get_next_redo_action () {
        if (stack.is_empty ()) {
            return null;
        }

        if (index == 0) {
            /* ... no redo actions */
            return null;
        }

        unowned Marlin.UndoManagerData? action = stack.peek_nth (index - 1);
        if (action.locked) {
            return null;
        } else {
            return action;
        }
    }

    private unowned Marlin.UndoManagerData? get_next_undo_action () {
        if (stack.is_empty ()) {
            return null;
        }

        if (index == stack.length) {
            return null;
        }

        unowned Marlin.UndoManagerData? action = stack.peek_nth (index);
        if (action.locked) {
            return null;
        } else {
            return action;
        }
    }

    private void do_menu_update () {
        Marlin.UndoMenuData data = Marlin.UndoMenuData ();

        mutex.lock ();
        unowned Marlin.UndoManagerData? action = get_next_undo_action ();
        if (action != null) {
            data.undo_label = action.get_undo_label ();
            data.undo_description = action.get_undo_description ();
        }

        action = get_next_redo_action ();
        if (action != null) {
            data.redo_label = action.get_redo_label ();
            data.redo_description = action.get_redo_description ();
        }

        mutex.unlock ();

        request_menu_update (data);
    }

    private bool can_undo () {
        return (get_next_undo_action () != null);
    }

    private unowned Marlin.UndoManagerData? stack_scroll_right () {
        if (!can_undo ())
            return null;

        weak Marlin.UndoManagerData? data = stack.peek_nth (index);
        if (index < stack.length) {
            index++;
        }

        return data;
    }

    private void undo_redo_done_transfer_callback (owned Marlin.UndoManagerData action) {
        /* If the action needed to be freed but was locked, free now */
        if (!action.freed) {
            action.locked = false;
        }

        undo_redo_flag = false;

        /* Update menus */
        do_menu_update ();
    }

    private static GLib.List<GLib.File> gfile_list_from_folder (GLib.List<string> uri_list, GLib.File parent) {
        var list = new GLib.List<GLib.File> ();
        foreach (unowned string uri in uri_list) {
            list.append (parent.get_child (uri));
        }

        return list;
    }

    private static GLib.List<GLib.File> gfile_list_from_uri (string uri) {
        var list = new GLib.List<GLib.File> ();
        list.append (GLib.File.new_for_uri (uri));
        return list;
    }

    private static GLib.HashTable<GLib.File, string>? retrieve_files_to_restore (GLib.HashTable<string, uint64?> trashed) {
        if (trashed.size () <= 0) {
            return null;
        }

        var trash = GLib.File.new_for_uri ("trash:");
        try {
            var enumerator = trash.enumerate_children (GLib.FileAttribute.STANDARD_NAME + "," + GLib.FileAttribute.TIME_MODIFIED + "," + GLib.FileAttribute.TRASH_ORIG_PATH, GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
            var to_restore = new GLib.HashTable<GLib.File, string> (direct_hash, direct_equal);
            GLib.FileInfo? info = null;
            while ((info = enumerator.next_file ()) != null) {
                unowned string? origpath = info.get_attribute_byte_string (GLib.FileAttribute.TRASH_ORIG_PATH);
                if (origpath != null) {
                    var origfile = GLib.File.new_for_path (origpath);
                    var origuri = origfile.get_uri ();
                    uint64? mtime = trashed.lookup (origuri);
                    if (mtime != null) {
                        uint64? mtime_item = info.get_attribute_uint64 (GLib.FileAttribute.TIME_MODIFIED);
                        if (mtime == mtime_item) {
                            var item = trash.get_child (info.get_name ()); /* File in the trash */
                            to_restore.insert (item, (owned)origuri);
                        }
                    }
                }
            }

            return to_restore;
        } catch (Error e) {
            debug (e.message);
        }

        return null;
    }
}
