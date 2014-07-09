/***
  Copyright (C)  

  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE. See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program. If not, see <http://www.gnu.org/licenses/>.

 Authors :    
***/

namespace Marlin.View {
    public class Slot : GOF.AbstractSlot {

        public GOF.Directory.Async directory;
        public GLib.File location;
        public ViewContainer ctab;

        public FM.Directory.View view_box;
        public Gtk.Box colpane;
        public Granite.Widgets.ThinPaned hpane;

        public int width = 0;
        public bool updates_frozen = false;
        public bool is_active = true;

        public signal void active (); //Listeners: this, MillerView
        public signal void inactive (); //Listeners: this
        public signal void frozen_changed (bool freeze); //Listeners: MillerView

        private ulong file_loaded_handler_id;

        public Slot (GLib.File location, Marlin.View.ViewContainer ctab) {
message ("New slot location %s", location.get_uri ());
            base.init ();
            this.location = location;
            this.ctab = ctab;
            this.directory = GOF.Directory.Async.from_gfile (location);

            this.active.connect (() => {
message ("Slot directory location %s is active", this.directory.location.get_uri ());
message ("Slot location %s is active", this.location.get_uri ());
                ctab.refresh_slot_info (this);
                this.view_box.merge_menus ();
                this.is_active = true;
            });
            this.inactive.connect (() => {
                this.view_box.unmerge_menus ();
                this.is_active = false;
            });
            (GOF.Preferences.get_default ()).notify["show-hidden-files"].connect ((s, p) => {
                show_hidden_files_changed (((GOF.Preferences)s).show_hidden_files);
            });
            (GOF.Preferences.get_default ()).notify["interpret-desktop-files"].connect ((s,p) => {
                this.directory.update_desktop_files ();
            });
            connect_directory_handlers ();
        }

        public Gtk.Widget make_icon_view () {
            make_view (Marlin.ViewMode.ICON);
            return content_box as Gtk.Widget;
        }
        public Gtk.Widget make_list_view () {
            make_view (Marlin.ViewMode.LIST);
            return content_box as Gtk.Widget;
        }

        /** Only called by MillerView.vala, which returns the content to ViewContainer */
        public void make_column_view () {
            make_view (Marlin.ViewMode.MILLER);
        }

        public void make_view (Marlin.ViewMode view_mode) {
            if (view_box != null)
                view_box.destroy ();

            switch (view_mode) {
                case Marlin.ViewMode.MILLER:
                    view_box = GLib.Object.@new (FM.Columns.View.get_type (),
                                                "window", this.ctab.window,
                                                "directory", this.directory,
                                                 null) as FM.Directory.View;
                    break;

                case Marlin.ViewMode.LIST:
                    view_box = GLib.Object.@new (FM.List.View.get_type (),
                                                "window", this.ctab.window,
                                                "directory", this.directory,
                                                 null) as FM.Directory.View;
                    break;

                case Marlin.ViewMode.ICON:
                default:
                    view_box = GLib.Object.@new (FM.Icon.View.get_type (),
                                                "window", this.ctab.window,
                                                "directory", this.directory,
                                                 null) as FM.Directory.View;
                    break;
            }

            if (view_mode != Marlin.ViewMode.MILLER) {
                content_box.pack_start (view_box, true, true, 0);
                directory.track_longest_name = false;
            }

            connect_view_handlers ();
            directory.load ();
        }

        public void autosize (int handle_size, int preferred_column_width) {
            if (this.slot_number < 0)
                return;

            Pango.Layout layout = view_box.create_pango_layout (null);

            if (directory.is_empty ())
                layout.set_markup (view_box.empty_message, -1);
            else
                layout.set_markup (GLib.Markup.escape_text (directory.longest_file_name), -1);

            Pango.Rectangle extents;
            layout.get_extents (null, out extents);

            this.width = (int) Pango.units_to_double (extents.width)
                  + 2 * directory.icon_size
                  + 2 * handle_size
                  + 12;

            /* TODO make min and max width to be properties of mwcols */
            this.width.clamp (preferred_column_width / 2, preferred_column_width * 2);
            this.hpane.set_position (this.width);
            
        }

        public void freeze_updates (bool freeze) {
            directory.freeze_update = freeze;
            updates_frozen = freeze;
            frozen_changed (freeze);
        }

        private void connect_view_handlers () {
            view_box.notify["zoom"].connect ((view, pspec) => {
                this.directory.queue_load_thumbnails (view_box.zoom_level);
            });

            view_box.notify["active"].connect ((view, pspec) => {
                if (view_box.active)
                    this.active ();
                else
                    this.inactive ();
            });

            view_box.notify["updates_frozen"].connect ((view, pspec) => {
                freeze_updates (view_box.updates_frozen);
            });

            view_box.change_path.connect ((location, flags) => {
                this.ctab.path_changed (location, flags, this);
            });

            view_box.sync_selection.connect (() => {
                if (this.is_active) {
                    this.ctab.window.selection_changed (this.view_box.get_selection ());
                    this.view_box.update_menus ();
                }
            });

            view_box.trash_files.connect ((locations) => {
                Marlin.FileOperations.trash_or_delete (locations, this.ctab.window, (void*) this.trash_or_delete_callback, null);
            });

            view_box.delete_files.connect ((locations) => {
                Marlin.FileOperations.@delete (locations, this.ctab.window, null, null);
            });

            view_box.restore_files.connect ((locations) => {
                Marlin.restore_files_from_trash (locations, this.ctab.window);
            });
        }

        private void trash_or_delete_callback (GLib.HashTable uris, bool user_cancelled) {
            view_box.set_selection_was_removed (!user_cancelled);
        }

        private void connect_directory_handlers () {
            file_loaded_handler_id = this.directory.file_loaded.connect ((f) => {
                view_box.set_select_added_files (false);
                view_box.add_file (f, this.directory);
            });

            this.directory.file_added.connect ((f) => {
                view_box.add_file (f, this.directory);
            });

            this.directory.file_changed.connect ((f) => {
                remove_marlin_icon_info_cache (f);
                view_box.get_model ().file_changed (f, this.directory);
                Marlin.Thumbnailer.get ().queue_file (f, null, false); // get small thumbnail
            });

            this.directory.file_deleted.connect ((f) => {
                remove_marlin_icon_info_cache (f);
                view_box.get_model ().remove_file (f, this.directory);
                if (f.is_folder ()) {
                    GOF.Directory.Async? dir = GOF.Directory.Async.cache_lookup (f.location);
                    if (dir != null)
                        dir.purge_dir_from_cache ();
                }
                //Not necessary to emit "deleted" signal on view_box ??
            });

            this.directory.done_loading.connect (() => {
                bool empty = this.directory.is_empty ();
                this.view_box.disconnect (file_loaded_handler_id);

                /* Ensure thumbnails updated */
                this.directory.queue_load_thumbnails (view_box.zoom_level);

                /* Apparently we need a queue_draw sometimes, the view is not refreshed until an event */
                if (empty)
                    this.view_box.queue_draw ();

                this.view_box.dir_action_set_sensitive ("Select All", !empty);
            });

            this.directory.thumbs_loaded.connect (() => {
                if (this.view_box.get_realized ())
                    this.view_box.queue_draw ();

                Marlin.IconInfo.infos_caches ();
            });

            this.directory.icon_changed.connect ((f) => {
                this.view_box.get_model ().file_changed (f, this.directory);
            });
        }

        private void remove_marlin_icon_info_cache (GOF.File file) {
            unowned string? path = file.get_thumbnail_path ();
            if (path != null) {
                int z;
                Marlin.IconSize icon_size;
                for (z = Marlin.ZoomLevel.SMALLEST;
                     z <= Marlin.ZoomLevel.LARGEST;
                     z++) {
                    icon_size = Marlin.zoom_level_to_icon_size ((Marlin.ZoomLevel)z);
                    Marlin.IconInfo.remove_cache (path, icon_size);
                }
            }
        }

        private void show_hidden_files_changed (bool show_hidden) {
            this.view_box.set_select_added_files (false);
            ulong handler_id = this.directory.file_loaded.connect ((f) => {
                this.view_box.add_file (f, this.directory);
            });
            if (show_hidden)
                directory.load_hiddens ();
            else {
                this.view_box.clear_model ();
                directory.load ();
            }
            directory.disconnect (handler_id);
        }
    }
}
