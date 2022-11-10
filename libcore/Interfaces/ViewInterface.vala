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

public interface Files.ViewInterface : Gtk.Widget {
    public abstract AbstractSlot slot { get; set construct; }
    public virtual Files.File? root_file {
        get {
            return slot.file;
        }
    }

    public virtual bool grab_focus () {
        return false;
    }
    public abstract ZoomLevel zoom_level { get; set; }
    public abstract ZoomLevel minimum_zoom { get; set; }
    public abstract ZoomLevel maximum_zoom { get; set; }
    public abstract Files.SortType sort_type { get; set; }
    public abstract bool sort_reversed { get; set; }
    public abstract bool all_selected { get; set; }
    public abstract bool is_renaming { get; set; }
    public abstract bool rename_after_add { get; set; }
    public abstract bool select_after_add { get; set; }
    protected abstract bool has_open_with { get; set; default = false;}

    public signal void selection_changed ();
    public signal void path_change_request (GLib.File location, Files.OpenFlag open_flag);

    public virtual void set_up_zoom_level () {}
    public virtual void zoom_in () {}
    public virtual void zoom_out () {}
    public virtual void zoom_normal () {}

    public virtual void show_and_select_file (Files.File? file, bool select, bool unselect_others, bool show = true) {}
    public virtual void select_files (List<Files.File> files_to_select) {}
    public virtual void invert_selection () {}
    public virtual void select_all () {}
    public virtual void unselect_all () {}
    public virtual void file_deleted (Files.File file) {}
    public virtual void file_changed (Files.File file) {}
    public virtual void add_file (Files.File file) {}
    public virtual void clear () {}
    public virtual void refresh_visible_items () {}
    public virtual void open_selected (Files.OpenFlag flag) {}

    public abstract void show_item_context_menu (Files.FileItemInterface? clicked_item, double x, double y);
    public abstract void show_appropriate_context_menu ();
    public abstract uint get_selected_files (out GLib.List<Files.File>? selected_files = null);

    protected void open_file (Files.File _file, Files.OpenFlag flag) {
        Files.File file = _file;
        if (_file.is_recent_uri_scheme ()) {
            file = Files.File.get_by_uri (file.get_display_target_uri ());
        }

        var is_folder_type = file.is_folder () ||
                             (file.get_ftype () == "inode/directory") ||
                             file.is_root_network_folder ();

        if (file.is_trashed () && !is_folder_type && flag == Files.OpenFlag.APP) {
            PF.Dialogs.show_error_dialog (
                ///TRANSLATORS: '%s' is a quoted placehorder for the name of a file.
                _("“%s” must be moved from Trash before opening").printf (file.basename),
                _("Files inside Trash cannot be opened. To open this file, it must be moved elsewhere."),
                (Gtk.Window)get_ancestor (typeof (Gtk.Window))
            );
            return;
        }

        var default_app = MimeActions.get_default_application_for_file (file);
        var location = file.get_target_location ();
        switch (flag) {
            case Files.OpenFlag.NEW_TAB:
            case Files.OpenFlag.NEW_WINDOW:
            case Files.OpenFlag.NEW_ROOT:
                path_change_request (location, flag);
                break;
            case Files.OpenFlag.DEFAULT: // Take default action
                if (is_folder_type) {
                    path_change_request (location, flag);
                } else if (file.is_executable ()) {
                    var content_type = FileUtils.get_or_guess_content_type (file);
                    //Do not execute scripts, desktop files etc
                    if (!ContentType.is_a (content_type, "text/plain")) {
                        try {
                            file.execute (null);
                        } catch (Error e) {
                            PF.Dialogs.show_warning_dialog (
                                _("Cannot execute this file"), e.message, (Gtk.Window)get_ancestor (typeof (Gtk.Window)
                            ));
                        }

                        return;
                    }
                } else {
                    if (FileUtils.can_open_file (file, true, (Gtk.Window)get_ancestor (typeof (Gtk.Window)))) {
                        MimeActions.open_glib_file_request (file.location, this, default_app);
                    }
                }

                break;
            case Files.OpenFlag.APP:
                if (FileUtils.can_open_file (file, true, (Gtk.Window)get_ancestor (typeof (Gtk.Window)))) {
                    MimeActions.open_glib_file_request (file.location, this, default_app);
                }
                break;
        }
    }
}
