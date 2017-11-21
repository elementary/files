/*-
 * Copyright (c) 2009-2010 Jannis Pohlmann <jannis@xfce.org>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, Inc.,; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

//#include <thunar/thunar-file.h>
#include "eel-gio-extensions.h"


/**
 * eel_g_file_list_new_from_string:
 * @string : a string representation of an URI list.
 *
 * Splits an URI list conforming to the text/uri-list
 * mime type defined in RFC 2483 into individual URIs,
 * discarding any comments and whitespace. The resulting
 * list will hold one #GFile for each URI.
 *
 * If @string contains no URIs, this function
 * will return %NULL.
 *
 * Return value: the list of #GFile<!---->s or %NULL.
**/
GList *
eel_g_file_list_new_from_string (const gchar *string)
{
    GList  *list = NULL;
    gchar **uris;
    gsize   n;

    uris = g_uri_list_extract_uris (string);

    for (n = 0; uris != NULL && uris[n] != NULL; ++n)
        list = g_list_append (list, g_file_new_for_uri (uris[n]));

    g_strfreev (uris);

    return list;
}

gchar *
eel_g_file_get_location (GFile *file)
{
    gchar *location;

    g_return_val_if_fail (G_IS_FILE (file), NULL);

    location = g_file_get_path (file);
    if (location == NULL)
        location = g_file_get_uri (file);

    return location;
}

GFile *
eel_g_file_get_trash_original_file (const gchar *string)
{
    GFile *location = NULL;
    char *filename;

    if (string != NULL) {
        /* file name is stored in URL encoding */
        filename = g_uri_unescape_string (string, "");
        location = g_file_new_for_path (filename);
        g_free (filename);
    }

    return location;
}

GKeyFile *
eel_g_file_query_key_file (GFile *file, GCancellable *cancellable, GError **error)
{
    GKeyFile *key_file;
    gchar    *contents = NULL;
    gsize     length;

    g_return_val_if_fail (G_IS_FILE (file), NULL);
    g_return_val_if_fail (cancellable == NULL || G_IS_CANCELLABLE (cancellable), NULL);
    g_return_val_if_fail (error == NULL || *error == NULL, NULL);

    /* try to load the entire file into memory */
    if (!g_file_load_contents (file, cancellable, &contents, &length, NULL, error))
        return NULL;

    /* allocate a new key file */
    key_file = g_key_file_new ();

    /* try to parse the key file from the contents of the file */
    if (G_LIKELY (length == 0
                  || g_key_file_load_from_data (key_file, contents, length,
                                                G_KEY_FILE_KEEP_COMMENTS
                                                | G_KEY_FILE_KEEP_TRANSLATIONS,
                                                error)))
    {
        g_free (contents);
        return key_file;
    }
    else
    {
        g_free (contents);
        g_key_file_free (key_file);
        return NULL;
    }
}

GFile *
eel_g_file_ref (GFile *file)
{
    if (file == NULL) {
        return NULL;
    }
    g_return_val_if_fail (G_FILE (file), NULL);

    return g_object_ref (file);
}

void
eel_g_file_unref (GFile *file)
{
    if (file == NULL) {
        return;
    }

    g_return_if_fail (G_FILE (file));

    g_object_unref (file);
}

