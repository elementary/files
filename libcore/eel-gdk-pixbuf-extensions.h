/* eel-gdk-pixbuf-extensions.c: Routines to augment what's in gdk-pixbuf.
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
 *          Ramiro Estrugo <ramiro@eazel.com>
 */

#ifndef EEL_GDK_PIXBUF_EXTENSIONS_H
#define EEL_GDK_PIXBUF_EXTENSIONS_H

#include <gdk-pixbuf/gdk-pixbuf.h>
#include <gdk/gdk.h>

/* return a lightened pixbuf for pre-lighting */
GdkPixbuf   *eel_create_spotlight_pixbuf (GdkPixbuf *source_pixbuf);

/* return a darkened pixbuf for selection hiliting */
GdkPixbuf   *eel_create_darkened_pixbuf  (GdkPixbuf *source_pixbuf,
                                          int        saturation,
                                          int        darken);

/* return a pixbuf colorized with the color specified by the parameters */
GdkPixbuf   *eel_create_colorized_pixbuf (GdkPixbuf *source_pixbuf,
                                          GdkRGBA *color);

GdkPixbuf   *eel_gdk_pixbuf_lucent (GdkPixbuf *source,
                                    guint percent);

#endif /* EEL_GDK_PIXBUF_EXTENSIONS_H */
