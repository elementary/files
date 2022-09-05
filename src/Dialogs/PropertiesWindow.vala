/*
* Copyright (c) 2011 Marlin Developers (http://launchpad.net/marlin)
* Copyright (c) 2015-2018 elementary LLC <https://elementary.io>
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1335 USA.
*
* Authored by: ammonkey <am.monkeyd@gmail.com>
*/

namespace Files.View {

public class PropertiesWindow : AbstractPropertiesDialog {
    private Gtk.Entry perm_code;
    private bool perm_code_should_update = true;
    private Gtk.Label l_perm;

    private PermissionButton perm_button_user;
    private PermissionButton perm_button_group;
    private PermissionButton perm_button_other;

    private Gtk.ListStore store_users;
    private Gtk.ListStore store_groups;
    private Gtk.ListStore store_apps;

    private GLib.List<Files.File> files;
    private bool only_one;
    private Files.File goffile;

    public Files.AbstractDirectoryView view {get; private set;}
    public Gtk.Entry entry {get; private set;}
    private string original_name {
        get {
            return view.original_name;
        }

        set {
            view.original_name = value;
        }
    }

    private string proposed_name {
        get {
            return view.proposed_name;
        }

        set {
            view.proposed_name = value;
        }
    }

    private Mutex mutex;
    private GLib.List<DeepCount>? deep_count_directories = null;

    private Gee.Set<string>? mimes;
    private ValueLabel contains_value;
    private ValueLabel resolution_value;
    private ValueLabel size_value;
    private ValueLabel type_value;
    private KeyLabel contains_key_label;
    private KeyLabel type_key_label;
    private string ftype; /* common type */
    private Gtk.Spinner spinner;
    private int size_warning = 0;
    private uint64 total_size = 0;

    private uint timeout_perm = 0;
    private GLib.Cancellable? cancellable;

    private bool files_contain_a_directory;

    private uint _uncounted_folders = 0;
    private uint selected_folders = 0;
    private uint selected_files = 0;
    private signal void uncounted_folders_changed ();

    private Gtk.Grid perm_grid;
    private int owner_perm_code = 0;
    private int group_perm_code = 0;
    private int everyone_perm_code = 0;

    private enum AppsColumn {
        APP_INFO,
        LABEL,
        ICON
    }

    private Posix.mode_t[,] vfs_perms = {
        { Posix.S_IRUSR, Posix.S_IWUSR, Posix.S_IXUSR },
        { Posix.S_IRGRP, Posix.S_IWGRP, Posix.S_IXGRP },
        { Posix.S_IROTH, Posix.S_IWOTH, Posix.S_IXOTH }
    };

    private uint uncounted_folders {
        get {
            return _uncounted_folders;
        }

        set {
            _uncounted_folders = value;
            uncounted_folders_changed ();
        }
    }

    /* Count of folders current NOT including top level (selected) folders (to match OverlayBar)*/
    private uint folder_count = 0;
    /* Count of files current including top level (selected) files other than folders */
    private uint file_count;

    public PropertiesWindow (
        GLib.List<Files.File> _files, Files.AbstractDirectoryView _view, Gtk.Window parent
    ) {
        base (_("Properties"), parent);

        if (_files == null) {
            critical ("Properties Window constructor called with null file list");
            return;
        }

        if (_view == null) {
            critical ("Properties Window constructor called with null Directory View");
            return;
        }

        view = _view;

        /* Connect signal before creating any DeepCount directories */
        this.close_request.connect (() => {
            foreach (var dir in deep_count_directories) {
                dir.cancel ();
            }

            return false;
        });

        /* The properties window may outlive the passed-in file object
           lifetimes. The objects must be referenced as a precaution.

           GLib.List.copy() would not guarantee valid references: because it
           does a shallow copy (copying the pointer values only) the objects'
           memory may be freed even while this code is using it. */
        foreach (Files.File file in _files) {
            /* prepend(G) is declared "owned G", so ref() will be called once
               on the unowned foreach value. */
            files.prepend (file);
        }

        var empty = (files == null || files.nth_data (0) == null); // May be large  - avoid length ()

        if (empty ) {
            critical ("Properties Window constructor called with empty file list");
            return;
        }

        if (!(files.data is Files.File)) {
            critical ("Properties Window constructor called with invalid file data (1)");
            return;
        }

        mimes = new Gee.HashSet<string> ();
        foreach (var gof in files) {
            if (!(gof is Files.File)) {
                critical ("Properties Window constructor called with invalid file data (2)");
                return;
            }

            var ftype = gof.get_ftype ();
            if (ftype != null) {
                mimes.add (ftype);
            }

            if (gof.is_directory) {
                files_contain_a_directory = true;
            }
        }

        goffile = (Files.File) files.data;
        only_one = files.nth_data (1) == null;

        construct_info_panel (goffile);
        cancellable = new GLib.Cancellable ();

        update_selection_size (); /* Start counting first to get number of selected files and folders */

        /* create some widgets first (may be hidden by update_selection_size ()) */
        var file_pix = goffile.get_icon_pixbuf (48, get_scale_factor (), Files.File.IconFlags.NONE);
        if (file_pix != null) {
            var file_icon = new Gtk.Image.from_gicon (file_pix);
            overlay_emblems (file_icon, goffile.emblems_list);
        }

        /* Build header box */
        if (!only_one ) {
            var label = new Gtk.Label (get_selected_label (selected_folders, selected_files));
            label.halign = Gtk.Align.START;
            header_title = label;
        } else if (!goffile.is_writable ()) {
            var label = new Gtk.Label (goffile.info.get_name ()) {
                halign = Gtk.Align.START,
                selectable = true
            };
            header_title = label;
        } else {
            entry = new Gtk.Entry ();
            original_name = goffile.info.get_name ();
            reset_entry_text ();

            entry.activate.connect (() => {
                rename_file (goffile, entry.get_text ());
            });

            // entry.focus_out_event.connect (() => {
            //     rename_file (goffile, entry.get_text ());
            //     return false;
            // });

            header_title = entry;
        }

        create_header_title ();

        /* Permissions */
        if (construct_perm_panel () != null) {
            if (!goffile.can_set_permissions ()) {
                var child = perm_grid.get_first_child ();
                while (child != null) {
                    child.set_sensitive (false);
                    child = child.get_next_sibling ();
                }
            }
        } else {
            perm_grid = new Gtk.Grid () {
                valign = Gtk.Align.CENTER
            };
            
            var label = new Gtk.Label (_("Unable to determine file ownership and permissions"));
            perm_grid.attach (label, 0, 0);
        }

        add_section (stack, _("Permissions"), PanelType.PERMISSIONS.to_string (), perm_grid);
    }

    private void update_size_value () {
        size_value.label = format_size (total_size);
        contains_value.label = get_contains_value (folder_count, file_count);
        update_widgets_state ();
        update_storage_block_size (total_size, Files.StorageBar.ItemDescription.FILES);

        if (size_warning > 0) {
            var size_warning_image = new Gtk.Image.from_icon_name ("help-info-symbolic") {
                halign = Gtk.Align.START,
                hexpand = true
            };
            var warning = ngettext (
                "%i file could not be read due to permissions or other errors.",
                "%i files could not be read due to permissions or other errors.",
                (ulong) size_warning
            ).printf (size_warning);

            size_warning_image.tooltip_markup = "<b>" + _("Actual Size Could Be Larger") + "</b>" + "\n" + warning
                                                ;
            info_grid.attach_next_to (size_warning_image, size_value, Gtk.PositionType.RIGHT);
        }
    }

    private void update_selection_size () {
        total_size = 0;
        uncounted_folders = 0;
        selected_folders = 0;
        selected_files = 0;
        folder_count = 0;
        file_count = 0;
        size_warning = 0;

        deep_count_directories = null;

        foreach (Files.File gof in files) {
            if (gof.is_root_network_folder ()) {
                size_value.label = _("unknown");
                continue;
            }
            if (gof.is_directory) {
                mutex.lock ();
                uncounted_folders++; /* this gets decremented by DeepCount*/
                mutex.unlock ();

                selected_folders++;
                var d = new DeepCount (gof.location); /* Starts counting on creation */
                deep_count_directories.prepend (d);

                d.finished.connect (() => {
                    mutex.lock ();
                    deep_count_directories.remove (d);

                    total_size += d.total_size;
                    size_warning = d.file_not_read;
                    if (file_count + uncounted_folders == size_warning) {
                        size_value.label = _("unknown");
                    }

                    folder_count += d.dirs_count;
                    file_count += d.files_count;
                    uncounted_folders--; /* triggers signal which updates description when reaches zero */
                    mutex.unlock ();
                });

            } else {
                selected_files++;
            }

            mutex.lock ();
            total_size += PropertiesWindow.file_real_size (gof);
            mutex.unlock ();
        }

        if (uncounted_folders > 0) {/* possible race condition - uncounted_folders could have been decremented? */
            spinner.start ();
            uncounted_folders_changed.connect (() => {
                if (uncounted_folders == 0) {
                    spinner.hide ();
                    spinner.stop ();
                    update_size_value ();
                }
            });
        } else {
            update_size_value ();
        }
    }

    private void rename_file (Files.File file, string _new_name) {
        /* Only rename if name actually changed */
        original_name = file.info.get_name ();

        var new_name = _new_name.strip (); // Disallow leading and trailing space

        if (new_name != "") { // Do not want a filename consisting of spaces only (even if legal)
            if (new_name != original_name) {
                proposed_name = new_name;
                view.set_file_display_name.begin (file.location, new_name, null, (obj, res) => {
                    GLib.File? new_location = null;
                    try {
                        new_location = view.set_file_display_name.end (res);
                        reset_entry_text (new_location.get_basename ());
                        goffile = Files.File.@get (new_location);
                        files.first ().data = goffile;
                    } catch (Error e) {} // Warning dialog already shown
                });
            }
        } else {
            warning ("Blank name not allowed");
            new_name = original_name;
        }

        reset_entry_text (new_name);
    }

    public void reset_entry_text (string? new_name = null) {
        if (new_name != null) {
            original_name = new_name;
        }

        entry.set_text (original_name);
    }

    private string? get_common_ftype () {
        string? ftype = null;
        if (files == null) {
            return null;
        }

        foreach (Files.File gof in files) {
            var gof_ftype = gof.get_ftype ();
            if (ftype == null && gof != null) {
                ftype = gof_ftype;
                continue;
            }

            if (ftype != gof_ftype) {
                return null;
            }
        }

        return ftype;
    }

    private bool got_common_location () {
        GLib.File? loc = null;
        foreach (Files.File gof in files) {
            if (loc == null && gof != null) {
                if (gof.directory == null) {
                    return false;
                }

                loc = gof.directory;
                continue;
            }

            if (!loc.equal (gof.directory)) {
                return false;
            }
        }

        return true;
    }

    private GLib.File? get_parent_loc (string path) {
        var loc = GLib.File.new_for_path (path);
        return loc.get_parent ();
    }

    private string? get_common_trash_orig () {
        GLib.File loc = null;
        string path = null;

        foreach (Files.File gof in files) {
            if (loc == null && gof != null) {
                loc = get_parent_loc (gof.info.get_attribute_byte_string (FileAttribute.TRASH_ORIG_PATH));
                continue;
            }

            if (gof != null &&
                !loc.equal (get_parent_loc (gof.info.get_attribute_byte_string (FileAttribute.TRASH_ORIG_PATH)))) {

                return null;
            }
        }

        if (loc == null) {
            path = "/";
        } else {
            path = loc.get_parse_name ();
        }

        return path;
    }

    private string filetype (Files.File file) {
        ftype = get_common_ftype ();
        if (ftype != null) {
            return ftype;
        } else {
            /* show list of mimetypes only if we got a default application in common */
            if (view.get_default_app () != null && !goffile.is_directory) {
                string str = null;
                foreach (var mime in mimes) {
                    (str == null) ? str = mime : str = string.join (", ", str, mime);
                }
                return str;
            }
        }
        return _("Unknown");
    }

    private string resolution (Files.File file) {
        /* get image size in pixels using an asynchronous method to stop the interface blocking on
         * large images. */
        if (file.width > 0) { /* resolution has already been determined */
            return goffile.width.to_string () + " × " + goffile.height.to_string () + " px";
        } else {
            /* Async function will update info when resolution determined */
            get_resolution.begin (file);
            return _("Loading…");
        }
    }

    private string location (Files.File file) {
        if (view.in_recent) {
            string original_location = file.get_display_target_uri ().replace ("%20", " ");
            string file_name = file.get_display_name ().replace ("%20", " ");
            string location_folder = original_location.slice (0, -file_name.length).replace ("%20", " ");
            string location_name = location_folder.slice (7, -1);

            return "<a href=\"" + Markup.escape_text (location_folder) +
                   "\">" + Markup.escape_text (location_name) + "</a>";
        } else {
            return "<a href=\"" + Markup.escape_text (file.directory.get_uri ()) +
                   "\">" + Markup.escape_text (file.directory.get_parse_name ()) + "</a>";
        }
    }

    private string original_location (Files.File file) {
        /* print orig location of trashed files */
        if (file.info.get_attribute_byte_string (FileAttribute.TRASH_ORIG_PATH) != null) {
            var trash_orig_loc = get_common_trash_orig ();
            if (trash_orig_loc != null) {
                var orig_pth = file.info.get_attribute_byte_string (FileAttribute.TRASH_ORIG_PATH);
                return "<a href=\"" + get_parent_loc (orig_pth).get_uri () + "\">" + trash_orig_loc + "</a>";
            }
        }
        return _("Unknown");
    }

    private async void get_resolution (Files.File goffile) {
        GLib.FileInputStream? stream = null;
        GLib.File file = goffile.location;
        string resolution = _("Could not be determined");

        try {
            stream = yield file.read_async (0, cancellable);
            if (stream == null) {
                error ("Could not read image file's size data");
            } else {
                var pixbuf = yield new Gdk.Pixbuf.from_stream_async (stream, cancellable);
                goffile.width = pixbuf.get_width ();
                goffile.height = pixbuf.get_height ();
                resolution = goffile.width.to_string () + " × " + goffile.height.to_string () + " px";
            }
        } catch (Error e) {
            warning ("Error loading image resolution in PropertiesWindow: %s", e.message);
        }
        try {
            stream.close ();
        } catch (GLib.Error e) {
            debug ("Error closing stream in get_resolution: %s", e.message);
        }

        resolution_value.label = resolution;
    }

    private void construct_info_panel (Files.File file) {
        /* Have to have these separate as size call is async */
        var size_key_label = new KeyLabel (_("Size:"));

        spinner = new Gtk.Spinner ();
        spinner.halign = Gtk.Align.START;

        size_value = new ValueLabel ("");

        type_key_label = new KeyLabel (_("Type:"));
        type_value = new ValueLabel ("");

        contains_key_label = new KeyLabel (_("Contains:"));
        contains_value = new ValueLabel ("");

        // /* Dialog may get displayed after these labels are hidden so we set no_show_all to true */
        // type_key_label.no_show_all = true;
        // type_value.no_show_all = true;
        // contains_key_label.no_show_all = true;
        // contains_value.no_show_all = true;

        info_grid.attach (size_key_label, 0, 1, 1, 1);
        info_grid.attach_next_to (spinner, size_key_label, Gtk.PositionType.RIGHT);
        info_grid.attach_next_to (size_value, size_key_label, Gtk.PositionType.RIGHT);
        info_grid.attach (type_key_label, 0, 2, 1, 1);
        info_grid.attach_next_to (type_value, type_key_label, Gtk.PositionType.RIGHT, 3, 1);
        info_grid.attach (contains_key_label, 0, 3, 1, 1);
        info_grid.attach_next_to (contains_value, contains_key_label, Gtk.PositionType.RIGHT, 3, 1);

        int n = 4;

        if (only_one) {
            /* Note most Linux filesystem do not store file creation time */
            var time_created = FileUtils.get_formatted_time_attribute_from_info (file.info,
                                                                                 FileAttribute.TIME_CREATED);
            if (time_created != "") {
                var key_label = new KeyLabel (_("Created:"));
                var value_label = new ValueLabel (time_created);
                info_grid.attach (key_label, 0, n, 1, 1);
                info_grid.attach_next_to (value_label, key_label, Gtk.PositionType.RIGHT, 3, 1);
                n++;
            }

            var time_modified = FileUtils.get_formatted_time_attribute_from_info (file.info,
                                                                                  FileAttribute.TIME_MODIFIED);

            if (time_modified != "") {
                var key_label = new KeyLabel (_("Modified:"));
                var value_label = new ValueLabel (time_modified);
                info_grid.attach (key_label, 0, n, 1, 1);
                info_grid.attach_next_to (value_label, key_label, Gtk.PositionType.RIGHT, 3, 1);
                n++;
            }
        }

        if (only_one && file.is_trashed ()) {
            var deletion_date = FileUtils.get_formatted_time_attribute_from_info (file.info,
                                                                                  FileAttribute.TRASH_DELETION_DATE);
            if (deletion_date != "") {
                var key_label = new KeyLabel (_("Deleted:"));
                var value_label = new ValueLabel (deletion_date);
                info_grid.attach (key_label, 0, n, 1, 1);
                info_grid.attach_next_to (value_label, key_label, Gtk.PositionType.RIGHT, 3, 1);
                n++;
            }
        }

        var ftype = filetype (file);

        var mimetype_key = new KeyLabel (_("Media type:"));
        var mimetype_value = new ValueLabel (ftype);
        info_grid.attach (mimetype_key, 0, n, 1, 1);
        info_grid.attach_next_to (mimetype_value, mimetype_key, Gtk.PositionType.RIGHT, 3, 1);
        n++;

        if (only_one && "image" in ftype) {
            var resolution_key = new KeyLabel (_("Resolution:"));
            resolution_value = new ValueLabel (resolution (file));
            info_grid.attach (resolution_key, 0, n, 1, 1);
            info_grid.attach_next_to (resolution_value, resolution_key, Gtk.PositionType.RIGHT, 3, 1);
            n++;
        }

        if (got_common_location ()) {
            var location_key = new KeyLabel (_("Location:"));
            var location_value = new ValueLabel (location (file));
            location_value.ellipsize = Pango.EllipsizeMode.MIDDLE;
            location_value.max_width_chars = 32;
            info_grid.attach (location_key, 0, n, 1, 1);
            info_grid.attach_next_to (location_value, location_key, Gtk.PositionType.RIGHT, 3, 1);
            n++;
        }

        if (only_one && file.info.get_is_symlink ()) {
            var key_label = new KeyLabel (_("Target:"));
            var value_label = new ValueLabel (file.info.get_symlink_target ());
            info_grid.attach (key_label, 0, n, 1, 1);
            info_grid.attach_next_to (value_label, key_label, Gtk.PositionType.RIGHT, 3, 1);
            n++;
        }

        if (file.is_trashed ()) {
            var key_label = new KeyLabel (_("Original Location:"));
            var value_label = new ValueLabel (original_location (file));
            info_grid.attach (key_label, 0, n, 1, 1);
            info_grid.attach_next_to (value_label, key_label, Gtk.PositionType.RIGHT, 3, 1);
            n++;
        }

        /* Open with */
        if (view.get_default_app () != null && !goffile.is_directory) {
            Gtk.TreeIter iter;

            AppInfo default_app = view.get_default_app ();
            store_apps = new Gtk.ListStore (3, typeof (AppInfo), typeof (string), typeof (Icon));
            unowned List<AppInfo> apps = view.get_open_with_apps ();
            foreach (var app in apps) {
                store_apps.append (out iter);
                store_apps.set (iter,
                                AppsColumn.APP_INFO, app,
                                AppsColumn.LABEL, app.get_name (),
                                AppsColumn.ICON, ensure_icon (app));
            }
            store_apps.append (out iter);
            store_apps.set (iter,
                            AppsColumn.LABEL, _("Other Application…"));
            store_apps.prepend (out iter);
            store_apps.set (iter,
                            AppsColumn.APP_INFO, default_app,
                            AppsColumn.LABEL, default_app.get_name (),
                            AppsColumn.ICON, ensure_icon (default_app));

            var renderer = new Gtk.CellRendererText ();
            var pix_renderer = new Gtk.CellRendererPixbuf ();

            var combo = new Gtk.ComboBox.with_model ((Gtk.TreeModel) store_apps);
            combo.active = 0;
            combo.valign = Gtk.Align.CENTER;
            combo.pack_start (pix_renderer, false);
            combo.pack_start (renderer, true);
            combo.add_attribute (renderer, "text", AppsColumn.LABEL);
            combo.add_attribute (pix_renderer, "gicon", AppsColumn.ICON);

            combo.changed.connect (combo_open_with_changed);

            var key_label = new KeyLabel (_("Open with:"));

            info_grid.attach (key_label, 0, n, 1, 1);
            info_grid.attach_next_to (combo, key_label, Gtk.PositionType.RIGHT);
            n++;
        }

        /* Device Usage */
        if (should_show_device_usage ()) {
            try {
                var info = goffile.get_target_location ().query_filesystem_info ("filesystem::*");
                create_storage_bar (info, n);
            } catch (Error e) {
                warning ("error: %s", e.message);
            }
        }
    }

    private bool should_show_device_usage () {
        if (files_contain_a_directory) {
            return true;
        }

        if (only_one) {
            if (goffile.can_unmount ()) {
                return true;
            }

            var rootfs_loc = GLib.File.new_for_uri ("file:///");
            if (goffile.get_target_location ().equal (rootfs_loc)) {
                return true;
            }
        }

        return false;
    }

    private void update_perm_codes (Permissions.Type pt, int val, int mult) {
        switch (pt) {
        case Permissions.Type.USER:
            owner_perm_code += mult * val;
            break;
        case Permissions.Type.GROUP:
            group_perm_code += mult * val;
            break;
        case Permissions.Type.OTHER:
            everyone_perm_code += mult * val;
            break;
        }
    }

    private void permission_button_toggle (Gtk.ToggleButton btn) {
        unowned Permissions.Type pt = btn.get_data ("permissiontype");
        unowned Permissions.Value permission_value = btn.get_data ("permissionvalue");
        int mult = 1;

        reset_and_cancel_perm_timeout ();

        if (!btn.get_active ()) {
            mult = -1;
        }

        switch (permission_value) {
            case Permissions.Value.READ:
                update_perm_codes (pt, 4, mult);
                break;
            case Permissions.Value.WRITE:
                update_perm_codes (pt, 2, mult);
                break;
            case Permissions.Value.EXE:
                update_perm_codes (pt, 1, mult);
                break;
        }

        if (perm_code_should_update) {
            perm_code.set_text ("%d%d%d".printf (owner_perm_code, group_perm_code, everyone_perm_code));
        }
    }

    private PermissionButton create_perm_choice (Permissions.Type pt) {
        var permission_button = new PermissionButton (pt);
        permission_button.btn_read.toggled.connect (permission_button_toggle);
        permission_button.btn_write.toggled.connect (permission_button_toggle);
        permission_button.btn_exe.toggled.connect (permission_button_toggle);
        return permission_button;
    }

    private uint32 get_perm_from_chmod_unit (uint32 vfs_perm, int nb,
                                             int chmod, Permissions.Type pt) {
        if (nb > 7 || nb < 0) {
            critical ("erroned chmod code %d %d", chmod, nb);
        }

        int[] chmod_types = { 4, 2, 1};

        int i = 0;
        for (; i < 3; i++) {
            int div = nb / chmod_types[i];
            int modulo = nb % chmod_types[i];
            if (div >= 1) {
                vfs_perm |= vfs_perms[pt,i];
            }

            nb = modulo;
        }

        return vfs_perm;
    }

    private uint32 chmod_to_vfs (int chmod) {
        uint32 vfs_perm = 0;

        /* user */
        vfs_perm = get_perm_from_chmod_unit (vfs_perm, (int) chmod / 100,
                                             chmod, Permissions.Type.USER);
        /* group */
        vfs_perm = get_perm_from_chmod_unit (vfs_perm, (int) (chmod / 10) % 10,
                                             chmod, Permissions.Type.GROUP);
        /* other */
        vfs_perm = get_perm_from_chmod_unit (vfs_perm, (int) chmod % 10,
                                             chmod, Permissions.Type.OTHER);

        return vfs_perm;
    }


    private void update_perm_grid_toggle_states (uint32 permissions) {
        perm_button_user.update_buttons (permissions);
        perm_button_group.update_buttons (permissions);
        perm_button_other.update_buttons (permissions);
    }

    private void reset_and_cancel_perm_timeout () {
        if (cancellable != null) {
            cancellable.cancel ();
            cancellable.reset ();
        }
        if (timeout_perm != 0) {
            Source.remove (timeout_perm);
            timeout_perm = 0;
        }
    }

    private async void file_set_attributes (Files.File file, string attr,
                                            uint32 val, Cancellable? _cancellable = null) {
        FileInfo info = new FileInfo ();

        try {
            info.set_attribute_uint32 (attr, val);
            yield file.location.set_attributes_async (info,
                                                      FileQueryInfoFlags.NONE,
                                                      Priority.DEFAULT,
                                                      _cancellable, null);
        } catch (Error e) {
            warning ("Could not set file attribute %s: %s", attr, e.message);
        }
    }

    private void entry_changed () {
        var str = perm_code.get_text ();
        if (Permissions.is_chmod_code (str)) {
            reset_and_cancel_perm_timeout ();
            timeout_perm = Timeout.add (60, () => {
                uint32 perm = chmod_to_vfs (int.parse (str));
                perm_code_should_update = false;
                update_perm_grid_toggle_states (perm);
                perm_code_should_update = true;
                int n = 0;
                foreach (Files.File gof in files) {
                    if (gof.can_set_permissions () && gof.permissions != perm) {
                        gof.permissions = perm;

                        /* update permission label once */
                        if (n < 1) {
                            l_perm.label = "<tt>%s</tt>".printf (goffile.get_permissions_as_string ());
                        }

                        /* real update permissions */
                        file_set_attributes.begin (gof, FileAttribute.UNIX_MODE, perm, cancellable);
                        n++;
                    } else {
                        warning ("can't change permission on %s", gof.uri);
                    }
                }

                timeout_perm = 0;

                return GLib.Source.REMOVE;
            });
        }
    }

    private void combo_owner_changed (Gtk.ComboBox combo) {
        Gtk.TreeIter iter;
        string user;
        Posix.uid_t? uid = null;

        if (!combo.get_active_iter (out iter)) {
            return;
        }

        store_users.get (iter, 0, out user);

        if (!goffile.can_set_owner ()) {
            critical ("error can't set user");
            return;
        }

        uid = PF.UserUtils.get_user_id_from_user_name (user);
        if (uid == null) {
            uid = PF.UserUtils.get_id_from_digit_string (user);
        }

        if (uid == null) {
            critical ("user doesn t exit");
            return;
        }

        if (uid == goffile.uid) {
            return;
        }

        foreach (Files.File gof in files) {
            file_set_attributes.begin (gof, FileAttribute.UNIX_UID, (uint32) uid);
        }
    }

    private void combo_group_changed (Gtk.ComboBox combo) {
        Gtk.TreeIter iter;
        string group;
        Posix.uid_t? gid;

        if (!combo.get_active_iter (out iter)) {
            return;
        }

        store_groups.get (iter, 0, out group);

        if (!goffile.can_set_group ()) {
            critical ("error can't set group");
            return;
        }

        /* match gid from name */

        gid = PF.UserUtils.get_group_id_from_group_name (group);
        if (gid == null) {
            gid = PF.UserUtils.get_id_from_digit_string (group);
        }

        if (gid == null) {
            critical ("group doesn t exit");
            return;
        }

        if (gid == goffile.gid) {
            return;
        }

        foreach (Files.File gof in files) {
            file_set_attributes.begin (gof, FileAttribute.UNIX_GID, (uint32) gid);
        }
    }

    private Gtk.Grid? construct_perm_panel () {
        var owner_user_choice = create_owner_choice ();
        if (owner_user_choice == null) {
            return null;
        } else {
            var owner_user_label = new KeyLabel (_("Owner:"));
            var group_combo_label = new KeyLabel (_("Group:"));
            group_combo_label.margin_bottom = 12;

            var group_combo = create_group_choice ();
            group_combo.margin_bottom = 12;

            var owner_label = new KeyLabel (_("Owner:"));
            perm_button_user = create_perm_choice (Permissions.Type.USER);

            var group_label = new KeyLabel (_("Group:"));
            perm_button_group = create_perm_choice (Permissions.Type.GROUP);

            var other_label = new KeyLabel (_("Everyone:"));
            perm_button_other = create_perm_choice (Permissions.Type.OTHER);

            perm_code = new Gtk.Entry ();
            perm_code.text = "000";
            perm_code.max_length = perm_code.max_width_chars = perm_code.width_chars = 3;

            l_perm = new Gtk.Label ("<tt>%s</tt>".printf (goffile.get_permissions_as_string ()));
            l_perm.halign = Gtk.Align.START;
            l_perm.use_markup = true;

            perm_grid = new Gtk.Grid () {
                column_spacing = 6,
                row_spacing = 6,
                halign = Gtk.Align.CENTER
            };
            perm_grid.attach (owner_user_label, 0, 1, 1, 1);
            perm_grid.attach (owner_user_choice, 1, 1, 2, 1);
            perm_grid.attach (group_combo_label, 0, 2, 1, 1);
            perm_grid.attach (group_combo, 1, 2, 2, 1);
            perm_grid.attach (owner_label, 0, 3, 1, 1);
            perm_grid.attach (perm_button_user, 1, 3, 2, 1);
            perm_grid.attach (group_label, 0, 4, 1, 1);
            perm_grid.attach (perm_button_group, 1, 4, 2, 1);
            perm_grid.attach (other_label, 0, 5, 1, 1);
            perm_grid.attach (perm_button_other, 1, 5, 2, 1);
            perm_grid.attach (l_perm, 1, 6, 1, 1);
            perm_grid.attach (perm_code, 2, 6, 1, 1);

            update_perm_grid_toggle_states (goffile.permissions);

            perm_code.changed.connect (entry_changed);
        }

        return perm_grid;
    }

    private bool selection_can_set_owner () {
        foreach (Files.File gof in files) {
            if (!gof.can_set_owner ()) {
                return false;
            }
        }

        return true;
    }

    private string? get_common_owner () {
        uint32 uid = -1;
        if (files == null) {
            return null;
        }

        foreach (Files.File gof in files) {
            if (uid == -1 && gof != null) {
                uid = gof.uid;
                continue;
            }

            if (gof != null && uid != gof.uid) {
                return null;
            }
        }

        return goffile.owner;
    }

    private bool selection_can_set_group () {
        foreach (Files.File gof in files) {
            if (!gof.can_set_group ()) {
                return false;
            }
        }

        return true;
    }

    private string? get_common_group () {
        uint32 gid = -1;
        if (files == null) {
            return null;
        }

        foreach (Files.File gof in files) {
            if (gid == -1 && gof != null) {
                gid = gof.gid;
                continue;
            }

            if (gof != null && gid != gof.gid) {
                return null;
            }
        }

        return goffile.group;
    }

    private Gtk.Widget? create_owner_choice () {
        Gtk.Widget? choice = null;
        if (selection_can_set_owner ()) {
            GLib.List<string> users;
            Gtk.TreeIter iter;

            store_users = new Gtk.ListStore (1, typeof (string));
            users = PF.UserUtils.get_user_names ();
            int owner_index = -1;
            int i = 0;
            foreach (var user in users) {
                if (user == goffile.owner) {
                    owner_index = i;
                }
                store_users.append (out iter);
                store_users.set (iter, 0, user);
                i++;
            }

            /* If ower is not known, we prepend it.
             * It happens when the owner has no matching identifier in the password file.
             */
            if (owner_index == -1) {
                store_users.prepend (out iter);
                store_users.set (iter, 0, goffile.owner);
            }

            var combo = new Gtk.ComboBox.with_model ((Gtk.TreeModel) store_users);
            var renderer = new Gtk.CellRendererText ();
            combo.pack_start (renderer, true);
            combo.add_attribute (renderer, "text", 0);
            if (owner_index == -1) {
                combo.set_active (0);
            } else {
                combo.set_active (owner_index);
            }

            combo.changed.connect (combo_owner_changed);

            choice = (Gtk.Widget) combo;
        } else {
            string? common_owner = get_common_owner ();
            if (common_owner == null) {
                return null;
            }

            choice = (Gtk.Widget) new Gtk.Label (common_owner);
            choice.set_halign (Gtk.Align.START);
        }

        choice.set_valign (Gtk.Align.CENTER);

        return choice;
    }

    private Gtk.Widget create_group_choice () {
        Gtk.Widget choice;

        if (selection_can_set_group ()) {
            GLib.List<string> groups;
            Gtk.TreeIter iter;

            store_groups = new Gtk.ListStore (1, typeof (string));
            groups = goffile.get_settable_group_names ();
            int group_index = -1;
            int i = 0;
            foreach (var group in groups) {
                if (group == goffile.group) {
                    group_index = i;
                }

                store_groups.append (out iter);
                store_groups.set (iter, 0, group);
                i++;
            }

            /* If ower is not known, we prepend it.
             * It happens when the owner has no matching identifier in the password file.
             */
            if (group_index == -1) {
                store_groups.prepend (out iter);
                store_groups.set (iter, 0, goffile.owner);
            }

            var combo = new Gtk.ComboBox.with_model ((Gtk.TreeModel) store_groups);
            var renderer = new Gtk.CellRendererText ();
            combo.pack_start (renderer, true);
            combo.add_attribute (renderer, "text", 0);

            if (group_index == -1) {
                combo.set_active (0);
            } else {
                combo.set_active (group_index);
            }

            combo.changed.connect (combo_group_changed);

            choice = (Gtk.Widget) combo;
        } else {
            string? common_group = get_common_group ();
            if (common_group == null) {
                common_group = "--";
            }

            choice = (Gtk.Widget) new Gtk.Label (common_group);
            choice.set_halign (Gtk.Align.START);
        }

        choice.set_valign (Gtk.Align.CENTER);

        return choice;
    }

    private Icon ensure_icon (AppInfo app) {
        Icon icon = app.get_icon ();
        if (icon == null) {
            icon = new ThemedIcon ("application-x-executable");
        }

        return icon;
    }

    private void combo_open_with_changed (Gtk.ComboBox combo) {
        Gtk.TreeIter iter;
        string app_label;
        AppInfo? app;

        if (!combo.get_active_iter (out iter)) {
            return;
        }

        store_apps.get (iter,
                        AppsColumn.LABEL, out app_label,
                        AppsColumn.APP_INFO, out app);

        if (app == null) {
            var app_chosen = MimeActions.choose_app_for_glib_file (goffile.location, this);
            if (app_chosen != null) {
                store_apps.prepend (out iter);
                store_apps.set (iter,
                                AppsColumn.APP_INFO, app_chosen,
                                AppsColumn.LABEL, app_chosen.get_name (),
                                AppsColumn.ICON, ensure_icon (app_chosen));
                combo.set_active (0);
            }
        } else {
            try {
                foreach (var mime in mimes) {
                    app.set_as_default_for_type (mime);
                }
            } catch (Error e) {
                critical ("Couldn't set as default: %s", e.message);
            }
        }
    }

    public static uint64 file_real_size (Files.File gof) {
        if (!gof.is_connected) {
            return 0;
        }

        uint64 file_size = gof.size;
        if (gof.location is GLib.File) {
            try {
                var info = gof.location.query_info (FileAttribute.STANDARD_ALLOCATED_SIZE, FileQueryInfoFlags.NONE);
                uint64 allocated_size = info.get_attribute_uint64 (FileAttribute.STANDARD_ALLOCATED_SIZE);
                /* Check for sparse file, allocated size will be smaller, for normal files allocated size
                 * includes overhead size so we don't use it for those here
                 */
                if (allocated_size > 0 && allocated_size < file_size && !gof.is_directory) {
                    file_size = allocated_size;
                }
            } catch (Error err) {
                debug ("%s", err.message);
                gof.is_connected = false;
            }
        }
        return file_size;
    }

    private string get_contains_value (uint folders, uint files) {
        string folders_txt = "";
        string files_txt = "";

        if (folders > 0) {
            folders_txt = (ngettext ("%u subfolder", "%u subfolders", folders)).printf (folders);
        }

        if (files > 0) {
            files_txt = (ngettext ("%u file", "%u files", files)).printf (files);
        }

        if (folders > 0 && files > 0) {
            ///TRANSLATORS: folders, files
            return _("%s, %s").printf (folders_txt, files_txt);
        } else if (files > 0) {
            return files_txt;
        } else {
            return folders_txt;
        }
    }

    private string get_selected_label (uint folders, uint files) {
        string folders_txt = "";
        string files_txt = "";

        if (folders > 0) {
            folders_txt = (ngettext ("%u folder", "%u folders", folders)).printf (folders);
        }

        if (files > 0) {
            files_txt = (ngettext ("%u file", "%u files", files)).printf (files);
        }

        if (files > 0 && folders > 0) {
            var total = folders + files;
            string total_txt = (ngettext ("%u selected item", "%u selected items", total)).printf (total);
            ///TRANSLATORS: total (folders, files)
            return _("%s (%s, %s)").printf (total_txt, folders_txt, files_txt);
        } else if (files > 0) {
            return files_txt;
        } else {
            return folders_txt;
        }
    }

    /** Hide certain widgets under certain conditions **/
    private void update_widgets_state () {
        if (uncounted_folders == 0) {
            spinner.hide ();
        }

        if (!only_one) {
            type_key_label.hide ();
            type_value.hide ();
        } else {
            if (ftype != null) {
                type_value.label = goffile.formated_type;
            }
        }

        if ((header_title is Gtk.Entry) && !view.in_recent) {
            int start_offset= 0, end_offset = -1;

            FileUtils.get_rename_region (goffile.info.get_name (), out start_offset, out end_offset,
                                         goffile.is_folder ());

            ((Gtk.Entry) header_title).select_region (start_offset, end_offset);
        }

        /* Only show 'contains' label when only folders selected - otherwise could be ambiguous whether
         * the "contained files" counted are only in the subfolders or not.*/
        /* Only show 'contains' label when folders selected are not empty */
        if (selected_files > 0 || contains_value.label.length < 1) {
            contains_key_label.hide ();
            contains_value.hide ();
        } else { /* Make sure it shows otherwise (may have been hidden by previous call)*/
            contains_key_label.show ();
            contains_value.show ();
        }
    }
}
}
