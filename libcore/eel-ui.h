/* helper functions for GtkUIManager stuff
 * imported from nautilus
 *
 * Copyright (C) 2004 Red Hat, Inc.
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
   Boston, MA 02110-1335 USA.
 *
 *  Authors: Alexander Larsson <alexl@redhat.com>
 */

#ifndef EEL_UI_H
#define EEL_UI_H

#include <gtk/gtk.h>

void        eel_ui_unmerge_ui               (GtkUIManager      *ui_manager,
                                             guint             *merge_id,
                                             GtkActionGroup   **action_group);
void        eel_ui_prepare_merge_ui         (GtkUIManager       *ui_manager,
                                             const char         *name,
                                             guint              *merge_id,
                                             GtkActionGroup    **action_group);
const char *eel_ui_string_get               (const char        *filename);

#endif /* EEL_UI_H */
