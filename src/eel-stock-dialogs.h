/* eel-stock-dialogs.c: Various standard dialogs for Eel.
 *
 * Copyright (C) 2000 Eazel, Inc.
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
 * Authors: Darin Adler <darin@eazel.com>
 */

#ifndef EEL_STOCK_DIALOGS_H
#define EEL_STOCK_DIALOGS_H

#include <gtk/gtk.h>

GtkDialog *
eel_show_error_dialog (const char *primary_text,
		       const char *secondary_text,
		       GtkWindow *parent);

#endif /* EEL_STOCK_DIALOGS_H */
