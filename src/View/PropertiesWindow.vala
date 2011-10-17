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
    public PropertiesWindow (GLib.List<GOF.File> files, Gtk.Window parent)
    {
        title = _("Properties");
        resizable = false;
        set_default_response(ResponseType.CANCEL);

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

        /* Basic */
        var basic_box = new HBox (false, 9);
        //basic_vbox.set_size_request (0, 40); 
        
        var file_pix = gof.get_icon_pixbuf (32, false, GOF.FileIconFlags.NONE);
        var file_img = new Image.from_pixbuf (file_pix);
        basic_box.pack_start(file_img, false, false);

        var vvbox = new VBox (false, 0);
        basic_box.pack_start(vvbox);
        var hhbox1 = new HBox (false, 0);
        var basic_filename = new Label ("<span weight='semibold' size='large'>" + gof.name + "</span>");
        //var basic_filename = new Label (gof.name);
        var basic_modified = new Label ("<span weight='light'>Modified: " + gof.formated_modified + "</span>");

        /*var font_style = new Pango.FontDescription();
        font_style.set_size(12 * 1000);
        basic_filename.modify_font(font_style);*/

        basic_filename.set_halign (Align.START);
        basic_filename.set_use_markup (true);
        basic_filename.set_ellipsize(Pango.EllipsizeMode.MIDDLE);
        basic_modified.set_halign (Align.START);
        basic_modified.set_use_markup (true);
        hhbox1.pack_start(basic_filename);
        if (!gof.is_directory) {
            var basic_size = new Label ("<span weight='semibold' size='large'>" + gof.format_size + "</span>");
            basic_size.set_halign (Align.START);
            basic_size.set_use_markup (true);
            basic_size.set_halign (Align.END);
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

    /*private void add_section (VBox vbox, string title, Box content) {
        var hbox = new HBox (false, 0);
        //var exp = new Expander("<span weight='semibold' size='large'>" + title + "</span>");
        var exp = new Expander("<span weight='semibold'>" + title + "</span>");
        exp.set_use_markup(true);
        exp.expanded = true;
        
        var sep = new Separator (Orientation.HORIZONTAL);
        sep.set_valign (Align.CENTER);

        hbox.pack_start(exp, false, false, 0);
        hbox.pack_start(sep);
        if (content != null)
            exp.add (content);
        vbox.pack_start(hbox, false, false, 0);
    }*/
}
