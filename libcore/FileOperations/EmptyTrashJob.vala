/* Copyright 2020 elementary LLC (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, Inc.,; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

// Used to empty a trash folder entirely.  Deleting selected files in trash uses a DeleteJob
// TODO Move into OperationsManager?
public class Files.FileOperations.EmptyTrashJob : DeleteJob {
    public EmptyTrashJob (Gtk.Window? parent_window = null, owned GLib.List<GLib.File>? trash_dirs = null) {
        base (parent_window, null, false);
        if (trash_dirs != null) {
            foreach (var dir in trash_dirs) {
                files.prepend (dir);
            }
        } else {
            this.files.prepend (GLib.File.new_for_uri ("trash:"));
        }
    }

    public async void empty_trash () {
        if (Files.Preferences.get_default ().confirm_trash) {
            unowned GLib.File? first_dir = files.nth_data (0);
            if (first_dir != null) {
                unowned string primary, secondary;
                if (first_dir.has_uri_scheme ("trash")) {
                    /* Empty all trash */
                    primary = _("Permanently delete all items from Trash?");
                    secondary = _("All items in all trash directories, including those on any mounted external drives, will be permanently deleted.");//vala-lint=line-length
                } else {
                    /* Empty trash on a particular mounted volume */
                    primary = _("Permanently delete all items from Trash on this mount?");
                    secondary = _("All items in the trash on this mount, will be permanently deleted.");
                }

                var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                    primary,
                    secondary,
                    "dialog-warning",
                    Gtk.ButtonsType.CANCEL
                ) {
                    transient_for = parent_window
                };

                unowned var empty_button = message_dialog.add_button (EMPTY_TRASH, Gtk.ResponseType.YES);
                empty_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

                message_dialog.response.connect ((response) => {
                    message_dialog.destroy ();
                    if (response == Gtk.ResponseType.YES) {
                        internal_empty_trash.begin ();
                    }
                });

                message_dialog.present ();
            }
        } else {
            internal_empty_trash.begin ();
        }
    }

    private async void internal_empty_trash () {
        scan_sources (files);
        progress.started ();
        if (aborted ()) {
            // There were problematic files and the user chose to cancel
            return;
        }

        var success = true;
        foreach (unowned GLib.File dir in files) {
            if (aborted ()) {
                success = false;
                break;
            }

            // Only delete children of dir
            if (!(yield delete_dir_children (dir, cancellable))) {
                success = false;
            }
        }

        progress.finished ();

        if (!success) {
            //TODO inform user or return false
            return;
        }

        /* There is no job callback after emptying trash */
        Files.UndoManager.instance ().trash_has_emptied ();
        PF.SoundManager.get_instance ().play_empty_trash_sound ();
    }
}
