/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2026 elementary, Inc. (https://elementary.io)
 */

// Minimal interface for main app window, functions needing to be accessed by libcore
public interface Files.ViewWindowInterface : Gtk.Window {
        public signal void free_space_change ();
}
