/*
 * Copyright (c) 2011 Lucas Baudin <xapantu@gmail.com>
 *
 * Marlin is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * Marlin is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; see the file COPYING.  If not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

using Gtk;
namespace Marlin.View
{
    class ImageButton : Button
    {
        public ImageButton(string title, string subtitle, string icon_name)
        {
            var hbox = new Box(Orientation.HORIZONTAL, 15);
            
            /* Image */
            hbox.pack_start(new Image.from_icon_name (icon_name, Gtk.IconSize.DIALOG), false, false);
            var vbox = new Box(Orientation.VERTICAL, 0);
            
            /* Title */
            var label = new Label(title);
            label.set_alignment(0, 0.5f);
            vbox.pack_start(label);
            
            /* Subtitle */
            label = new Label(subtitle);
            label.set_sensitive(false);
            label.set_alignment(0, 0.5f);
            
            /* Pack all */
            vbox.pack_start(label);
            hbox.pack_start(vbox);

            set_relief(Gtk.ReliefStyle.NONE);
            add(hbox);
        }
    }

    static void make_and_jump_to_new_dir (File new_folder, void *data) {
        ViewContainer tab = (ViewContainer) data;
        //message ("make and jump %s", new_folder.get_uri ());
        tab.path_changed (new_folder);
    }

    public class DirectoryNotFound : Alignment
    {
        public GOF.Directory.Async dir_saved;
        public ViewContainer ctab;

        public DirectoryNotFound(GOF.Directory.Async dir, ViewContainer tab)
        {
            set(0.5f,0.4f,0,0.1f);
            dir_saved = dir;
            ctab = tab;
            var box = new Box(Orientation.VERTICAL, 5);
            var label = new Label("");

            label.set_markup("<span size=\"x-large\">%s</span>".printf(_("Folder does not exist")));
            box.pack_start(label, false, false);

            label = new Label(_("Files can't find the folder %s").printf(dir.location.get_basename()));
            label.set_sensitive(false);
            label.set_alignment(0.5f, 0.0f);
            box.pack_start(label, true, true);

            var create_button = new ImageButton(_("Create"), _("Create the folder %s").printf(dir.location.get_basename()), "folder-new");
            create_button.clicked.connect( () => {
                Marlin.FileOperations.new_folder_with_name(null, null,
                                                           dir_saved.location.get_parent(),
                                                           dir_saved.location.get_basename(),
                                                           (void *) make_and_jump_to_new_dir, tab);
            });
            box.pack_start(create_button, false, false);
            
            add(box);
        }
    }
}
