/*
 * Copyright (C) 2011 Marlin Developers
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
 *
 * Author: ammonkey <am.monkeyd@gmail.com>
 */

public class Marlin.View.PropertiesWindow : Granite.Widgets.LightWindow {
    private class Pair<F, G> {
        public F key;
        public G value;

        public Pair (F key, G value) {
            this.key = key;
            this.value = value;
        }
    }

    private Gee.LinkedList<Pair<string, string>> info;
    private Granite.Widgets.ImgEventBox evbox;
    private Granite.Widgets.XsEntry perm_code;
    private bool perm_code_should_update = true;
    private Gtk.Label l_perm;

    private Gtk.ListStore store_users;
    private Gtk.ListStore store_groups;
    private Gtk.ListStore store_apps;

    private uint count;
    private GLib.List<GOF.File> files;
    private GOF.File goffile;
    private FM.Directory.View view;

    private Gee.Set<string>? mimes;

    private Granite.Widgets.WrapLabel header_title;
    private Gtk.Label header_desc;
    private string ftype; /* common type */
    private Gtk.Spinner spinner;
    private Gtk.Label spinner_label;

    private uint timeout_perm = 0;
    private GLib.Cancellable? cancellable;

    private Gtk.SizeGroup sg;

    private bool files_contain_a_directory;

    //To stop the spinner
    private uint _folder_count;
    private signal void folder_count_changed ();

    private uint folder_count {
        get {
            return _folder_count;
        }

        set {
            _folder_count = value;
            folder_count_changed ();
        }
    }

    private uint file_count;

    private enum PanelType {
        INFO,
        PERMISSIONS,
        PREVIEW
    }

    public PropertiesWindow (GLib.List<GOF.File> _files, FM.Directory.View _view, Gtk.Window parent) {
        title = _("Properties");
        resizable = false;
        set_default_size (220, -1);


        // Set the default containers
        var content_area = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        var action_area = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        border_width = 5;
        sg = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);

        add (content_area);
        add (action_area);

        var content_vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        //var content_vbox = new VBox(false, 12);
        content_area.pack_start (content_vbox);

        // Adjust sizes
        content_vbox.margin_right = 5;
        content_vbox.margin_left = 5;

        view = _view;
        files = _files.copy ();
        count = files.length();
        goffile = (GOF.File) files.data;

        mimes = new Gee.HashSet<string> ();
        foreach (var gof in files)
        {
            var ftype = gof.get_ftype ();
            if (ftype != null)
                mimes.add (ftype);
            if (gof.is_directory)
                files_contain_a_directory = true;
        }

        get_info (goffile);
        cancellable = new GLib.Cancellable ();

        /* Header Box */
        var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 9);
        add_header_box (content_vbox, header_box);

        /* Static Notebook */
        var notebook = new Granite.Widgets.StaticNotebook ();
        notebook.margin_bottom = 15;
        content_vbox.pack_start (notebook, true, true, 0);

        /* Info */
        if (info.size > 0) {
            var info_vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            construct_info_panel (info_vbox, info);
            add_section (notebook, _("General"), PanelType.INFO, info_vbox);
        }

        /* Permissions */
        /* Don't show permissions for uri scheme trash and archives */
        if (!(count == 1 && !goffile.location.is_native () && !goffile.is_remote_uri_scheme ())) {
            var perm_vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            construct_perm_panel (perm_vbox);
            add_section (notebook, _("More"), PanelType.PERMISSIONS, perm_vbox);
            if (!goffile.can_set_permissions ()) {
                foreach (var widget in perm_vbox.get_children ())
                    widget.set_sensitive (false);
            }
        }

        /* Preview */
        //message ("flag %d", (int) goffile.flags);
        if (count == 1 && goffile.flags != 0) {
            /* Retrieve the low quality (existent) thumbnail.
            This will be shown to prevent resizing the properties window
            when the large preview is retrieved. */
            var small_preview = goffile.get_icon_pixbuf (256, true, GOF.FileIconFlags.USE_THUMBNAILS);
            /* Request the creation of the large thumbnail */
            Marlin.Thumbnailer.get ().queue_file (goffile, null, /* LARGE */ true);
            var preview_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            construct_preview_panel (preview_box, small_preview);
            add_section (notebook, _("Preview"), PanelType.PREVIEW, preview_box);
        }

        set_transient_for (parent);
        set_position (Gtk.WindowPosition.CENTER_ALWAYS);
        set_destroy_with_parent (true);

        content_vbox.show ();
        content_area.show_all ();
        show_all ();

        present ();

        if (folder_count == 0) {
            spinner.hide ();
        } else if (file_count == 0) {
            header_desc.hide ();
        }

        if (file_count > 0)
            spinner_label.hide ();
    }


    private string span_weight_light (string str) {
        return "<span weight='light'>" + str + "</span>";
    }

    private uint64 total_size = 0;

    private void update_header_desc () {
        string header_desc_str;

        //header_desc_str = Eel.format_size (total_size);
        header_desc_str = format_size ((int64) total_size);
        if (ftype != null) {
            header_desc_str += ", " + goffile.formated_type;
        }
        header_desc.set_markup (span_weight_light(header_desc_str));
    }

    private Mutex mutex;
    private GLib.List<Marlin.DeepCount>? deep_count_directories = null;

    private void selection_size_update () {
        total_size = 0;
        deep_count_directories = null;
        folder_count = 0;
        file_count = 0;

        foreach (GOF.File gof in files) {
            if (gof.is_directory) {
                folder_count++;
                var d = new Marlin.DeepCount (gof.location);
                deep_count_directories.prepend (d);
                d.finished.connect (() => {
                                    mutex.lock ();
                                    deep_count_directories.remove (d);
                                    total_size += d.total_size;
                                    update_header_desc ();
                                    folder_count--;
                                    if (!header_desc.visible)
                                        header_desc.show ();
                                    if (spinner_label.visible)
                                        spinner_label.hide ();
                                    mutex.unlock ();
                                    });
            } else {
                file_count++;
            }

            mutex.lock ();
            total_size += gof.size;
            mutex.unlock ();
        }

        if (file_count > 0)
            update_header_desc ();

        if (folder_count > 0) {
            spinner.start ();

            folder_count_changed.connect (() => {
                if (folder_count == 0) {
                    spinner_label.hide ();
                    spinner.hide ();
                    spinner.stop ();
                }
            });
        }

        this.destroy.connect (() => {
            foreach (var dir in deep_count_directories)
                dir.cancel ();
        });
    }
/*
    private void selection_size_cancel () {
        foreach (var d in deep_count_directories) {
            mutex.lock ();
            d.cancel ();
            deep_count_directories.remove (d);
            mutex.unlock ();
        }
        deep_count_directories = null;
    }
*/
    private void add_header_box (Gtk.Box vbox, Gtk.Box content) {
        var file_pix = goffile.get_icon_pixbuf (48, false, GOF.FileIconFlags.NONE);
        var file_img = new Gtk.Image.from_pixbuf (file_pix);
        file_img.set_valign (Gtk.Align.START);
        content.pack_start (file_img, false, false);

        var vvbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        content.pack_start (vvbox);

        header_title = new Granite.Widgets.WrapLabel ();
        if (count > 1)
            header_title.set_markup ("<span weight='semibold' size='large'>" + _("%u selected items").printf(count) + "</span>");
        else
            header_title.set_markup ("<span weight='semibold' size='large'>" + goffile.info.get_name () + "</span>");

        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);
        hbox.set_halign (Gtk.Align.START);

        spinner = new Gtk.Spinner ();
        spinner.set_hexpand (false);
        spinner_label = new Gtk.Label (_("Calculating size…"));

        header_desc = new Gtk.Label (null);
        header_desc.set_use_markup (true);

        if (ftype != null) {
            header_desc.set_markup (span_weight_light (goffile.formated_type));
        }

        selection_size_update ();

        hbox.pack_start (spinner);
        hbox.pack_start (spinner_label);
        hbox.pack_start (header_desc);

        /*var font_style = new Pango.FontDescription();
          font_style.set_size(12 * 1000);
          header_title.modify_font(font_style);*/

        vvbox.pack_start (header_title);
        vvbox.pack_start (hbox);

        /* Bottom padding */
        vvbox.margin_bottom = 12;

        vbox.pack_start (content, false, false, 0);
    }

    private void add_section (Granite.Widgets.StaticNotebook notebook, string title, PanelType type, Gtk.Box content) {
        if (content != null) {
            content.set_border_width (5);
            content.margin_right = 15;
            content.margin_left = 0;
            notebook.append_page(content, new Gtk.Label (title));
        }
    }

    private string? get_common_ftype () {
        string? ftype = null;
        if (files == null)
            return null;

        foreach (GOF.File gof in files) {
            var gof_ftype = gof.get_ftype ();
            if (ftype == null && gof != null) {
                ftype = gof_ftype;
                continue;
            }
            if (ftype != gof_ftype)
                return null;
        }

        return ftype;
    }

    private bool got_common_location () {
        File? loc = null;
        foreach (GOF.File gof in files) {
            if (loc == null && gof != null) {
                if (gof.directory == null)
                    return false;
                loc = gof.directory;
                continue;
            }
            if (!loc.equal (gof.directory))
                return false;
        }

        return true;
    }

    private GLib.File? get_parent_loc (string path) {
        var loc = File.new_for_path (path);
        return loc.get_parent ();
    }

    private string? get_common_trash_orig () {
        File loc = null;
        string path = null;

        foreach (GOF.File gof in files) {
            if (loc == null && gof != null) {
                loc = get_parent_loc (gof.info.get_attribute_byte_string (FileAttribute.TRASH_ORIG_PATH));
                continue;
            }
            if (!loc.equal (get_parent_loc (gof.info.get_attribute_byte_string (FileAttribute.TRASH_ORIG_PATH))))
                return null;
        }

        if (loc == null)
            path = "/";
        else
            path = loc.get_parse_name();

        return path;
    }

    private void get_info (GOF.File file) {
        info = new Gee.LinkedList<Pair<string, string>>();

        /* localized time depending on MARLIN_PREFERENCES_DATE_FORMAT locale, iso .. */
        if (count == 1) {
            var time_created = file.get_formated_time (FileAttribute.TIME_CREATED);
            if (time_created != null)
                info.add (new Pair<string, string>(_("Created") + (": "), time_created));
            if (file.formated_modified != null)
                info.add (new Pair<string, string>(_("Modified") + (": "), file.formated_modified));
            var time_last_access = file.get_formated_time (FileAttribute.TIME_ACCESS);
            if (time_last_access != null)
                info.add (new Pair<string, string>(_("Last Access") + (": "), time_last_access));
            /* print deletion date if trashed file */
            //TODO format trash deletion date string
            if (file.is_trashed ()) {
                var deletion_date = file.info.get_attribute_as_string ("trash::deletion-date");
                if (deletion_date != null)
                    info.add (new Pair<string, string>(_("Deleted") + (": "), deletion_date));
            }
        }
        ftype = get_common_ftype ();
        if (ftype != null) {
            info.add (new Pair<string, string>(_("MimeType") + (": "), ftype));
        } else {
            /* show list of mimetypes only if we got a default application in common */
            if (view.get_default_app () != null && !goffile.is_directory) {
                string str = null;
                foreach (var mime in mimes) {
                    (str == null) ? str = mime : str = string.join (", ", str, mime);
                }
                info.add (new Pair<string, string>(_("MimeTypes") + (": "), str));
            }
        }

        /* get image size in pixels */
        var mime = file.icon.to_string ();
        if ("image" in mime) {
            var path = file.location.get_path ();

            try {
                Gdk.Pixbuf pixbuf = new Gdk.Pixbuf.from_file (path);
                var width = pixbuf.get_width ().to_string ();
                var height = pixbuf.get_height ().to_string ();
                info.add (new Pair<string, string> (_("Size") + (": "), width +" × " + height + " px"));
            } catch (Error e) {
                stdout.printf ("Error: %s\n", e.message);
            }
        }

        if (got_common_location ())
            info.add (new Pair<string, string>(_("Location") + (": "), "<a href=\"" + Markup.escape_text (file.directory.get_uri ()) + "\">"
                                                            + Markup.escape_text (file.directory.get_parse_name ()) + "</a>"));
        if (count == 1 && file.info.get_is_symlink ())
            info.add (new Pair<string, string>(_("Target") + (": "), file.info.get_symlink_target()));

        /* print orig location of trashed files */
        if (file.is_trashed () && file.info.get_attribute_byte_string (FileAttribute.TRASH_ORIG_PATH) != null) {
            var trash_orig_loc = get_common_trash_orig ();
            if (trash_orig_loc != null)
                info.add (new Pair<string, string>(_("Origin Location") + (": "), "<a href=\"" + get_parent_loc (file.info.get_attribute_byte_string (FileAttribute.TRASH_ORIG_PATH)).get_uri () + "\">" + trash_orig_loc + "</a>"));
        }
    }

    private void construct_info_panel (Gtk.Box box, Gee.LinkedList<Pair<string, string>> item_info) {
        var information = new Gtk.Grid();
        information.row_spacing = 3;

        var label = new Gtk.Label ("");
        label.use_markup = true;
        label.set_markup ("<b>" + _("Info:") + "\t\t\t</b>"); //FIXME: find a better solution for this
        information.attach (label, 0, 0, 1, 1);

        int n = 1;

        foreach (var pair in item_info) {
            var value_label = new Granite.Widgets.WrapLabel (pair.value);
            var key_label = create_label_key (pair.key);
            key_label.margin_left = 20;
            value_label.set_selectable (true);
            value_label.set_size_request (150, -1);
            value_label.set_hexpand (true);
            value_label.set_use_markup (true);

            information.attach (key_label, 0, n, 1, 1);
            information.attach_next_to (value_label, key_label, Gtk.PositionType.RIGHT, 3, 1);
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
                            AppsColumn.LABEL, _("Other application..."));
            store_apps.prepend (out iter);
            store_apps.set (iter,
                            AppsColumn.APP_INFO, default_app,
                            AppsColumn.LABEL, default_app.get_name (),
                            AppsColumn.ICON, ensure_icon (default_app));

            var combo = new Gtk.ComboBox.with_model ((Gtk.TreeModel) store_apps);
            var renderer = new Gtk.CellRendererText ();
            var pix_renderer = new Gtk.CellRendererPixbuf ();
            combo.pack_start (pix_renderer, false);
            combo.pack_start (renderer, true);

            combo.add_attribute (renderer, "text", AppsColumn.LABEL);
            combo.add_attribute (pix_renderer, "gicon", AppsColumn.ICON);

            combo.set_active (0);
            combo.set_valign (Gtk.Align.CENTER);

            var hcombo = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            hcombo.pack_start (combo, false, false, 0);

            combo.changed.connect (combo_open_with_changed);

            var key_label = create_label_key (_("Open with:"), Gtk.Align.CENTER);

            information.attach (key_label, 0, n, 1, 1);
            information.attach (hcombo, 1, n, 1, 1);
        }

        /* Device Usage */
        if (should_show_device_usage ()) {
            try {
                var info = goffile.get_target_location ().query_filesystem_info ("filesystem::*");
                if (info.has_attribute (FileAttribute.FILESYSTEM_SIZE) &&
                    info.has_attribute (FileAttribute.FILESYSTEM_FREE)) {
                    uint64 fs_capacity = info.get_attribute_uint64 (FileAttribute.FILESYSTEM_SIZE);
                    uint64 fs_free = info.get_attribute_uint64 (FileAttribute.FILESYSTEM_FREE);

                    n++;

                    debug ("%d", n);
                    label = new Gtk.Label ("");
                    label.use_markup = true;
                    label.set_markup ("<b>" + _("Usage:") + "\t\t\t</b>"); //FIXME: find a better solution for this
                    information.attach (label, 0, n, 1, 1);

                    n++;

                    var key_label = create_label_key (_("Device usage:"), Gtk.Align.CENTER);
                    information.attach (key_label, 0, n, 1, 1);
                    debug ("%d", n);
                    var progressbar = new Gtk.ProgressBar ();
                    double used =  1.0 - (double) fs_free / (double) fs_capacity;
                    progressbar.set_fraction (used);
                    progressbar.set_show_text (true);
                    progressbar.set_text (_("%s free of %s (%d%% used)").printf (format_size ((int64) fs_free), format_size ((int64) fs_capacity), (int) (used * 100)));
                    information.attach_next_to (progressbar, key_label, Gtk.PositionType.RIGHT, 3, 1);
                }
            } catch (Error e) {
                warning ("error: %s", e.message);
            }
        }

        box.pack_start (information);
    }

    private bool should_show_device_usage () {
        if (files_contain_a_directory)
            return true;
        if (count == 1) {
            if (goffile.can_unmount ())
                return true;
            var rootfs_loc = File.new_for_uri ("file:///");
            if (goffile.get_target_location ().equal (rootfs_loc))
                return true;
        }

        return false;
    }

    private float get_alignment_float_from_align (Gtk.Align align) {
        switch (align) {
        case Gtk.Align.START:
            return 0.0f;
        case Gtk.Align.END:
            return 1.0f;
        case Gtk.Align.CENTER:
            return 0.5f;
        default:
            return 0.0f;
        }
    }

    private Gtk.Widget create_label_key (string str, Gtk.Align valign = Gtk.Align.START) {
        Gtk.Label key_label = new Gtk.Label (str);
        key_label.set_sensitive (false);
        /*key_label.set_halign (Align.END);
        key_label.set_valign (valign);*/
        //key_label.set_hexpand (true);
        key_label.margin_right = 5;
        var yalign = get_alignment_float_from_align (valign);

        var align = new Gtk.Alignment (1.0f, yalign, 0, 0);
        align.add (key_label);
        sg.add_widget (align);

        return align;
    }

    private void toggle_button_add_label (Gtk.ToggleButton btn, string str) {
        var l_read = new Gtk.Label ("<span size='small'>"+ str + "</span>");
        l_read.set_use_markup (true);
        btn.add (l_read);
    }

    private enum PermissionType {
        USER,
        GROUP,
        OTHER
    }

    private enum PermissionValue {
        READ = (1<<0),
        WRITE = (1<<1),
        EXE = (1<<2)
    }

    private Posix.mode_t[,] vfs_perms = {
        { Posix.S_IRUSR, Posix.S_IWUSR, Posix.S_IXUSR },
        { Posix.S_IRGRP, Posix.S_IWGRP, Posix.S_IXGRP },
        { Posix.S_IROTH, Posix.S_IWOTH, Posix.S_IXOTH }
    };

    private Gtk.Grid perm_grid;
    private int owner_perm_code = 0;
    private int group_perm_code = 0;
    private int everyone_perm_code = 0;

    private void update_perm_codes (PermissionType pt, int val, int mult) {
        switch (pt) {
        case PermissionType.USER:
            owner_perm_code += mult*val;
            break;
        case PermissionType.GROUP:
            group_perm_code += mult*val;
            break;
        case PermissionType.OTHER:
            everyone_perm_code += mult*val;
            break;
        }
    }

    private void action_toggled_read (Gtk.ToggleButton btn) {
        unowned PermissionType pt = btn.get_data ("permissiontype");
        int mult = 1;

        reset_and_cancel_perm_timeout ();
        if (!btn.get_active ())
            mult = -1;
        update_perm_codes (pt, 4, mult);
        if (perm_code_should_update)
            perm_code.set_text ("%d%d%d".printf (owner_perm_code, group_perm_code, everyone_perm_code));
    }

    private void action_toggled_write (Gtk.ToggleButton btn) {
        unowned PermissionType pt = btn.get_data ("permissiontype");
        int mult = 1;

        reset_and_cancel_perm_timeout ();
        if (!btn.get_active ())
            mult = -1;
        update_perm_codes (pt, 2, mult);
        if (perm_code_should_update)
            perm_code.set_text ("%d%d%d".printf(owner_perm_code, group_perm_code, everyone_perm_code));
    }

    private void action_toggled_execute (Gtk.ToggleButton btn) {
        unowned PermissionType pt = btn.get_data ("permissiontype");
        int mult = 1;

        reset_and_cancel_perm_timeout ();
        if (!btn.get_active ())
            mult = -1;
        update_perm_codes (pt, 1, mult);
        if (perm_code_should_update)
            perm_code.set_text ("%d%d%d".printf(owner_perm_code, group_perm_code, everyone_perm_code));
    }

    private Gtk.Box create_perm_choice (PermissionType pt) {
        Gtk.Box hbox;

        hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        hbox.homogeneous = true;
        var btn_read = new Gtk.ToggleButton ();
        toggle_button_add_label (btn_read, _("Read"));
        //btn_read.set_relief (Gtk.ReliefStyle.NONE);
        btn_read.set_data ("permissiontype", pt);
        btn_read.toggled.connect (action_toggled_read);
        var btn_write = new Gtk.ToggleButton ();
        toggle_button_add_label (btn_write, _("Write"));
        //btn_write.set_relief (Gtk.ReliefStyle.NONE);
        btn_write.set_data ("permissiontype", pt);
        btn_write.toggled.connect (action_toggled_write);
        var btn_exe = new Gtk.ToggleButton ();
        toggle_button_add_label (btn_exe, _("Execute"));
        //btn_exe.set_relief (Gtk.ReliefStyle.NONE);
        btn_exe.set_data ("permissiontype", pt);
        btn_exe.toggled.connect (action_toggled_execute);
        hbox.pack_start (btn_read);
        hbox.pack_start (btn_write);
        hbox.pack_start (btn_exe);

        return hbox;
    }

    private uint32 get_perm_from_chmod_unit (uint32 vfs_perm, int nb,
                                             int chmod, PermissionType pt) {
        //message ("chmod code %d %d", chmod, nb);
        if (nb > 7 || nb < 0)
            critical ("erroned chmod code %d %d", chmod, nb);

        int[] chmod_types = { 4, 2, 1};

        int i = 0;
        for (; i<3; i++) {
            int div = nb / chmod_types[i];
            int modulo = nb % chmod_types[i];
            if (div >= 1)
                vfs_perm |= vfs_perms[pt,i];
            nb = modulo;
            //message ("div %d modulo %d", div, modulo);
        }

        return vfs_perm;
    }

    private uint32 chmod_to_vfs (int chmod) {
        uint32 vfs_perm = 0;

        /* user */
        vfs_perm = get_perm_from_chmod_unit (vfs_perm, (int) chmod / 100,
                                             chmod, PermissionType.USER);
        /* group */
        vfs_perm = get_perm_from_chmod_unit (vfs_perm, (int) (chmod / 10) % 10,
                                             chmod, PermissionType.GROUP);
        /* other */
        vfs_perm = get_perm_from_chmod_unit (vfs_perm, (int) chmod % 10,
                                             chmod, PermissionType.OTHER);

        return vfs_perm;
    }

    private void update_permission_type_buttons (Gtk.Box hbox, uint32 permissions, PermissionType pt) {
        int i=0;
        foreach (var widget in hbox.get_children ()) {
            Gtk.ToggleButton btn = (Gtk.ToggleButton) widget;
            ((permissions & vfs_perms[pt, i]) != 0) ? btn.active = true : btn.active = false;
            i++;
        }
    }

    private void update_perm_grid_toggle_states (uint32 permissions) {
        Gtk.Box hbox;

        /* update USR row */
        hbox = (Gtk.Box) perm_grid.get_child_at (1,3);
        update_permission_type_buttons (hbox, permissions, PermissionType.USER);

        /* update GRP row */
        hbox = (Gtk.Box) perm_grid.get_child_at (1,4);
        update_permission_type_buttons (hbox, permissions, PermissionType.GROUP);

        /* update OTHER row */
        hbox = (Gtk.Box) perm_grid.get_child_at (1,5);
        update_permission_type_buttons (hbox, permissions, PermissionType.OTHER);
    }

    private bool is_chmod_code (string str) {
        try {
            var regex = new Regex ("^[0-7]{3}$");
            if (regex.match (str))
                return true;
        } catch (RegexError e) {
            assert_not_reached ();
        }

        return false;
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

    private async void file_set_attributes (GOF.File file, string attr,
                                            uint32 val, Cancellable? _cancellable = null) {
        FileInfo info = new FileInfo ();

        //TODO use marlin jobs
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
        if (is_chmod_code (str)) {
            reset_and_cancel_perm_timeout ();
            timeout_perm = Timeout.add (60, () => {
                //message ("changed %s", str);
                uint32 perm = chmod_to_vfs (int.parse (str));
                perm_code_should_update = false;
                update_perm_grid_toggle_states (perm);
                perm_code_should_update = true;
                int n = 0;
                foreach (GOF.File gof in files) {
                    if (gof.can_set_permissions() && gof.permissions != perm) {
                        gof.permissions = perm;
                        /* update permission label once */
                        if (n<1)
                            l_perm.set_text (goffile.get_permissions_as_string ());
                        /* real update permissions */
                        file_set_attributes.begin (gof, FileAttribute.UNIX_MODE, perm, cancellable);
                        n++;
                    } else {
                        //TODO add a list of permissions set errors in the property dialog.
                        warning ("can't change permission on %s", gof.uri);
                    }
                }
                timeout_perm = 0;

                return false;
            });
        }
    }

    private void combo_owner_changed (Gtk.ComboBox combo) {
        Gtk.TreeIter iter;
        string user;
        int uid;

        if (!combo.get_active_iter(out iter))
            return;

        store_users.get (iter, 0, out user);
        //message ("combo_user changed: %s", user);

        if (!goffile.can_set_owner ()) {
            critical ("error can't set user");
            return;
        }

        if (!Eel.get_user_id_from_user_name (user, out uid)
            && !Eel.get_id_from_digit_string (user, out uid)) {
            critical ("user doesn t exit");
        }

        if (uid == goffile.uid)
            return;

        foreach (GOF.File gof in files)
            file_set_attributes.begin (gof, FileAttribute.UNIX_UID, uid);
    }

    private void combo_group_changed (Gtk.ComboBox combo) {
        Gtk.TreeIter iter;
        string group;
        int gid;

        if (!combo.get_active_iter(out iter))
            return;

        store_groups.get (iter, 0, out group);
        //message ("combo_group changed: %s", group);

        if (!goffile.can_set_group ()) {
            critical ("error can't set group");
            //TODO
            //_("Not allowed to set group"));
            return;
        }

        /* match gid from name */
        if (!Eel.get_group_id_from_group_name (group, out gid)
            && !Eel.get_id_from_digit_string (group, out gid)) {
            critical ("group doesn t exit");
            //TODO
            //_("Specified group '%s' doesn't exist"), group);
            return;
        }

        if (gid == goffile.gid)
            return;

        foreach (GOF.File gof in files)
            file_set_attributes.begin (gof, FileAttribute.UNIX_GID, gid);
    }

    private void construct_perm_panel (Gtk.Box box) {
        perm_grid = new Gtk.Grid();

        Gtk.Widget key_label;
        Gtk.Widget value_label;
        Gtk.Box value_hlabel;

        key_label = create_label_key(_("Owner") + ": ", Gtk.Align.CENTER);
        perm_grid.attach (key_label, 0, 1, 1, 1);
        value_label = create_owner_choice ();
        perm_grid.attach (value_label, 1, 1, 1, 1);

        key_label = create_label_key(_("Group") + ": ", Gtk.Align.CENTER);
        perm_grid.attach (key_label, 0, 2, 1, 1);
        value_label = create_group_choice ();
        perm_grid.attach (value_label, 1, 2, 1, 1);

        /* make a separator with margins */
        key_label.margin_bottom = 7;
        value_label.margin_bottom = 7;
        key_label = create_label_key (_("Owner") + ": ", Gtk.Align.CENTER);
        value_hlabel = create_perm_choice (PermissionType.USER);
        perm_grid.attach (key_label, 0, 3, 1, 1);
        perm_grid.attach (value_hlabel, 1, 3, 1, 1);
        key_label = create_label_key (_("Group") + ": ", Gtk.Align.CENTER);
        value_hlabel = create_perm_choice (PermissionType.GROUP);
        perm_grid.attach (key_label, 0, 4, 1, 1);
        perm_grid.attach (value_hlabel, 1, 4, 1, 1);
        key_label = create_label_key (_("Everyone") + ": ", Gtk.Align.CENTER);
        value_hlabel = create_perm_choice (PermissionType.OTHER);
        perm_grid.attach (key_label, 0, 5, 1, 1);
        perm_grid.attach (value_hlabel, 1, 5, 1, 1);

        perm_code = new Granite.Widgets.XsEntry ();
        //var perm_code = new Label("705");
        //perm_code.margin_right = 2;
        perm_code.set_text ("000");
        perm_code.set_max_length (3);
        //perm_code.set_has_frame (false);
        perm_code.set_size_request (35, -1);

        var perm_code_hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
        //var l_perm = new Label("-rwxr-xr-x");
        l_perm = new Gtk.Label (goffile.get_permissions_as_string ());
        perm_code_hbox.pack_start (l_perm, true, true, 0);
        perm_code_hbox.pack_start (perm_code, false, false, 0);

        perm_grid.attach (perm_code_hbox, 1, 6, 1, 1);

        box.pack_start (perm_grid);

        /*uint32 perm = chmod_to_vfs (702);
        update_perm_grid_toggle_states (perm);*/
        update_perm_grid_toggle_states (goffile.permissions);

        perm_code.changed.connect (entry_changed);

        /*int nbb;

        nbb = 702;
        goffile.permissions = chmod_to_vfs(nbb);
        message ("test chmod %d %s", nbb, goffile.get_permissions_as_string());
        nbb = 343;
        goffile.permissions = chmod_to_vfs(nbb);
        message ("test chmod %d %s", nbb, goffile.get_permissions_as_string());
        nbb = 206;
        goffile.permissions = chmod_to_vfs(nbb);
        message ("test chmod %d %s", nbb, goffile.get_permissions_as_string());
        nbb = 216;
        goffile.permissions = chmod_to_vfs(nbb);
        message ("test chmod %d %s", nbb, goffile.get_permissions_as_string());*/
    }

    private bool selection_can_set_owner () {
        foreach (GOF.File gof in files)
            if (!gof.can_set_owner ())
                return false;

        return true;
    }

    private string? get_common_owner () {
        int uid = -1;
        if (files == null)
            return null;

        foreach (GOF.File gof in files){
            if (uid == -1 && gof != null) {
                uid = gof.uid;
                continue;
            }
            if (uid != gof.uid)
                return null;
        }

        return goffile.info.get_attribute_string (FileAttribute.OWNER_USER);
    }

    private bool selection_can_set_group () {
        foreach (GOF.File gof in files)
            if (!gof.can_set_group ())
                return false;

        return true;
    }

    private string? get_common_group () {
        int gid = -1;
        if (files == null)
            return null;

        foreach (GOF.File gof in files) {
            if (gid == -1 && gof != null) {
                gid = gof.gid;
                continue;
            }
            if (gid != gof.gid)
                return null;
        }

        return goffile.info.get_attribute_string (FileAttribute.OWNER_GROUP);
    }

    private Gtk.Widget create_owner_choice () {
        Gtk.Widget choice;
        choice = null;

        //if (goffile.can_set_owner()) {
        if (selection_can_set_owner ()) {
            GLib.List<string> users;
            Gtk.TreeIter iter;

            store_users = new Gtk.ListStore (1, typeof (string));
            users = Eel.get_user_names();
            int owner_index = -1;
            int i = 0;
            foreach (var user in users) {
                if (user == goffile.owner) {
                    owner_index = i;
                }
                store_users.append(out iter);
                store_users.set(iter, 0, user);
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
            //renderer.attributes = EelPango.attr_list_small();
            if (owner_index == -1)
                combo.set_active (0);
            else
                combo.set_active (owner_index);

            combo.changed.connect (combo_owner_changed);

            choice = (Gtk.Widget) combo;
        } else {
            //choice = (Gtk.Widget) new Gtk.Label (goffile.info.get_attribute_string(FileAttribute.OWNER_USER));
            string? common_owner = get_common_owner ();
            if (common_owner == null)
                common_owner = "--";
            choice = (Gtk.Widget) new Gtk.Label (common_owner);
            //choice.margin_left = 6;
            choice.set_halign (Gtk.Align.START);
        }

        choice.set_valign (Gtk.Align.CENTER);

        return choice;
    }

    private Gtk.Widget create_group_choice () {
        Gtk.Widget choice;

        //if (goffile.can_set_group()) {
        if (selection_can_set_group ()) {
            GLib.List<string> groups;
            Gtk.TreeIter iter;

            store_groups = new Gtk.ListStore (1, typeof (string));
            groups = goffile.get_settable_group_names ();
            int group_index = -1;
            int i = 0;
            foreach (var group in groups) {
                if (group == goffile.owner) {
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
            //renderer.attributes = EelPango.attr_list_small();
            if (group_index == -1)
                combo.set_active (0);
            else
                combo.set_active (group_index);

            combo.changed.connect (combo_group_changed);

            choice = (Gtk.Widget) combo;
        } else {
            //choice = (Gtk.Widget) new Gtk.Label (goffile.info.get_attribute_string(FileAttribute.OWNER_GROUP));
            string? common_group = get_common_group ();
            if (common_group == null)
                common_group = "--";
            choice = (Gtk.Widget) new Gtk.Label (common_group);
            choice.set_halign (Gtk.Align.START);
        }

        choice.set_valign (Gtk.Align.CENTER);

        return choice;
    }

    private void construct_preview_panel (Gtk.Box box, Gdk.Pixbuf? small_preview) {
        evbox = new Granite.Widgets.ImgEventBox (Gtk.Orientation.HORIZONTAL);
        if (small_preview != null)
            evbox.set_from_pixbuf (small_preview);
        box.pack_start (evbox, false, true, 0);

        goffile.icon_changed.connect (() => {
            var large_preview_path = goffile.get_preview_path ();
            if (large_preview_path != null)
                try {
                    var large_preview = new Gdk.Pixbuf.from_file (large_preview_path);
                    evbox.set_from_pixbuf (large_preview);
                } catch (Error e) {
                    warning (e.message);
                }
        });
    }

    private enum AppsColumn {
        APP_INFO,
        LABEL,
        ICON
    }

    private Icon ensure_icon (AppInfo app) {
        Icon icon = app.get_icon ();
        if (icon == null)
            icon = new ThemedIcon ("application-x-executable");

        return icon;
    }

    private void combo_open_with_changed (Gtk.ComboBox combo) {
        Gtk.TreeIter iter;
        string app_label;
        AppInfo? app;

        if (!combo.get_active_iter (out iter))
            return;

        store_apps.get (iter,
                        AppsColumn.LABEL, out app_label,
                        AppsColumn.APP_INFO, out app);
        //message ("combo_open_with changed: %s %s", app_label, app.get_name ());
        if (app == null) {
            var app_chooser_dlg = new Gtk.AppChooserDialog (this, 0, goffile.location);
            string str = null;
            foreach (var mime in mimes) {
                (str == null) ? str = mime : str = string.join (", ", str, mime);
            }
            app_chooser_dlg.set_heading (_("Select an application to open " + str));
            app_chooser_dlg.show_all ();

            int res = app_chooser_dlg.run ();
            if (res == Gtk.ResponseType.OK) {
                var app_chosen = app_chooser_dlg.get_app_info ();
                store_apps.prepend (out iter);
                store_apps.set (iter,
                                AppsColumn.APP_INFO, app_chosen,
                                AppsColumn.LABEL, app_chosen.get_name (),
                                AppsColumn.ICON, ensure_icon (app_chosen));
                combo.set_active (0);
            }
            app_chooser_dlg.destroy ();
        } else {
            try {
                foreach (var mime in mimes)
                    app.set_as_default_for_type (mime);
                view.notify_selection_changed ();
            } catch (Error e) {
                critical ("Couldn't set as default: %s", e.message);
            }
        }
    }
}