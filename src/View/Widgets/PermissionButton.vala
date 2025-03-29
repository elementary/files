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

public class PermissionButton : Gtk.ListBoxRow {
    public Gtk.ToggleButton btn_read { get; private set; }
    public Gtk.ToggleButton btn_write { get; private set; }
    public Gtk.ToggleButton btn_exe { get; private set; }

    public Permissions.Type permission_type { get; construct; }

    private Posix.mode_t[,] vfs_perms = {
        { Posix.S_IRUSR, Posix.S_IWUSR, Posix.S_IXUSR },
        { Posix.S_IRGRP, Posix.S_IWGRP, Posix.S_IXGRP },
        { Posix.S_IROTH, Posix.S_IWOTH, Posix.S_IXOTH }
    };

    private static Gtk.SizeGroup label_sizegroup;

    public PermissionButton (Permissions.Type permission_type) {
        Object (permission_type: permission_type);
    }

    static construct {
        label_sizegroup = new Gtk.SizeGroup (HORIZONTAL);
    }

    construct {
        var label = new Gtk.Label (permission_type.to_string ()) {
            xalign = 0
        };

        label_sizegroup.add_widget (label);

        btn_read = new Gtk.ToggleButton () {
            hexpand = true,
            // image = new Gtk.Image.from_icon_name ("permission-read-symbolic", BUTTON),
            tooltip_text = _("Read")
        };
        btn_read.set_data ("permissiontype", permission_type);
        btn_read.set_data ("permissionvalue", Permissions.Value.READ);

        btn_write = new Gtk.ToggleButton () {
            hexpand = true,
            // image = new Gtk.Image.from_icon_name ("permission-write-symbolic", BUTTON),
            tooltip_text = _("Write")
        };
        btn_write.set_data ("permissiontype", permission_type);
        btn_write.set_data ("permissionvalue", Permissions.Value.WRITE);

        btn_exe = new Gtk.ToggleButton () {
            hexpand = true,
            // image = new Gtk.Image.from_icon_name ("permission-execute-symbolic", BUTTON),
            tooltip_text = _("Execute")
        };
        btn_exe.set_data ("permissiontype", permission_type);
        btn_exe.set_data ("permissionvalue", Permissions.Value.EXE);

        var box = new Gtk.Box (HORIZONTAL, 6);
        box.append (label);
        box.append (btn_read);
        box.append (btn_write);
        box.append (btn_exe);

        child = box;
        selectable = false;
        activatable = false;
    }

    public void update_buttons (uint32 permissions) {
        if ((permissions & vfs_perms[permission_type, 0]) != 0) {
            btn_read.active = true;
            // ((Gtk.Image) btn_read.image).icon_name = "permission-read-symbolic";
        } else {
            btn_read.active = false;
            // ((Gtk.Image) btn_read.image).icon_name = "permission-read-prevent-symbolic";
        }

        if ((permissions & vfs_perms[permission_type, 1]) != 0) {
            btn_write.active = true;
            // ((Gtk.Image) btn_write.image).icon_name = "permission-write-symbolic";
        } else {
            btn_write.active = false;
            // ((Gtk.Image) btn_write.image).icon_name = "permission-write-prevent-symbolic";
        }

        if ((permissions & vfs_perms[permission_type, 2]) != 0) {
            btn_exe.active = true;
            // ((Gtk.Image) btn_exe.image).icon_name = "permission-execute-symbolic";
        } else {
            btn_exe.active = false;
            // ((Gtk.Image) btn_exe.image).icon_name = "permission-execute-prevent-symbolic";
        }
    }
}
