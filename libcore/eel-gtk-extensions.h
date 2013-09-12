/* eel-gtk-extensions.h - interface for new functions that operate on
  			       gtk classes. Perhaps some of these should be
  			       rolled into gtk someday.

   Copyright (C) 1999, 2000, 2001 Eazel, Inc.

   The Gnome Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public License as
   published by the Free Software Foundation; either version 2 of the
   License, or (at your option) any later version.

   The Gnome Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with the Gnome Library; see the file COPYING.LIB.  If not,
   write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
   Boston, MA 02111-1307, USA.

   Authors: John Sullivan <sullivan@eazel.com>
            Ramiro Estrugo <ramiro@eazel.com>
*/

#ifndef EEL_GTK_EXTENSIONS_H
#define EEL_GTK_EXTENSIONS_H

#include <gtk/gtk.h>
#include "eel-gdk-extensions.h"

#define EEL_DEFAULT_POPUP_MENU_DISPLACEMENT 	2

char	    *eel_gtk_window_get_geometry_string (GtkWindow *window);
void	    eel_gtk_window_set_initial_geometry_from_string (GtkWindow *window,
							     const char *geometry_string,
							     guint minimum_width,
							     guint minimum_height,
							     gboolean ignore_position);

void	    eel_gtk_window_set_initial_geometry (GtkWindow *window,
						 EelGdkGeometryFlags geometry_flags,
						 int left,
						 int top,
						 guint width,
						 guint height);

//void    eel_gtk_adjustment_set_value (GtkAdjustment *adjustment, float value);
GtkMenuItem *eel_gtk_menu_append_separator (GtkMenu *menu);

void        eel_pop_up_context_menu (GtkMenu	     *menu,
                                     gint16	      offset_x,
                                     gint16	      offset_y,
                                     GdkEventButton *event);
void        eel_gtk_widget_set_shown (GtkWidget *widget, gboolean shown);

void        eel_gtk_tree_view_set_activate_on_single_click (GtkTreeView *tree_view,
                                                            gboolean should_activate);
GdkScreen   *eel_gtk_widget_get_screen (GtkWidget *widget);

#endif /* EEL_GTK_EXTENSIONS_H */
