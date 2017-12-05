/* eel-gtk-extensions.c - implementation of new functions that operate on
 * gtk classes. Perhaps some of these should be
 * rolled into gtk someday.
 *
 * Copyright (C) 1999, 2000, 2001 Eazel, Inc.
 *
 * The Gnome Library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License as
 * published by the Free Software Foundation, Inc.,; either version 2 of the
 * License, or (at your option) any later version.
 *
 * The Gnome Library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with the Gnome Library; see the file COPYING.LIB.  If not,
 * write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
 * Boston, MA 02110-1335 USA.
 *
 * Authors: John Sullivan <sullivan@eazel.com>
 *          Ramiro Estrugo <ramiro@eazel.com>
 *          Darin Adler <darin@eazel.com>
 */

#include <glib.h>
#include "eel-gtk-extensions.h"
#include <gdk/gdk.h>


/**
 * eel_pop_up_context_menu:
 *
 * Pop up a context menu under the mouse.
 * The menu is sunk after use, so it will be destroyed unless the
 * caller first ref'ed it.
 *
 * This function is more of a helper function than a gtk extension,
 * so perhaps it belongs in a different file.
 *
 * @menu: The menu to pop up under the mouse.
 * @offset_x: Number of pixels to displace the popup menu vertically
 * @offset_y: Number of pixels to displace the popup menu horizontally
 * @event: The event that invoked this popup menu.
**/
void
eel_pop_up_context_menu (GtkMenu         *menu,
                         gint16       offset_x,
                         gint16       offset_y,
                         GdkEventButton *event)
{
    GdkPoint offset;
    int button;

    g_return_if_fail (GTK_IS_MENU (menu));

    offset.x = offset_x;
    offset.y = offset_y;

    /* The event button needs to be 0 if we're popping up this menu from
     * a button release, else a 2nd click outside the menu with any button
     * other than the one that invoked the menu will be ignored (instead
     * of dismissing the menu). This is a subtle fragility of the GTK menu code.
     */

    if (event) {
        button = event->type == GDK_BUTTON_RELEASE
            ? 0
            : event->button;
    } else {
        button = 0;
    }

    gtk_menu_popup (menu,                   /* menu */
                    NULL,                   /* parent_menu_shell */
                    NULL,                   /* parent_menu_item */
                    NULL,
                    &offset,                /* data */
                    button,                 /* button */
                    event ? event->time : GDK_CURRENT_TIME); /* activate_time */

    g_object_ref_sink (menu);
    g_object_unref (menu);
}

GdkScreen *
eel_gtk_widget_get_screen (GtkWidget *widget)
{
    GdkScreen *screen = NULL;

    if (G_UNLIKELY (widget == NULL))
        screen = gdk_screen_get_default ();
    else if (GTK_IS_WIDGET (widget))
        screen = gtk_widget_get_screen (widget);

    return screen;
}
