/* DeviceRow.vala
 *
 * Copyright 2020 elementary LLC. <https://elementary.io>
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
 * Authors : Jeremy Wootten <jeremy@elementaryos.org>
 */

public class Sidebar.DeviceRow : Sidebar.BookmarkRow {
    private Gtk.Stack mount_eject_stack;
    private Gtk.Revealer mount_eject_revealer;
    private Gtk.Spinner mount_eject_spinner;

    private bool _mounted = false;
    private bool valid = true;

    public string? uuid { get; set construct; }
    public Drive? drive { get; set construct; }
    public Volume? volume { get; set construct; }
    public Mount? mount { get; set construct; }

    public bool mounted {
        get {
            return _mounted;
        }

        set {
            _mounted = value;
            if (_mounted) {
                mount_eject_stack.visible_child_name = "eject";
            }

             mount_eject_revealer.reveal_child = _mounted && _can_eject;
        }
    }

    private bool _can_eject = true;
    public bool can_eject {
        get {
            return _can_eject;
        }

        set {
            _can_eject = value;
             mount_eject_revealer.reveal_child = _can_eject && _mounted;
        }
    }

    public bool working {
        get {
            return mount_eject_stack.visible_child_name == "spinner";
        }

        set {
            if (!valid) {
                return;
            }

            if (_can_eject) {
                mount_eject_revealer.reveal_child = true;
                mount_eject_stack.visible_child_name = "spinner";
                mount_eject_spinner.start ();
            } else {
                mount_eject_spinner.stop ();
                mount_eject_stack.visible_child_name = "eject";
                mount_eject_revealer.reveal_child = _can_eject && _mounted;
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

        var volume_monitor = VolumeMonitor.@get ();
        volume_monitor.volume_removed.connect (volume_removed);
        volume_monitor.mount_removed.connect (mount_removed);
        volume_monitor.drive_disconnected.connect (drive_removed);
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
                        mounted = true;
                        can_eject = mount.can_unmount ();
                        uri = mount.get_default_location ().get_uri ();
                        add_tooltip ();
                        sidebar.path_change_request (uri, Marlin.OpenFlag.DEFAULT);
                    }
                } catch (GLib.Error error) {
                    var primary = _("Error mounting volume %s").printf (volume.get_name ());
                    PF.Dialogs.show_error_dialog (primary, error.message, Marlin.get_active_window ());
                } finally {
                    working = false;
                }
            });
        } else if (drive != null && (drive.can_start () || drive.can_start_degraded ())) {
            working = true;
            drive.start.begin (DriveStartFlags.NONE,
                               new Gtk.MountOperation (null),
                               null,
                               (obj, res) => {
                    try {
                        if (drive.start.end (res)) {
                            mounted = true;
                            can_eject = drive.can_eject () || drive.can_stop ();
                        }
                    } catch (Error e) {
                            var primary = _("Unable to start %s").printf (drive.get_name ());
                            PF.Dialogs.show_error_dialog (primary, e.message, Marlin.get_active_window ());
                    } finally {
                        working = false;
                    }
                }
            );
        }
    }

    private void eject () {
        var mount_op = new Gtk.MountOperation (Marlin.get_active_window ());
        if (mount != null) {
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
        } else if (drive != null && drive.can_eject () || drive.can_stop ()) {
            working = true;
            if (drive.can_stop ()) {
                drive.stop.begin (
                    GLib.MountUnmountFlags.NONE,
                    mount_op,
                    null,
                    (obj, res) => {
                        try {
                            drive.stop.end (res);
                        } catch (Error e) {

                        } finally {
                            working = false;
                        }
                    }
                );
            } else if (drive.can_eject ()) {
                drive.eject_with_operation.begin (
                    GLib.MountUnmountFlags.NONE,
                    mount_op,
                    null,
                    (obj, res) => {
                        try {
                            drive.eject_with_operation.end (res);
                        } catch (Error e) {

                        } finally {
                            working = false;
                        }
                    }
                );
            }
        }
    }


    private void drive_removed (Drive removed_drive) {
        if (valid && drive == removed_drive) {
            valid = false;
            sidebar.remove_item_id (id);
        }
    }

    private void volume_removed (Volume removed_volume) {
        if (valid && volume == removed_volume) {
            valid = false;
            sidebar.remove_item_id (id);
        }
    }

    private void mount_removed (Mount removed_mount) {
        if (valid && mount == removed_mount) {
            if (drive == null && volume == null) {
                valid = false;
                sidebar.remove_item_id (id);
            } else {
                mounted = false;
            }
        }
    }

    public override async void add_tooltip () {
        set_tooltip_markup (
            uri
        );
    }
}
