/*-
 * Copyright (c) 2015-2018 elementary LLC <https://elementary.io>
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
 * Authored by: Adam Bieńkowski <donadigos159@gmail.com>
 */

/*** The Gtk.FileChooserWidget widget names and paths can be found in "gtkfilechooserwidget.ui"
 *   in the Gtk+3 source code package.  Changes to that file could break this code.
***/
public class CustomFileChooserDialog : Object {
    /* Response to get parent of the bottom box */
    private const int BUTTON_RESPONSE = -6;

    /* Paths to widgets */
    private const string[] GTK_PATHBAR_PATH = { "widget", "browse_widgets_box", "browse_files_box",
                                                "browse_header_revealer" };

    private const string[] GTK_FILTERCHOOSER_PATH = { "extra_and_filters", "filter_combo_hbox" };
    private const string[] GTK_TREEVIEW_PATH = { "browse_files_stack", "browse_files_swin", "browse_files_tree_view" };

    private unowned Gtk.FileChooserDialog chooser_dialog;
    private unowned Gtk.Widget rootwidget;

    private unowned Gtk.Box container_box;
    private unowned Gtk.Button? gtk_folder_button = null;

    private GLib.Queue<string> previous_paths;
    private GLib.Queue<string> next_paths;

    private bool filters_available = false;

    private string current_path = null;
    private bool is_previous = false;
    private bool is_button_next = false;
    private bool can_activate = true;

    public CustomFileChooserDialog (Gtk.FileChooserDialog dialog) {
        previous_paths = new GLib.Queue<string> ();
        next_paths = new GLib.Queue<string> ();
        /* The "chooser_dialog" variable is the main dialog */
        chooser_dialog = dialog;
        chooser_dialog.can_focus = true;
        chooser_dialog.deletable = false;
        /* If not local only during creation, strange bug occurs on fresh installs */
        chooser_dialog.local_only = true;

        var chooser_settings = new Settings ("io.elementary.files.file-chooser");

        assign_container_box ();
        remove_gtk_widgets ();
        setup_filter_box ();

        var header_bar = new Gtk.HeaderBar ();

        var button_back = new Gtk.Button.from_icon_name ("go-previous-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        button_back.tooltip_text = _("Previous");
        button_back.sensitive = false;

        var button_forward = new Gtk.Button.from_icon_name ("go-next-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        button_forward.tooltip_text = _("Next");
        button_forward.sensitive = false;

        var location_bar = new Marlin.View.Chrome.BasicLocationBar ();
        location_bar.hexpand = true;

        header_bar.pack_start (button_back);
        header_bar.pack_start (button_forward);
        header_bar.pack_start (location_bar);
        if ((gtk_folder_button != null) && (chooser_dialog.get_action () != Gtk.FileChooserAction.OPEN)) {
            gtk_folder_button.image = new Gtk.Image.from_icon_name ("folder-new", Gtk.IconSize.LARGE_TOOLBAR);
            ((Gtk.Container) gtk_folder_button.get_parent ()).remove (gtk_folder_button);
            header_bar.pack_end (gtk_folder_button);
        }

        chooser_dialog.set_titlebar (header_bar);
        chooser_dialog.show_all ();

        /* Connect signals */
        button_back.clicked.connect (() => {
            /* require history not to contain nulls */
            is_previous = true;
            chooser_dialog.set_current_folder_uri (previous_paths.pop_head ());
        });

        button_forward.clicked.connect (() => {
            /* require history not to contain nulls */
            is_button_next = true;
            chooser_dialog.set_current_folder_uri (next_paths.pop_head ());
        });

        chooser_dialog.current_folder_changed.connect (() => {
            var previous_path = current_path ?? Environment.get_home_dir ();
            current_path = chooser_dialog.get_current_folder_uri () ?? Environment.get_home_dir ();

            if (previous_path == null || previous_path == current_path) {
                location_bar.set_display_path (current_path);
                return;
            }

            if (is_previous) {
                next_paths.push_head (previous_path);
                is_previous = false;
            } else {
                previous_paths.push_head (previous_path);
                if (!is_button_next) {
                    next_paths.clear ();
                } else {
                    is_button_next = false;
                }
            }

            button_back.sensitive = !previous_paths.is_empty ();
            button_forward.sensitive = !next_paths.is_empty ();
            location_bar.set_display_path (current_path);
        });
        chooser_dialog.unrealize.connect (() => {
            var last_path = location_bar.get_display_path () ?? Environment.get_home_dir ();
            chooser_settings.set_string ("last-folder-uri", last_path);
        });

        location_bar.path_change_request.connect ((uri) => {
            if (uri != null) {
                chooser_dialog.set_current_folder_uri (uri);
            }
            /* OK to set to not local only now.*/
            chooser_dialog.local_only = false;
        });

        /* Try to provide a syntactically valid path or fallback to user home directory
         * The setting will be valid except after a fresh install or if the user
         * edits the setting to an invalid path. */

        var last_folder = chooser_settings.get_string ("last-folder-uri");
        if (last_folder.length < 1) {
            last_folder = Environment.get_home_dir ();
        }

        last_folder = PF.FileUtils.sanitize_path (last_folder);
        if (Uri.parse_scheme (last_folder) == null) {
            last_folder = "file://" + last_folder;
        }

        chooser_dialog.set_current_folder_uri (last_folder);
    }

    /*
     * Playing with the native Gtk dialog.
     */

    /* Remove GTK's native path bar and FileFilter chooser by widgets names */
    private void remove_gtk_widgets () {
        chooser_dialog.get_children ().foreach ((root) => {
            ((Gtk.Container)root).get_children ().foreach ((w0) => {
                if (w0.get_name () == GTK_PATHBAR_PATH[0]) {
                    /* Add top separator between headerbar and filechooser when is not Save action */
                    var chooserwidget = (Gtk.Container)w0;
                    chooserwidget.vexpand = true;

                    ((Gtk.Container)root).remove (w0);
                    var root_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
                    root_box.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
                    root_box.add (chooserwidget);

                    if (chooser_dialog.get_extra_widget () == null) {
                        root_box.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
                    }

                    ((Gtk.Container)root).add (root_box);
                    rootwidget = chooserwidget;
                    rootwidget = w0;
                    rootwidget.can_focus = true;
                    transform_rootwidget_container (rootwidget, w0);
                }
            });
        });
    }

    private void transform_rootwidget_container (Gtk.Widget rootwidget, Gtk.Widget w0) {
        ((Gtk.Container)rootwidget).get_children ().foreach ((w1) => {
            if (w1.name == "GtkBox" && w1.get_name () != GTK_PATHBAR_PATH[1]) {
                w1.ref ();
                ((Gtk.Container)rootwidget).remove (w1);

                ((Gtk.Container)w1).get_children ().foreach ((grid) => {
                    grid.ref ();
                    grid.margin = 0;
                    grid.valign = Gtk.Align.CENTER;
                    ((Gtk.Container)grid).border_width = 0;
                    ((Gtk.Container)w1).remove (grid);
                    container_box.pack_start (grid);
                    ((Gtk.ButtonBox)container_box).set_child_secondary (grid, true);
                    grid.unref ();
                });

                w1.unref ();
                container_box.show_all ();
            } else if (w1.get_name () == GTK_PATHBAR_PATH[1]) {
                transform_w1_container (w1);
            } else {
                if (w1.get_name () == GTK_FILTERCHOOSER_PATH[0]) {
                    /* Remove extra_and_filters if there is no extra widget */
                    if (chooser_dialog.get_extra_widget () == null) {
                        ((Gtk.Container)w0).remove (w1);
                    } else {
                        ((Gtk.Container)w1).get_children ().foreach ((w5) => {
                            if (w5.get_name () == GTK_FILTERCHOOSER_PATH[1]) {
                               ((Gtk.Container)w1).remove (w5);
                            }
                        });
                    }
                }
            }
        });
    }

    private void transform_w1_container (Gtk.Widget w1) {
        ((Gtk.Container)w1).get_children ().foreach ((paned) => {
            ((Gtk.Container)paned).get_children ().foreach ((w2) => {
                if (w2 is Gtk.PlacesSidebar) {
                    var sidebar = (Gtk.PlacesSidebar)w2;
                    sidebar.show_desktop = false;
                    sidebar.show_enter_location = false;
                    sidebar.show_recent = true;
                } else {
                    transform_w2_container (w2);
                }
            });
        });
    }

    private void transform_w2_container (Gtk.Widget w2) {
        ((Gtk.Container)w2).get_children ().foreach ((w3) => {
            if (w3.get_name () == GTK_PATHBAR_PATH[3]) {
                ((Gtk.Container)w3).get_children ().foreach ((w4) => {
                    ((Gtk.Container)w4).get_children ().foreach ((w5) => {
                        ((Gtk.Container)w5).get_children ().foreach ((w6) => {
                            if (w6 is Gtk.Box) {
                                ((Gtk.Container)w6).get_children ().foreach ((w7) => {
                                    if (w7 is Gtk.Button) {
                                        /* Register the button so we can use it's signal */
                                        gtk_folder_button = (Gtk.Button)w7;
                                    }
                                });
                            }
                        });
                    });
                });

                ((Gtk.Container)w2).remove (w3);
            } else if (w3.get_name () == "list_and_preview_box") { /* file browser list and preview box */
                var tv = find_tree_view (w3);
                if (tv != null) {
                    /* We need to modify native behaviour to only activate on folders */
                    tv.add_events (Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK);
                    tv.button_press_event.connect (on_tv_button_press_event);
                    tv.button_release_event.connect (on_tv_button_release_event);
                }
            }
        });
    }

    private Gtk.TreeView? find_tree_view (Gtk.Widget browser_box) {
        /* Locate the TreeView */
        Gtk.TreeView? tv = null;
        ((Gtk.Container)browser_box).get_children ().foreach ((w) => {
            if (w.get_name () == GTK_TREEVIEW_PATH[0]) {
                ((Gtk.Container)w).get_children ().foreach ((w) => {
                    if (w.name == "GtkBox") {
                        ((Gtk.Container)w).get_children ().foreach ((w) => {
                            if (w.get_name () == GTK_TREEVIEW_PATH[1]) {
                                ((Gtk.Container)w).get_children ().foreach ((w) => {
                                    if (w.get_name () == GTK_TREEVIEW_PATH[2]) {
                                        tv = (Gtk.TreeView)w;
                                    }
                                });
                            }
                        });
                    }
                });
            }
        });

        return tv;
    }

    private void assign_container_box () {
        container_box = chooser_dialog.get_action_area ();
        container_box.valign = Gtk.Align.CENTER;
        container_box.get_children ().foreach ((child) => {
            child.valign = Gtk.Align.CENTER;
        });
    }

    private void setup_filter_box () {
        var filters = chooser_dialog.list_filters ();

        if (filters.length () > 0) { // Can be assumed to be limited in length
            string? current_filter_name = null;
            var current_filter = chooser_dialog.get_filter ();
            if (current_filter != null) {
                current_filter_name = current_filter.get_filter_name ();
            }

            filters_available = true;
            var combo_box = new Gtk.ComboBoxText ();
            combo_box.changed.connect (() => {
                chooser_dialog.list_filters ().foreach ((filter) => {
                    if (filter.get_filter_name () == combo_box.get_active_text ()) {
                        chooser_dialog.set_filter (filter);
                    }
                });
            });

            var index = 0;
            filters.foreach ((filter) => {
                var name = filter.get_filter_name ();
                combo_box.append_text (name);
                if (name == current_filter_name) {
                    combo_box.active = index;
                }

                index++;
            });

            var grid = new Gtk.Grid ();
            grid.valign = Gtk.Align.CENTER;
            grid.add (combo_box);
            container_box.pack_end (grid);
            ((Gtk.ButtonBox) container_box).set_child_secondary (grid, true);
        }
    }

    private bool on_tv_button_press_event (Gtk.Widget w, Gdk.EventButton event) {
        can_activate = false;
        if (event.type == Gdk.EventType.@2BUTTON_PRESS) {
            can_activate = true;
            return false;
        }

        if (w == null) {
            return false;
        }

        Gtk.TreeView tv = ((Gtk.TreeView)(w));
        Gtk.TreePath? path = null;
        int cell_x, cell_y;

        tv.get_path_at_pos ((int)(event.x), (int)(event.y), out path, null, out cell_x, out cell_y);

        if (path != null) {
            var model = tv.get_model ();
            Gtk.TreeIter? iter = null;
            if (model.get_iter (out iter, path)) {
                bool is_folder;
                model.@get (iter, 5, out is_folder);
                if (is_folder) {
                    can_activate = true;
                }
            }
        }

        return false;
    }

    private bool on_tv_button_release_event (Gdk.EventButton event) {
        return !can_activate;
    }
}
