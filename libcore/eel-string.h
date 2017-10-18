/* -*- Mode: C; indent-tabs-mode: t; c-basic-offset: 8; tab-width: 8 -*-
 *
 * eel-string.h: String routines to augment <string.h>.
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

#ifndef EEL_STRING_H
#define EEL_STRING_H

#include <glib.h>
#include <string.h>
#include <stdarg.h>

/* We use the "str" abbrevation to mean char * string, since
 * "string" usually means g_string instead. We use the "istr"
 * abbreviation to mean a case-insensitive char *.
 */

int      eel_strcmp                        (const char    *str_a,
                                            const char    *str_b);
/* Other basic string operations. */
gboolean eel_str_is_empty                  (const char    *str_or_null);
gboolean eel_str_is_equal                  (const char    *str_a,
                                            const char    *str_b);
/* Escape function for '_' character. */
char *   eel_str_double_underscores        (const char    *str);

/* Middle truncate a string to a maximum of truncate_length characters.
 * The resulting string will be truncated in the middle with a "..."
 * delimiter.
 */
char *   eel_str_middle_truncate           (const char    *str,
                                            guint          truncate_length);


typedef struct {
    char character;
    char *(*to_string) (char *format, va_list va);
    void (*skip) (va_list *va);
} EelPrintfHandler;

char *eel_strdup_vprintf_with_custom (EelPrintfHandler *custom,
                                      const char *format,
                                      va_list va);
#endif /* EEL_STRING_H */
