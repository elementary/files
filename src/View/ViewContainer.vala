//
//  ViewContainer.vala
//
//  Authors:
//       Mathijs Henquet <mathijs.henquet@gmail.com>
//       ammonkey <am.monkeyd@gmail.com>
//
//  Copyright (c) 2010 Mathijs Henquet
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
//

namespace Marlin.View {
    public class ViewContainer : Gtk.Overlay {
        public Gtk.Widget? content_item;
        public bool content_shown = false;
        public bool can_show_folder = true;
        public Gtk.Label label;
        public Marlin.View.Window window;
        public Slot? slot = null;
        public Marlin.View.Miller? mwcol = null;
        Browser browser;
        public Marlin.ViewMode view_mode = 0;
        public OverlayBar overlay_statusbar;

        private GLib.List<GLib.File> select_childs = null;

        public signal void path_changed (GLib.File? file, int flag = 0, Slot? source_slot = null);
        public signal void up ();
        public signal void back (int n=1);
        public signal void forward (int n=1);
        public signal void tab_name_changed (string tab_name);

        public ViewContainer (Marlin.View.Window win, GLib.File location, Marlin.ViewMode viewmode) {
//message ("New ViewContainer");
            window = win;
            overlay_statusbar = new OverlayBar (win, this);
            this.view_mode = viewmode;

            /* set active tab */
            browser = new Browser ();
            label = new Gtk.Label ("Loading...");
            label.set_ellipsize (Pango.EllipsizeMode.END);
            label.set_single_line_mode (true);
            label.set_alignment (0.0f, 0.5f);
            label.set_padding (0, 0);
            window.button_back.fetcher = get_back_menu;
            window.button_forward.fetcher = get_forward_menu;

            this.show_all ();

            /* Override background color to support transparency on overlay widgets */
            Gdk.RGBA transparent = {0, 0, 0, 0};
            override_background_color (0, transparent);

            /* overlay statusbar */
            set_events (Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK);
//message ("adding overlay");
            //add_overlay (overlay_statusbar);
            overlay_statusbar.showbar = view_mode != Marlin.ViewMode.LIST;
//message ("connections");
            path_changed.connect ((location, flag, host_slot) => {
                switch ((Marlin.OpenFlag)flag) {
                    case Marlin.OpenFlag.NEW_TAB:
                        this.window.add_tab (location, view_mode);
                        return;

                    case Marlin.OpenFlag.NEW_WINDOW:
                        this.window.add_window (location, view_mode);
                        return;

                    case Marlin.OpenFlag.DEFAULT:
                        if (mwcol != null && host_slot != null) {
                            /* We have a Miller View with a host_slot*/
                            if (location != null && this.slot.directory.file.exists && this.slot.location.equal (location)) {
                                /* No change in path - just re-activate existing slot and return */
                                this.slot.active ();
                                return;
                            } else {
                                /* Nest new slot in specified host_slot */
                                /* this.slot is used to temporarily store reference to host_slot */
                                this.slot = host_slot;
                            }
                        } else
                            /* Create a new root slot */
                            mwcol = null;

                        break;

                    case Marlin.OpenFlag.NEW_ROOT:
                    default:
                        /* Create a new root slot */
                        mwcol = null;
                        break;
                }
                change_view(this.view_mode, location);
                update_location_state (true);
            });

            up.connect (() => {
                if (slot.directory.has_parent ())
                    path_changed (slot.directory.get_parent ());
            });

            back.connect ((n) => {
                path_changed (File.new_for_commandline_arg (browser.go_back (n)));
            });

            forward.connect ((n) => {
                 path_changed (File.new_for_commandline_arg (browser.go_forward (n)));
            });
//message ("changing path");
            /* handle all path changes through the path-changed signal */
            path_changed (location);
//message ("Leaving new container");
        }

        public Gtk.Widget content {
            set {
                if (content_item != null)
                    remove (content_item);
                add (value);
                content_item = value;
                content_item.show_all ();
                content_shown = true;
            }
            get {
                return content_item;
            }
        }

        public string tab_name {
            set {
                label.label = value;
                tab_name_changed (value);
            }
            get {
                return label.label;
            }
        }

        private void set_up_slot () {
            connect_available_info ();
            if (slot != null) {
                slot.directory.done_loading.connect (directory_done_loading);
                slot.directory.need_reload.connect (reload);
            }
            plugin_directory_loaded ();
        }

        private void plugin_directory_loaded () {
            Object[] data = new Object[3];
            data[0] = window;
            (mwcol != null) ? data[1] = mwcol : data[1] = slot;
            data[2] = slot.directory.file;
            plugins.directory_loaded ((void*) data);
        }

        private void connect_available_info () {
//message ("Connect available info");
            if (window.current_tab == this)
                window.loading_uri (slot.directory.file.uri);
        }

        public void refresh_slot_info (GOF.File? file) {
//message ("Refresh slot info");
            if (file == null)
                return;

//message ("Refresh slot info - no null");
            //var slot_path = aslot.directory.file.location.get_path ();
            var slot_path = file.location.get_path ();
            if (slot_path == Environment.get_home_dir ())
                tab_name = _("Home");
            else if (slot_path == "/")
                tab_name = _("File System");
            //else if (aslot.directory.file.exists && (aslot.directory.file.info is FileInfo))
            else if (file.exists && (file.info is FileInfo))
                tab_name = file.info.get_attribute_string (FileAttribute.STANDARD_DISPLAY_NAME);
            else {
                tab_name = _("This folder does not exist");
                can_show_folder = false;
            }

            if (Posix.getuid() == 0)
                tab_name = tab_name + " " + _("(as Administrator)");

            /* update window title */
//message ("Refresh slot info - update window title");
            if (window.current_tab == this) {
                window.set_title (tab_name);
                if (window.top_menu.location_bar != null)
                    //window.top_menu.location_bar.path = aslot.directory.file.location.get_parse_name ();
                    window.top_menu.location_bar.path = file.location.get_parse_name ();
            }
        }

        /* Handle nonexistent, non-directory, and unpermitted location */
        public void directory_done_loading () {
            FileInfo file_info;
            try {
                file_info = slot.location.query_info ("standard::*,access::*", FileQueryInfoFlags.NONE);

                /* If not readable, alert the user */
                if (slot.directory.permission_denied) {
                    content = new Granite.Widgets.Welcome (_("This does not belong to you."),
                                                           _("You don't have permission to view this folder."));
                    can_show_folder = false;
                }

                /* If not a directory, then change the location to the parent */
                if (file_info.get_file_type () == FileType.DIRECTORY) {
                    content_shown = false;

                    if (select_childs != null)
                        ((FM.Directory.View) slot.view_box).select_glib_files (select_childs);
                } else {
                    path_changed (slot.location.get_parent ());
                }
            } catch (Error err) {
                /* query_info will throw an expception if it cannot find the file */
                content = new DirectoryNotFound (slot.directory, this);
            }

            debug ("directory done loading");
            slot.directory.done_loading.disconnect (directory_done_loading);
        }

        private ViewMode real_mode (Marlin.ViewMode mode) {
            switch (view_mode) {
                case Marlin.ViewMode.ICON:
                case Marlin.ViewMode.LIST:
                case Marlin.ViewMode.MILLER:
                    return mode;
                case Marlin.ViewMode.PREFERRED:
                    return (Marlin.ViewMode)(Preferences.settings.get_enum ("default-viewmode"));
                default:
                    break;
            }
            return this.view_mode;
        }

        public void change_view_mode (Marlin.ViewMode mode) {
            mode = real_mode (mode);
            if (mode != view_mode)
                change_view (mode, null);
        }

        private void change_view (Marlin.ViewMode mode, GLib.File? location) {
//message ("ViewContainer: change view");
            /* if location is null then we have a user change view request */
            bool user_change_rq = location == null;
            select_childs = null;
            Slot? current_slot = get_current_slot ();
            if (current_slot != null)
                current_slot.inactive ();

            if (location == null) {
                /* we re just changing view keep the same location */
                if (current_slot == null) {
                    warning ("No active slot found - cannot change view");
                    return;
                }
                location = current_slot.location;
                /* store the old selection to restore it */
                if (slot != null && !content_shown) {
                    unowned List<GOF.File> list = ((FM.Directory.View) slot.view_box).get_selection ();
                    foreach (var elem in list)
                        select_childs.prepend (elem.location);
                }
            } else if (mode == view_mode && current_slot != null && location.equal (current_slot.location)) {
                /* check if the requested location and viewmode are unchanged */
                    return;
            } else {
                can_show_folder = true;
                /* check if the requested location is a parent of the previous one */
                if (slot != null) {
                    var parent = slot.location.get_parent ();
                    if (parent != null && parent.equal (location))
                        select_childs.prepend (slot.directory.file.location);
                }
            }

            if (slot != null && slot.directory != null && slot.directory.file.exists) {
                slot.directory.cancel ();
                if (mwcol == null)
                    slot.directory.track_longest_name = false;
            }

            if (mode == Marlin.ViewMode.MILLER) {
                if (mwcol == null) {
                    mwcol = new Marlin.View.Miller (location, this);
                } else {
                    /* Create new slot in existing mwcol
                     * this.slot is the host_slot, newly created slot becomes active and assigned to this.slot.*/
                    assert (slot != null);
//message ("ViewContainer: mwcol add location %s to host %s", location.get_uri (), slot.location.get_uri ());
                    mwcol.add_location (location, slot);
                    slot = mwcol.current_slot;
                    ((FM.Directory.View) slot.view_box).select_first_for_empty_selection ();

                    if (slot != null) {
                        set_up_slot ();
                    } else
                        critical ("marlin window column view has no active slot");

                    return;
                }
            } else {
                mwcol = null;
                slot = new Slot (location, this);
            }

            switch (mode) {
            case Marlin.ViewMode.LIST:
                content = slot.make_list_view ();
                break;
            case Marlin.ViewMode.MILLER:
                content = mwcol.make_view ();
                slot = mwcol.current_slot;
                break;
            default:
                content = slot.make_icon_view ();
                break;
            }

            /* automagicly enable icon view for icons keypath */
            if (!user_change_rq && slot.directory.uri_contain_keypath_icons)
                mode = 0; /* icon view */

            /* Setting up view_mode and its button */
            view_mode = mode;
            if (window.top_menu.view_switcher != null)
                window.top_menu.view_switcher.mode = view_mode;

            set_up_slot ();
            slot.active ();

            overlay_statusbar.showbar = mode != ViewMode.LIST;
        }

        public Slot? get_current_slot () {
            if (mwcol != null)
                return mwcol.current_slot;
            else
                return slot;
        }

        public string? get_root_uri () {
            if (mwcol != null)
                return mwcol.get_root_uri ();
            else
                return slot.location.get_uri ();
        }

        public string? get_tip_uri () {
            if (mwcol != null)
                return mwcol.get_tip_uri ();
            else
                return "";
        }

        public void reload () {
            GOF.Directory.Async dir = slot.directory;
            dir.cancel ();
            dir.need_reload.disconnect (reload);
            dir.remove_dir_from_cache ();
            /* emitting path_changed signal with null location, results in current location being reloaded with the current viewmode setting. */
            path_changed (null);
        }

        public void update_location_state (bool save_history) {
//message ("Update location state");
            if (!slot.directory.file.exists)
                return;

            if (save_history)
                browser.record_uri (slot.directory.location.get_parse_name ());

            window.can_go_up = slot.directory.has_parent ();
            window.can_go_back = browser.can_go_back ();
            window.can_go_forward = browser.can_go_forward ();
            /* update ModeButton */
            if (window.top_menu.view_switcher != null)
                window.top_menu.view_switcher.mode = view_mode;
        }

        public Gtk.Menu get_back_menu () {
            /* Clear the back menu and re-add the correct entries. */
            var back_menu = new Gtk.Menu ();
            var list = browser.go_back_list ();
            var n = 1;
            foreach (var path in list) {
                int cn = n++; // No i'm not mad, thats just how closures work in vala (and other langs).
                              // You see if I would just use back(n) the reference to n would be passed
                              // in the clusure, restulting in a value of n which would always be n=1. So
                              // by introducting a new variable I can bypass this anoyance.
                var item = new Gtk.MenuItem.with_label (GLib.Uri.unescape_string (path));
                item.activate.connect (() => { back(cn); });
                back_menu.insert (item, -1);
            }

            back_menu.show_all ();
            return back_menu;
        }

        public Gtk.Menu get_forward_menu () {
            /* Same for the forward menu */
            var forward_menu = new Gtk.Menu ();
            var list = browser.go_forward_list ();
            var n = 1;
            foreach (var path in list) {
                int cn = n++; // For explanation look up
                var item = new Gtk.MenuItem.with_label (GLib.Uri.unescape_string (path));
                item.activate.connect (() => forward (cn));
                forward_menu.insert (item, -1);
            }

            forward_menu.show_all ();
            return forward_menu;
        }

        public new Gtk.Widget get_window ()
        {
            return ((Gtk.Widget) window);
        }
    }
}
