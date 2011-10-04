/*
 * Ubuntu One Nautilus plugin
 *
 * Authors: Alejandro J. Cura <alecu@canonical.com>
 *
 * Copyright 2010 Canonical Ltd.
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 3, as published
 * by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#include <string.h>
#include <glib.h>

static gint
compare_glongs (gconstpointer a,
	        gconstpointer b,
		gpointer user_data)
{
	return (glong) a - (glong) b;
}


static void
tree_of_arrays_insert (GTree *tree,
		       gpointer key,
		       gpointer value)
{
	GPtrArray *array = g_tree_lookup (tree, key);
	if (array == NULL) {
		array = g_ptr_array_new ();
		g_tree_insert (tree, key, array);
	}
	g_ptr_array_add (array, value);
}


static void
destroy_tree_array (gpointer data)
{
	g_ptr_array_free (data, TRUE);
}

typedef struct {
	GString *built_string;
	gchar *source_string;
	gchar *source_cursor;
} BuildResultsData;


static void
append_array_strings (gpointer data,
		      gpointer user_data)
{
	g_string_append (user_data, data);
}


static gboolean
build_results (gpointer key,
	       gpointer value,
	       gpointer data)
{
	BuildResultsData* results_data = data;
	glong tag_start = (glong)key;
	gchar *tag_start_ptr = g_utf8_offset_to_pointer (results_data->source_string,
							 tag_start);
	glong len = tag_start_ptr - results_data->source_cursor;

	gchar *escaped_str = g_markup_escape_text (results_data->source_cursor,
						   len);
	
	g_string_append (results_data->built_string,
			 escaped_str);
	g_free (escaped_str);
	results_data->source_cursor += len;

	g_ptr_array_foreach (value,
			     append_array_strings,
			     results_data->built_string);
	return FALSE;
}


gchar *
highlight_result(gchar *needles, gchar *haystack)
{
	gchar **split_needles;
	GTree *result_parts;
	gchar *folded_needles;
	gchar *folded_haystack;
	gchar **needle;
	gchar *escaped_str;
	BuildResultsData results_data;

	folded_needles = g_utf8_casefold (needles, -1);
	folded_haystack = g_utf8_casefold (haystack, -1);

	results_data.built_string = g_string_new ("");
	results_data.source_string = haystack;
	results_data.source_cursor = haystack;

	result_parts = g_tree_new_full (compare_glongs,
					NULL,
					NULL,
					destroy_tree_array);
	
	split_needles = g_strsplit (folded_needles, " ", 0);
	needle = split_needles;
	while (*needle != NULL) {
		gchar *search_start;
		gchar *start_ptr;
		glong needle_len = g_utf8_strlen (*needle, -1);
		if (needle_len < 1) {
			needle++;
			continue;
		}
		search_start = folded_haystack;
		start_ptr = g_strstr_len (search_start, -1, *needle);
		while (start_ptr != NULL) {
			glong start = g_utf8_pointer_to_offset (folded_haystack,
								start_ptr);
			glong end = start + g_utf8_strlen (*needle, -1);
			tree_of_arrays_insert (result_parts,
					       (gpointer) start,
					       "<b>");
			tree_of_arrays_insert (result_parts,
					       (gpointer) end,
					       "</b>");
			search_start = g_utf8_next_char (start_ptr);
			start_ptr = g_strstr_len (search_start,
			                          -1,
						  *needle);
		}
		needle++;
	}
	g_free (folded_needles);
	g_free (folded_haystack);


	g_tree_foreach (result_parts, build_results, &results_data);

	escaped_str = g_markup_escape_text (results_data.source_cursor, -1);
	g_string_append (results_data.built_string,
			 escaped_str);
	g_free (escaped_str);

	g_tree_destroy (result_parts);
	g_strfreev (split_needles);
	return g_string_free (results_data.built_string,
			      FALSE);
}
