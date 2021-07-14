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
    private double storage_capacity = 0;
    private double storage_free = 0;

    protected static Gtk.CssProvider devicerow_provider;
    protected static VolumeMonitor volume_monitor;

    private Gtk.Stack mount_eject_stack;
    private Gtk.Revealer mount_eject_revealer;
    private Gtk.Spinner mount_eject_spinner;
    private Gtk.Button eject_button;
    private Gtk.LevelBar storage_levelbar;

    public Mount? mount { get; construct; }

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

        storage_levelbar = new Gtk.LevelBar () {
            value = 0.5,
            hexpand = true,
            no_show_all = true
        };
        storage_levelbar.add_offset_value (Gtk.LEVEL_BAR_OFFSET_LOW, 0.9);
        storage_levelbar.add_offset_value (Gtk.LEVEL_BAR_OFFSET_HIGH, 0.95);
        storage_levelbar.add_offset_value (Gtk.LEVEL_BAR_OFFSET_FULL, 1);

        unowned var storage_style_context = storage_levelbar.get_style_context ();
        storage_style_context.add_class (Gtk.STYLE_CLASS_FLAT);
        storage_style_context.add_class ("inverted");
        storage_style_context.add_provider (devicerow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        icon_label_grid.attach (storage_levelbar, 1, 1);

        volume_monitor.mount_removed.connect (on_mount_removed);
        volume_monitor.mount_added.connect (on_mount_added);
        eject_button.clicked.connect (() => {eject.begin (); });

        show_all ();

        add_mountable_tooltip.begin ();

        update_visibilities ();
    }

    protected void update_visibilities () {
        mount_eject_revealer.reveal_child = can_unmount;
        storage_levelbar.visible = is_mounted;
    }

    protected override void update_plugin_data (Files.SidebarPluginItem item) {
        base.update_plugin_data (item);
        working = item.show_spinner;
    }

    protected async bool eject_mount (Mount mount) {
        if (working || !valid) {
            return false;
        }

        var mount_op = new Gtk.MountOperation (Files.get_active_window ());
        if (!permanent) {
            if (mount.can_eject ()) {
                working = true;
                try {
                    yield mount.eject_with_operation (
                            GLib.MountUnmountFlags.NONE,
                            mount_op,
                            null
                    );
                    return true;
                } catch (GLib.Error e) {
                    PF.Dialogs.show_error_dialog (_("Unable to eject '%s'").printf (mount.get_name ()),
                                                  e.message,
                                                  null);
                    return false;
                } finally {
                    working = false;
                }
            } else if (mount.can_unmount ()) {
                working = true;
                try {
                    yield mount.unmount_with_operation (
                            GLib.MountUnmountFlags.NONE,
                            mount_op,
                            null
                    );
                    return true;
                } catch (GLib.Error e) {
                    PF.Dialogs.show_error_dialog (_("Unable to unmount '%s'").printf (mount.get_name ()),
                                                  e.message,
                                                  null);
                    return false;
                } finally {
                    working = false;
                }
            }
        }

        return true;
    }

    protected void add_extra_menu_items_for_mount (Mount? mount, PopupMenuBuilder menu_builder) {
        if (mount != null) {
            if (Files.FileOperations.has_trash_files (mount)) {
                menu_builder
                    .add_separator ()
                    .add_empty_mount_trash (() => {
                        Files.FileOperations.empty_trash_for_mount (this, mount);
                    })
                ;
            }

            if (mount.can_unmount ()) {
                menu_builder.add_unmount (() => {eject.begin ();});
            } else if (mount.can_eject ()) {
                menu_builder.add_eject (() => {eject.begin ();});
            }
        }

        menu_builder
            .add_separator ()
            .add_drive_property (() => {show_mount_info ();}); // This will mount if necessary
    }

    protected virtual void on_mount_removed (Mount removed_mount) {}
    protected virtual void on_mount_added (Mount added_mount) {}
    protected virtual async bool eject () { return true; }
    protected virtual void show_mount_info () {}
    protected virtual async bool get_filesystem_space (Cancellable? update_cancellable) {
        return false;
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

    protected virtual async void add_mountable_tooltip () {
        if (pinned && permanent) {
            return; // A tooltip was added after construction
        }
        string storage_text = yield get_storage_text ();
        string mount_text;
        if (uri != "") {
            mount_text = Files.FileUtils.sanitize_path (uri, null, false);
        } else {
            mount_text = _("%s (%s)").printf (custom_name, _("Not mounted"));
        }

        set_tooltip_markup (mount_text + storage_text);
    }

    public virtual void update_free_space () {
        add_mountable_tooltip.begin ();
    }
}
