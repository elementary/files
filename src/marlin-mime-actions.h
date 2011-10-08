/* nautilus-mime-actions.h - uri-specific versions of mime action functions
 *
 * Copyright (C) 2000 Eazel, Inc.
 * Copyright (c) 2011 ammonkey <am.monkeyd@gmail.com>
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
 * Authors: Maciej Stachowiak <mjs@eazel.com>
 *          ammonkey <am.monkeyd@gmail.com>
 */

#ifndef MARLIN_MIME_ACTIONS_H
#define MARLIN_MIME_ACTIONS_H

#include <gio/gio.h>
#include <gof-file.h>

GAppInfo *             marlin_mime_get_default_application_for_file     (GOFFile            *file);
//GList *                marlin_mime_get_applications_for_file            (GOFFile            *file);

GAppInfo *             marlin_mime_get_default_application_for_files    (GList                   *files);
/*GList *                marlin_mime_get_applications_for_files           (GList                   *file);*/

#endif /* MARLIN_MIME_ACTIONS_H */
