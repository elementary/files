/*
 * Copyright 2020 Jeremy Paul Wootten <jeremy@jeremy-Kratos-Ubuntu>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 *
 */

public class Sidebar.DeviceListBox : Sidebar.BookmarkListBox {
    protected VolumeMonitor volume_monitor;
    public DeviceListBox (Sidebar.SidebarWindow sidebar) {
        base (sidebar);
    }

    construct {
        volume_monitor = VolumeMonitor.@get ();
        volume_monitor.volume_added.connect (volume_added);
        volume_monitor.mount_added.connect (mount_added);
        volume_monitor.drive_connected.connect (drive_added);
    }

    public new DeviceRow add_bookmark (string label, string uri, Icon gicon,
                                       string? uuid = null,
                                       Drive? drive = null,
                                       Volume? volume = null,
                                       Mount? mount = null) {
        var row = new DeviceRow (
            label,
            uri,
            gicon,
            sidebar,
            uuid,
            drive,
            volume,
            mount
        );

        add (row);
        return row;
    }

    private void add_volume (Volume volume) {
        var mount = volume.get_mount ();
        if (mount != null) {
            add_mount (mount);
        } else {
            /* Do show the unmounted volumes in the sidebar;
            * this is so the user can mount it (in case automounting
            * is off).
            *
            * Also, even if automounting is enabled, this gives a visual
            * cue that the user should remember to yank out the media if
            * he just unmounted it.
            */

            var bm = add_bookmark (
                volume.get_name (),
                volume.get_name (),
                volume.get_icon (),
                volume.get_uuid (),
                null,
                volume,
                null
            );

            bm.mounted = false;
            bm.can_eject = volume.can_eject () ||
                           volume.get_drive () != null && volume.get_drive ().can_eject ();
        }
    }

    private void add_mount (Mount mount)  {
        /* show mounted volume in sidebar */
        var root = mount.get_root ();
        var device_label = root.get_basename ();
        if (device_label != mount.get_name ()) {
            ///TRANSLATORS: The first string placeholder '%s' represents a device label, the second '%s' represents a mount name.
            device_label = _("%s on %s").printf (device_label, mount.get_name ());
        }

        var bm = add_bookmark (
            device_label,
            mount.get_default_location ().get_uri (),
            mount.get_icon (),
            mount.get_uuid () ?? mount.get_volume ().get_uuid (),
            mount.get_drive (),
            mount.get_volume (),
            mount
        );

        bm.add_tooltip.begin ();
        bm.mounted = true;
        bm.can_eject = mount.can_unmount ();
    }

   private void add_drive (Drive drive) {
       var volumes = drive.get_volumes ();
        if (volumes != null) {
            add_volumes (volumes);
        } else if (drive.is_media_removable () && !drive.is_media_check_automatic ()) {
        /* If the drive has no mountable volumes and we cannot detect media change.. we
         * display the drive in the sidebar so the user can manually poll the drive by
         * right clicking and selecting "Rescan..."
         *
         * This is mainly for drives like floppies where media detection doesn't
         * work.. but it's also for human beings who like to turn off media detection
         * in the OS to save battery juice.
         */
            var bm = add_bookmark (
                drive.get_name (),
                drive.get_name (),
                drive.get_icon (),
                drive.get_name (), // Unclear what to use as a unique identifier for a drive so use name
                drive,
                null,
                null
            );

            bm.mounted = true;
            bm.can_eject = drive.can_eject ();
        }
    }

    private void drive_added (Drive drive)  {}

    private void volume_added (Volume vol)  {
        add_volume (vol);
    }

    private void mount_added (Mount mount)  {
        var vol = mount.get_volume ();
        if (!has_uuid (vol.get_uuid ())) {
            add_mount (mount);
        }
    }

    public void add_all_local_volumes_and_mounts () {
        add_connected_drives (); // Add drives and their associated volumes
        add_volumes_without_drive (); // Add volumes not associated with a drive
        add_native_mounts_without_volume ();
    }

    private void add_connected_drives () {
        foreach (GLib.Drive drive in volume_monitor.get_connected_drives ()) {
            add_drive (drive);
        }
    }

    private void add_volumes (List<Volume> volumes) {
        foreach (Volume volume in volumes) {
            add_volume (volume);
        }
    }

    private void add_volumes_without_drive () {
        foreach (Volume volume in volume_monitor.get_volumes ()) {
            if (volume.get_drive () == null) {
                add_volume (volume);
            }
        }
    }

    private void add_native_mounts_without_volume () {
        foreach (Mount mount in volume_monitor.get_mounts ()) {
            if (mount.is_shadowed ()) {
                continue;
            }

            var volume = mount.get_volume ();
            if (volume == null) {
                var root = mount.get_root ();
                if (root.is_native () && root.get_uri_scheme () != "archive") {
                    add_mount (mount);
                }
            }
        }
    }

    private bool has_uuid (string? uuid, string? fallback = null) {
        var search = uuid != null ? uuid : fallback;

        if (search == null) {
            return false;
        }

        foreach (var child in get_children ()) {
            if (((DeviceRow)child).uuid == uuid) {
                return true;
            }
        }

        return false;
    }
}


public class Sidebar.DeviceRow : Sidebar.BookmarkRow {
    private Gtk.Stack mount_eject_stack;
    private Gtk.Revealer mount_eject_revealer;
    private Gtk.Spinner mount_eject_spinner;

    private bool _mounted = false;

    public string? uuid { get; set construct; }
    public Drive? drive { get; set construct; }
    public Volume? volume { get; set construct; }
    public Mount? mount { get; set construct; }

    public bool mounted {
        get {
            return _mounted;
        }

        set {
            if (value && _can_eject) {
                mount_eject_stack.visible_child_name = "eject";
                mount_eject_revealer.reveal_child = true;
            } else {
                mount_eject_revealer.reveal_child = false;
            }

            _mounted = value;
        }
    }

    private bool _can_eject = true;
    public bool can_eject {
        get {
            return _can_eject;
        }

        set {
            if (!value) {
                mount_eject_revealer.reveal_child = false;
            }

            _can_eject = value;
        }
    }

    public bool working {
        get {
            return mount_eject_stack.visible_child_name == "spinner";
        }

        set {
            if (value && _can_eject) {
                mount_eject_revealer.reveal_child = true;
                mount_eject_stack.visible_child_name = "spinner";
                mount_eject_spinner.start ();
            } else {
                mount_eject_spinner.stop ();
                mount_eject_stack.visible_child_name = "eject";
            }
        }
    }

    public DeviceRow (string name, string uri, Icon gicon, Sidebar.SidebarWindow sidebar,
                      string? _uuid, Drive? drive, Volume? volume, Mount? mount) {
        Object (
            custom_name: name,
            uri: uri,
            gicon: gicon,
            sidebar: sidebar,
            uuid: _uuid,
            drive: drive,
            volume: volume,
            mount: mount
        );
    }

    construct {
        mount_eject_revealer = new Gtk.Revealer ();

        mount_eject_stack = new Gtk.Stack () {
            halign = Gtk.Align.END,
            hexpand = true
        };

        Gtk.Image eject_image = new Gtk.Image.from_icon_name ("media-eject-symbolic", Gtk.IconSize.MENU) {
            margin_end = 9
        };

        var eject_image_event_box = new Gtk.EventBox () {
            above_child = true
        };

        eject_image_event_box.add_events (Gdk.EventMask.BUTTON_PRESS_MASK);
        eject_image_event_box.add (eject_image);
        eject_image_event_box.button_press_event.connect ( () => {
            eject ();
            return true;
        });
        mount_eject_stack.add_named (eject_image_event_box, "eject");
        mount_eject_stack.visible_child_name = "eject";

        mount_eject_spinner = new Gtk.Spinner ();
        mount_eject_stack.add_named (mount_eject_spinner, "spinner");

        mount_eject_revealer.add (mount_eject_stack);
        mount_eject_revealer.reveal_child = false;

        content_grid.add (mount_eject_revealer);
        show_all ();
    }

    public override void activated () {
        if (mounted) {
            sidebar.path_change_request (uri, Marlin.OpenFlag.DEFAULT);
        } else if (volume != null && !working) {
            working = true;
            volume.mount.begin (GLib.MountMountFlags.NONE,
                                new Gtk.MountOperation (Marlin.get_active_window ()),
                                null,
                                (obj, res) => {
                try {
                    volume.mount.end (res);
                    mount = volume.get_mount ();
                    if (mount != null) {
                        warning ("Successfully mounted %s", custom_name);
                        mounted = true;
                        var location = mount.get_root ();
                        sidebar.path_change_request (location.get_uri (), Marlin.OpenFlag.DEFAULT);
                    }
                } catch (GLib.Error error) {
                    var primary = _("Error mounting volume %s").printf (volume.get_name ());
                    PF.Dialogs.show_error_dialog (primary, error.message, Marlin.get_active_window ());
                } finally {
                    working = false;
                }
            });
        } else if (drive != null && (drive.can_start () || drive.can_start_degraded ())) {
            drive.start.begin (DriveStartFlags.NONE,
                               new Gtk.MountOperation (null),
                               null,
                               (obj, res) => {
                    try {
                        if (drive.start.end (res)) {
                            mounted = true;
                        }
                    }
                    catch (Error e) {
                            var primary = _("Unable to start %s").printf (drive.get_name ());
                            PF.Dialogs.show_error_dialog (primary, e.message, Marlin.get_active_window ());
                    }
                }
            );
        }
    }

    private void eject () {
        if (mount != null) {
            var mount_op = new Gtk.MountOperation (Marlin.get_active_window ());
            if (mount.can_eject ()) {
                working = true;
                mount.eject_with_operation.begin (
                    GLib.MountUnmountFlags.NONE,
                    mount_op,
                    null,
                    (obj, res) => {
                        try {
                            mounted = !mount.eject_with_operation.end (res);
                        } catch (GLib.Error error) {
                            warning ("Error ejecting mount: %s", error.message);
                        } finally {
                            working = false;
                        }
                    }
                );

                return;
            } else if (mount.can_unmount ()) {
                working = true;
                mount.unmount_with_operation.begin (
                    GLib.MountUnmountFlags.NONE,
                    mount_op,
                    null,
                    (obj, res) => {
                        try {
                            mounted = !mount.unmount_with_operation.end (res);
                        } catch (GLib.Error error) {
                            warning ("Error while unmounting mount %s", error.message);
                        } finally {
                            working = false;
                        }
                    }
                );
            }
        }
    }

    public override async void add_tooltip () {

    }
}

