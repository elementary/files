/*-
 * Copyright (c) 2021 elementary, Inc. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

namespace Portal {
    const string DBUS_DESKTOP_PATH = "/org/freedesktop/portal/desktop";
    const string DBUS_DESKTOP_NAME = "org.freedesktop.portal.Desktop";
    Email? email = null;

    public static string generate_token () {
        return "%s_%i".printf (
            GLib.Application.get_default ().application_id.replace (".", "_"),
            Random.int_range (0, int32.MAX)
        );
    }

    [DBus (name = "org.freedesktop.portal.Email")]
    interface Email : DBusProxy {
        [DBus (name = "version")]
        public abstract uint version { get; }

        public static Email @get () throws IOError, DBusError {
            if (email == null) {
                var connection = GLib.Application.get_default ().get_dbus_connection ();
                email = connection.get_proxy_sync<Email> (DBUS_DESKTOP_NAME, DBUS_DESKTOP_PATH);
            }

            return email;
        }

        [DBus (visible = false)]
        public ObjectPath compose_email (string window_handle, HashTable<string, Variant> options, UnixFDList? attachments) throws Error {
            var options_builder = new VariantBuilder (VariantType.VARDICT);
            options.foreach ((key, val) => {
                options_builder.add ("{sv}", key, val);
            });

            var response = call_with_unix_fd_list_sync (
                "ComposeEmail",
                new Variant ("(sa{sv})", window_handle, options_builder),
                DBusCallFlags.NONE,
                -1,
                attachments
            );

            return (ObjectPath) response.get_child_value (0).get_string ();
        }
    }
}
