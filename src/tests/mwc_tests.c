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

#include "tests/mwc_tests.h"

static gboolean marlin_mwc_fatal_handler(const gchar* log_domain,
                               GLogLevelFlags log_level,
                               const gchar* message,
                               gpointer user_data)
{
    return FALSE;
}

void marlin_window_columns_tests(void)
{
    MarlinViewWindow* win;
    MarlinViewViewContainer* view_container;
    MarlinWindowColumns* mwcols;
    GFile* location;

    /* Init the main windows (it shouldn't be required, FIXME)
     * This code is used to enable warnings, it shouldn't be required either :( */
    g_test_log_set_fatal_handler(marlin_mwc_fatal_handler, NULL);
    win = marlin_view_window_new(marlin_application_new(), gdk_screen_get_default());
    view_container = marlin_view_view_container_new(win, g_file_new_for_path("/usr/"));

    g_assert(win != NULL);

    mwcols = marlin_window_columns_new(g_file_new_for_path("/usr/"), view_container);
    location = marlin_window_columns_get_location(mwcols);
    g_assert_cmpstr(g_file_get_path(location), ==, "/usr");

    marlin_window_columns_make_view(mwcols);

    /* GOFWindowSlot */

    GOFWindowSlot* gof = gof_window_slot_new(g_file_new_for_path("/home/"), NULL);

    /* Check if the two functions returns the same result */
    g_assert_cmpstr(g_file_get_uri(gof->location), ==, "file:///home");
    g_assert_cmpstr(g_file_get_path(gof->location), ==, "/home");

    g_assert_cmpint(g_list_length(mwcols->slot), ==, 1);

    /* Add new slots to the MWC */
    marlin_window_columns_add_location(mwcols, g_file_new_for_path("/usr/share"));
    g_assert_cmpstr(g_file_get_path(marlin_window_columns_get_location(mwcols)),
                                    ==,
                                    "/usr");
 
    g_assert_cmpint(g_list_length(mwcols->slot), ==, 2);
}
