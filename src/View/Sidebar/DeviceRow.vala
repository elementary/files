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

public class Sidebar.DeviceRow : Sidebar.BookmarkRow, SidebarItemInterface {
    private static Gtk.CssProvider levelbar_provider;

    private Gtk.Stack mount_eject_stack;
    private Gtk.Revealer mount_eject_revealer;
    private Gtk.Spinner mount_eject_spinner;

    private bool _mounted = false;
    private bool valid = true;
    private double storage_capacity = 0;
    private double storage_free = 0;
    private string storage_text = "";

    public Gtk.LevelBar storage { get; set construct; }
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

            if (value) {
                mount_eject_revealer.reveal_child = true;
                mount_eject_stack.visible_child_name = "spinner";
                mount_eject_spinner.start ();
            } else {
                mount_eject_spinner.stop ();
                mount_eject_stack.visible_child_name = "eject";
            }

            mount_eject_revealer.reveal_child = _mounted && _can_eject;
        }
    }

    public DeviceRow (string name, string uri, Icon gicon, SidebarListInterface list,
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
    }

    static construct {
        levelbar_provider = new Gtk.CssProvider ();
        levelbar_provider.load_from_resource ("/io/elementary/files/DiskRenderer.css");
    }

    construct {
        var eject_button = new Gtk.Button.from_icon_name ("media-eject-symbolic", Gtk.IconSize.MENU) {
            tooltip_text = _("Eject “%s”").printf (custom_name)
        };
        eject_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        mount_eject_spinner = new Gtk.Spinner ();

        mount_eject_stack = new Gtk.Stack () {
            transition_type = Gtk.StackTransitionType.CROSSFADE
        };
        mount_eject_stack.add_named (eject_button, "eject");
        mount_eject_stack.add_named (mount_eject_spinner, "spinner");
        mount_eject_stack.visible_child_name = "eject";

        mount_eject_revealer = new Gtk.Revealer () {
            transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT,
            valign = Gtk.Align.CENTER
        };
        mount_eject_revealer.add (mount_eject_stack);
        mount_eject_revealer.reveal_child = false;

        content_grid.column_spacing = 6;
        content_grid.attach (mount_eject_revealer, 1, 0);

        storage = new Gtk.LevelBar () {
            value = 0.5,
            hexpand = true
        };
        storage.add_offset_value (Gtk.LEVEL_BAR_OFFSET_LOW, 0.9);
        storage.add_offset_value (Gtk.LEVEL_BAR_OFFSET_HIGH, 0.95);
        storage.add_offset_value (Gtk.LEVEL_BAR_OFFSET_FULL, 1);
        storage.get_style_context ().add_provider (levelbar_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        icon_label_grid.attach (storage, 1, 1, 1, 1);

        show_all ();

        var volume_monitor = VolumeMonitor.@get ();
        volume_monitor.volume_removed.connect (volume_removed);
        volume_monitor.mount_removed.connect (mount_removed);
        volume_monitor.mount_added.connect (mount_added);
        volume_monitor.drive_disconnected.connect (drive_removed);

        add_device_tooltip.begin ();

        eject_button.clicked.connect (() => {
                eject ();
        });
    }

    protected override void update_plugin_data (Marlin.SidebarPluginItem item) {
        base.update_plugin_data (item);
        working = item.show_spinner;
    }

    protected override void activated (Marlin.OpenFlag flag = Marlin.OpenFlag.DEFAULT) {
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
                new Gtk.MountOperation (Marlin.get_active_window ()),
                null,
                (obj, res) => {
                    try {
                        volume.mount.end (res);
                        mount = volume.get_mount ();
                        if (mount != null) {
                            mounted = true;
                            can_eject = mount.can_unmount () || mount.can_eject ();
                            uri = mount.get_default_location ().get_uri ();
                            list.open_item (this, flag);
                        }
                    } catch (GLib.Error error) {
                        var primary = _("Error mounting volume %s").printf (volume.get_name ());
                        PF.Dialogs.show_error_dialog (primary, error.message, Marlin.get_active_window ());
                    } finally {
                        working = false;
                        add_device_tooltip.begin ();
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
                            can_eject = drive.can_eject () || drive.can_stop ();
                        }
                    } catch (Error e) {
                            var primary = _("Unable to start %s").printf (drive.get_name ());
                            PF.Dialogs.show_error_dialog (primary, e.message, Marlin.get_active_window ());
                    } finally {
                        working = false;
                        add_device_tooltip.begin ();
                    }
                }
            );
        }
    }

    private void eject () {
        if (working || !valid) {
            return;
        }

        var mount_op = new Gtk.MountOperation (Marlin.get_active_window ());
        if (!permanent && mounted && mount != null) {
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
                            if (!mounted) {
                                mount = null;
                            }
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
                            if (!mounted) {
                                mount = null;
                            }
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
                            mounted = drive.stop.end (res);
                        } catch (Error e) {

                        } finally {
                            working = false;
                            if (!mounted) {
                                mount = null;
                            }
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
                            mounted = drive.eject_with_operation.end (res);
                        } catch (Error e) {

                        } finally {
                            working = false;
                            if (!mounted) {
                                mount = null;
                            }
                        }
                    }
                );
            }
        }
    }

    private void drive_removed (Drive removed_drive) {
        if (valid && drive == removed_drive) {
            valid = false;
            list.remove_item_by_id (id);
        }
    }

    private void volume_removed (Volume removed_volume) {
        if (valid && volume == removed_volume) {
            valid = false;
            list.remove_item_by_id (id);
        }
    }

    /* This handler gets spammed by the monitor! */
    private void mount_removed (Mount removed_mount) {
        if (valid && !working && mounted && mount == removed_mount) {
            if (drive == null && volume == null) {
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

        if (volume.get_name () == added_volume.get_name () &&
            (mount == null || (mount.get_name () == added_mount.get_name ()))) {
            mount = added_mount;
            mounted = true;
        }
        working = false;
    }

    protected override void add_extra_menu_items (PopupMenuBuilder menu_builder) {
        if (mount != null && mounted) {
            if (Marlin.FileOperations.has_trash_files (mount)) {
                menu_builder
                    .add_separator ()
                    .add_empty_mount_trash (() => {
                        Marlin.FileOperations.empty_trash_for_mount (this, mount);
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
            Marlin.FileOperations.mount_volume_full.begin (volume, null, (obj, res) => {
                try {
                    mounted = Marlin.FileOperations.mount_volume_full.end (res);
                } catch (Error e) {
                    mounted = false;
                    mount = null;
                } finally {
                    working = false;
                }

                if (mounted) {
                    new Marlin.View.VolumePropertiesWindow (
                        volume.get_mount (),
                        Marlin.get_active_window ()
                    );
                }
            });
        } else if ((mount != null && mounted) || uri == Marlin.ROOT_FS_URI) {
            new Marlin.View.VolumePropertiesWindow (
                mount,
                Marlin.get_active_window ()
            );
        }
    }

    private async bool get_filesystem_space (Cancellable? update_cancellable) {
        storage_capacity = 0;
        storage_free = 0;

        if (mount == null && !permanent) {
            return false;
        }

        File root;
        string scheme = Uri.parse_scheme (uri);
        if ("sftp davs".contains (scheme)) {
            return false; /* Cannot get info from these protocols */
        }

        if ("smb afp".contains (scheme)) {
            /* Check network is functional */
            var net_mon = GLib.NetworkMonitor.get_default ();
            if (!net_mon.get_network_available ()) {
                return false;
            }
        }

        if (mount != null) {
            root = mount.get_root ();
        } else {
            root = File.new_for_uri (scheme + ":///"); //Is this always "file:///" if no mount?
        }

        GLib.FileInfo info;
        try {
            info = yield root.query_filesystem_info_async ("filesystem::*", 0, update_cancellable);
        }
        catch (GLib.Error error) {
            if (!(error is IOError.CANCELLED)) {
                warning ("Error querying %s filesystem info: %s", root.get_uri (), error.message);
            }

            info = null;
        }

        if (update_cancellable.is_cancelled () || info == null) {
            return false;
        } else {
            if (info.has_attribute (FileAttribute.FILESYSTEM_SIZE)) {
                storage_capacity = (double)(info.get_attribute_uint64 (FileAttribute.FILESYSTEM_SIZE));
            }
            if (info.has_attribute (FileAttribute.FILESYSTEM_FREE)) {
                storage_free = (double)(info.get_attribute_uint64 (FileAttribute.FILESYSTEM_FREE));
            }

            return true;
        }
    }

    private async void add_device_tooltip () {
        if (yield get_filesystem_space (null)) {
            storage.@value = (storage_capacity - storage_free) / storage_capacity;
            storage.show ();
        } else {
            storage_text = "";
            storage.hide ();
        }

        if (storage_capacity > 0) {
            var used_string = _("%s free").printf (format_size ((uint64)storage_free));
            var size_string = _("%s used of %s").printf (
                format_size ((uint64)(storage_capacity - storage_free)),
                format_size ((uint64)storage_capacity)
            );

            storage_text = "\n%s\n<span weight=\"600\" size=\"smaller\" alpha=\"75%\">%s</span>"
                .printf (used_string, size_string);
        } else {
            storage_text = "";
        }

        set_tooltip_markup (PF.FileUtils.sanitize_path (uri, null, false) + storage_text);
    }
}
