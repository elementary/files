/*  
 * Copyright (C) 2011 Elementary Developers
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

public class Marlin.View.PropertiesWindow : Gtk.Dialog
{
    private Gee.LinkedList<Pair<string, string>> info;
    private ImgEventBox evbox;
    private XsEntry perm_code;

    public PropertiesWindow (GLib.List<GOF.File> files, Gtk.Window parent)
    {
        title = _("Properties");
        //resizable = false;
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

        GOF.File? gof = (GOF.File) files.data;
        get_info (gof);

        /* Basic */
        var basic_box = new HBox (false, 9);
        //basic_vbox.set_size_request (0, 40); 

        var file_pix = gof.get_icon_pixbuf (32, false, GOF.FileIconFlags.NONE);
        var file_img = new Image.from_pixbuf (file_pix);
        file_img.set_valign (Align.START);
        basic_box.pack_start(file_img, false, false);

        var vvbox = new VBox (false, 0);
        basic_box.pack_start(vvbox);
        var hhbox1 = new HBox (false, 0);
        //var basic_filename = new Label ("<span weight='semibold' size='large'>" + gof.name + "</span>");
        var basic_filename = new Granite.Widgets.WrapLabel ("<span weight='semibold' size='large'>" + gof.name + "</span>");
        //var basic_filename = new Label (gof.name);
        var basic_modified = new Label ("<span weight='light'>Modified: " + gof.formated_modified + "</span>");

        /*var font_style = new Pango.FontDescription();
          font_style.set_size(12 * 1000);
          basic_filename.modify_font(font_style);*/

        //basic_filename.set_halign (Align.START);
        //basic_filename.set_size_request (200, -1);
        basic_filename.set_use_markup (true);
        //basic_filename.set_use_markup (true);
        //basic_filename.set_line_wrap (true);
        //basic_filename.set_ellipsize(Pango.EllipsizeMode.MIDDLE);
        basic_modified.set_halign (Align.START);
        basic_modified.set_use_markup (true);
        hhbox1.pack_start(basic_filename);
        if (!gof.is_directory) {
            var basic_size = new Label ("<span weight='semibold' size='large'>" + gof.format_size + "</span>");
            basic_size.set_use_markup (true);
            basic_size.set_halign (Align.END);
            basic_size.set_valign (Align.START);
            hhbox1.pack_start(basic_size);
        }
        vvbox.pack_start(hhbox1);
        vvbox.pack_start(basic_modified);

        content_vbox.pack_start(basic_box, false, false, 0);
        var sep = new Separator (Orientation.HORIZONTAL);
        sep.margin = 7;
        content_vbox.pack_start(sep, false, false, 0);


        /* Info */
        var info_vbox = new VBox(false, 0);
        construct_info_panel (info_vbox, info);
        add_section (content_vbox, _("Info"), info_vbox);

        /* Permissions */
        var perm_vbox = new VBox(false, 0);
        /*var name_label = new Label("blabla");
        name_label.xalign = 0;
        name_label.set_line_wrap(true);
        perm_vbox.pack_start(name_label);*/
        construct_perm_panel (perm_vbox, gof);
        add_section (content_vbox, _("Permissions"), perm_vbox);
        if (!gof.can_set_permissions()) {
            foreach (var widget in perm_vbox.get_children())
                widget.set_sensitive (false);
        }

        /* Preview */
        var preview_box = new VBox(false, 0);
        construct_preview_panel (preview_box, gof);
        add_section (content_vbox, _("Preview"), preview_box);

        /* Open With */
        var openw_box = new VBox (false, 0);

        add_section (content_vbox, _("Open With"), openw_box);

        var close_button = new Button.from_stock(Stock.CLOSE);
        close_button.clicked.connect(() => { response(ResponseType.CLOSE); });
        action_area.pack_end (close_button, false, false, 0);
        //add_button (Stock.CLOSE, ResponseType.CLOSE);

        content_vbox.show();

        content_area.show_all();
        action_area.show_all();
        close_button.grab_focus();

        response.connect (on_response);

        set_modal (true);
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

    private void add_section (VBox vbox, string title, Box content) {
        //var exp = new Expander("<span weight='semibold' size='large'>" + title + "</span>");
        var exp = new Expander("<span weight='semibold'>" + title + "</span>");
        exp.set_use_markup(true);
        exp.expanded = true;
        vbox.pack_start(exp, false, false, 0);
        if (content != null)
            exp.add (content);
    }

    private void get_info (GOF.File file) {
        var file_info = file.info;
        info = new Gee.LinkedList<Pair<string, string>>();

        info.add(new Pair<string, string>(_("Name") + (": "), file.name));
        info.add(new Pair<string, string>(_("Type") + (": "), file.formated_type));
        info.add(new Pair<string, string>(_("MimeType") + (": "), file.ftype));

        var raw_type = file_info.get_file_type();
        if(raw_type != FileType.DIRECTORY)
            info.add(new Pair<string, string>(_("Size") + (": "), file.format_size));
        /* localized time depending on MARLIN_PREFERENCES_DATE_FORMAT locale, iso .. */
        info.add(new Pair<string, string>(_("Created") + (": "), file.get_formated_time (FILE_ATTRIBUTE_TIME_CREATED)));
        info.add(new Pair<string, string>(_("Modified") + (": "), file.formated_modified));
        info.add(new Pair<string, string>(_("Last Access") + (": "), file.get_formated_time (FILE_ATTRIBUTE_TIME_ACCESS)));
        /* print deletion date if trashed file */
        //TODO format trash deletion date string
        if (file.is_trashed())
            info.add(new Pair<string, string>(_("Deleted") + (": "), file_info.get_attribute_as_string("trash::deletion-date")));
        if (file_info.get_is_symlink())
            info.add(new Pair<string, string>(_("Target") + (": "), file_info.get_symlink_target()));
        string path = file.location.get_parse_name ();
        if (path != null)
            info.add(new Pair<string, string>(_("Location") + (": "), path));
        else
            info.add(new Pair<string, string>(_("Location") + (": "), file.uri));
        /* print orig location of trashed files */
        if (file.is_trashed() && file.trash_orig_path != null)
            info.add(new Pair<string, string>(_("Origin Location") + (": "), file.trash_orig_path));


    }

    private void construct_info_panel (Box box, Gee.LinkedList<Pair<string, string>> item_info) {
        var information = new Grid();
        //information.row_spacing = 10;

        int n = 0;
        foreach(var pair in item_info){
            /* skip the firs parameter "name" for vertical panel */
            if (n>0) {
                var value_label = new Granite.Widgets.WrapLabel(pair.value);
                //value_label.set_line_wrap (true);
                /*var key_label = new Gtk.Label(pair.key);
                key_label.set_sensitive(false);
                key_label.set_halign(Align.END);
                key_label.set_valign(Align.START);
                key_label.margin_right = 5;*/
                Gtk.Label key_label = create_label_key(pair.key);
                /*key_label.set_ellipsize(Pango.EllipsizeMode.START);*/
                //value_label.set_ellipsize(Pango.EllipsizeMode.MIDDLE);
                value_label.set_selectable(true);
                value_label.set_size_request(200, -1);

                information.attach(key_label, 0, n, 1, 1);
                information.attach(value_label, 1, n, 1, 1);
            }
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
        if (!btn.get_active())
            mult = -1;
        update_perm_codes (pt, 4, mult);
        perm_code.set_text("%d%d%d".printf(owner_perm_code, group_perm_code, everyone_perm_code));
    }

    private void action_toggled_write (Gtk.ToggleButton btn) {
        unowned PermissionType pt = btn.get_data ("permissiontype");
        int mult = 1;
        if (!btn.get_active())
            mult = -1;
        update_perm_codes (pt, 2, mult);
        perm_code.set_text("%d%d%d".printf(owner_perm_code, group_perm_code, everyone_perm_code));
    }
    
    private void action_toggled_execute (Gtk.ToggleButton btn) {
        unowned PermissionType pt = btn.get_data ("permissiontype");
        int mult = 1;
        if (!btn.get_active())
            mult = -1;
        update_perm_codes (pt, 1, mult);
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

    private void update_permission_type_buttons (Gtk.HBox hbox, int32 permissions, PermissionType pt) {
        int i=0;
        foreach (var widget in hbox.get_children()) {
            Gtk.ToggleButton btn = (Gtk.ToggleButton) widget;
            ((permissions & vfs_perms[pt, i]) != 0) ? btn.active = true : btn.active = false;
            i++;
        }
    }

    private void update_perm_grid_toggle_states (GOF.File file) {
        Gtk.HBox hbox;

        /* update USR row */
        hbox = (Gtk.HBox) perm_grid.get_child_at (1,3);
        update_permission_type_buttons (hbox, file.permissions, PermissionType.USER);
        
        /* update GRP row */
        hbox = (Gtk.HBox) perm_grid.get_child_at (1,4);
        update_permission_type_buttons (hbox, file.permissions, PermissionType.GROUP);
        
        /* update OTHER row */
        hbox = (Gtk.HBox) perm_grid.get_child_at (1,5);
        update_permission_type_buttons (hbox, file.permissions, PermissionType.OTHER);
    }
   
    private void construct_perm_panel (Box box, GOF.File file) {
        perm_grid = new Grid();
                
        Gtk.Label key_label;
        Gtk.HBox value_label;
        
        key_label = create_label_key(_("Owner") + ": ");
        perm_grid.attach(key_label, 0, 1, 1, 1);
        key_label = create_label_key(_("Group") + ": ");
        perm_grid.attach(key_label, 0, 2, 1, 1);
        key_label = create_label_key(_("Owner") + ": ", Align.CENTER);
        value_label = create_perm_choice(PermissionType.USER);
        perm_grid.attach(key_label, 0, 3, 1, 1);
        perm_grid.attach(value_label, 1, 3, 1, 1);
        key_label = create_label_key(_("Group") + ": ", Align.CENTER);
        value_label = create_perm_choice(PermissionType.GROUP);
        perm_grid.attach(key_label, 0, 4, 1, 1);
        perm_grid.attach(value_label, 1, 4, 1, 1);
        key_label = create_label_key(_("Everyone") + ": ", Align.CENTER);
        value_label = create_perm_choice(PermissionType.OTHER);
        perm_grid.attach(key_label, 0, 5, 1, 1);
        perm_grid.attach(value_label, 1, 5, 1, 1);
        
        perm_code = new XsEntry();
        //var perm_code = new Label("705");
        //perm_code.margin_right = 2;
        perm_code.set_text("000");
        perm_code.set_max_length(3);
        //perm_code.set_has_frame (false);
        perm_code.set_size_request(35, -1);
        var perm_code_hbox = new HBox(false, 10);
        //var l_perm = new Label("-rwxr-xr-x");
        var l_perm = new Label(file.get_permissions_as_string());
        perm_code_hbox.pack_start(l_perm, true, true, 0);
        perm_code_hbox.pack_start(perm_code, false, false, 0);

        perm_grid.attach(perm_code_hbox, 1, 6, 1, 1);
        
        box.pack_start(perm_grid);
        update_perm_grid_toggle_states (file);
    }
    
    private void construct_preview_panel (Box box, GOF.File file) {
        evbox = new ImgEventBox(Orientation.HORIZONTAL);
        file.update_icon (256);
        if (file.pix != null)
            evbox.set_from_pixbuf (file.pix);

        box.pack_start(evbox, false, true, 0);
    }
}
