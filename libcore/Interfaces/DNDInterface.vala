/*
* Copyright 2022 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Jeremy Wootten <jeremy@elementaryos.org>
*/

public interface Files.DNDInterface : Gtk.Widget, Files.ViewInterface {
    protected abstract uint auto_open_timeout_id { get; set; default = 0; }
    protected abstract FileItemInterface? previous_target_item { get; set; default = null; }
    //Need to ensure fileitem gets selected before drag
    public List<Files.File> get_file_list_for_drag (double x, double y, out Gdk.Paintable? paintable) {
        paintable = null;
        var dragitem = get_item_at (x, y);
        List<Files.File> drag_files = null;
        if (dragitem != null) {
            uint n_items = 0;
            if (!dragitem.selected) {
                drag_files.append (dragitem.file);
                n_items = 1;
            } else {
                n_items = get_selected_files (out drag_files);
            }

            paintable = get_paintable_for_drag (dragitem, n_items);
        }
        return (owned) drag_files;
    }

    private Gdk.Paintable get_paintable_for_drag (FileItemInterface dragged_item, uint item_count) {
        Gdk.Paintable paintable;
        if (item_count > 1) {
            var theme = Gtk.IconTheme.get_for_display (Gdk.Display.get_default ());
            paintable = theme.lookup_icon (
                "edit-copy", //TODO Provide better icon?
                 null,
                 16,
                 this.scale_factor,
                 get_default_direction (),
                 Gtk.IconLookupFlags.FORCE_REGULAR | Gtk.IconLookupFlags.PRELOAD
            );
        } else {
            paintable = dragged_item.get_paintable_for_drag ();
        }

        return paintable;
    }

    // public abstract Files.File get_target_file_for_drop (double x, double y);
    // Accessed by DndHandler
    public Files.File get_target_file_for_drop (double x, double y) {
        var droptarget = get_item_at (x, y);
        if (droptarget == null) {
            if (auto_open_timeout_id > 0) {
                Source.remove (auto_open_timeout_id);
                if (previous_target_item != null) {
                    previous_target_item.drop_pending = false;
                    previous_target_item = null;
                }
                auto_open_timeout_id = 0;
            }
            return root_file;
        } else {
            var target_file = droptarget.file;
            if (target_file.is_folder ()) {
                if (!droptarget.drop_pending) {
                    if (previous_target_item != null) {
                        previous_target_item.drop_pending = false;
                    }

                    droptarget.drop_pending = true;
                    previous_target_item = droptarget;
                    //TODO Start time for auto open
                    if (auto_open_timeout_id > 0) {
                        Source.remove (auto_open_timeout_id);
                    }

                    auto_open_timeout_id = Timeout.add (1000, () => {
                        auto_open_timeout_id = 0;
                        change_path (droptarget.file.location, Files.OpenFlag.DEFAULT);
                        // path_change_request (droptarget.file.location, Files.OpenFlag.DEFAULT);
                        return Source.REMOVE;
                    });
                }
            }

            return target_file;
        }
    }

    public abstract void leave ();
    // Whether is accepting any drops at all
    public bool can_accept_drops () {
       // We cannot ever drop on some locations
        if (!root_file.is_folder () || root_file.is_recent_uri_scheme ()) {
            return false;
        }
        return true;
    }
    // Whether is accepting any drags at all
    public bool can_start_drags () {
        return root_file.is_readable ();
    }
}
