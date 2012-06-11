/* marlin-dnd.h - Common Drag & drop handling code 
 *
 * Copyright (c) 2005-2006 Benedikt Meurer <benny@xfce.org>
 * Copyright (c) 2009-2011 Jannis Pohlmann <jannis@xfce.org>
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
 */

#ifndef MARLIN_DND_H
#define MARLIN_DND_H

#include <gtk/gtk.h>
#include "gof-file.h"

typedef enum {
    MARLIN_DND_ACTION_FIRST = GDK_ACTION_ASK << 1,
    MARLIN_DND_ACTION_SET_AS_BACKGROUND = MARLIN_DND_ACTION_FIRST << 0,
    MARLIN_DND_ACTION_SET_AS_FOLDER_BACKGROUND = MARLIN_DND_ACTION_FIRST << 1,
    MARLIN_DND_ACTION_SET_AS_GLOBAL_BACKGROUND = MARLIN_DND_ACTION_FIRST << 2
} MarlinDndAction;


GdkDragAction	marlin_drag_drop_action_ask (GtkWidget *widget, GdkDragAction possible_actions);
gboolean        marlin_dnd_perform          (GtkWidget       *widget,
                                             GOFFile         *file,
                                             GList           *file_list,
                                             GdkDragAction   action,
                                             GClosure        *new_files_closure);

#endif
