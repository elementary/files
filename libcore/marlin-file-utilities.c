/* nautilus-file-utilities.h - interface for file manipulation routines.
 *
 *  Copyright (C) 1999, 2000, 2001 Eazel, Inc.
 *
 * The Gnome Library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * The Gnome Library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with the Gnome Library; see the file COPYING.LIB.  If not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authors: John Sullivan <sullivan@eazel.com>
 */

#include "marlin-file-utilities.h"

#include "gof-file.h"
#include "eel-gio-extensions.h"
#include "eel-stock-dialogs.h"
#include <glib.h>
#include <glib/gprintf.h>
#include <glib/gi18n.h>

#include "marlin-file-operations.h"


/**
 * marlin_get_accel_map_file:
 *
 * Get the path for the filename containing nautilus accelerator map.
 * The filename need not exist. (according to gnome standard))
 *
 * Return value: the filename path, or NULL if the home directory could not be found
**/
char *
marlin_get_accel_map_file (void)
{
    return g_build_filename (g_get_home_dir (), ".gnome2/accels/marlin", NULL);
}

static void
my_list_free_full (GList *list)
{
    g_list_free_full (list, g_object_unref);
}

GHashTable *
marlin_trashed_files_get_original_directories (GList *files, GList **unhandled_files)
{
    GHashTable *directories;
    GOFFile *file;
    GFile *original_file, *original_dir;
    GList *l, *m;
    GFile *parent;

    directories = NULL;

    if (unhandled_files != NULL) {
        *unhandled_files = NULL;
    }

    for (l = files; l != NULL; l = l->next) {
        file = GOF_FILE (l->data);
        /* Check it is a valid file (e.g. not a dummy row from list view) */
        if (!(file->location != NULL && g_utf8_strlen (g_file_get_basename (file->location),2) > 0))
            continue;

        /* Check that file is in root of trash.  If not, do not try to restore
         * (it will be restored with its parent anyway) */
        parent = g_file_get_parent(file->location);
        if (parent != NULL && strcmp (g_file_get_basename (parent), G_DIR_SEPARATOR_S) == 0) {
            original_file = eel_g_file_get_trash_original_file (
                                g_file_info_get_attribute_byte_string (file->info,
                                                                       G_FILE_ATTRIBUTE_TRASH_ORIG_PATH));
            original_dir = NULL;
            if (original_file != NULL) {
                original_dir = g_file_get_parent (original_file);
            }

            if (original_dir != NULL) {
                if (directories == NULL) {
                    directories = g_hash_table_new_full (g_file_hash,
                                                         (GEqualFunc) g_file_equal,
                                                         (GDestroyNotify) g_object_unref,
                                                         (GDestroyNotify) my_list_free_full);
                }
                m = g_hash_table_lookup (directories, original_dir);
                if (m != NULL) {
                    g_hash_table_steal (directories, original_dir);
                }
                m = g_list_append (m, g_object_ref (file->location));
                g_hash_table_insert (directories, original_dir, m);
            } else if (unhandled_files != NULL) {
                *unhandled_files = g_list_append (*unhandled_files, gof_file_ref (file));
                if (original_dir != NULL)
                    g_object_unref (original_dir);
            }

            if (original_file != NULL)
                g_object_unref (original_file);

            if (parent)
                g_object_unref (parent);
        }
    }

    return directories;
}

void
marlin_restore_files_from_trash (GList *files, GtkWindow *parent_window)
{
    GOFFile *file;
    GHashTable *original_dirs_hash;
    GList *original_dirs, *unhandled_files;
    GFile *original_dir;
    GList *locations, *l;
    char *message;

    original_dirs_hash = marlin_trashed_files_get_original_directories (files, &unhandled_files);
    for (l = unhandled_files; l != NULL; l = l->next) {
        file = GOF_FILE (l->data);
        message = g_strdup_printf (_("Could not determine original location of \"%s\" "),
                                   gof_file_get_display_name (file));

        eel_show_warning_dialog (message,
                                 _("The item cannot be restored from trash"),
                                 parent_window);
        g_free (message);
    }

    if (original_dirs_hash != NULL) {
        original_dirs = g_hash_table_get_keys (original_dirs_hash);
        for (l = original_dirs; l != NULL; l = l->next) {
            original_dir = l->data;

            locations = g_hash_table_lookup (original_dirs_hash, original_dir);

            /*printf ("original dir: %s\n", g_file_get_uri (original_dir));*/
            marlin_file_operations_move (locations, NULL,
                                         original_dir,
                                         parent_window,
                                         NULL, NULL);
        }
        g_hash_table_destroy (original_dirs_hash);
    }

    gof_file_list_free (unhandled_files);
}

void
marlin_get_rename_region (const char *filename, int *start_offset, int *end_offset, gboolean select_all)
{
    if (select_all) {
        *start_offset = 0;
        *end_offset = g_utf8_strlen (filename, -1);
    } else
        eel_filename_get_rename_region (filename, start_offset, end_offset);
}
