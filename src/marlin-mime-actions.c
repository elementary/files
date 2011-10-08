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

#include <config.h>

#include "marlin-mime-actions.h"

static gboolean
file_has_local_path (GOFFile *file)
{
	char *path;
	gboolean res;
	
	/* Don't only check _is_native, because we want to support
	   using the fuse path */
	if (g_file_is_native (file->location)) {
		res = TRUE;
	} else {
		path = g_file_get_path (file->location);
		res = path != NULL;
		g_free (path);
	}
	
	return res;
}

static int
file_compare_by_mime_type (GOFFile *a, GOFFile *b)
{
	return strcmp (a->ftype, b->ftype);
}

static char *
gof_get_parent_uri (GOFFile *file)
{
    return (file->directory != NULL) ? g_file_get_uri (file->directory) : NULL;
}

static int
file_compare_by_parent_uri (GOFFile *a, GOFFile *b) {
	char *parent_uri_a, *parent_uri_b;
	int ret;

	parent_uri_a = gof_get_parent_uri (a);
	parent_uri_b = gof_get_parent_uri (b);

	ret = strcmp (parent_uri_a, parent_uri_b);

	g_free (parent_uri_a);
	g_free (parent_uri_b);

	return ret;
}

GAppInfo *
marlin_mime_get_default_application_for_file (GOFFile *file)
{
	GAppInfo *app;
	char *uri_scheme;

	app = g_app_info_get_default_for_type (file->ftype, !file_has_local_path (file));

	if (app == NULL) {
		uri_scheme =  g_file_get_uri_scheme (file->location);
		if (uri_scheme != NULL) {
			app = g_app_info_get_default_for_uri_scheme (uri_scheme);
			g_free (uri_scheme);
		}
	}
	
	return app;
}

GAppInfo *
marlin_mime_get_default_application_for_files (GList *files)
{
	GList *l, *sorted_files;
	GOFFile *file;
	GAppInfo *app, *one_app;

	g_assert (files != NULL);

	sorted_files = g_list_sort (g_list_copy (files), (GCompareFunc) file_compare_by_mime_type);

	app = NULL;
	for (l = sorted_files; l != NULL; l = l->next) {
		file = l->data;

		if (l->prev &&
		    file_compare_by_mime_type (file, l->prev->data) == 0 &&
		    file_compare_by_parent_uri (file, l->prev->data) == 0) {
			continue;
		}

		one_app = marlin_mime_get_default_application_for_file (file);
		if (one_app == NULL || (app != NULL && !g_app_info_equal (app, one_app))) {
			if (app) {
				g_object_unref (app);
			}
			if (one_app) {
				g_object_unref (one_app);
			}
			app = NULL;
			break;
		}

		if (app == NULL) {
			app = one_app;
		} else {
			g_object_unref (one_app);
		}
	}

	g_list_free (sorted_files);

	return app;
}


