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
    public class DirectoryNotFound : Granite.Widgets.Welcome {
        public GOF.Directory.Async dir_saved;
        public ViewContainer ctab;

        public DirectoryNotFound(GOF.Directory.Async dir, ViewContainer tab) {
            base(_("Folder does not exist"), _("Files can't find the folder \"%s\"").printf (dir.location.get_basename ()));           
            
            append("folder-new", _("Create"), _("Create the folder \"%s\"").printf (dir.location.get_basename ()));
            
            dir_saved = dir;
            ctab = tab;

            this.activated.connect ((index) => {
                Marlin.FileOperations.new_folder_with_name_recursive(null, null,
                                                               dir_saved.location.get_parent (),
                                                               dir_saved.location.get_basename (),
                                                               (void *) jump_to_new_dir, ctab);
            });

            show_all();
        }
        
        static void jump_to_new_dir (File? new_folder, void *user_data) {
            if (new_folder != null) {
                ViewContainer tab = (ViewContainer) user_data;
                tab.path_changed (new_folder);
            }
        }
    }
}
