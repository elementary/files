/* SidebarWindow.vala
 *
 * Copyright 2020–2021 elementary, Inc. <https://elementary.io>
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

public class Sidebar.SidebarWindow : Gtk.Box, Files.SidebarInterface {
    private Gtk.ScrolledWindow scrolled_window;
    private BookmarkListBox bookmark_listbox;
    private DeviceListBox device_listbox;
    private NetworkListBox network_listbox;
    private string selected_uri = "";
    private bool loading = false;
    public bool ejecting_or_unmounting = false;

    construct {
        orientation = Gtk.Orientation.VERTICAL;
        bookmark_listbox = new BookmarkListBox (this);
        device_listbox = new DeviceListBox (this);
        network_listbox = new NetworkListBox (this);

        var bookmark_expander = new SidebarExpander (_("Bookmarks")) {
            tooltip_text = _("Common places plus saved folders and files")
        };

        var bookmark_revealer = new Gtk.Revealer ();
        bookmark_revealer.set_child (bookmark_listbox);

        /// TRANSLATORS: Generic term for collection of storage devices, mount points, etc.
        var device_expander = new SidebarExpander (_("Storage")) {
            tooltip_text = _("Internal and connected storage devices")
        };

        var device_revealer = new Gtk.Revealer ();
        device_revealer.set_child (device_listbox);

        var network_expander = new SidebarExpander (_("Network")) {
            tooltip_text = _("Devices and places available via a network"),
            visible = !Files.is_admin ()
        };

        var network_revealer = new Gtk.Revealer ();
        network_revealer.set_child (network_listbox);

        var bookmarklists_grid = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            vexpand = true
        };
        bookmarklists_grid.append (bookmark_expander);
        bookmarklists_grid.append (bookmark_revealer);
        bookmarklists_grid.append (device_expander);
        bookmarklists_grid.append (device_revealer);
        bookmarklists_grid.append (network_expander);
        bookmarklists_grid.append (network_revealer);

        scrolled_window = new Gtk.ScrolledWindow () {
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };
        scrolled_window.set_child (bookmarklists_grid);

        var connect_server_button = new Gtk.Button () {
            hexpand = true,
            visible = !Files.is_admin (),
            tooltip_markup = Granite.markup_accel_tooltip ({"<Alt>C"}),
            can_focus = false
        };

        var csb_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        csb_box.append (new Gtk.Image.from_icon_name ("network-server-symbolic"));
        csb_box.append (new Gtk.Label (_("Connect Server…")));
        connect_server_button.set_child (csb_box);

        var sidebar_menu = new Menu ();
        sidebar_menu.append (_("Collapse all"), "sb.collapse-all");
        sidebar_menu.append (_("Refresh"), "sb.refresh");
        sidebar_menu.append (_("Restore Special Directories"), "sb.restore");

        var sidebar_menu_button = new Gtk.MenuButton () {
            icon_name = "view-more-symbolic",
            menu_model = sidebar_menu,
            can_focus = false
        };

        var action_bar = new Gtk.ActionBar () {
            hexpand = true,
        };

        action_bar.add_css_class ("flat");
        action_bar.pack_start (connect_server_button);
        action_bar.pack_end (sidebar_menu_button);

        orientation = Gtk.Orientation.VERTICAL;
        width_request = Files.app_settings.get_int ("minimum-sidebar-width");
        add_css_class ("sidebar");
        append (scrolled_window);
        append (action_bar);

        //Create sidebar action group
        var collapse_all_action = new SimpleAction ("collapse-all", null);
        collapse_all_action.activate.connect (() => {
            bookmark_expander.set_active (false);
            device_expander.set_active (false);
            network_expander.set_active (false);
        });
        var refresh_action = new SimpleAction ("refresh", null);
        refresh_action.activate.connect (() => {
            reload ();
        });
        var restore_action = new SimpleAction ("restore", null);
        restore_action.activate.connect (() => {
            bookmark_listbox.bookmark_list.add_special_directories (); // Ignores duplicates
            activate_action ("sb.refresh", null);
        });
        var sidebar_action_group = new SimpleActionGroup ();
        sidebar_action_group.add_action (collapse_all_action);
        sidebar_action_group.add_action (refresh_action);
        sidebar_action_group.add_action (restore_action);
        this.insert_action_group ("sb", sidebar_action_group);

        //Create common bookmark action group (insert here so available to all listboxes)
        var open_bookmark_action = new SimpleAction ("open-bookmark", new VariantType ("u"));
        open_bookmark_action.activate.connect ((param) => {
            var row = SidebarItemInterface.get_item_by_id (param.get_uint32 ());
            if (row != null) {
                row.list.open_item (row, Files.OpenFlag.DEFAULT);
            }
        });
        var open_tab_action = new SimpleAction ("open-tab", new VariantType ("u"));
        open_tab_action.activate.connect ((param) => {
            var row = SidebarItemInterface.get_item_by_id (param.get_uint32 ());
            if (row != null) {
                row.list.open_item (row, Files.OpenFlag.NEW_TAB);
            }
        });
        var open_window_action = new SimpleAction ("open-window", new VariantType ("u"));
        open_window_action.activate.connect ((param) => {
            var row = SidebarItemInterface.get_item_by_id (param.get_uint32 ());
            if (row != null) {
                row.list.open_item (row, Files.OpenFlag.NEW_WINDOW);
            }
        });
        var remove_bookmark_action = new SimpleAction ("remove-bookmark", new VariantType ("u"));
        remove_bookmark_action.activate.connect ((param) => {
            var row = SidebarItemInterface.get_item_by_id (param.get_uint32 ());
            row.list.remove_item (row, false);
        });
        var rename_bookmark_action = new SimpleAction ("rename-bookmark", new VariantType ("u"));
        rename_bookmark_action.activate.connect ((param) => {
            var row = SidebarItemInterface.get_item_by_id (param.get_uint32 ());
            row.start_renaming ();
        });
        var empty_all_trash_action = new SimpleAction ("empty-all-trash", null);
        empty_all_trash_action.activate.connect (() => {
            var job = new Files.FileOperations.EmptyTrashJob (
                (Gtk.Window)get_ancestor (typeof (Gtk.Window))
            );
            job.empty_trash.begin ();
        });
        var bookmark_action_group = new SimpleActionGroup ();
        bookmark_action_group.add_action (open_bookmark_action);
        bookmark_action_group.add_action (open_tab_action);
        bookmark_action_group.add_action (open_window_action);
        bookmark_action_group.add_action (remove_bookmark_action);
        bookmark_action_group.add_action (rename_bookmark_action);
        bookmark_action_group.add_action (empty_all_trash_action);
        insert_action_group ("bm", bookmark_action_group);

        var secondary_click_controller = new Gtk.GestureClick ();
        add_controller (secondary_click_controller);
        secondary_click_controller.set_button (Gdk.BUTTON_SECONDARY);
        secondary_click_controller.released.connect ((n_press, x, y) => {
            if (n_press == 1) {
                var widget = pick (x, y, Gtk.PickFlags.DEFAULT);
                if (widget != null) {
                    var row = widget.get_ancestor (typeof (BookmarkRow));
                    if (row != null && row is BookmarkRow) {
                        var popover = ((BookmarkRow)row).get_context_menu ();
                        if (popover != null) {
                            popover.set_parent (this);
                            popover.pointing_to = { (int)x, (int)y, 1, 1 };
                            popover.popup ();
                        }
                    }
                }
            }
        });

        // For now, only bookmark listbox can have keyboard focus and control
        //TODO Implement keyboard handling of other list boxes.
        var key_controller = new Gtk.EventControllerKey () {
            propagation_phase = Gtk.PropagationPhase.BUBBLE
        };
        add_controller (key_controller);
        key_controller.key_pressed.connect ((val, code, state) => {
            switch (val) {
                case Gdk.Key.Escape:
                case Gdk.Key.Tab:
                    if (state == 0) {
                        if (bookmark_listbox.is_renaming) {
                            // Dont want Tab to end rename
                            // But Escape does end rename
                            if (val == Gdk.Key.Escape) {
                                // Entry loses focus causes end of rename
                                focus_bookmarks ();
                            }

                            return true;
                        }
                        // If not renaming refocus view
                        activate_action ("win.focus-view", null, null);
                        return true;
                    }

                    break;
                default:
                    break;
            }

            return false;
        });

        //Bind properties, connect signals
        Files.app_settings.bind (
            "sidebar-cat-personal-expander", bookmark_expander, "active", SettingsBindFlags.DEFAULT
        );
        Files.app_settings.bind (
            "sidebar-cat-devices-expander", device_expander, "active", SettingsBindFlags.DEFAULT
        );
        Files.app_settings.bind (
            "sidebar-cat-network-expander", network_expander, "active", SettingsBindFlags.DEFAULT
        );

        bookmark_expander.bind_property ("active", bookmark_revealer, "reveal-child", GLib.BindingFlags.SYNC_CREATE);
        device_expander.bind_property ("active", device_revealer, "reveal-child", GLib.BindingFlags.SYNC_CREATE);
        network_expander.bind_property ("active", network_revealer, "reveal-child", GLib.BindingFlags.SYNC_CREATE);

        connect_server_button.clicked.connect (() => {
            connect_server_request ();
        });

        plugins.sidebar_loaded (this);
    }

    /* SidebarInterface */
    public uint32 add_plugin_item (Files.SidebarPluginItem plugin_item, Files.PlaceType category) {
        uint32 id = 0;
        switch (category) {
            case Files.PlaceType.BOOKMARKS_CATEGORY:
                id = bookmark_listbox.add_plugin_item (plugin_item);
                break;

            case Files.PlaceType.STORAGE_CATEGORY:
                id = device_listbox.add_plugin_item (plugin_item);
                break;

            case Files.PlaceType.NETWORK_CATEGORY:
                id = network_listbox.add_plugin_item (plugin_item);
                break;

            default:
                break;
        }

        return id;
    }

    public void focus_bookmarks () {
        bookmark_listbox.focus_selected_item ();
    }

    public void rename_selected_bookmark () {
        bookmark_listbox.rename_selected_item ();
    }

    public bool update_plugin_item (Files.SidebarPluginItem plugin_item, uint32 id) {
        if (id == 0) {
            return false;
        }

        SidebarItemInterface? item = SidebarItemInterface.get_item_by_id (id);
        if (item == null) {
            return false;
        }

        item.update_plugin_data (plugin_item);

        return true;
    }

    uint sync_timeout_id = 0;
    public void sync_uri (string location) {
        if (sync_timeout_id > 0) {
            Source.remove (sync_timeout_id);
        }

        selected_uri = location;
        sync_timeout_id = Timeout.add (100, () => {
            if (loading) { // Wait until bookmarks are constructed
                return Source.CONTINUE;
            }

            sync_timeout_id = 0;
            /* select_uri () will unselect other uris in each listbox */
            bookmark_listbox.select_uri (location);
            device_listbox.select_uri (location);
            network_listbox.select_uri (location);

            // activate_action ("win.focus-view", null, null);
            return Source.REMOVE;
        });
    }

    /* Throttle rate of destroying and re-adding listbox rows */
    // uint reload_timeout_id = 0;
    public void reload () {
        if (loading) {
            return;
        }

        loading = true;
        Timeout.add (100, () => {
            bookmark_listbox.refresh ();
            device_listbox.refresh ();
            network_listbox.refresh ();
            loading = false;
            // plugins.update_sidebar (this);
            sync_uri (selected_uri);
            return false;
        });
    }

    public void add_favorite_uri (string uri, string custom_name = "") {
        bookmark_listbox.add_favorite (uri, custom_name);
    }

    public bool has_favorite_uri (string uri) {
        return bookmark_listbox.has_uri (uri);
    }

    public void on_free_space_change () {
        /* We cannot be sure which devices will experience a freespace change so refresh all */
        device_listbox.refresh_info ();
    }

    private class SidebarExpander : Gtk.ToggleButton {
        public string expander_label { get; construct; }
        private static Gtk.CssProvider expander_provider;

        public SidebarExpander (string label) {
            Object (expander_label: label);
        }

        static construct {
            expander_provider = new Gtk.CssProvider ();
            expander_provider.load_from_resource ("/io/elementary/files/SidebarExpander.css");
        }

        construct {
            var title = new Gtk.Label (expander_label) {
                hexpand = true,
                xalign = 0
            };

            var arrow = new Gtk.Spinner ();

            unowned Gtk.StyleContext arrow_style_context = arrow.get_style_context ();
            arrow.add_css_class ("arrow");
            arrow.get_style_context ().add_provider (expander_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var grid = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            grid.append (title);
            grid.append (arrow);

            set_child (grid);

            // unowned Gtk.StyleContext style_context = get_style_context ();
            add_css_class (Granite.STYLE_CLASS_H4_LABEL);
            add_css_class ("expander");
            get_style_context ().add_provider (expander_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
    }
}
