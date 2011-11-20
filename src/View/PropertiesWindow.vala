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

using Gtk;
using Posix;
using GLib;
using Varka.Widgets;

public class Marlin.View.PropertiesWindow : Gtk.Dialog
{
    private Gee.LinkedList<Pair<string, string>> info;
    private ImgEventBox evbox;
    private XsEntry perm_code;
    private bool perm_code_should_update = true;
    private Gtk.Label l_perm;
    private Gtk.ListStore store_users;
    private Gtk.ListStore store_groups;
    private uint count;
    private unowned GLib.List<GOF.File> files;
    private GOF.File goffile;

    private Varka.Widgets.WrapLabel header_title;
    private Gtk.Label header_desc;
    private string ftype; /* common type */

    private uint timeout_perm = 0;
    private GLib.Cancellable? cancellable;

    public PropertiesWindow (GLib.List<GOF.File> _files, Gtk.Window parent)
    {
        title = _("Properties");
        resizable = false;
        set_default_response(ResponseType.CANCEL);
        set_default_size (220, -1);

        // Set the default containers
        Box content_area = (Box)get_content_area();
        Box action_area = (Box)get_action_area();
        action_area.set_border_width (5);
        border_width = 5;

        VBox content_vbox = new VBox(false, 0);
        //var content_vbox = new VBox(false, 12);
        content_area.pack_start(content_vbox);

        // Adjust sizes
        //content_vbox.margin = 12;
        /*content_vbox.margin_right = 12;
          content_vbox.margin_left = 12;
          content_vbox.margin_bottom = 12;*/
        //content_vbox.height_request = 160;
        content_vbox.width_request = 288;

        files = _files;
        count = files.length();
        goffile = (GOF.File) files.data;
        get_info (goffile);
        cancellable = new GLib.Cancellable ();

        /* Header Box */
        var header_box = new HBox (false, 9);
        add_header_box (content_vbox, header_box);

        /* Separator */
        var sep = new Separator (Orientation.HORIZONTAL);
        sep.margin = 7;
        content_vbox.pack_start(sep, false, false, 0);

        /* Info */
        var info_vbox = new VBox(false, 0);
        construct_info_panel (info_vbox, info);
        add_section (content_vbox, _("Info"), info_vbox);

        /* Permissions */
        var perm_vbox = new VBox(false, 0);
        construct_perm_panel (perm_vbox);
        add_section (content_vbox, _("Permissions"), perm_vbox);
        if (!goffile.can_set_permissions()) {
            foreach (var widget in perm_vbox.get_children())
                widget.set_sensitive (false);
        }

        /* Preview */
        //message ("flag %d", (int) goffile.flags);
        if (count == 1 && goffile.flags != 0) {
            var preview_box = new VBox(false, 0);
            construct_preview_panel (preview_box);
            add_section (content_vbox, _("Preview"), preview_box);
        }

        /* Open With */
        /*var openw_box = new VBox (false, 0);
        construct_open_with_panel (openw_box, gof);
        add_section (content_vbox, _("Open With"), openw_box);*/

        var close_button = new Button.from_stock(Stock.CLOSE);
        close_button.clicked.connect(() => { response(ResponseType.CLOSE); });
        action_area.pack_end (close_button, false, false, 0);
        //add_button (Stock.CLOSE, ResponseType.CLOSE);

        content_vbox.show();

        content_area.show_all();
        action_area.show_all();
        close_button.grab_focus();

        response.connect (on_response);

        Preferences.settings.bind ("dialog-property-modal", this, "modal", 0);
        set_transient_for (parent);
        set_destroy_with_parent (true);
        present ();

    }

    private void on_response (Dialog source, int response_id) {
        switch (response_id) {
        case ResponseType.HELP:
            // show_help ();
            break;
        case ResponseType.CLOSE:
            destroy ();
            break;
        }
    }

    private string span_weight_light (string str) {
        return "<span weight='light'>" + str + "</span>";
    }

    private uint64 total_size = 0;

    private void update_header_desc () {
        string header_desc_str;

        //header_desc_str = Eel.format_size (total_size);
        header_desc_str = format_size_for_display ((int64) total_size);
        if (ftype != null) {
            header_desc_str += ", " + goffile.formated_type;
        } 
        header_desc.set_markup (span_weight_light(header_desc_str));
    }

    private Mutex mutex = new Mutex ();
    private GLib.List<Marlin.DeepCount>? deep_count_directories = null;

    private void selection_size_update () {
        total_size = 0;
        deep_count_directories = null;

        foreach (GOF.File gof in files)
        {
            if (gof.is_directory) {
                var d = new Marlin.DeepCount (gof.location);
                deep_count_directories.prepend (d);
                d.finished.connect (() => { 
                                    mutex.lock ();
                                    deep_count_directories.remove (d);
                                    total_size += d.total_size;
                                    update_header_desc ();
                                    mutex.unlock ();
                                    });
            } 
            mutex.lock ();
            total_size += gof.size;
            mutex.unlock ();
        }
        update_header_desc ();
    }

    private void add_header_box (VBox vbox, Box content) {
        var file_pix = goffile.get_icon_pixbuf (32, false, GOF.FileIconFlags.NONE);
        var file_img = new Image.from_pixbuf (file_pix);
        file_img.set_valign (Align.START);
        content.pack_start(file_img, false, false);

        var vvbox = new VBox (false, 0);
        content.pack_start(vvbox);
       
        header_title = new Varka.Widgets.WrapLabel ();
        if (count > 1)
            header_title.set_markup ("<span weight='semibold' size='large'>" + "%u selected items".printf(count) + "</span>");
        else
            header_title.set_markup ("<span weight='semibold' size='large'>" + goffile.name + "</span>");
        
        header_desc = new Label (null);
        header_desc.set_halign(Align.START);
        header_desc.set_use_markup(true);

        if (ftype != null) {
            header_desc.set_markup(span_weight_light(goffile.formated_type));
        }
        selection_size_update();

        /*var font_style = new Pango.FontDescription();
          font_style.set_size(12 * 1000);
          header_title.modify_font(font_style);*/

        vvbox.pack_start(header_title);
        vvbox.pack_start(header_desc);

        vbox.pack_start(content, false, false, 0);
    }

    private void add_section (VBox vbox, string title, Box content) {
        //var exp = new Expander("<span weight='semibold' size='large'>" + title + "</span>");
        var exp = new Expander("<span weight='semibold'>" + title + "</span>");
        exp.set_use_markup(true);
        exp.expanded = true;
        exp.margin_bottom = 5;
        vbox.pack_start(exp, false, false, 0);
        if (content != null)
            exp.add (content);
    }

    private string? get_common_ftype () {
        string? ftype = null;
        if (files == null)
            return null;

        foreach (GOF.File gof in files)
        {
            if (ftype == null && gof != null) {
                ftype = gof.ftype;
                continue;
            }
            if (ftype != gof.ftype)
                return null;
        }

        return ftype;
    }

    private bool got_common_location () {
        File? loc = null;
        foreach (GOF.File gof in files)
        {
            if (loc == null && gof != null) {
                loc = gof.directory;
                continue;
            }
            if (!loc.equal (gof.directory))
                return false;            
        }

        return true;
    }
    
    private GLib.File? get_parent_loc (string path) {
        var loc = File.new_for_path(path);
        return loc.get_parent();    
    }

    private string? get_common_trash_orig() {
        File loc = null;
        string path = null;

        foreach (GOF.File gof in files)
        {
            if (loc == null && gof != null) {
                loc = get_parent_loc(gof.trash_orig_path);
                continue;
            }
            if (!loc.equal (get_parent_loc (gof.trash_orig_path)))
                return null;
        }

        if (loc == null)
            path = "/";
        else
            path = loc.get_parse_name();

        return path;
    }

    private void get_info (GOF.File file) {
        var file_info = file.info;
        info = new Gee.LinkedList<Pair<string, string>>();

        /* localized time depending on MARLIN_PREFERENCES_DATE_FORMAT locale, iso .. */
        if (count == 1) {
            info.add(new Pair<string, string>(_("Created") + (": "), file.get_formated_time (FILE_ATTRIBUTE_TIME_CREATED)));
            info.add(new Pair<string, string>(_("Modified") + (": "), file.formated_modified));
            info.add(new Pair<string, string>(_("Last Access") + (": "), file.get_formated_time (FILE_ATTRIBUTE_TIME_ACCESS)));
            /* print deletion date if trashed file */
            //TODO format trash deletion date string
            if (file.is_trashed())
                info.add(new Pair<string, string>(_("Deleted") + (": "), file_info.get_attribute_as_string("trash::deletion-date")));
        }
        ftype = get_common_ftype();
        if (ftype != null)
            info.add(new Pair<string, string>(_("MimeType") + (": "), ftype));
        if (got_common_location())
            info.add(new Pair<string, string>(_("Location") + (": "), file.directory.get_parse_name()));
        if (count == 1 && file_info.get_is_symlink())
            info.add(new Pair<string, string>(_("Target") + (": "), file_info.get_symlink_target()));

        /* print orig location of trashed files */
        if (file.is_trashed() && file.trash_orig_path != null) {
            var trash_orig_loc = get_common_trash_orig();
            if (trash_orig_loc != null)
                info.add(new Pair<string, string>(_("Origin Location") + (": "), trash_orig_loc));
        }
    }

    private void construct_info_panel (Box box, Gee.LinkedList<Pair<string, string>> item_info) {
        var information = new Grid();
        information.row_spacing = 3;

        int n = 0;
        foreach(var pair in item_info){
            var value_label = new Varka.Widgets.WrapLabel(pair.value);
            var key_label = create_label_key(pair.key);
            value_label.set_selectable(true);
            value_label.set_size_request(200, -1);

            information.attach(key_label, 0, n, 1, 1);
            information.attach(value_label, 1, n, 1, 1);
            n++;
        }
        box.pack_start(information);
    }

    private Gtk.Label create_label_key (string str, Gtk.Align valign = Align.START) {
        Gtk.Label key_label = new Gtk.Label(str);
        key_label.set_sensitive(false);
        key_label.set_halign(Align.END);
        key_label.set_valign(valign);
        key_label.margin_right = 5;

        return key_label;
    }

    private void toggle_button_add_label (Gtk.ToggleButton btn, string str) {
        var l_read = new Gtk.Label("<span size='small'>"+ str + "</span>");
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

    private mode_t[,] vfs_perms = {
        { S_IRUSR, S_IWUSR, S_IXUSR },
        { S_IRGRP, S_IWGRP, S_IXGRP },
        { S_IROTH, S_IWOTH, S_IXOTH }
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
        
        reset_and_cancel_perm_timeout();
        if (!btn.get_active())
            mult = -1;
        update_perm_codes (pt, 4, mult);
        if (perm_code_should_update)
            perm_code.set_text("%d%d%d".printf(owner_perm_code, group_perm_code, everyone_perm_code));
    }

    private void action_toggled_write (Gtk.ToggleButton btn) {
        unowned PermissionType pt = btn.get_data ("permissiontype");
        int mult = 1;
        
        reset_and_cancel_perm_timeout();
        if (!btn.get_active())
            mult = -1;
        update_perm_codes (pt, 2, mult);
        if (perm_code_should_update)
            perm_code.set_text("%d%d%d".printf(owner_perm_code, group_perm_code, everyone_perm_code));
    }
    
    private void action_toggled_execute (Gtk.ToggleButton btn) {
        unowned PermissionType pt = btn.get_data ("permissiontype");
        int mult = 1;
        
        reset_and_cancel_perm_timeout();
        if (!btn.get_active())
            mult = -1;
        update_perm_codes (pt, 1, mult);
        if (perm_code_should_update)
            perm_code.set_text("%d%d%d".printf(owner_perm_code, group_perm_code, everyone_perm_code));
    }
    
    private Gtk.HBox create_perm_choice (PermissionType pt) {
        Gtk.HBox hbox;

        hbox = new Gtk.HBox(true, 0);
        var btn_read = new Gtk.ToggleButton();
        toggle_button_add_label (btn_read, _("Read"));
        //btn_read.set_relief (Gtk.ReliefStyle.NONE);
        btn_read.set_data ("permissiontype", pt);
        btn_read.toggled.connect (action_toggled_read);
        var btn_write = new Gtk.ToggleButton();
        toggle_button_add_label (btn_write, _("Write"));
        //btn_write.set_relief (Gtk.ReliefStyle.NONE); 
        btn_write.set_data ("permissiontype", pt);
        btn_write.toggled.connect (action_toggled_write);
        var btn_exe = new Gtk.ToggleButton();
        toggle_button_add_label (btn_exe, _("Execute"));
        //btn_exe.set_relief (Gtk.ReliefStyle.NONE); 
        btn_exe.set_data ("permissiontype", pt);
        btn_exe.toggled.connect (action_toggled_execute);
        hbox.pack_start(btn_read);
        hbox.pack_start(btn_write);
        hbox.pack_start(btn_exe);

        return hbox;
    }

    private uint32 get_perm_from_chmod_unit (uint32 vfs_perm, int nb, 
                                             int chmod, PermissionType pt)
    {
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

    private uint32 chmod_to_vfs (int chmod)
    {
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

    private void update_permission_type_buttons (Gtk.HBox hbox, uint32 permissions, PermissionType pt) 
    {
        int i=0;
        foreach (var widget in hbox.get_children()) {
            Gtk.ToggleButton btn = (Gtk.ToggleButton) widget;
            ((permissions & vfs_perms[pt, i]) != 0) ? btn.active = true : btn.active = false;
            i++;
        }
    }

    private void update_perm_grid_toggle_states (uint32 permissions) {
        Gtk.HBox hbox;

        /* update USR row */
        hbox = (Gtk.HBox) perm_grid.get_child_at (1,3);
        update_permission_type_buttons (hbox, permissions, PermissionType.USER);
        
        /* update GRP row */
        hbox = (Gtk.HBox) perm_grid.get_child_at (1,4);
        update_permission_type_buttons (hbox, permissions, PermissionType.GROUP);
        
        /* update OTHER row */
        hbox = (Gtk.HBox) perm_grid.get_child_at (1,5);
        update_permission_type_buttons (hbox, permissions, PermissionType.OTHER);
    }

    private bool is_chmod_code (string str) {
        try {
            var regex = new GLib.Regex ("^[0-7]{3}$");
            if (regex.match (str))
                return true;
        } catch (GLib.RegexError e) {
			GLib.assert_not_reached ();
		}

        return false;
    }

    private void reset_and_cancel_perm_timeout () {
        if (cancellable != null) {
            cancellable.cancel();
            cancellable.reset();
        }
        if (timeout_perm != 0) {
            Source.remove(timeout_perm);
            timeout_perm = 0;
        }
    }

    private async void file_set_attributes (GOF.File file, string attr, 
                                            uint32 val, GLib.Cancellable? _cancellable = null) 
    {
        GLib.FileInfo info = new FileInfo ();

        //TODO use marlin jobs
        try {
            info.set_attribute_uint32(attr, val);
            yield file.location.set_attributes_async (info, 
                                                      GLib.FileQueryInfoFlags.NONE,
                                                      GLib.Priority.DEFAULT, 
                                                      _cancellable, null);
        } catch (GLib.Error e) {
            GLib.warning ("Could not set file attribute %s: %s", attr, e.message);
        }
    }

    private void entry_changed () {
        var str = perm_code.get_text();
        if (is_chmod_code(str)) {
            reset_and_cancel_perm_timeout();
            timeout_perm = Timeout.add(60, () => {
                //message ("changed %s", str);
                uint32 perm = chmod_to_vfs (int.parse (str));
                perm_code_should_update = false;
                update_perm_grid_toggle_states (perm);
                perm_code_should_update = true;
                int n = 0;
                foreach (GOF.File gof in files)
                {
                    if (gof.can_set_permissions() && gof.permissions != perm) {
                        gof.permissions = perm;
                        /* update permission label once */
                        if (n<1)
                            l_perm.set_text(goffile.get_permissions_as_string());
                        /* real update permissions */
                        file_set_attributes (gof, FILE_ATTRIBUTE_UNIX_MODE, perm, cancellable);
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

        if (!goffile.can_set_owner()) {
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
            file_set_attributes (gof, FILE_ATTRIBUTE_UNIX_UID, uid);
    }

    private void combo_group_changed (Gtk.ComboBox combo) {
        Gtk.TreeIter iter;
        string group;
        int gid;

        if (!combo.get_active_iter(out iter))
            return;
        
        store_groups.get (iter, 0, out group);
        //message ("combo_group changed: %s", group);

        if (!goffile.can_set_group()) {
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
            file_set_attributes (gof, FILE_ATTRIBUTE_UNIX_GID, gid);
    }
   
    private void construct_perm_panel (Box box) {
        perm_grid = new Grid();
                
        Gtk.Label key_label;
        Gtk.Widget value_label;
        Gtk.HBox value_hlabel;
        
        key_label = create_label_key(_("Owner") + ": ", Align.CENTER);
        perm_grid.attach(key_label, 0, 1, 1, 1);
        value_label = create_owner_choice();
        perm_grid.attach(value_label, 1, 1, 1, 1);
        
        key_label = create_label_key(_("Group") + ": ", Align.CENTER);
        perm_grid.attach(key_label, 0, 2, 1, 1);
        value_label = create_group_choice();
        perm_grid.attach(value_label, 1, 2, 1, 1);

        /* make a separator with margins */
        key_label.margin_bottom = 7;
        value_label.margin_bottom = 7;
        key_label = create_label_key(_("Owner") + ": ", Align.CENTER);
        value_hlabel = create_perm_choice(PermissionType.USER);
        perm_grid.attach(key_label, 0, 3, 1, 1);
        perm_grid.attach(value_hlabel, 1, 3, 1, 1);
        key_label = create_label_key(_("Group") + ": ", Align.CENTER);
        value_hlabel = create_perm_choice(PermissionType.GROUP);
        perm_grid.attach(key_label, 0, 4, 1, 1);
        perm_grid.attach(value_hlabel, 1, 4, 1, 1);
        key_label = create_label_key(_("Everyone") + ": ", Align.CENTER);
        value_hlabel = create_perm_choice(PermissionType.OTHER);
        perm_grid.attach(key_label, 0, 5, 1, 1);
        perm_grid.attach(value_hlabel, 1, 5, 1, 1);
        
        perm_code = new XsEntry();
        //var perm_code = new Label("705");
        //perm_code.margin_right = 2;
        perm_code.set_text("000");
        perm_code.set_max_length(3);
        //perm_code.set_has_frame (false);
        perm_code.set_size_request(35, -1);

        var perm_code_hbox = new HBox(false, 10);
        //var l_perm = new Label("-rwxr-xr-x");
        l_perm = new Label(goffile.get_permissions_as_string());
        perm_code_hbox.pack_start(l_perm, true, true, 0);
        perm_code_hbox.pack_start(perm_code, false, false, 0);

        perm_grid.attach(perm_code_hbox, 1, 6, 1, 1);
        
        box.pack_start(perm_grid);

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
            if (!gof.can_set_owner())
                return false;            

        return true;
    }
        
    private string? get_common_owner () {
        int uid = -1;
        if (files == null)
            return null;

        foreach (GOF.File gof in files)
        {
            if (uid == -1 && gof != null) {
                uid = gof.uid;
                continue;
            }
            if (uid != gof.uid)
                return null;
        }

        return goffile.info.get_attribute_string(FILE_ATTRIBUTE_OWNER_USER);
    }

    private bool selection_can_set_group () {
        foreach (GOF.File gof in files)
            if (!gof.can_set_group())
                return false;            

        return true;
    }
        
    private string? get_common_group () {
        int gid = -1;
        if (files == null)
            return null;

        foreach (GOF.File gof in files)
        {
            if (gid == -1 && gof != null) {
                gid = gof.gid;
                continue;
            }
            if (gid != gof.gid)
                return null;
        }

        return goffile.info.get_attribute_string(FILE_ATTRIBUTE_OWNER_GROUP);
    }

    private Gtk.Widget create_owner_choice() {
        Gtk.Widget choice;
        choice = null;

        //if (goffile.can_set_owner()) {
        if (selection_can_set_owner()) {
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
                store_users.prepend(out iter);
                store_users.set(iter, 0, goffile.owner);
            }
            
            var combo = new Gtk.ComboBox.with_model ((Gtk.TreeModel) store_users);
            var renderer = new Gtk.CellRendererText ();
            combo.pack_start(renderer, true);
            combo.add_attribute(renderer, "text", 0);
            //renderer.attributes = EelPango.attr_list_small();
            if (owner_index == -1)
                combo.set_active(0);
            else 
                combo.set_active(owner_index);

            combo.changed.connect (combo_owner_changed);

            choice = (Gtk.Widget) combo;
        } else {
            //choice = (Gtk.Widget) new Gtk.Label (goffile.info.get_attribute_string(FILE_ATTRIBUTE_OWNER_USER));
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
   
    private Gtk.Widget create_group_choice() {
        Gtk.Widget choice;

        //if (goffile.can_set_group()) {
        if (selection_can_set_group()) {
            GLib.List<string> groups;
            Gtk.TreeIter iter;

            store_groups = new Gtk.ListStore (1, typeof (string)); 
            groups = goffile.get_settable_group_names();
            int group_index = -1;
            int i = 0;
            foreach (var group in groups) {
                if (group == goffile.owner) {
                    group_index = i;
                }
                store_groups.append(out iter);
                store_groups.set(iter, 0, group);
                i++;
            }

            /* If ower is not known, we prepend it. 
             * It happens when the owner has no matching identifier in the password file.
             */
            if (group_index == -1) {
                store_groups.prepend(out iter);
                store_groups.set(iter, 0, goffile.owner);
            }
            
            var combo = new Gtk.ComboBox.with_model ((Gtk.TreeModel) store_groups);
            var renderer = new Gtk.CellRendererText ();
            combo.pack_start(renderer, true);
            combo.add_attribute(renderer, "text", 0);
            //renderer.attributes = EelPango.attr_list_small();
            if (group_index == -1)
                combo.set_active(0);
            else 
                combo.set_active(group_index);
            
            combo.changed.connect (combo_group_changed);

            choice = (Gtk.Widget) combo;
        } else {
            //choice = (Gtk.Widget) new Gtk.Label (goffile.info.get_attribute_string(FILE_ATTRIBUTE_OWNER_GROUP));
            string? common_group = get_common_group ();
            if (common_group == null)
                common_group = "--";
            choice = (Gtk.Widget) new Gtk.Label (common_group);
            choice.set_halign (Gtk.Align.START);
        }

        choice.set_valign (Gtk.Align.CENTER);

        return choice;
    }
    
    private void construct_preview_panel (Box box) {
        evbox = new ImgEventBox(Orientation.HORIZONTAL);
        goffile.update_icon (256);
        if (goffile.pix != null)
            evbox.set_from_pixbuf (goffile.pix);

        box.pack_start(evbox, false, true, 0);
    }
    
    /*private void construct_open_with_panel (Box box) {
        Widget app_chooser;

        app_chooser = new AppChooserWidget (goffile.ftype);
        //app_chooser.set_size_request (-1, 120);
        box.pack_start(app_chooser);

    }*/
}
