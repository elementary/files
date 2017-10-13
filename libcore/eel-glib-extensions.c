/* eel-glib-extensions.c - implementation of new functions that conceptually
 * belong in glib. Perhaps some of these will be
 * actually rolled into glib someday.
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
 * Authors: John Sullivan <sullivan@eazel.com>
 *          ammonkey <am.monkeyd@gmail.com>
 */

#include "eel-glib-extensions.h"
#include <sys/time.h>
#include <math.h>

//~ /**
 //~ * eel_add_weak_pointer
 //~ *
 //~ * Nulls out a saved reference to an object when the object gets destroyed.
 //~ *
 //~ * @pointer_location: Address of the saved pointer.
//~ **/
//~ void
//~ eel_add_weak_pointer (gpointer pointer_location)
//~ {
    //~ gpointer *object_location;

    //~ g_return_if_fail (pointer_location != NULL);

    //~ object_location = (gpointer *) pointer_location;
    //~ if (*object_location == NULL) {
        //~ /* The reference is NULL, nothing to do. */
        //~ return;
    //~ }

    //~ g_return_if_fail (G_IS_OBJECT (*object_location));

    //~ g_object_add_weak_pointer (G_OBJECT (*object_location),
                               //~ object_location);
//~ }

//~ /**
 //~ * eel_remove_weak_pointer
 //~ *
 //~ * Removes the weak pointer that was added by eel_add_weak_pointer.
 //~ * Also nulls out the pointer.
 //~ *
 //~ * @pointer_location: Pointer that was passed to eel_add_weak_pointer.
//~ **/
//~ void
//~ eel_remove_weak_pointer (gpointer pointer_location)
//~ {
    //~ gpointer *object_location;

    //~ g_return_if_fail (pointer_location != NULL);

    //~ object_location = (gpointer *) pointer_location;
    //~ if (*object_location == NULL) {
        //~ /* The object was already destroyed and the reference
         //~ * nulled out, nothing to do.
         //~ */
        //~ return;
    //~ }

    //~ g_return_if_fail (G_IS_OBJECT (*object_location));

    //~ g_object_remove_weak_pointer (G_OBJECT (*object_location),
                                  //~ object_location);

    //~ *object_location = NULL;
//~ }


