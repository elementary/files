/* -*- Mode: C; indent-tabs-mode: t; c-basic-offset: 8; tab-width: 8 -*-

   eel-debug.c: Eel debugging aids.

   Copyright (C) 2000, 2001 Eazel, Inc.

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public License as
   published by the Free Software Foundation, Inc.,; either version 2 of the
   License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this program; if not, write to the
   Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
   Boston, MA 02110-1335 USA.

   Author: Darin Adler <darin@eazel.com>
*/

#include "eel-debug.h"

#include <glib.h>
#include <signal.h>
#include <stdio.h>

typedef struct {
    gpointer data;
    GFreeFunc function;
} ShutdownFunction;

static GList *shutdown_functions;

void
eel_debug_shut_down (void)
{
    ShutdownFunction *f;

    while (shutdown_functions != NULL) {
        f = shutdown_functions->data;
        shutdown_functions = g_list_remove (shutdown_functions, f);

        f->function (f->data);
        g_free (f);
    }
}

void
eel_debug_call_at_shutdown (EelFunction function)
{
    eel_debug_call_at_shutdown_with_data ((GFreeFunc) function, NULL);
}

void
eel_debug_call_at_shutdown_with_data (GFreeFunc function, gpointer data)
{
    ShutdownFunction *f;

    f = g_new (ShutdownFunction, 1);
    f->data = data;
    f->function = function;
    shutdown_functions = g_list_prepend (shutdown_functions, f);
}
