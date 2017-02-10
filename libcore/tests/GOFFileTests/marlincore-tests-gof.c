/*
 * Copyright (C) 2011, Lucas Baudin <xapantu@gmail.com>
 *
 * Marlin is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, Inc.,; either version 2 of the
 * License, or (at your option) any later version.
 *
 * Marlin is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1335 USA.
 *
 */

#include <stdlib.h>
#include <gtk/gtk.h>
#include <glib.h>
#include <gio/gio.h>
#include "marlincore-tests-gof.h"


static gboolean fatal_handler(const gchar* log_domain,
                              GLogLevelFlags log_level,
                              const gchar* message,
                              gpointer user_data)
{
    return FALSE;
}


void marlincore_tests_goffile(void)
{
    GOFFile* file;

    g_test_log_set_fatal_handler(fatal_handler, NULL);
    /* The URI is valid, the target exists */
    file = gof_file_get_by_uri("file:///usr/share");
    g_assert(file != NULL);
    gof_file_query_update (file);
    g_assert(file != NULL);
    g_assert(file->info != NULL);
    g_assert_cmpstr(g_file_info_get_name (file->info), ==, "share");
    g_assert_cmpstr(g_file_info_get_display_name (file->info), ==, "share");
    g_assert_cmpstr(file->basename, ==, "share");
    g_assert_cmpint(file->is_directory, ==, TRUE);
    g_assert_cmpint(file->is_hidden, ==, FALSE);
    g_assert_cmpstr(gof_file_get_ftype (file), ==, "inode/directory");
    g_assert_cmpint(gof_file_is_symlink(file), ==, FALSE);
    /* TODO: formated_type needs a test too, but there are some issues with
     * translations. */
    g_assert_cmpstr(g_file_get_uri(file->location), ==, "file:///usr/share");
    g_assert_cmpstr(gof_file_get_uri(file), ==, "file:///usr/share");

    /* some allocations tests */
    int i;
    for (i=0; i<5; i++) {
        GFile *location = g_file_new_for_path ("/usr/share");
        file = gof_file_get(location);
        g_object_unref (location);
    }
    for (i=0; i<5; i++)
        g_object_unref (file);
    /* we got to remove the file from the cache other the next cache lookup */
    gof_file_remove_from_caches (file);
    g_object_unref (file);
    file = gof_file_get_by_uri("file:///usr/share");
    g_object_unref (file);


    /* The URI is valid, the target doesn't exist */
    g_test_log_set_fatal_handler(fatal_handler, NULL);
    file = gof_file_get_by_uri("file:///tmp/very/long/path/azerty");
    g_assert(file != NULL);

    system("rm /tmp/.marlin_backup /tmp/marlin_sym -f && touch /tmp/.marlin_backup");
    /* The URI is valid, the target exists */
    file = gof_file_get_by_uri("file:///tmp/.marlin_backup");
    gof_file_query_update (file);
    g_assert(file != NULL);
    g_assert_cmpint(file->is_directory, ==, FALSE);
    g_assert_cmpint(file->is_hidden, ==, TRUE); /* it's a backup, so, it's hidden */
    g_assert_cmpint(file->size, ==, 0); /* the file is empty since we just create it it */

    system("ln -s /tmp/marlin_backup~ /tmp/marlin_sym ");

    /* a symlink */
    file = gof_file_get_by_uri("file:///tmp/marlin_sym");
    gof_file_query_update (file);
    g_assert(file != NULL);
    g_assert_cmpstr(gof_file_get_symlink_target(file), ==, "/tmp/marlin_backup~");
    g_assert_cmpint(gof_file_is_symlink(file), ==, TRUE);
    g_assert_cmpint(file->is_directory, ==, FALSE);
    g_assert_cmpint(file->is_hidden, ==, FALSE);
}
