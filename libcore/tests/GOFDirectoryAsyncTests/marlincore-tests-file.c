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
#include "marlincore-tests-file.h"
#include "pantheon-files-core.h"
#include "gof-file.h"

GMainLoop* loop;

static gboolean fatal_handler(const gchar* log_domain,
                              GLogLevelFlags log_level,
                              const gchar* message,
                              gpointer user_data)
{
    return FALSE;
}

static void second_load_done(GOFDirectoryAsync* dir, gpointer data)
{
    g_message ("%s", G_STRFUNC);
    g_assert_cmpint(dir->file->exists, ==, TRUE);

    GOFDirectoryAsync *dir2 = gof_directory_async_from_file(dir->file);
    g_assert_cmpint(dir->files_count, ==, dir2->files_count);
    g_message ("files_count %u", dir->files_count);
    g_object_unref (dir2);

    /* some files testing inside a cached directory */
    GOFFile *f1 = gof_file_get_by_uri ("file:///tmp/marlin-test/a");
    g_object_unref (f1);

    GOFFile *f2 = gof_file_get_by_uri ("file:///tmp/marlin-test/a");
    g_object_unref (f2);

    /* use a marlin function would show a dialog, FIXME */
    system("rm -rf /tmp/marlin-test");
    /* free previously allocated dir */
    g_object_unref (dir);

    g_main_loop_quit(loop);

}

static void first_load_done(GOFDirectoryAsync* dir, gpointer data)
{
    g_message ("%s", G_STRFUNC);
    g_assert_cmpint(dir->file->exists, ==, FALSE);

    system("mkdir /tmp/marlin-test");
    system("touch /tmp/marlin-test/a");
    system("touch /tmp/marlin-test/b");
    system("touch /tmp/marlin-test/c");
    system("touch /tmp/marlin-test/d");

    /* we use cached directories so better block this callback */
    g_signal_handlers_block_by_func (dir, first_load_done, NULL);

    GOFDirectoryAsync *dir2;
    dir2 = gof_directory_async_from_file(dir->file);
    g_signal_connect(dir2, "done_loading", (GCallback) second_load_done, NULL);
    gof_directory_async_init(dir2, NULL, NULL);

    /* free previously allocated dir */
    g_object_unref (dir);
}

void marlincore_tests_file(void)
{
    GOFDirectoryAsync* dir;

    g_test_log_set_fatal_handler(fatal_handler, NULL);
    system("rm -rf /tmp/marlin-test");

    dir = gof_directory_async_from_gfile(g_file_new_for_path("/tmp/marlin-test"));
    g_signal_connect(dir, "done_loading", (GCallback) first_load_done, NULL);
    gof_directory_async_init(dir, NULL, NULL);

    loop = g_main_loop_new(NULL, FALSE);
    g_main_loop_run(loop);
}
