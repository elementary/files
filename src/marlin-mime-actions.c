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
    return g_strcmp0 (gof_file_get_ftype (a), gof_file_get_ftype (b));
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

    app = gof_file_get_default_handler (file);

    if (app == NULL) {
        uri_scheme = g_file_get_uri_scheme (file->location);
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


static int
application_compare_by_name (const GAppInfo *app_a,
			     const GAppInfo *app_b)
{
	return g_utf8_collate (g_app_info_get_display_name ((GAppInfo *)app_a),
			       g_app_info_get_display_name ((GAppInfo *)app_b));
}

static int
application_compare_by_id (const GAppInfo *app_a,
			   const GAppInfo *app_b)
{
	const char *id_a, *id_b;

	id_a = g_app_info_get_id ((GAppInfo *)app_a);
	id_b = g_app_info_get_id ((GAppInfo *)app_b);

	if (id_a == NULL && id_b == NULL) {
		if (g_app_info_equal ((GAppInfo *)app_a, (GAppInfo *)app_b)) {
			return 0;
		}
		if ((gsize)app_a < (gsize) app_b) {
			return -1;
		}
		return 1;
	}

	if (id_a == NULL) {
		return -1;
	}
	
	if (id_b == NULL) {
		return 1;
	}
	
	
	return strcmp (id_a, id_b);
}

static GList*
filter_non_uri_apps (GList *apps)
{
	GList *l, *next;
	GAppInfo *app;

	for (l = apps; l != NULL; l = next) {
		app = l->data;
		next = l->next;
		
		if (!g_app_info_supports_uris (app)) {
			apps = g_list_delete_link (apps, l);
			g_object_unref (app);
		}
	}
	return apps;
}

GList *
marlin_mime_get_applications_for_file (GOFFile *file)
{
	char *uri_scheme;
	GList *result;
	GAppInfo *uri_handler;

	result = g_app_info_get_all_for_type (gof_file_get_ftype (file));

    uri_scheme = g_file_get_uri_scheme (file->location);
	if (uri_scheme != NULL) {
		uri_handler = g_app_info_get_default_for_uri_scheme (uri_scheme);
		if (uri_handler) {
			result = g_list_prepend (result, uri_handler);
		}
		g_free (uri_scheme);
	}
	
	if (!file_has_local_path (file)) {
		/* Filter out non-uri supporting apps */
		result = filter_non_uri_apps (result);
	}
	
	result = g_list_sort (result, (GCompareFunc) application_compare_by_name);

	return (result);
}


/* returns an intersection of two mime application lists,
 * and returns a new list, freeing a, b and all applications
 * that are not in the intersection set.
 * The lists are assumed to be pre-sorted by their IDs */
static GList *
intersect_application_lists (GList *a, GList *b)
{
	GList *l, *m;
	GList *ret;
	GAppInfo *a_app, *b_app;
	int cmp;

	ret = NULL;

	l = a;
	m = b;

	while (l != NULL && m != NULL) {
		a_app = (GAppInfo *) l->data;
		b_app = (GAppInfo *) m->data;

		cmp = application_compare_by_id (a_app, b_app);
		if (cmp > 0) {
			g_object_unref (b_app);
			m = m->next;
		} else if (cmp < 0) {
			g_object_unref (a_app);
			l = l->next;
		} else {
			g_object_unref (b_app);
			ret = g_list_prepend (ret, a_app);
			l = l->next;
			m = m->next;
		}
	}

	g_list_foreach (l, (GFunc) g_object_unref, NULL);
	g_list_foreach (m, (GFunc) g_object_unref, NULL);

	g_list_free (a);
	g_list_free (b);

	return g_list_reverse (ret);
}

GList *
marlin_mime_get_applications_for_files (GList *files)
{
	GList *l, *sorted_files;
	GOFFile *file;
	GList *one_ret, *ret;

	g_assert (files != NULL);

	sorted_files = g_list_sort (g_list_copy (files), (GCompareFunc) file_compare_by_mime_type);

	ret = NULL;
	for (l = sorted_files; l != NULL; l = l->next) {
		file = l->data;

		if (l->prev &&
		    file_compare_by_mime_type (file, l->prev->data) == 0 &&
		    file_compare_by_parent_uri (file, l->prev->data) == 0) {
			continue;
		}

		one_ret = marlin_mime_get_applications_for_file (file);
		one_ret = g_list_sort (one_ret, (GCompareFunc) application_compare_by_id);
		if (ret != NULL) {
			ret = intersect_application_lists (ret, one_ret);
		} else {
			ret = one_ret;
		}

		if (ret == NULL) {
			break;
		}
	}

	g_list_free (sorted_files);

	ret = g_list_sort (ret, (GCompareFunc) application_compare_by_name);
	
	return ret;
}


