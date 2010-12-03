/* eel-gtk-extensions.c - implementation of new functions that operate on
 * gtk classes. Perhaps some of these should be
 * rolled into gtk someday.
 *
 * Copyright (C) 1999, 2000, 2001 Eazel, Inc.
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
 *          Ramiro Estrugo <ramiro@eazel.com>
 *          Darin Adler <darin@eazel.com>
 */

#include <glib.h>
#include "eel-gtk-extensions.h"

#if 0
/* The standard gtk_adjustment_set_value ignores page size, which
 * disagrees with the logic used by scroll bars, for example.
 */
void
eel_gtk_adjustment_set_value (GtkAdjustment *adjustment,
                              float value)
{
    float upper_page_start, clamped_value;

    g_return_if_fail (GTK_IS_ADJUSTMENT (adjustment));

    upper_page_start = MAX (gtk_adjustment_get_upper (adjustment) -
                            gtk_adjustment_get_page_size (adjustment),
                            gtk_adjustment_get_lower (adjustment));
    printf (">> upper: %f page_size: %f lower: %f value: %f upper_page_start %f\n", 
            gtk_adjustment_get_upper (adjustment),
            gtk_adjustment_get_page_size (adjustment),
            gtk_adjustment_get_lower (adjustment),
            gtk_adjustment_get_value (adjustment),
            upper_page_start);
    clamped_value = CLAMP (value, gtk_adjustment_get_lower (adjustment), upper_page_start);
    printf (">>clamped %f\n", clamped_value);
    printf ("CLAMP test: %f\n", CLAMP (value, 0.0, 100.0));
    if (clamped_value != gtk_adjustment_get_value (adjustment)) {
        gtk_adjustment_set_value (adjustment, clamped_value);
        gtk_adjustment_value_changed (adjustment);
    }
}
#endif

GtkMenuItem *
eel_gtk_menu_insert_separator (GtkMenu *menu, int index)
{
	GtkWidget *menu_item;

	menu_item = gtk_separator_menu_item_new ();
	gtk_widget_show (menu_item);
	gtk_menu_shell_insert (GTK_MENU_SHELL (menu), menu_item, index);

	return GTK_MENU_ITEM (menu_item);
}

GtkMenuItem *
eel_gtk_menu_append_separator (GtkMenu *menu)
{
	return eel_gtk_menu_insert_separator (menu, -1);
}
