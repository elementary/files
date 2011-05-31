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

#include <gio/gio.h>
#include <gtk/gtk.h>
#include <glib.h>
#include "marlincore-tests-gof.h"
#include "marlincore-tests-file.h"
#include "marlin-global-preferences.h"

int main (int argc, char* argv[])
{
    g_type_init ();
    g_thread_init (NULL);
    gtk_test_init (&argc, &argv);

    settings = g_settings_new ("org.gnome.marlin.preferences");

    /* these tests are not working, TODO */
    //g_test_add_func("/marlin/goffile", marlincore_tests_goffile);
    //g_test_add_func("/marlin/goffile", marlincore_tests_file);
    //g_test_add_func("/marlin/gof", marlin_location_bar_tests);

    return g_test_run();
}
