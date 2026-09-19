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

public class Files.FileOperations.EmptyTrashJob : DeleteJob {
    // private GLib.List<GLib.File> trash_dirs;

    public EmptyTrashJob (Gtk.Window? parent_window = null, owned GLib.List<GLib.File>? trash_dirs = null) {
        base (parent_window, null, false);
        if (trash_dirs != null) {
            this.files = (owned) trash_dirs;
        } else {
            this.files.prepend (GLib.File.new_for_uri ("trash:"));
        }
    }

    // private async void delete_trash_file (GLib.File file, bool delete_file = true, bool delete_children = true) {
    //     if (aborted ()) {
    //         return;
    //     }

    //     if (delete_children) {
    //         try {
    //             const string ATTRIBUTES = GLib.FileAttribute.STANDARD_NAME + "," + GLib.FileAttribute.STANDARD_TYPE;
    //             var enumerator = yield file.enumerate_children_async (
    //                 ATTRIBUTES,
    //                 GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
    //                 GLib.Priority.DEFAULT, cancellable
    //             );

    //             var infos = yield enumerator.next_files_async (10, GLib.Priority.DEFAULT, cancellable);
    //             while (infos.nth_data (0) != null) {
    //                 foreach (unowned GLib.FileInfo info in infos) {
    //                     var child = file.get_child (info.get_name ());
    //                     yield delete_trash_file (child, true, info.get_file_type () == GLib.FileType.DIRECTORY);
    //                 }

    //                 infos = yield enumerator.next_files_async (10, GLib.Priority.DEFAULT, cancellable);
    //             }
    //         } catch (GLib.Error e) {
    //             debug (e.message);
    //             return;
    //         }
    //     }

    //     if (aborted ()) {
    //         return;
    //     }

    //     if (delete_file) {
    //         try {
    //             yield file.delete_async (GLib.Priority.DEFAULT, cancellable);
    //         } catch (GLib.Error e) {
    //             debug (e.message);
    //             return;
    //         }
    //     }
    // }

    public async void empty_trash () {

        if (Files.Preferences.get_default ().confirm_trash) {
            unowned GLib.File? first_dir = files.nth_data (0);
            if (first_dir != null) {
                unowned string primary = null;
                unowned string secondary = null;
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
                    if (response == Gtk.ResponseType.YES) {
                        internal_empty_trash.begin ();
                    }

                    message_dialog.destroy ();
                });

                message_dialog.present ();
            }
        } else {
            internal_empty_trash.begin ();
        }
    }

    private async void internal_empty_trash () {
        source_info = scan_sources (files);
        if (aborted ()) {
            // There were problematic files and the user chose to cancel
            return;
        }

        transfer_info = new TransferInfo ();
        var some_not_deleted = false;
        foreach (unowned GLib.File dir in files) {
            if (aborted ()) {
                some_not_deleted = true;
                break;
            }

            if (!yield delete_non_empty_dir (dir, cancellable, true)) {
                warning ("delete non empty dir failed for %s", dir.get_uri ());
                some_not_deleted = true;
            }
        }

        if (some_not_deleted) {
            warning ("Some not deleted");
            //TODO inform user or return false
            return;
        }

        /* There is no job callback after emptying trash */
        Files.UndoManager.instance ().trash_has_emptied ();
        PF.SoundManager.get_instance ().play_empty_trash_sound ();
    }
}
