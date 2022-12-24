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
    protected abstract string? uri_string { get; set; default = null;}

    protected abstract uint auto_open_timeout_id { get; set; default = 0; }
    protected abstract FileItemInterface? previous_target_item { get; set; default = null; }
    protected abstract string current_drop_uri { get; set; default = "";}
    protected abstract uint current_drag_button { get; set; default = 1;}
    protected abstract bool drop_accepted { get; set; default = false; }
    private static List<GLib.File> dropped_files;

    protected void set_up_drag_source () {
        //Set up as drag source for bookmarking
        var drag_source = new Gtk.DragSource () {
            button = 0, // Need to drag with secondary button as well
            propagation_phase = Gtk.PropagationPhase.CAPTURE,
            actions = Gdk.DragAction.LINK |
                      Gdk.DragAction.COPY |
                      Gdk.DragAction.MOVE
        };
        get_view_widget ().add_controller (drag_source);
        drag_source.prepare.connect ((x, y) => {
            current_drag_button = drag_source.get_current_button ();
            var widget = pick (x, y, Gtk.PickFlags.DEFAULT);
            var item = widget.get_ancestor (typeof (FileItemInterface));
            if (item != null && (item is FileItemInterface)) {
                var fileitem = ((FileItemInterface)item);
                if (!fileitem.selected) {
                    multi_selection.select_item (fileitem.pos, true);
                }

                var selected_files = new GLib.List<Files.File> ();
                get_selected_files (out selected_files);
                uri_string = FileUtils.make_string_from_file_list (selected_files);
                // Use a simple string content to match sidebar drop target
                var list_val = new GLib.Value (Type.STRING);
                list_val.set_string (uri_string);
                return new Gdk.ContentProvider.for_value (list_val);
            }

            return null;
        });
        drag_source.drag_begin.connect ((drag) => {
            //FIXME Work around for Gtk4 bug(?) whereby eventcontroller modifier-state does not include buttons
            drag.set_data<uint> ("button", current_drag_button);
            //TODO Set drag icon
            return;
        });
        drag_source.drag_end.connect ((drag, delete_data) => {
            //FIXME Does this leak memory?
            uri_string = null;
            return;
        });
        drag_source.drag_cancel.connect ((drag, reason) => {
            //FIXME Does this leak memory?
            uri_string = null;
            return true;
        });
    }

    protected virtual void set_up_drop_target () {
        //Set up as drag target. Use simple (synchronous) string target for now as most reliable
        //Based on code for BookmarkListBox (some DRYing may be possible?)
        //TODO Use Gdk.FileList target when Gtk4 version 4.8+ available
        var view_widget = get_view_widget ();
        var drop_target = new Gtk.DropTarget (
            Type.STRING,
            Gdk.DragAction.LINK |
            Gdk.DragAction.COPY |
            Gdk.DragAction.MOVE |
            Gdk.DragAction.ASK  // Ignored??
        ) {
            propagation_phase = Gtk.PropagationPhase.CAPTURE,
        };

        view_widget.add_controller (drop_target);
        drop_target.accept.connect ((drop) => {
            drop_accepted = false;
            drop.read_value_async.begin (
                Type.STRING,
                Priority.DEFAULT,
                null,
                (obj, res) => {
                    try {
                        var val = drop.read_value_async.end (res);
                        if (val != null && DndHandler.can_accept_drops (root_file)) {
                            // Error thrown if string does not contain valid uris as uri-list
                            drop_accepted = Files.FileUtils.files_from_uris (val.get_string (), out dropped_files);
                        } else {
                            warning ("dropped value null");
                        }
                    } catch (Error e) {
                        warning ("Could not retrieve valid uri (s)");
                    }
                }
            );

            return true;
        });
        // drop_target.enter.connect (() => {
        //     return 0;
        // });
        drop_target.leave.connect (() => {
            drop_accepted = false;
            dropped_files = null;
        });
        drop_target.motion.connect ((x, y) => {
            if (!drop_accepted) {
                return 0;
            }

            var drop = drop_target.get_current_drop ();
            var drag = drop.drag;
            // Getting mods from the drop object does not work for some reason
            //Gtk already filters available actions according to keyboard modifier state
            //Drag unmodified = selected_action = as returned by DndHandler in motion handler
            // drag_actions = drop_target common actions
            //Drag with Ctrl - selected action == COPY drag actions = COPY
            //Drag with Shift - selected action = MOVE drag_actions = MOVE
            //Drag with Shift+Ctrl - selected action == LINK, drag actions LINK
            //Note: Gtk does not seem to implement a Gtk.DragAction.ASK modifier so we use <ALT>
            var seat = Gdk.Display.get_default ().get_default_seat ();
            var mods = seat.get_keyboard ().modifier_state & Gdk.MODIFIER_MASK;
            var alt_pressed = (mods & Gdk.ModifierType.ALT_MASK) > 0;
            var alt_only = alt_pressed && ((mods & ~Gdk.ModifierType.ALT_MASK) == 0);
            var button_pressed = drop.drag.get_data<uint> ("button");
            var secondary_button_pressed = (button_pressed == Gdk.BUTTON_SECONDARY);

            var widget = pick (x, y, Gtk.PickFlags.DEFAULT);
            var fileitem = (FileItemInterface)(widget.get_ancestor (typeof (FileItemInterface)));
            if (fileitem != null) {
                current_drop_uri = fileitem.file.uri;
                Files.DndHandler.valid_and_preferred_actions (
                    fileitem.file,
                    dropped_files, // read-only
                    drop,
                    alt_only || secondary_button_pressed
                );
            } else {
                current_drop_uri = root_file.uri;
                Files.DndHandler.valid_and_preferred_actions (
                    root_file,
                    dropped_files, // read-only
                    drop,
                    alt_only || secondary_button_pressed
                );
            }
            //Handle auto open
            if (fileitem == null) {
                if (auto_open_timeout_id > 0) {
                    Source.remove (auto_open_timeout_id);
                    if (previous_target_item != null) {
                        previous_target_item.drop_pending = false;
                        previous_target_item = null;
                    }

                    auto_open_timeout_id = 0;
                }
            } else {
                if (fileitem.file.is_folder ()) {
                    if (!fileitem.drop_pending) {
                        if (previous_target_item != null) {
                            previous_target_item.drop_pending = false;
                        }

                        fileitem.drop_pending = true;
                        previous_target_item = fileitem;
                        //TODO Start time for auto open
                        if (auto_open_timeout_id > 0) {
                            Source.remove (auto_open_timeout_id);
                        }

                        auto_open_timeout_id = Timeout.add (1000, () => {
                            auto_open_timeout_id = 0;
                            warning ("setting drop_pending false fir %s", fileitem.file.uri);
                            fileitem.drop_pending = false;
                            previous_target_item.drop_pending = false;
                            change_path (fileitem.file.location, Files.OpenFlag.DEFAULT);
                            return Source.REMOVE;
                        });
                    }
                }
            }

            return Files.DndHandler.preferred_action; //Sets drag emblem
        });

        drop_target.on_drop.connect ((val, x, y) => {
            if (dropped_files != null &&
                current_drop_uri != null &&
                Files.DndHandler.valid_actions > 0) {

                Files.DndHandler.handle_file_drop_actions (
                    this,
                    x, y,
                    Files.File.@get (GLib.File.new_for_uri (current_drop_uri)),
                    dropped_files
                );
            }

            drop_accepted = false;
            if (current_drop_uri != null) {
                current_drop_uri = null;
            }

            return true;
        });
    }

    //Need to ensure fileitem gets selected before drag
    public List<Files.File> get_file_list_for_drag (
        double x,
        double y,
        out Gdk.Paintable? paintable
    ) {
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

    private Gdk.Paintable get_paintable_for_drag (
        FileItemInterface dragged_item,
        uint item_count
    ) {
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

    public void leave () {
        // Cancel auto-open and restore normal icon
        if (auto_open_timeout_id > 0) {
            Source.remove (auto_open_timeout_id);
            auto_open_timeout_id = 0;
        }

        if (previous_target_item != null) {
            previous_target_item.drop_pending = false;
        }
    }

    public bool can_start_drags () {
        return root_file.is_readable ();
    }
}
