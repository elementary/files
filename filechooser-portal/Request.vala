/*-
 * Copyright (c) 2019 elementary, Inc. (https://elementary.io)
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

enum ResponseType {
    SUCCESS = 0,
    CANCELLED,
    ENDED
}

[DBus (name = "org.freedesktop.portal.Request")]
public class Request : Object {
    [DBus (visible = false)]
    public ObjectPath handle { get; construct; }

    [DBus (visible = false)]
    public signal void closed ();

    public Request (ObjectPath handle) {
        Object (handle: handle);
    }

    public static uint hash (Request req) {
        return str_hash (req.handle);
    }

    public signal void response (uint repsonse, HashTable<string, Variant> results);
    public void close () throws Error {
        closed ();
    }
}