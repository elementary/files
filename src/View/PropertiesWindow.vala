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

public class Marlin.View.PropertiesWindow : Gtk.Dialog
{
    private Gee.LinkedList<Pair<string, string>> info;

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

        /* Permissions */
        var perm_vbox = new VBox(false, 0);
        var name_label = new Label("blabla");
        name_label.xalign = 0;
        name_label.set_line_wrap(true);
        perm_vbox.pack_start(name_label);

        /* Preview */
        var preview_box = new VBox(false, 0);

        /* Open With */
        var openw_box = new VBox (false, 0);

        add_section (content_vbox, _("Info"), info_vbox);
        add_section (content_vbox, _("Permissions"), perm_vbox);
        add_section (content_vbox, _("Preview"), preview_box);
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
        info.add(new Pair<string, string>(_("Last Opened") + (": "), file.get_formated_time (FILE_ATTRIBUTE_TIME_ACCESS)));
        if (file_info.get_is_symlink())
            info.add(new Pair<string, string>(_("Target") + (": "), file_info.get_symlink_target()));
        string path = file.location.get_parse_name ();
        if (path != null)
            info.add(new Pair<string, string>(_("Location") + (": "), path));
        else
            info.add(new Pair<string, string>(_("Location") + (": "), file.uri));


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
                var key_label = new Gtk.Label(pair.key);
                key_label.set_sensitive(false);
                key_label.set_halign(Align.END);
                key_label.set_valign(Align.START);
                key_label.margin_right = 5;
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
}
