/*
* Copyright (c) 2016 elementary LLC. (http://launchpad.net/pantheon-files)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 59 Temple Place - Suite 330,
* Boston, MA 02111-1307, USA.
*/

public class PermissionButton : Gtk.Box {
    public Gtk.ToggleButton btn_read;
    public Gtk.ToggleButton btn_write;
    public Gtk.ToggleButton btn_exe;

    public Marlin.View.PropertiesWindow.PermissionType permission_type { get; construct; }

    public enum Value {
        READ,
        WRITE,
        EXE
    }

    public PermissionButton (Marlin.View.PropertiesWindow.PermissionType permission_type) {
        Object (permission_type: permission_type);
    }

    construct {
        btn_read = new Gtk.ToggleButton.with_label (_("Read"));
        btn_read.set_data ("permissiontype", permission_type);
        btn_read.set_data ("permissionvalue", Value.READ);

        btn_write = new Gtk.ToggleButton.with_label (_("Write"));
        btn_write.set_data ("permissiontype", permission_type);
        btn_write.set_data ("permissionvalue", Value.WRITE);

        btn_exe = new Gtk.ToggleButton.with_label (_("Execute"));
        btn_exe.set_data ("permissiontype", permission_type);
        btn_exe.set_data ("permissionvalue", Value.EXE);

        homogeneous = true;
        get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        add (btn_read);
        add (btn_write);
        add (btn_exe);
    }
}
