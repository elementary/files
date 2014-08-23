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

using Marlin;

namespace Marlin.View {
    public class ViewContainer : Gtk.Overlay {
        public Gtk.Widget? content_item;
        //public bool content_shown = false;
        public bool can_show_folder = true;
        public string label;
        public Marlin.View.Window window;
        public GOF.AbstractSlot? view = null;
        Browser browser;
        public Marlin.ViewMode view_mode = Marlin.ViewMode.INVALID;
        public GLib.File location {
            get {
                return get_current_slot ().location;
            }
        }
        public string uri {
            get {
                return get_current_slot ().uri;
            }
        }
        public OverlayBar overlay_statusbar;

        private GLib.List<GLib.File> select_childs = null;
        private ulong directory_done_loading_handler_id = 0;
        private ulong reload_handler_id = 0;

        /* The path_changed signal is listened to by Slot, Miller as well as ViewContainer */
        /* The path_changed signal is emitted by :
         * Window (go to actions)
         * LocationBar (context menu - directory itens)
         * TopMenu, ViewContainer, DirectoryView Sidebar*/
        /* LocationBar has a different signal named "path_changed" */

       // public signal void path_changed (GLib.File? file, int flag = 0, Slot? source_slot = null);

        public signal void up ();
        public signal void back (int n=1);
        public signal void forward (int n=1);
        public signal void tab_name_changed (string tab_name);
        public signal void loading (bool is_loading);

        /* Initial location now set by Window.make_tab after connecting signals */
        public ViewContainer (Marlin.View.Window win, Marlin.ViewMode mode, GLib.File loc) {
//message ("New ViewContainer");
            window = win;
            overlay_statusbar = new OverlayBar (win, this);
            //this.view_mode = viewmode;
            browser = new Browser ();
            label = _("Loading…");

            this.show_all ();

            /* Override background color to support transparency on overlay widgets */
            Gdk.RGBA transparent = {0, 0, 0, 0};
            override_background_color (0, transparent);

            /* overlay statusbar */
            set_events (Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK);
            /* The overlay is already added in the constructor of the statusbar */
            overlay_statusbar.showbar = view_mode != Marlin.ViewMode.LIST;

            connect_signals ();
            change_view_mode (mode, loc);
//message ("New ViewContainer leaving");
        }

        public Gtk.Widget content {
            set {
                if (content_item != null)
                    remove (content_item);
                add (value);
                content_item = value;
                content_item.show_all ();
                //content_shown = true;
            }
            get {
                return content_item;
            }
        }

        public string tab_name {
            set {
                label = value;
                tab_name_changed (value);
            }
            get {
                return label;
            }
        }

        private void connect_signals () {
            up.connect (() => {
                if (view.directory.has_parent ())
                    user_path_change_request (view.directory.get_parent ());
            });

            back.connect ((n) => {
                string? loc = browser.go_back (n);
                if (loc != null)
                    user_path_change_request (File.new_for_commandline_arg (loc));
            });

            forward.connect ((n) => {
                string? loc = browser.go_forward (n);
                if (loc != null)
                    user_path_change_request (File.new_for_commandline_arg (loc));
            });
        }

        public void change_view_mode (Marlin.ViewMode mode, GLib.File? loc = null) {
message ("change view mode.  Mode is %i,  View mode is %i", (int)mode, (int)view_mode);
            if (mode != view_mode) {

                if (loc == null) { /* Only untrue on container creation */
                    loc = this.location;
                }

                if (view != null) {
                    store_selection ();
                    view.destroy ();
                }

                if (mode == Marlin.ViewMode.MILLER_COLUMNS)
                    view = new Miller (loc, this, mode);
                else
                    view = new Slot (loc, this, mode);

                set_up_current_slot ();
                update_view (mode);
                restore_selection ();
            }
        }

        public void user_path_change_request (GLib.File loc) {
message ("VC user path changed request");
            view.user_path_change_request (loc);
        }

        public void new_container_request (GLib.File loc, int flag = 1) {
message ("VC new container request");
            switch ((Marlin.OpenFlag)flag) {
                case Marlin.OpenFlag.NEW_TAB:
                    this.window.add_tab (loc, view_mode);
                    break;

                case Marlin.OpenFlag.NEW_WINDOW:
                    this.window.add_window (loc, view_mode);
                    break;

                default:
                    assert_not_reached ();
            }
        }

        public void slot_path_changed (GLib.File loc) {
message ("VC path changed");
#if 0
            /* automagicly enable icon view for icons keypath */
            if (!user_change_rq && slot.directory.uri_contain_keypath_icons)
                mode = 0; /* icon view */
#endif

            set_up_current_slot ();
            browser.record_uri (loc.get_parse_name ()); /* will ignore null changes */

        }

        private void set_up_current_slot () {
message ("set up current slot");
            var slot = get_current_slot ();
            assert (slot != null);
            assert (slot.directory != null);

            content = view.get_content_box ();
            can_show_folder = true;

            directory_done_loading_handler_id = slot.directory.done_loading.connect (() => {
                directory_done_loading (slot);
            });

            reload_handler_id = slot.directory.need_reload.connect (() => {
                reload_slot (slot);
            });

            plugin_directory_loaded ();
        }

        private void plugin_directory_loaded () {
//message ("plugin directory loaded");
            var slot = get_current_slot ();
            Object[] data = new Object[3];
            data[0] = window;
            data[1] = slot;
            data[2] = slot.directory.file;

            //plugins.directory_loaded ((void*) data);
        }

        public void refresh_slot_info (GLib.File loc) {
message ("refresh slot info");
            loading (false);
            var slot_path = loc.get_path ();

            if (slot_path == Environment.get_home_dir ())
                tab_name = _("Home");
            else if (slot_path == "/")
                tab_name = _("File System");
            else
                tab_name = loc.get_basename ();
                // TODO can_show_folder setting required ?

            if (Posix.getuid() == 0)
                tab_name = tab_name + " " + _("(as Administrator)");

            window.loading_uri (loc.get_uri ());
            window.update_top_menu ();
            window.update_labels (loc.get_parse_name (), tab_name);
        }

        /* Handle nonexistent, non-directory, and unpermitted location */
        public void directory_done_loading (GOF.AbstractSlot slot) {
message ("directory done loading");
            FileInfo file_info;

            try {
                file_info = slot.location.query_info ("standard::*,access::*", FileQueryInfoFlags.NONE);

                /* If not readable, alert the user */
                if (slot.directory.permission_denied) {
                    content = new Granite.Widgets.Welcome (_("This does not belong to you."),
                                                           _("You don't have permission to view this folder."));
                    can_show_folder = false;
                }


                if (file_info.get_file_type () == FileType.DIRECTORY) {
//message ("loaded directory");
                    //content_shown = false;  ????
                    if (select_childs != null) {
//message ("THere are selected childs");
                        slot.select_glib_files (select_childs);
                    }
                } else {
                    /* If not a directory, then change the location to the parent */
                    user_path_change_request (slot.location.get_parent ());
                }
            } catch (Error err) {
                /* query_info will throw an expception if it cannot find the file */
                if (err is IOError.NOT_MOUNTED) {
                    reload ();
                } else {
                    content = new DirectoryNotFound (slot.directory, this);
                }
            }

            warning ("directory done loading");
            //slot.directory.done_loading.disconnect (directory_done_loading);
            slot.directory.disconnect (directory_done_loading_handler_id);
        }

        private void store_selection () {}
        private void restore_selection () {}

        private void update_view (Marlin.ViewMode mode) {
            overlay_statusbar.showbar = mode != Marlin.ViewMode.LIST;
            view_mode = mode;
        }

        public GOF.AbstractSlot get_current_slot () {
//message ("VC get current slot");
            var slot = view.get_current_slot ();
            assert (slot != null);
           return slot;
        }

        public void set_active_state (bool is_active) {
            get_current_slot ().set_active_state (is_active);
        }
#if 0
        public void change_view (int nview, GLib.File? location, GLib.File? focus_file = null) {
            /* if location is null then we have a user change view request */
            bool user_change_rq = location == null;
            select_childs = null;

            if (location == null) {
                /* we re just changing view keep the same location */
                GOF.Window.Slot? active_slot = get_active_slot ();
                if (active_slot == null) {
                    warning ("No active slot found - cannot change view");
                    return;
                }
                location = active_slot.location;
                /* store the old selection to restore it */
                if (slot != null && !content_shown) {
                    unowned List<GOF.File> list = ((FM.Directory.View) slot.view_box).get_selection ();
                    foreach (var elem in list)
                        select_childs.prepend (elem.location);
                }
            } else {
                can_show_folder = true;
                /* check if the requested location is a parent of the previous one */
                if (slot != null) {
                    var parent = slot.location.get_parent ();
                    if (parent != null && parent.equal (location))
                        select_childs.prepend (slot.directory.file.location);
                }
            }

            if (focus_file != null)
                select_childs.prepend (focus_file);

            Marlin.Window.Columns new_mwcol;
            GOF.Window.Slot new_slot;

            if (nview == ViewMode.MILLER) {
                new_mwcol = new Marlin.Window.Columns (location, this);
                new_slot = new_mwcol.active_slot;
            } else {
                new_mwcol = null;
                new_slot = new GOF.Window.Slot (location, this);
            }

            /* automagicly enable icon view for icons keypath */
            if (!user_change_rq && new_slot.directory.uri_contain_keypath_icons)
                nview = 0; /* icon view */

            /* Mount the directory if it's not mounted */
            if (!new_slot.directory.file.is_mounted) {
                tab_name = _("Connecting…");
                loading (true);
                
                new_slot.directory.mount_mountable.begin ((obj,res) => {
                    try {
                        new_slot.directory.mount_mountable.end (res);
                        make_view (nview, new_mwcol, new_slot);
                    } catch (Error e) {
                        warning ("mount_mountable failed: %s", e.message);

                        if (get_active_slot () == null) {
                            /* There's no previous slot to refresh */
                            File home = File.new_for_path (Environment.get_home_dir ());
                            change_view (nview, home);
                        } else {
                            /* Reset the tab label */
                            refresh_slot_info ();
                        }
                    }
                });
            } else {
                make_view (nview, new_mwcol, new_slot);
            }
        }

        private void make_view (int nview, Marlin.Window.Columns? new_mwcol, GOF.Window.Slot new_slot) {
            if (slot != null && slot.directory != null && slot.directory.file.exists) {
                slot.directory.cancel ();
                slot.directory.track_longest_name = false;
            }

            slot = new_slot;
            mwcol = new_mwcol;

            /* Setting up view_mode and its button */
            view_mode = nview;
            if (window.top_menu.view_switcher != null)
                window.top_menu.view_switcher.mode = (ViewMode) view_mode;

            connect_available_info ();
            if (slot != null) {
                slot.directory.done_loading.connect (directory_done_loading);
                slot.directory.need_reload.connect (reload);
            }
            plugin_directory_loaded ();

            switch (nview) {
            case ViewMode.LIST:
                slot.make_list_view ();
                break;
            case ViewMode.MILLER:
                mwcol.make_view ();
                break;
            default:
                slot.make_icon_view ();
                break;
            }

            overlay_statusbar.showbar = nview != ViewMode.LIST;
        }
#endif
        public void focus_file (File file) {
            File? loc = null;
            if (file.query_file_type (0) == FileType.DIRECTORY) {
                if (location.equal (file))
                    return;

                //change_view (view_mode, file);
                loc = file;
                user_path_change_request (loc);
            } else {
                if (location.equal (file.get_parent ())) {
                    var list = new List<File> ();
                    list.prepend (file);
                    get_current_slot ().select_glib_files (list);
                } else
                    //change_view (view_mode, file.get_parent (), file);
                    loc = file.get_parent ();
                    user_path_change_request (loc);
                    //TODO implement request focus file on path change
            }

            //update_location_state (true);
            if (loc != null) {
                slot_path_changed (loc);
                refresh_slot_info (loc);
            }
        }
#if 0
        public GOF.Window.Slot? get_active_slot () {
            if (mwcol != null)
                return mwcol.active_slot;
            else
                return slot;
        }
#endif
        public string? get_root_uri () {
            return view.get_root_uri ();
        }

        public string? get_tip_uri () {
            return view.get_tip_uri ();
        }

        public void reload () {
            reload_slot (view.get_current_slot ());
        }

        private void reload_slot (GOF.AbstractSlot slot) {
//message ("reload");
//            GOF.Directory.Async dir = slot.directory;
//            dir.cancel ();
//            dir.disconnect (reload_handler_id);
//            dir.remove_dir_from_cache ();
            slot.reload ();
        }


        public Gee.List<string> get_go_back_path_list () {
            return browser.go_back_list ();
        }

        public Gee.List<string> get_go_forward_path_list () {
            return browser.go_forward_list ();
        }

        public new void grab_focus () {
            content.grab_focus ();
        }

//        public new Gtk.Widget get_window () {
//            return ((Gtk.Widget) window);
//        }
    }
}
