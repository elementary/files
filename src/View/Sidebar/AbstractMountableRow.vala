/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later

 * Authored by: Jeremy Wootten <jeremy@elementaryos.org>
*/

// Used to determine first level sort order.
public enum MountableType {
    VOLUMELESS_MOUNT,
    VOLUME,
    EMPTY_DRIVE
}

public abstract class Sidebar.AbstractMountableRow : Sidebar.BookmarkRow, SidebarItemInterface {
    private double storage_capacity = 0;
    private double storage_free = 0;
    public string sort_key { get; set construct; default = "";} // Higher index -> further down list

    protected static VolumeMonitor volume_monitor;

    private Gtk.Stack unmount_eject_working_stack;
    private Gtk.Revealer unmount_eject_revealer;
    private Gtk.Spinner working_spinner;
    private Gtk.Button unmount_eject_button;
    private Gtk.LevelBar storage_levelbar;

    public Mount? mount { get; set construct; default = null; }
    public Drive? drive { get; construct; default = null; }

    protected bool valid = true;
    public string? uuid { get; set construct; }

    public virtual bool is_mounted {
        get {
            return mount != null;
        }
    }

    public virtual bool can_unmount {
        get {
            return is_mounted && mount.can_unmount ();
        }
    }

    public virtual bool can_eject {
        get {
            return is_mounted && mount.can_eject ();
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
                working_spinner.start ();
                unmount_eject_working_stack.visible_child = working_spinner;
            } else {
                unmount_eject_working_stack.visible_child = unmount_eject_revealer;
                working_spinner.stop ();
            }
        }
    }

    protected AbstractMountableRow (string name, string uri, Icon gicon, SidebarListInterface list,
                         bool pinned, bool permanent,
                         string? _uuid) {
        Object (
            custom_name: name,
            uri: uri,
            gicon: gicon,
            list: list,
            pinned: pinned,
            permanent: permanent,
            uuid: _uuid
        );
    }

    static construct {
        volume_monitor = VolumeMonitor.@get ();
    }

    construct {
        unmount_eject_button = new Gtk.Button () {
            icon_name = "media-eject-symbolic",
            tooltip_text = (can_eject ? _("Eject '%s'") : _("Unmount '%s'")).printf (custom_name)
        };

        working_spinner = new Gtk.Spinner ();

        unmount_eject_revealer = new Gtk.Revealer () {
            transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT,
            valign = Gtk.Align.CENTER,
            reveal_child = false
        };

        unmount_eject_revealer.set_child (unmount_eject_button);

        unmount_eject_working_stack = new Gtk.Stack () {
            margin_start = 6,
            transition_type = Gtk.StackTransitionType.CROSSFADE
        };

        unmount_eject_working_stack.add_child (unmount_eject_revealer);
        unmount_eject_working_stack.add_child (working_spinner);

        content_grid.attach (unmount_eject_working_stack, 1, 0);

        storage_levelbar = new Gtk.LevelBar () {
            value = 0.5,
            hexpand = true,
            margin_top = 3
        };
        storage_levelbar.add_offset_value (Gtk.LEVEL_BAR_OFFSET_LOW, Files.DISK_OFFSET_LOW);
        storage_levelbar.add_offset_value (Gtk.LEVEL_BAR_OFFSET_HIGH, Files.DISK_OFFSET_HIGH);
        storage_levelbar.add_offset_value (Gtk.LEVEL_BAR_OFFSET_FULL, Files.DISK_OFFSET_FULL);

        unowned var storage_style_context = storage_levelbar.get_style_context ();
        storage_style_context.add_class ("flat");
        storage_style_context.add_class ("inverted");

        content_grid.attach (storage_levelbar, 0, 1, 2, 1);

        volume_monitor.mount_removed.connect (on_mount_removed);
        volume_monitor.mount_added.connect (on_mount_added);
        unmount_eject_button.clicked.connect (() => {
            if (can_eject) {
                eject_mount.begin ();
            } else {
                unmount_mount.begin ();
            }
        });

        add_mountable_tooltip.begin ();

        update_visibilities ();
    }

    protected void update_visibilities () {
        unmount_eject_button.tooltip_text =
            (can_eject ? _("Eject '%s'") : _("Unmount '%s'")).printf (custom_name);
        unmount_eject_revealer.reveal_child = can_unmount;
        storage_levelbar.visible = is_mounted;
    }

    protected override void update_plugin_data (Files.SidebarPluginItem item) {
        base.update_plugin_data (item);
        working = item.show_spinner;
    }

    public async bool unmount_mount () {
        if (working || !valid || permanent) {
            return false;
        }

        working = true;
        var success = yield Files.FileOperations.unmount_mount (mount, Files.get_active_window ());
        working = false;
        update_visibilities ();
        return success;
    }

    protected async bool eject_mount () {
        if (working || !valid || permanent) {
            return false;
        }

        working = true;
        var success = yield Files.FileOperations.eject_mount (mount, Files.get_active_window ());
        working = false;
        update_visibilities ();
        return success;
    }

    public async void safely_remove_drive () {
        if (working || !valid || drive == null) {
            return;
        }

        debug ("Eject/stop drive %s: can_eject %s, can_stop %s, can start %s, can start degraded %s, media_removable %s, drive removable %s",
        drive.get_name (), drive.can_eject ().to_string (), drive.can_stop ().to_string (), drive.can_start ().to_string (),
        drive.can_start_degraded ().to_string (), drive.is_media_removable ().to_string (), drive.is_removable ().to_string ());

        working = true;
        yield Files.FileOperations.safely_remove_drive (drive, Files.get_active_window ());
        working = false;
        update_visibilities ();
    }

    public async void eject_drive () {
        if (working || !valid || drive == null) {
            return;
        }
        working = true;
        yield Files.FileOperations.eject_drive (drive, Files.get_active_window ());
        working = false;
        update_visibilities ();
    }

    protected void add_extra_menu_items_for_mount (Mount? mount, PopupMenuBuilder menu_builder) {
        // Do not add items for a volume that is in the middle of being mounted or unmounted
        if (working) {
            return;
        }

        if (mount != null) {
            if (Files.FileOperations.has_trash_files (mount)) {
                // menu_builder
                //     .add_separator ()
                //     .add_empty_mount_trash (() => {
                //         Files.FileOperations.empty_trash_for_mount (this, mount);
                //     })
                ;
            }

            if (mount.can_unmount ()) {
                menu_builder.add_unmount (Action.print_detailed_name (
                    "device.unmount", new Variant.uint32 (id))
                ); // This will moun
            }
        }

        menu_builder
            .add_separator ()
            .add_properties (Action.print_detailed_name (
                "device.properties", new Variant.uint32 (id))
            ); // This will mount if necessary
    }

    protected async bool get_filesystem_space_for_root (File root, Cancellable? update_cancellable) {
        storage_capacity = 0;
        storage_free = 0;

        string scheme = Uri.parse_scheme (uri);
        if (scheme == null || "sftp davs".contains (scheme)) {
            return false; /* Cannot get info from these protocols */
        }

        if ("smb afp".contains (scheme)) {
            /* Check network is functional */
            var net_mon = GLib.NetworkMonitor.get_default ();
            if (!net_mon.get_network_available ()) {
                return false;
            }
        }

        GLib.FileInfo info;
        try {
            info = yield root.query_filesystem_info_async ("filesystem::*", 0, update_cancellable);
        }
        catch (GLib.Error error) {
            if (!(error is IOError.CANCELLED)) {
                warning ("Error querying filesystem info for '%s': %s", root.get_uri (), error.message);
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

    protected async string get_storage_text () {
        string storage_text = "";
        storage_capacity = 0;

        if (yield get_filesystem_space (null)) {
            if (storage_capacity > 0) {
                var used_string = _("%s free").printf (format_size ((uint64)storage_free));
                var size_string = _("%s used of %s").printf (
                    format_size ((uint64)(storage_capacity - storage_free)),
                    format_size ((uint64)storage_capacity)
                );

                storage_text = "\n%s\n<span weight=\"600\" size=\"smaller\" alpha=\"75%\">%s</span>"
                    .printf (used_string, size_string);

                storage_levelbar.@value = (storage_capacity - storage_free) / storage_capacity;
                storage_levelbar.show ();
            }
        }

        if (storage_capacity == 0) {
            storage_levelbar.hide ();
        }

        return storage_text;
    }

    public virtual void update_free_space () {
        add_mountable_tooltip.begin ();
    }

    protected virtual async void add_mountable_tooltip () {
        string storage_text = yield get_storage_text ();
        string mount_text;
        if (uri != "") {
            mount_text = Files.FileUtils.sanitize_path (uri, null, false);
        } else {
            mount_text = _("%s (%s)").printf (custom_name, _("Not mounted"));
        }

        set_tooltip_markup (mount_text + storage_text);
    }

    protected virtual void on_mount_removed (Mount removed_mount) {}
    protected virtual void on_mount_added (Mount added_mount) {}
    public virtual void show_mount_info () {}
    protected virtual async bool get_filesystem_space (Cancellable? update_cancellable) {
        return false;
    }
}
