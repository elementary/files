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

    public virtual bool is_mounted {
        get {
            return false;
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

        add_mountable_tooltip.begin ();

        eject_button.clicked.connect (() => {eject.begin (); });

        notify["is-mounted"].connect (() => {
            mount_eject_revealer.reveal_child = is_mounted;
        });
    }

    protected override void update_plugin_data (Files.SidebarPluginItem item) {
        base.update_plugin_data (item);
        working = item.show_spinner;
    }

    protected virtual async bool eject () { return true; }

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
                } catch (GLib.Error error) {
                    warning ("Error ejecting mount '%s': %s", mount.get_name (), error.message);
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
                } catch (GLib.Error error) {
                    warning ("Error while unmounting mount '%s': %s", mount.get_name (), error.message);
                    return false;
                } finally {
                    working = false;
                }
            }
        }

        return true;
    }

    protected void add_extra_menu_items_for_mount (Mount? mount, PopupMenuBuilder menu_builder) {
        if (is_mounted) {

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

    protected virtual void show_mount_info () {}

    protected virtual async void add_mountable_tooltip () {
        set_tooltip_markup (Files.FileUtils.sanitize_path (uri, null, false));
    }

    public virtual void update_free_space () {}
}
