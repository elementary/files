/* eel-gtk-extensions.h - interface for new functions that operate on
                   gtk classes. Perhaps some of these should be
                   rolled into gtk someday.

   Copyright (C) 1999, 2000, 2001 Eazel, Inc.

   The Gnome Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public License as
   published by the Free Software Foundation, Inc.,; either version 2 of the
   License, or (at your option) any later version.

   The Gnome Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with the Gnome Library; see the file COPYING.LIB.  If not,
   write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
   Boston, MA 02110-1335 USA.

   Authors: John Sullivan <sullivan@eazel.com>
            Ramiro Estrugo <ramiro@eazel.com>
*/

#ifndef EEL_GTK_EXTENSIONS_H
#define EEL_GTK_EXTENSIONS_H

#include <gtk/gtk.h>

void        eel_pop_up_context_menu (GtkMenu         *menu,
                                     gint16       offset_x,
                                     gint16       offset_y,
                                     GdkEventButton *event);

GdkScreen   *eel_gtk_widget_get_screen (GtkWidget *widget);

#endif /* EEL_GTK_EXTENSIONS_H */
