/* eel-stock-dialogs.c: Various standard dialogs for Eel.
 *
 * Copyright (C) 2000 Eazel, Inc.
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
 * Authors: Darin Adler <darin@eazel.com>
 */

#ifndef EEL_STOCK_DIALOGS_H
#define EEL_STOCK_DIALOGS_H

#include <gtk/gtk.h>

GtkDialog *
eel_show_warning_dialog (const char *primary_text,
                         const char *secondary_text,
                         GtkWindow *parent);

GtkDialog *
eel_show_error_dialog (const char *primary_text,
                       const char *secondary_text,
                       GtkWindow *parent);

void
marlin_dialogs_show_error (gpointer      parent,
                           const GError *error,
                           const gchar  *format,
                           ...);

void eel_gtk_message_dialog_set_details_label (GtkMessageDialog *dialog,
                                               const gchar *details_text);

#endif /* EEL_STOCK_DIALOGS_H */
