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

void marlin_window_columns_tests(void)
{
    MarlinWindowColumns* mwcols;
    GFile* location;

    mwcols = marlin_window_columns_new(g_file_new_for_path("/home/"), NULL);
    location = marlin_window_columns_get_location(mwcols);
    g_assert_cmpstr(g_file_get_path(location), ==, "/home");

}
