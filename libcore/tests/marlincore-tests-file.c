/*
 * Copyright (C) 2011, Lucas Baudin <xapantu@gmail.com>
 *
 * Marlin is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * Marlin is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 */

#include <stdlib.h>
#include <gtk/gtk.h>
#include <glib.h>
#include <gio/gio.h>
#include "marlincore-tests-file.h"
#include "gof-directory-async.h"
#include "marlin-file-operations.h"

GMainLoop* loop;

static gboolean fatal_handler(const gchar* log_domain,
                              GLogLevelFlags log_level,
                              const gchar* message,
                              gpointer user_data)
{
    return FALSE;
}

/*static void quit(gpointer data, gpointer data_)
{
    g_main_loop_quit(loop);
}*/

static void second_load_done(GOFDirectoryAsync* dir, gpointer data)
{
    g_assert_cmpint(dir->file->exists, ==, TRUE);
    /* use a marlin function would show a dialog, FIXME */
    system("rm /tmp/marlin-test -R");
    g_main_loop_quit(loop);
}

static void first_load_done(GOFDirectoryAsync* dir, gpointer data)
{
    g_assert_cmpint(dir->file->exists, ==, FALSE);
    marlin_file_operations_new_folder_with_name (NULL, NULL, g_file_new_for_path("/tmp"), "marlin-test", NULL, NULL);
    dir = gof_directory_async_new(g_file_new_for_path("/tmp/marlin-test"));
    g_signal_connect(dir, "done_loading", (GCallback) second_load_done, NULL);
    gof_directory_async_load(dir);
}

void marlincore_tests_file(void)
{
    GOFDirectoryAsync* dir;
    g_test_log_set_fatal_handler(fatal_handler, NULL);
    dir = gof_directory_async_new(g_file_new_for_path("/tmp/marlin-test"));
    g_signal_connect(dir, "done_loading", (GCallback) first_load_done, NULL);
    gof_directory_async_load(dir);
    loop = g_main_loop_new(NULL, FALSE);
    g_main_loop_run(loop);
}
