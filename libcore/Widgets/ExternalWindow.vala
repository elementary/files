/*-
 * Copyright 2021 elementary LLC <https://elementary.io>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
 * Boston, MA 02110-1335 USA.
 *
 * Authored by: David Hewitt <davidmhewitt@gmail.com>
 */

public interface ExternalWindow : GLib.Object {
    public abstract void set_parent_of (Gdk.Window child_window);

    public static ExternalWindow? from_handle (string handle) {
        const string X11_PREFIX = "x11:";
        const string WAYLAND_PREFIX = "wayland:";
        ExternalWindow? external_window = null;

        if (handle.has_prefix (X11_PREFIX)) {
            try {
                external_window = new ExternalWindowX11 (handle.substring (X11_PREFIX.length));
            } catch (Error e) {
                warning ("Error getting external X11 window: %s", e.message);
                return null;
            }
        } else if (handle.has_prefix (WAYLAND_PREFIX)) {
            try {
                external_window = new ExternalWindowWayland (handle.substring (WAYLAND_PREFIX.length));
            } catch (Error e) {
                warning ("Error getting external Wayland window: %s", e.message);
                return null;
            }
        } else {
            warning ("Unhandled parent window type %s", handle);
        }

        return external_window;
    }
}

public class ExternalWindowX11 : ExternalWindow, GLib.Object {
    private static Gdk.Display? x11_display = null;

    private Gdk.Window foreign_gdk_window;

    public ExternalWindowX11 (string handle) throws GLib.IOError {
        var display = get_x11_display ();
        if (display == null) {
            throw new IOError.FAILED ("No X display connection, ignoring X11 parent");
        }

        int xid;
        if (!int.try_parse (handle, out xid, null, 16)) {
            throw new IOError.FAILED ("Failed to reference external X11 window, invalid XID %s", handle);
        }

        foreign_gdk_window = new Gdk.X11.Window.foreign_for_display ((Gdk.X11.Display)display, xid);
        if (foreign_gdk_window == null) {
            throw new IOError.FAILED ("Failed to create foreign window for XID %d", xid);
        }
    }

    private static Gdk.Display get_x11_display () {
        if (x11_display != null) {
            return x11_display;
        }

        Gdk.set_allowed_backends ("x11");
        x11_display = Gdk.Display.open (null);
        Gdk.set_allowed_backends (null);

        if (x11_display == null) {
            warning ("Failed to open X11 display");
        }

        return x11_display;
    }

    public void set_parent_of (Gdk.Window child_window) {
        child_window.set_transient_for (foreign_gdk_window);
    }
}

public class ExternalWindowWayland : ExternalWindow, GLib.Object {
    private static Gdk.Display? wayland_display = null;

    private string handle;

    public ExternalWindowWayland (string handle) throws GLib.IOError {
        var display = get_wayland_display ();
        if (display == null) {
            throw new IOError.FAILED ("No Wayland display connection, ignoring Wayland parent");
        }

        this.handle = handle;
    }

    private static Gdk.Display? get_wayland_display () {
        if (wayland_display != null) {
            return wayland_display;
        }

        Gdk.set_allowed_backends ("wayland");
        wayland_display = Gdk.Display.open (null);
        Gdk.set_allowed_backends (null);

        if (wayland_display == null) {
            warning ("Failed to open Wayland display");
        }

        return wayland_display;
    }

    public void set_parent_of (Gdk.Window child_window) {
        if (!((Gdk.Wayland.Window) child_window).set_transient_for_exported (handle)) {
            warning ("Failed to set portal window transient for external parent");
        }
    }
}
