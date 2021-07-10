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

public abstract class Sidebar.DeviceRow : Sidebar.AbstractMountableRow {
    private double storage_capacity = 0;
    private double storage_free = 0;
    private string storage_text = "";

    public Gtk.LevelBar storage_levelbar { get; set construct; }

    protected DeviceRow (string name, string uri, Icon gicon, SidebarListInterface list,
                      bool pinned, bool permanent,
                      string? _uuid) {

        base (name, uri, gicon, list, pinned, permanent, _uuid);
    }

    construct {
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
    }

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

    protected override async void add_mountable_tooltip () {
        if (yield get_filesystem_space (null)) {
            storage_levelbar.@value = (storage_capacity - storage_free) / storage_capacity;
            storage_levelbar.show ();
        } else {
            storage_text = "";
            storage_levelbar.hide ();
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

        // set_tooltip_markup (Files.FileUtils.sanitize_path (uri, null, false) + storage_text);
    }

    public override void update_free_space () {
        add_mountable_tooltip.begin ();
    }
}
