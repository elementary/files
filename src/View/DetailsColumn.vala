/*
 * SPDX-License-Identifier: GPL-2.0+
 * SPDX-FileCopyrightText: 2020-2025 elementary, Inc. (https://elementary.io)
 *
 * Authors : Andres Mendez <shiruken@gmail.com>
 */


public class Files.View.DetailsColumn : Gtk.Box {
    protected Gtk.Grid info_grid;

    construct {
    }


    // private void construct_info_panel (Files.File file) {
    //     /* Have to have these separate as size call is async */
    //     var size_key_label = make_key_label (_("Size:"));

    //     spinner = new Gtk.Spinner ();
    //     spinner.halign = Gtk.Align.START;

    //     size_value = make_value_label ("");

    //     info_grid.attach (size_key_label, 0, 1);
    //     info_grid.attach_next_to (spinner, size_key_label, RIGHT);
    //     info_grid.attach_next_to (size_value, size_key_label, RIGHT);

    //     int n = 4;

    //     if (only_one) {
    //         /* Note most Linux filesystem do not store file creation time */
    //         var time_created = FileUtils.get_formatted_time_attribute_from_info (file.info,
    //                                                                              FileAttribute.TIME_CREATED);
    //         if (time_created != "") {
    //             var key_label = make_key_label (_("Created:"));
    //             var value_label = make_value_label (time_created);
    //             info_grid.attach (key_label, 0, n, 1, 1);
    //             info_grid.attach_next_to (value_label, key_label, Gtk.PositionType.RIGHT, 3, 1);
    //             n++;
    //         }

    //         var time_modified = FileUtils.get_formatted_time_attribute_from_info (file.info,
    //                                                                               FileAttribute.TIME_MODIFIED);

    //         if (time_modified != "") {
    //             var key_label = make_key_label (_("Modified:"));
    //             var value_label = make_value_label (time_modified);
    //             info_grid.attach (key_label, 0, n, 1, 1);
    //             info_grid.attach_next_to (value_label, key_label, Gtk.PositionType.RIGHT, 3, 1);
    //             n++;
    //         }
    //     }

    //     if (only_one && file.is_trashed ()) {
    //         var deletion_date = FileUtils.get_formatted_time_attribute_from_info (file.info,
    //                                                                               FileAttribute.TRASH_DELETION_DATE);
    //         if (deletion_date != "") {
    //             var key_label = make_key_label (_("Deleted:"));
    //             var value_label = make_value_label (deletion_date);
    //             info_grid.attach (key_label, 0, n, 1, 1);
    //             info_grid.attach_next_to (value_label, key_label, Gtk.PositionType.RIGHT, 3, 1);
    //             n++;
    //         }
    //     }

    //     var ftype = filetype (file);

    //     var mimetype_key = make_key_label (_("Media type:"));
    //     var mimetype_value = make_value_label (ftype);
    //     info_grid.attach (mimetype_key, 0, n, 1, 1);
    //     info_grid.attach_next_to (mimetype_value, mimetype_key, Gtk.PositionType.RIGHT, 3, 1);
    //     n++;

    //     if (only_one && "image" in ftype) {
    //         var resolution_key = make_key_label (_("Resolution:"));
    //         resolution_value = make_value_label (resolution (file));
    //         info_grid.attach (resolution_key, 0, n, 1, 1);
    //         info_grid.attach_next_to (resolution_value, resolution_key, Gtk.PositionType.RIGHT, 3, 1);
    //         n++;
    //     }

    //     if (got_common_location ()) {
    //         var location_key = make_key_label (_("Location:"));
    //         var location_value = make_value_label (location (file));
    //         location_value.ellipsize = Pango.EllipsizeMode.MIDDLE;
    //         location_value.max_width_chars = 32;
    //         info_grid.attach (location_key, 0, n, 1, 1);
    //         info_grid.attach_next_to (location_value, location_key, Gtk.PositionType.RIGHT, 3, 1);
    //         n++;
    //     }

    //     if (only_one && file.info.get_attribute_boolean (GLib.FileAttribute.STANDARD_IS_SYMLINK)) {
    //         var key_label = make_key_label (_("Target:"));
    //         var value_label = make_value_label (file.info.get_attribute_byte_string (GLib.FileAttribute.STANDARD_SYMLINK_TARGET));
    //         info_grid.attach (key_label, 0, n, 1, 1);
    //         info_grid.attach_next_to (value_label, key_label, Gtk.PositionType.RIGHT, 3, 1);
    //         n++;
    //     }

    //     if (file.is_trashed ()) {
    //         var key_label = make_key_label (_("Original Location:"));
    //         var value_label = make_value_label (original_location (file));
    //         info_grid.attach (key_label, 0, n, 1, 1);
    //         info_grid.attach_next_to (value_label, key_label, Gtk.PositionType.RIGHT, 3, 1);
    //         n++;
    //     }

    //     /* Open with */
    //     if (view.get_default_app () != null && !goffile.is_directory) {
    //         Gtk.TreeIter iter;

    //         AppInfo default_app = view.get_default_app ();
    //         store_apps = new Gtk.ListStore (3, typeof (AppInfo), typeof (string), typeof (Icon));
    //         unowned List<AppInfo> apps = view.get_open_with_apps ();
    //         foreach (var app in apps) {
    //             store_apps.append (out iter);
    //             store_apps.set (iter,
    //                             AppsColumn.APP_INFO, app,
    //                             AppsColumn.LABEL, app.get_name (),
    //                             AppsColumn.ICON, ensure_icon (app));
    //         }
    //         store_apps.append (out iter);
    //         store_apps.set (iter,
    //                         AppsColumn.LABEL, _("Other Application…"));
    //         store_apps.prepend (out iter);
    //         store_apps.set (iter,
    //                         AppsColumn.APP_INFO, default_app,
    //                         AppsColumn.LABEL, default_app.get_name (),
    //                         AppsColumn.ICON, ensure_icon (default_app));

    //         var renderer = new Gtk.CellRendererText ();
    //         var pix_renderer = new Gtk.CellRendererPixbuf ();

    //         var combo = new Gtk.ComboBox.with_model ((Gtk.TreeModel) store_apps);
    //         combo.active = 0;
    //         combo.valign = Gtk.Align.CENTER;
    //         combo.pack_start (pix_renderer, false);
    //         combo.pack_start (renderer, true);
    //         combo.add_attribute (renderer, "text", AppsColumn.LABEL);
    //         combo.add_attribute (pix_renderer, "gicon", AppsColumn.ICON);

    //         combo.changed.connect (combo_open_with_changed);

    //         var key_label = make_key_label (_("Open with:"));

    //         info_grid.attach (key_label, 0, n, 1, 1);
    //         info_grid.attach_next_to (combo, key_label, Gtk.PositionType.RIGHT);
    //         n++;
    //     }

    //     /* Device Usage */
    //     if (should_show_device_usage ()) {
    //         try {
    //             var info = goffile.get_target_location ().query_filesystem_info ("filesystem::*");
    //             create_storage_bar (info, n);
    //         } catch (Error e) {
    //             warning ("error: %s", e.message);
    //         }
    //     }
    // }
}
