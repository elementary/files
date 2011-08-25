/*
 * Copyright (C) Lucas Baudin 2011 <xapantu@gmail.com>
 * 
 * Marlin is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * Marlin is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;

const string PLUGIN_NAME = "MarlinTrash";

public void receive_all_hook(void* user_data, int hook)
{
    switch(hook)
    {
    case Marlin.PluginHook.INTERFACE:
        break;
    case Marlin.PluginHook.INIT:
        break;
    case Marlin.PluginHook.DIRECTORY:
        GOF.File file = ((Object[])user_data)[2] as GOF.File;
        var trash_file = File.new_for_uri("trash://");
        if(file.location.has_parent(trash_file) || file.location.equal(trash_file))
        {
            assert(((Object[])user_data)[1] is GOF.AbstractSlot);
            GOF.AbstractSlot slot = ((Object[])user_data)[1] as GOF.AbstractSlot;
            
            var infobar = new InfoBar();
            (infobar.get_content_area() as Gtk.Box).add(new Gtk.Label("This is the trash."));
            infobar.add_button("Empty the trash", 0);
            infobar.response.connect( (self, response) => {
                Marlin.FileOperations.empty_trash(self);
                });
            infobar.set_message_type(Gtk.MessageType.INFO);

            slot.add_extra_widget(infobar);
            infobar.show_all();
        }
        break;
    default:
        debug("%s doesn't know this hook: %d\n", PLUGIN_NAME, hook);
        break;
    }
}
