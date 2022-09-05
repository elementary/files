/*
* Copyright (c) 2016-2018 elementary LLC. <https://elementary.io>
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation, Inc.,; either
* version 2 of the License, or (at your option) any later version.
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
*/

public class PermissionButton : Gtk.Box {
    public Gtk.ToggleButton btn_read;
    public Gtk.ToggleButton btn_write;
    public Gtk.ToggleButton btn_exe;

    public Permissions.Type permission_type { get; construct; }

    private Posix.mode_t[,] vfs_perms = {
        { Posix.S_IRUSR, Posix.S_IWUSR, Posix.S_IXUSR },
        { Posix.S_IRGRP, Posix.S_IWGRP, Posix.S_IXGRP },
        { Posix.S_IROTH, Posix.S_IWOTH, Posix.S_IXOTH }
    };

    public PermissionButton (Permissions.Type permission_type) {
        Object (permission_type: permission_type);
    }

    construct {
        orientation = Gtk.Orientation.HORIZONTAL;

        btn_read = new Gtk.ToggleButton.with_label (_("Read"));
        btn_read.set_data ("permissiontype", permission_type);
        btn_read.set_data ("permissionvalue", Permissions.Value.READ);

        btn_write = new Gtk.ToggleButton.with_label (_("Write"));
        btn_write.set_data ("permissiontype", permission_type);
        btn_write.set_data ("permissionvalue", Permissions.Value.WRITE);

        btn_exe = new Gtk.ToggleButton.with_label (_("Execute"));
        btn_exe.set_data ("permissiontype", permission_type);
        btn_exe.set_data ("permissionvalue", Permissions.Value.EXE);

        add_css_class ("linked");
        append (btn_read);
        append (btn_write);
        append (btn_exe);
    }

    public void update_buttons (uint32 permissions) {
        if ((permissions & vfs_perms[permission_type, 0]) != 0) {
            btn_read.active = true;
        } else {
            btn_read.active = false;
        }

        if ((permissions & vfs_perms[permission_type, 1]) != 0) {
            btn_write.active = true;
        } else {
            btn_write.active = false;
        }

        if ((permissions & vfs_perms[permission_type, 2]) != 0) {
            btn_exe.active = true;
        } else {
            btn_exe.active = false;
        }
    }
}
