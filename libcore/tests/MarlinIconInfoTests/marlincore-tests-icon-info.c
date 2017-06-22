/*
 * Copyright (C) 2012, ammonkey <am.monkeyd@gmail.com>
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
#include "marlincore-tests-icon-info.h"

GMainLoop* loop;

static gboolean fatal_handler(const gchar* log_domain,
                              GLogLevelFlags log_level,
                              const gchar* message,
                              gpointer user_data)
{
    return FALSE;
}

void marlincore_tests_icon_info (void)
{
    GOFFile* file;
    g_test_log_set_fatal_handler (fatal_handler, NULL);
    /* The URI is valid, the target must exist on Travis CI */
    file = gof_file_get_by_uri ("file:///usr/share/icons/hicolor/16x16/apps/system-file-manager.svg");
    g_assert(file != NULL);
    gof_file_query_update (file);
    g_assert(file->pix == NULL);
    file->flags = 2; /* ThumbState.READY */
    gof_file_update_icon (file, 128);
    g_assert(file->pix != NULL);
    gof_file_update_icon (file, 32);
    g_object_unref (file->pix);
}
