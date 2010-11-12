/* -*- Mode: C; indent-tabs-mode: t; c-basic-offset: 8; tab-width: 8 -*- */
/*
 * Copyright (C) 2010 ammonkey
 *
 * This library is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License
 * version 3.0 as published by the Free Software Foundation.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License version 3.0 for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library. If not, see
 * <http://www.gnu.org/licenses/>.
 *
 * Author: ammonkey <am.monkeyd@gmail.com>
 */

#include "gof-file.h"
#include <stdlib.h>
#include <string.h>
#include "nautilus-icon-info.h"
#include "marlin-global-preferences.h" 
#include "eel-i18n.h"
#include "eel-fcts.h"


/*struct _GOFFilePrivate {
	GFileInfo* _file_info;
};*/


//#define gof_FILE_GET_PRIVATE(o) (G_TYPE_INSTANCE_GET_PRIVATE ((o), GOF_TYPE_FILE, GOFFilePrivate))
/*enum  {
	gof_FILE_DUMMY_PROPERTY,
	gof_FILE_NAME,
	gof_FILE_SIZE,
	gof_FILE_DIRECTORY
};*/

enum {
	FM_LIST_MODEL_FILE_COLUMN,
        FM_LIST_MODEL_ICON,
        FM_LIST_MODEL_FILENAME,
        FM_LIST_MODEL_SIZE,
        FM_LIST_MODEL_TYPE,
        FM_LIST_MODEL_MODIFIED,
	/*FM_LIST_MODEL_SUBDIRECTORY_COLUMN,
	FM_LIST_MODEL_SMALLEST_ICON_COLUMN,
	FM_LIST_MODEL_SMALLER_ICON_COLUMN,
	FM_LIST_MODEL_SMALL_ICON_COLUMN,
	FM_LIST_MODEL_STANDARD_ICON_COLUMN,
	FM_LIST_MODEL_LARGE_ICON_COLUMN,
	FM_LIST_MODEL_LARGER_ICON_COLUMN,
	FM_LIST_MODEL_LARGEST_ICON_COLUMN,
	FM_LIST_MODEL_SMALLEST_EMBLEM_COLUMN,
	FM_LIST_MODEL_SMALLER_EMBLEM_COLUMN,
	FM_LIST_MODEL_SMALL_EMBLEM_COLUMN,
	FM_LIST_MODEL_STANDARD_EMBLEM_COLUMN,
	FM_LIST_MODEL_LARGE_EMBLEM_COLUMN,
	FM_LIST_MODEL_LARGER_EMBLEM_COLUMN,
	FM_LIST_MODEL_LARGEST_EMBLEM_COLUMN,
	FM_LIST_MODEL_FILE_NAME_IS_EDITABLE_COLUMN,*/
	FM_LIST_MODEL_NUM_COLUMNS
};


//static void gof_file_get_property (GObject * object, guint property_id, GValue * value, GParamSpec * pspec);
//static void gof_file_set_property (GObject * object, guint property_id, const GValue * value, GParamSpec * pspec);

G_DEFINE_TYPE (GOFFile, gof_file, G_TYPE_OBJECT)

#define SORT_LAST_CHAR1 '.'
#define SORT_LAST_CHAR2 '#'

/*        
static int _vala_strcmp0 (const char * str1, const char * str2) {
	if (str1 == NULL) {
		return -(str1 != str2);
	}
	if (str2 == NULL) {
		return str1 != str2;
	}
	return strcmp (str1, str2);
}*/

#if 0
gint gof_file_NameCompareFunc (GOFFile* a, GOFFile* b) {
	gint result = 0;
	g_return_val_if_fail (a != NULL, 0);
	g_return_val_if_fail (b != NULL, 0);
	if (gof_file_get_directory (a) != gof_file_get_directory (b)) {
		result = ((gint) gof_file_get_directory (b)) - ((gint) gof_file_get_directory (a));
		return result;
	} else {
		char* _tmp1_ = g_utf8_casefold (gof_file_get_name (b), -1);
		char* _tmp0_ = g_utf8_casefold (gof_file_get_name (a), -1);
		if (_vala_strcmp0 (_tmp0_, _tmp1_) < 0) {
                        _g_free0 (_tmp1_);
                        _g_free0 (_tmp0_);
			return -1;
		} else {
			char* _tmp4_;
			char* _tmp3_;
			gboolean _tmp5_;
			if ((_tmp5_ = _vala_strcmp0 (_tmp3_ = g_utf8_casefold (gof_file_get_name (a), -1), _tmp4_ = g_utf8_casefold (gof_file_get_name (b), -1)) == 0, _g_free0 (_tmp4_), _g_free0 (_tmp3_), _tmp5_)) {
				result = 0;
				return result;
			} else {
				result = 1;
				return result;
			}
		}
	}
}

gint gof_file_SizeCompareFunc (GOFFile* a, GOFFile* b) {
	gint result = 0;
	g_return_val_if_fail (a != NULL, 0);
	g_return_val_if_fail (b != NULL, 0);
	if (gof_file_get_directory (a) != gof_file_get_directory (b)) {
		result = ((gint) gof_file_get_directory (b)) - ((gint) gof_file_get_directory (a));
		return result;
	} else {
		if (gof_file_get_size (a) < gof_file_get_size (b)) {
			result = -1;
			return result;
		} else {
			if (gof_file_get_size (a) > gof_file_get_size (b)) {
				result = 1;
				return result;
			} else {
				result = 0;
				return result;
			}
		}
	}
}
#endif

//GOFFile* gof_file_new (GFileInfo* file_info, GFileEnumerator *enumerator)
GOFFile* gof_file_new (GFileInfo* file_info, GFile *dir)
{
	GOFFile * self;
        NautilusIconInfo *nicon;

	g_return_val_if_fail (file_info != NULL, NULL);
	self = (GOFFile*) g_object_new (GOF_TYPE_FILE, NULL);
	self->info = file_info;
        //self->parent_dir = g_file_enumerator_get_container (enumerator);
        self->directory = dir;
        //printf ("test parent_dir %s\n", g_file_get_uri(self->directory));
        //g_object_ref (self->directory);
	self->name = g_file_info_get_name (file_info);
        self->location = g_file_get_child(self->directory, self->name);
        self->ftype = g_file_info_get_attribute_string (file_info, G_FILE_ATTRIBUTE_STANDARD_FAST_CONTENT_TYPE);
        self->utf8_collation_key = g_utf8_collate_key (self->name, -1);
	self->size = (guint64) g_file_info_get_size (file_info);
        self->format_size = g_format_size_for_display(self->size);
        self->file_type = g_file_info_get_file_type(file_info);
	//self->is_directory = (self->file_type & G_FILE_TYPE_DIRECTORY) != 0;
	self->is_directory = (self->file_type == G_FILE_TYPE_DIRECTORY);
        self->icon = g_content_type_get_icon (self->ftype);
        self->is_hidden = g_file_info_get_is_hidden (file_info);
        self->modified = g_file_info_get_attribute_uint64 (file_info, G_FILE_ATTRIBUTE_TIME_MODIFIED);

        nicon = nautilus_icon_info_lookup (self->icon, 16);
        self->pix = nautilus_icon_info_get_pixbuf_nodefault (nicon);
        g_object_unref (nicon);
	
        return self;
}


GFileInfo* gof_file_get_file_info (GOFFile* self) {
	GFileInfo* result;
	g_return_val_if_fail (self != NULL, NULL);
	result = self->info;
	return result;
}

static void gof_file_init (GOFFile *self) {
        ;
}

static void gof_file_finalize (GObject* obj) {
	GOFFile *file;

	file = GOF_FILE (obj);
        printf ("%s %s\n", G_STRFUNC, file->name);
	_g_object_unref0 (file->info);
	_g_object_unref0 (file->location);
        g_free(file->utf8_collation_key);
        g_free(file->format_size);
        _g_object_unref0 (file->icon);
        _g_object_unref0 (file->pix);

	G_OBJECT_CLASS (gof_file_parent_class)->finalize (obj);
}

static void gof_file_class_init (GOFFileClass * klass) {
	gof_file_parent_class = g_type_class_peek_parent (klass);
	//g_type_class_add_private (klass, sizeof (GOFFilePrivate));
	/*G_OBJECT_CLASS (klass)->get_property = gof_file_get_property;
	G_OBJECT_CLASS (klass)->set_property = gof_file_set_property;*/
	G_OBJECT_CLASS (klass)->finalize = gof_file_finalize;
	/*g_object_class_install_property (G_OBJECT_CLASS (klass), gof_FILE_NAME, g_param_spec_string ("name", "name", "name", NULL, G_PARAM_STATIC_NAME | G_PARAM_STATIC_NICK | G_PARAM_STATIC_BLURB | G_PARAM_READABLE));
	g_object_class_install_property (G_OBJECT_CLASS (klass), gof_FILE_SIZE, g_param_spec_uint64 ("size", "size", "size", 0, G_MAXUINT64, 0U, G_PARAM_STATIC_NAME | G_PARAM_STATIC_NICK | G_PARAM_STATIC_BLURB | G_PARAM_READABLE));
	g_object_class_install_property (G_OBJECT_CLASS (klass), gof_FILE_DIRECTORY, g_param_spec_boolean ("directory", "directory", "directory", FALSE, G_PARAM_STATIC_NAME | G_PARAM_STATIC_NICK | G_PARAM_STATIC_BLURB | G_PARAM_READABLE));*/
}

/*
static void gof_file_instance_init (GOFFile * self) {
	self->priv = gof_FILE_GET_PRIVATE (self);
}*/

#if 0
GType gof_file_get_type (void) {
	static volatile gsize gof_file_type_id__volatile = 0;
	if (g_once_init_enter (&gof_file_type_id__volatile)) {
		static const GTypeInfo g_define_type_info = { sizeof (GOFFileClass), (GBaseInitFunc) NULL, (GBaseFinalizeFunc) NULL, (GClassInitFunc) gof_file_class_init, (GClassFinalizeFunc) NULL, NULL, sizeof (GOFFile), 0, (GInstanceInitFunc) gof_file_instance_init, NULL };
		GType gof_file_type_id;
		gof_file_type_id = g_type_register_static (G_TYPE_OBJECT, "GOFFile", &g_define_type_info, 0);
		g_once_init_leave (&gof_file_type_id__volatile, gof_file_type_id);
	}
	return gof_file_type_id__volatile;
}
#endif

#if 0
static void gof_file_get_property (GObject * object, guint property_id, GValue * value, GParamSpec * pspec) {
	GOFFile * self;
	self = GOF_FILE (object);
	switch (property_id) {
		case gof_FILE_NAME:
		g_value_set_string (value, gof_file_get_name (self));
		break;
		case gof_FILE_SIZE:
		g_value_set_uint64 (value, gof_file_get_size (self));
		break;
		case gof_FILE_DIRECTORY:
		g_value_set_boolean (value, gof_file_get_directory (self));
		break;
		default:
		G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
		break;
	}
}


static void gof_file_set_property (GObject * object, guint property_id, const GValue * value, GParamSpec * pspec) {
	GOFFile * self;
	self = GOF_FILE (object);
	switch (property_id) {
		default:
		G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
		break;
	}
}
#endif

static int
compare_files_by_time (GOFFile *file1, GOFFile *file2)
{
	if (file1->modified < file2->modified)
		return -1;
        else if (file1->modified > file2->modified)
		return 1;

	return 0;
}

static int
compare_by_time (GOFFile *file1, GOFFile *file2)
{
        if (file1->is_directory && !file2->is_directory)
                return -1;
        if (file2->is_directory && !file1->is_directory)
                return 1;

	return compare_files_by_time (file1, file2);
}

static int
compare_by_type (GOFFile *file1, GOFFile *file2)
{
	/*char *type_string_1;
	char *type_string_2;
	int result;*/

	/* Directories go first. Then, if mime types are identical,
	 * don't bother getting strings (for speed). This assumes
	 * that the string is dependent entirely on the mime type,
	 * which is true now but might not be later.
	 */
	if (file1->is_directory && file2->is_directory)
		return 0;
	if (file1->is_directory)
		return -1;
	if (file2->is_directory)
		return +1;
#if 0	
	if (file1->ftype != NULL && file2->ftype != NULL &&
	    strcmp (eel_ref_str_peek (file_1->details->mime_type),
		    eel_ref_str_peek (file_2->details->mime_type)) == 0) {
		return 0;
	}

	type_string_1 = nautilus_file_get_type_as_string (file_1);
	type_string_2 = nautilus_file_get_type_as_string (file_2);

	result = g_utf8_collate (type_string_1, type_string_2);

	g_free (type_string_1);
	g_free (type_string_2);
#endif
	return (strcmp (file1->utf8_collation_key, file2->utf8_collation_key));
	//return result;
}

static int
compare_by_display_name (GOFFile *file1, GOFFile *file2)
{
	const char *name_1, *name_2;
	gboolean sort_last_1, sort_last_2;
	int compare;

        name_1 = file1->name;
        name_2 = file2->name;

	sort_last_1 = name_1[0] == SORT_LAST_CHAR1 || name_1[0] == SORT_LAST_CHAR2;
	sort_last_2 = name_2[0] == SORT_LAST_CHAR1 || name_2[0] == SORT_LAST_CHAR2;

	if (sort_last_1 && !sort_last_2) {
		compare = +1;
	} else if (!sort_last_1 && sort_last_2) {
		compare = -1;
	} else {
		compare = strcmp (file1->utf8_collation_key, file2->utf8_collation_key);
	}

	return compare;
}

static int
compare_files_by_size (GOFFile *file1, GOFFile *file2)
{
	if (file1->size < file2->size) {
		return -1;
	}
        else if (file1->size > file2->size) {
		return 1;
	}

	return 0;
}

static int
compare_by_size (GOFFile *file1, GOFFile *file2)
{
        if (file1->is_directory && !file2->is_directory)
                return -1;
        if (file2->is_directory && !file1->is_directory)
                return 1;

	/*if (file1->is_directory) {
		return compare_directories_by_count (file1, file2);
	} else {*/
		return compare_files_by_size (file1, file2);
	//}
}

static int
gof_file_compare_for_sort_internal (GOFFile *file1,
                                    GOFFile *file2,
                                    gboolean directories_first,
                                    gboolean reversed)
{
        if (directories_first) {
                if (file1->is_directory && !file2->is_directory) {
                        return -1;
                }
                if (file2->is_directory && !file1->is_directory) {
                        return 1;
                }
        }

        /*if (file1->details->sort_order < file2->details->sort_order) {
                return reversed ? 1 : -1;
        } else if (file_1->details->sort_order > file_2->details->sort_order) {
                return reversed ? -1 : 1;
        }*/

        return 0;
}

int
gof_file_compare_for_sort (GOFFile *file1,
                           GOFFile *file2,
                           gint sort_type,
                           gboolean directories_first,
                           gboolean reversed)
{
        int result;

        if (file1 == file2) {
                return 0;
        }

        result = gof_file_compare_for_sort_internal (file1, file2, directories_first, reversed);
        //printf ("res %d %s %s\n", result, file1->name, file2->name);

        if (result == 0) {
                switch (sort_type) {
                case FM_LIST_MODEL_FILENAME:
                        result = compare_by_display_name (file1, file2);
                        /*if (result == 0) {
                                result = compare_by_directory_name (file_1, file_2);
                        }*/
                        break;
                case FM_LIST_MODEL_SIZE:
                        result = compare_by_size (file1, file2);
                        break;
                case FM_LIST_MODEL_TYPE:
                        result = compare_by_type (file1, file2);
                        break;
                case FM_LIST_MODEL_MODIFIED:
                        result = compare_by_time (file1, file2);
                        break;
                }

                if (reversed) {
                        result = -result;
                }
        }
#if 0
        if (result == 0) {
                switch (sort_type) {
                case NAUTILUS_FILE_SORT_BY_DISPLAY_NAME:
                        result = compare_by_display_name (file_1, file_2);
                        if (result == 0) {
                                result = compare_by_directory_name (file_1, file_2);
                        }
                        break;
                case NAUTILUS_FILE_SORT_BY_DIRECTORY:
                        result = compare_by_full_path (file_1, file_2);
                        break;
                case NAUTILUS_FILE_SORT_BY_SIZE:
                        /* Compare directory sizes ourselves, then if necessary
                         * use GnomeVFS to compare file sizes.
                         */
                        result = compare_by_size (file_1, file_2);
                        if (result == 0) {
                                result = compare_by_full_path (file_1, file_2);
                        }
                        break;
                case NAUTILUS_FILE_SORT_BY_TYPE:
                        /* GnomeVFS doesn't know about our special text for certain
                         * mime types, so we handle the mime-type sorting ourselves.
                         */
                        result = compare_by_type (file_1, file_2);
                        if (result == 0) {
                                result = compare_by_full_path (file_1, file_2);
                        }
                        break;
                case NAUTILUS_FILE_SORT_BY_MTIME:
                        result = compare_by_time (file_1, file_2, NAUTILUS_DATE_TYPE_MODIFIED);
                        if (result == 0) {
                                result = compare_by_full_path (file_1, file_2);
                        }
                        break;
                case NAUTILUS_FILE_SORT_BY_ATIME:
                        result = compare_by_time (file_1, file_2, NAUTILUS_DATE_TYPE_ACCESSED);
                        if (result == 0) {
                                result = compare_by_full_path (file_1, file_2);
                        }
                        break;
                case NAUTILUS_FILE_SORT_BY_TRASHED_TIME:
                        result = compare_by_time (file_1, file_2, NAUTILUS_DATE_TYPE_TRASHED);
                        if (result == 0) {
                                result = compare_by_full_path (file_1, file_2);
                        }
                        break;
                case NAUTILUS_FILE_SORT_BY_EMBLEMS:
                        /* GnomeVFS doesn't know squat about our emblems, so
                         * we handle comparing them here, before falling back
                         * to tie-breakers.
                         */
                        result = compare_by_emblems (file_1, file_2);
                        if (result == 0) {
                                result = compare_by_full_path (file_1, file_2);
                        }
                        break;
                default:
                        g_return_val_if_reached (0);
                }

                if (reversed) {
                        result = -result;
                }
        }
#endif
        return result;
}

GOFFile *
gof_file_ref (GOFFile *file)
{
	if (file == NULL) {
		return NULL;
	}
	g_return_val_if_fail (GOF_IS_FILE (file), NULL);

	return g_object_ref (file);
}

void
gof_file_unref (GOFFile *file)
{
	if (file == NULL) {
		return;
	}

	g_return_if_fail (GOF_IS_FILE (file));

	g_object_unref (file);
}

static const char *TODAY_TIME_FORMATS [] = {
	/* Today, use special word.
	 * strftime patterns preceeded with the widest
	 * possible resulting string for that pattern.
	 *
	 * Note to localizers: You can look at man strftime
	 * for details on the format, but you should only use
	 * the specifiers from the C standard, not extensions.
	 * These include "%" followed by one of
	 * "aAbBcdHIjmMpSUwWxXyYZ". There are two extensions
	 * in the Nautilus version of strftime that can be
	 * used (and match GNU extensions). Putting a "-"
	 * between the "%" and any numeric directive will turn
	 * off zero padding, and putting a "_" there will use
	 * space padding instead of zero padding.
	 */
	N_("today at 00:00:00 PM"),
	N_("today at %-I:%M:%S %p"),
	
	N_("today at 00:00 PM"),
	N_("today at %-I:%M %p"),
	
	N_("today, 00:00 PM"),
	N_("today, %-I:%M %p"),
	
	N_("today"),
	N_("today"),

	NULL
};

static const char *YESTERDAY_TIME_FORMATS [] = {
	/* Yesterday, use special word.
	 * Note to localizers: Same issues as "today" string.
	 */
	N_("yesterday at 00:00:00 PM"),
	N_("yesterday at %-I:%M:%S %p"),
	
	N_("yesterday at 00:00 PM"),
	N_("yesterday at %-I:%M %p"),
	
	N_("yesterday, 00:00 PM"),
	N_("yesterday, %-I:%M %p"),
	
	N_("yesterday"),
	N_("yesterday"),

	NULL
};

static const char *CURRENT_WEEK_TIME_FORMATS [] = {
	/* Current week, include day of week.
	 * Note to localizers: Same issues as "today" string.
	 * The width measurement templates correspond to
	 * the day/month name with the most letters.
	 */
	N_("Wednesday, September 00 0000 at 00:00:00 PM"),
	N_("%A, %B %-d %Y at %-I:%M:%S %p"),

	N_("Mon, Oct 00 0000 at 00:00:00 PM"),
	N_("%a, %b %-d %Y at %-I:%M:%S %p"),

	N_("Mon, Oct 00 0000 at 00:00 PM"),
	N_("%a, %b %-d %Y at %-I:%M %p"),
	
	N_("Oct 00 0000 at 00:00 PM"),
	N_("%b %-d %Y at %-I:%M %p"),
	
	N_("Oct 00 0000, 00:00 PM"),
	N_("%b %-d %Y, %-I:%M %p"),
	
	N_("00/00/00, 00:00 PM"),
	N_("%m/%-d/%y, %-I:%M %p"),

	N_("00/00/00"),
	N_("%m/%d/%y"),

	NULL
};

char *
gof_file_get_date_as_string (guint64 d)
{
	//time_t file_time_raw;
	struct tm *file_time;
	const char **formats;
	const char *width_template;
	const char *format;
	char *date_string;
	//char *result;
	GDate *today;
	GDate *file_date;
	guint32 file_date_age;
	int i;

	file_time = localtime (&d);

        gchar *date_format_pref = g_settings_get_string(settings, MARLIN_PREFERENCES_DATE_FORMAT);

        if (!strcmp (date_format_pref, "locale"))
		return eel_strdup_strftime ("%c", file_time);
        else if (!strcmp (date_format_pref, "iso"))
		return eel_strdup_strftime ("%Y-%m-%d %H:%M:%S", file_time);

	file_date = eel_g_date_new_tm (file_time);
	
	today = g_date_new ();
	g_date_set_time_t (today, time (NULL));

	/* Overflow results in a large number; fine for our purposes. */
	file_date_age = (g_date_get_julian (today) -
			 g_date_get_julian (file_date));

	g_date_free (file_date);
	g_date_free (today);

	/* Format varies depending on how old the date is. This minimizes
	 * the length (and thus clutter & complication) of typical dates
	 * while providing sufficient detail for recent dates to make
	 * them maximally understandable at a glance. Keep all format
	 * strings separate rather than combining bits & pieces for
	 * internationalization's sake.
	 */

	if (file_date_age == 0)	{
		formats = TODAY_TIME_FORMATS;
	} else if (file_date_age == 1) {
		formats = YESTERDAY_TIME_FORMATS;
	} else if (file_date_age < 7) {
		formats = CURRENT_WEEK_TIME_FORMATS;
	} else {
		formats = CURRENT_WEEK_TIME_FORMATS;
	}

	/* Find the date format that just fits the required width. Instead of measuring
	 * the resulting string width directly, measure the width of a template that represents
	 * the widest possible version of a date in a given format. This is done by using M, m
	 * and 0 for the variable letters/digits respectively.
	 */
	format = NULL;
	
	for (i = 0; ; i += 2) {
		width_template = (formats [i] ? _(formats [i]) : NULL);
		if (width_template == NULL) {
			/* no more formats left */
			g_assert (format != NULL);
			
			/* Can't fit even the shortest format -- return an ellipsized form in the
			 * shortest format
			 */
			
			date_string = eel_strdup_strftime (format, file_time);

			return date_string;
		}
		
		format = _(formats [i + 1]);

		/* don't care about fitting the width */
		break;
	}
	
	return eel_strdup_strftime (format, file_time);
}

void
gof_file_list_unref (GList *list)
{
	g_list_foreach (list, (GFunc) gof_file_unref, NULL);
}

void
gof_file_list_free (GList *list)
{
	gof_file_list_unref (list);
	g_list_free (list);
}

