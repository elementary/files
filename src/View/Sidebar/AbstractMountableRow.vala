/* DeviceRow.vala
 *
 * Copyright 2021 elementary LLC. <https://elementary.io>
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

public abstract class Sidebar.AbstractMountableRow : Sidebar.BookmarkRow, SidebarItemInterface {
    protected static Gtk.CssProvider devicerow_provider;

    protected Gtk.Stack mount_eject_stack;
    protected Gtk.Revealer mount_eject_revealer;
    protected Gtk.Spinner mount_eject_spinner;
    protected Gtk.Button eject_button;

    protected bool valid = true;
    public string? uuid { get; set construct; }
    public Drive? drive { get; set construct; }
    public Volume? volume { get; set construct; }
    public Mount? mount { get; set construct; }

    protected bool _mounted = false;
    public bool mounted {
        get {
            return _mounted;
        }

        set {
            _mounted = value;
            can_eject = _mounted && (mount.can_unmount () || mount.can_eject ());
            mount_eject_revealer.reveal_child = _mounted && _can_eject;
            if (_mounted) {
                update_free_space ();
            }
        }
    }

    protected bool _can_eject = false;
    public bool can_eject {
        get {
            return _can_eject;
        }

        set {
            _can_eject = !permanent && value;
             mount_eject_revealer.reveal_child = _can_eject && _mounted;
        }
    }

    private bool _working = false;
    public bool working {
        get {
            return _working;
        }

        set {
            if (!valid) {
                return;
            }

            _working = value;

            if (value) {
                mount_eject_spinner.start ();
                mount_eject_stack.visible_child = mount_eject_spinner;
            } else {
                mount_eject_stack.visible_child = eject_button;
                mount_eject_spinner.stop ();
            }
        }
    }

    protected AbstractMountableRow (string name, string uri, Icon gicon, SidebarListInterface list,
                         bool pinned, bool permanent,
                         string? _uuid, Drive? drive, Volume? volume, Mount? mount) {
        Object (
            custom_name: name,
            uri: uri,
            gicon: gicon,
            list: list,
            pinned: pinned,
            permanent: permanent,
            uuid: _uuid,
            drive: drive,
            volume: volume,
            mount: mount
        );

        if (mount != null) {
            mounted = true;
        } else if (volume != null) {
            mounted = volume.get_mount () != null;
        } else if (drive != null) {
            //TODO Make drive entries an expandable item?
            mounted = true;
            can_eject = drive.can_eject () || drive.can_stop ();
        }
    }

    static construct {
        devicerow_provider = new Gtk.CssProvider ();
        devicerow_provider.load_from_resource ("/io/elementary/files/DiskRenderer.css");
    }

    construct {
        eject_button = new Gtk.Button.from_icon_name ("media-eject-symbolic", Gtk.IconSize.MENU) {
            tooltip_text = _("Eject '%s'").printf (custom_name)
        };
        eject_button.get_style_context ().add_provider (devicerow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        mount_eject_spinner = new Gtk.Spinner ();

        mount_eject_stack = new Gtk.Stack () {
            margin_start = 6,
            transition_type = Gtk.StackTransitionType.CROSSFADE
        };

        mount_eject_stack.add (eject_button);
        mount_eject_stack.add (mount_eject_spinner);

        mount_eject_revealer = new Gtk.Revealer () {
            transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT,
            valign = Gtk.Align.CENTER
        };

        mount_eject_revealer.add (mount_eject_stack);
        mount_eject_revealer.reveal_child = false;

        content_grid.attach (mount_eject_revealer, 1, 0);

        working = false;
        show_all ();

        var volume_monitor = VolumeMonitor.@get ();
        volume_monitor.volume_removed.connect (volume_removed);
        volume_monitor.mount_removed.connect (mount_removed);
        volume_monitor.mount_added.connect (mount_added);

        add_mountable_tooltip.begin ();

        eject_button.clicked.connect (() => {
            eject ();
        });
    }

    protected override void update_plugin_data (Files.SidebarPluginItem item) {
        base.update_plugin_data (item);
        working = item.show_spinner;
    }

    protected override void activated (Files.OpenFlag flag = Files.OpenFlag.DEFAULT) {
        if (working) {
            return;
        }

        if (mounted || permanent) { //Permanent devices are always accessible
            list.open_item (this, flag);
            return;
        }

        if (volume != null) {
            working = true;
            volume.mount.begin (
                GLib.MountMountFlags.NONE,
                new Gtk.MountOperation (Files.get_active_window ()),
                null,
                (obj, res) => {
                    try {
                        volume.mount.end (res);
                        mount = volume.get_mount ();
                        if (mount != null) {
                            mounted = true;
                            uri = mount.get_default_location ().get_uri ();
                            if (volume.get_uuid () == null) {
                                uuid = uri;
                            }

                            list.open_item (this, flag);
                        }
                    } catch (GLib.Error error) {
                        var primary = _("Error mounting volume '%s'").printf (volume.get_name ());
                        PF.Dialogs.show_error_dialog (primary, error.message, Files.get_active_window ());
                    } finally {
                        working = false;
                        add_mountable_tooltip.begin ();
                    }
                }
            );
        } else if (drive != null && (drive.can_start () || drive.can_start_degraded ())) {
            working = true;
            drive.start.begin (
               DriveStartFlags.NONE,
               new Gtk.MountOperation (null),
               null,
               (obj, res) => {
                    try {
                        if (drive.start.end (res)) {
                            mounted = true;
                        }
                    } catch (Error e) {
                            var primary = _("Unable to start '%s'").printf (drive.get_name ());
                            PF.Dialogs.show_error_dialog (primary, e.message, Files.get_active_window ());
                    } finally {
                        working = false;
                        add_mountable_tooltip.begin ();
                    }
                }
            );
        }
    }

    private void eject () {
        if (working || !valid) {
            return;
        }

        var mount_op = new Gtk.MountOperation (Files.get_active_window ());
        if (!permanent && mounted && mount != null) {
            if (mount.can_eject ()) {
                working = true;
                mount.eject_with_operation.begin (
                    GLib.MountUnmountFlags.NONE,
                    mount_op,
                    null,
                    (obj, res) => {
                        try {
                            if (mount != null) {
                                mount.eject_with_operation.end (res);
                            }
                        } catch (GLib.Error error) {
                            warning ("Error ejecting mount '%s': %s", mount.get_name (), error.message);
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
                            if (mount != null) {
                                mount.unmount_with_operation.end (res);
                            }
                        } catch (GLib.Error error) {
                            warning ("Error while unmounting mount '%s': %s", mount.get_name (), error.message);
                        } finally {
                            working = false;
                        }
                    }
                );
            }
        } else if (drive != null && (drive.can_eject () || drive.can_stop ())) {
            working = true;
            if (drive.can_stop ()) {
                drive.stop.begin (
                    GLib.MountUnmountFlags.NONE,
                    mount_op,
                    null,
                    (obj, res) => {
                        try {
                            if (drive != null) {
                                drive.stop.end (res);
                            }
                        } catch (Error e) {
                            warning ("Could not stop drive '%s': %s", drive.get_name (), e.message);
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
                            if (drive != null) {
                                drive.eject_with_operation.end (res);
                            }
                        } catch (Error e) {
                            warning ("Could not eject drive '%s': %s", drive.get_name (), e.message);
                        } finally {
                            working = false;
                        }
                    }
                );
            }
        }
    }

    private void volume_removed (Volume removed_volume) {
        if (!valid) { //Already removed
            return;
        }

        if (volume == removed_volume) {
            valid = false;
            list.remove_item_by_id (id);
        }
    }

    /* This handler gets spammed by the monitor! */
    private void mount_removed (Mount removed_mount) {
        if (!valid || mount == null || !mounted) { //Already removed or unmounted
            return;
        }

        if (mount == removed_mount) {
            if (drive == null && volume == null) { // e.g. network mounts
                valid = false;
                list.remove_item_by_id (id);
            } else {
                mounted = false;
                mount = null;
            }
        }
    }

    /* This gets spammed by VolumeMonitor! */
    private void mount_added (Mount added_mount) {
        if (working || permanent || volume == null) {
            return;
        }

        working = true;
        var added_volume = added_mount.get_volume ();

        //Check added mount and volume agains this row's mount and volume details
        if ((added_volume == null || volume == null || volume.get_name () == added_volume.get_name ()) &&
            (mount == null || mount.get_name () == added_mount.get_name ())) {

            //Details match
            mount = added_mount;
            // If mount is from an auto-mounted volume (e.g. USB stick) we need to set the uri correctly
            if (uri == "") {
                uri = mount.get_default_location ().get_uri ();
            }

            mounted = true;
        }


        working = false;
    }

    protected override void add_extra_menu_items (PopupMenuBuilder menu_builder) {
        if (mount != null && mounted) {
            if (Files.FileOperations.has_trash_files (mount)) {
                menu_builder
                    .add_separator ()
                    .add_empty_mount_trash (() => {
                        Files.FileOperations.empty_trash_for_mount (this, mount);
                    })
                ;
            }

            if (mount.can_unmount ()) {
                menu_builder.add_unmount (() => {eject ();});
            } else if (mount.can_eject ()) {
                menu_builder.add_eject (() => {eject ();});
            }
        }

        menu_builder
            .add_separator ()
            .add_drive_property (() => {show_mount_info ();});
    }

    private void show_mount_info () {
        if (!mounted && volume != null) {
            /* Mount the device if possible, defer showing the dialog after
             * we're done */
            working = true;
            Files.FileOperations.mount_volume_full.begin (volume, null, (obj, res) => {
                try {
                    mounted = Files.FileOperations.mount_volume_full.end (res);
                } catch (Error e) {
                    mounted = false;
                    mount = null;
                } finally {
                    working = false;
                }

                if (mounted) {
                    new Files.View.VolumePropertiesWindow (
                        volume.get_mount (),
                        Files.get_active_window ()
                    );
                }
            });
        } else if ((mount != null && mounted) || uri == Files.ROOT_FS_URI) {
            new Files.View.VolumePropertiesWindow (
                mount,
                Files.get_active_window ()
            );
        }
    }

    protected virtual async void add_mountable_tooltip () {
        set_tooltip_markup (PF.FileUtils.sanitize_path (uri, null, false));
    }

    public virtual void update_free_space () {}
}
