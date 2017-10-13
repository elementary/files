/*
 * Copyright (C) 1999, 2000, 2001 Eazel, Inc.
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
 *          Darin Adler <darin@bentspoon.com>
 */


#include "eel-fcts.h"

#include <glib-object.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <pwd.h>
#include <grp.h>
#include <glib/gi18n.h>
/**
 * eel_get_date_as_string:
 *
 * Get a formated date string where format equal iso, locale, informal.
 * The caller is responsible for g_free-ing the result.
 * @d: contains the UNIX time.
 * @date_format: string representing the format to convert the date to.
 *
 * Returns: Newly allocated date.
 *
**/
char *
eel_get_date_as_string (guint64 d, gchar *date_format)
{
    const char *format;
    gchar *result = NULL;
    GDateTime *date_time, *today, *last_year;
    GTimeSpan file_date_age;
    gboolean is_last_year;

    g_return_val_if_fail (date_format != NULL, NULL);
    date_time = g_date_time_new_from_unix_local ((gint64) d);

    if (!strcmp (date_format, "locale")) {
        result = g_date_time_format (date_time, "%c");
        goto out;
    } else if (!strcmp (date_format, "iso")) {
        result = g_date_time_format (date_time, "%Y-%m-%d %H:%M:%S");
        goto out;
    }

    today = g_date_time_new_now_local ();
    last_year = g_date_time_add_years (today, -1);
    file_date_age = g_date_time_difference (today, date_time);
    is_last_year = g_date_time_compare (date_time, last_year) > 0;
    g_date_time_unref (today);
    g_date_time_unref (last_year);

    /* Format varies depending on how old the date is. This minimizes
     * the length (and thus clutter & complication) of typical dates
     * while providing sufficient detail for recent dates to make
     * them maximally understandable at a glance. Keep all format
     * strings separate rather than combining bits & pieces for
     * internationalization's sake.
     */

    if (file_date_age < G_TIME_SPAN_DAY) {
        //TODAY_TIME_FORMATS
        //"Today at 00:00 PM"
        format = _("Today at %-I:%M %p");
    } else if (file_date_age < 2 * G_TIME_SPAN_DAY) {
        //YESTERDAY_TIME_FORMATS
        //"Yesterday at 00:00 PM"
        format = _("Yesterday at %-I:%M %p");
    } else if (is_last_year) {
        //CURRENT_YEAR_TIME_FORMATS
        //"Mon 00 Oct at 00:00 PM"
        format = _("%a %-d %b at %-I:%M %p");
    } else {
        //CURRENT_WEEK_TIME_FORMATS
        //"Mon 00 Oct 0000 at 00:00 PM"
        format = _("%a %-d %b %Y at %-I:%M %p");
    }

    result = g_date_time_format (date_time, format);

 out:
    g_date_time_unref (date_time);
    return result;
}

/**
 * eel_get_user_names:
 *
 * Get a list of user names.
 * The caller is responsible for freeing this list and its contents.
 */
GList *
eel_get_user_names (void)
{
    GList *list;
    struct passwd *user;

    list = NULL;
    setpwent ();
    while ((user = getpwent ()) != NULL) {
        list = g_list_prepend (list, g_strdup (user->pw_name));
    }
    endpwent ();

    return g_list_sort (list, (GCompareFunc) g_utf8_collate);
}

/* Get a list of group names, filtered to only the ones
 * that contain the given username. If the username is
 * NULL, returns a list of all group names.
 */
GList *
eel_get_group_names_for_user (void)
{
    GList *list;
    struct group *group;
    int count, i;
    gid_t gid_list[NGROUPS_MAX + 1];


    list = NULL;

    count = getgroups (NGROUPS_MAX + 1, gid_list);
    for (i = 0; i < count; i++) {
        group = getgrgid (gid_list[i]);
        if (group == NULL)
            break;

        list = g_list_prepend (list, g_strdup (group->gr_name));
    }

    return g_list_sort (list, (GCompareFunc) g_utf8_collate);
}

/**
 * Get a list of all group names.
 */
GList *
eel_get_all_group_names (void)
{
    GList *list;
    struct group *group;

    list = NULL;

    setgrent ();

    while ((group = getgrent ()) != NULL)
        list = g_list_prepend (list, g_strdup (group->gr_name));

    endgrent ();

    return g_list_sort (list, (GCompareFunc) g_utf8_collate);
}

gboolean
eel_user_in_group (const char *group_name)
{
    GList *list;
    struct group *group;
    int count, i;
    gid_t gid_list[NGROUPS_MAX + 1];
    gboolean found;

    list = NULL;
    found = FALSE;

    count = getgroups (NGROUPS_MAX + 1, gid_list);
    for (i = 0; i < count; i++) {
        group = getgrgid (gid_list[i]);
        if (group == NULL)
            break;

        if (g_strcmp0 (group_name, group->gr_name) == 0) {
            found = TRUE;
            break;
        }
    }

    return found;
}

gboolean
eel_get_group_id_from_group_name (const char *group_name, uid_t *gid)
{
    struct group *group;

    g_assert (gid != NULL);

    group = getgrnam (group_name);

    if (group == NULL)
        return FALSE;

    *gid = group->gr_gid;

    return TRUE;
}

gboolean
eel_get_user_id_from_user_name (const char *user_name, uid_t *uid)
{
    struct passwd *password_info;

    g_assert (uid != NULL);

    password_info = getpwnam (user_name);

    if (password_info == NULL)
        return FALSE;

    *uid = password_info->pw_uid;

    return TRUE;
}

static const char*
get_user_home_from_user_uid (uid_t uid)
{
    struct passwd *password_info;

    password_info = getpwuid (uid);

    if (password_info == NULL || password_info->pw_dir == NULL)
        return NULL;

    return password_info->pw_dir;
}

char*
eel_get_real_user_home ()
{
    const char *real_uid_s;
    int uid;

    real_uid_s = g_environ_getenv (g_get_environ (), "PKEXEC_UID");
    /* If running as administrator return the real user home, not root home */
    if (real_uid_s != NULL && eel_get_id_from_digit_string (real_uid_s, &uid)) {
        return g_strdup (get_user_home_from_user_uid ((uid_t)uid));
    } else {
        return g_strdup (g_get_home_dir ());
    }
}

gboolean
eel_get_id_from_digit_string (const char *digit_string, uid_t *id)
{
    long scanned_id;
    char c;

    g_assert (id != NULL);

    /* Only accept string if it has one integer with nothing
     * afterwards.
     */
    if (sscanf (digit_string, "%ld%c", &scanned_id, &c) != 1) {
        return FALSE;
    }

    *id = scanned_id;

    return TRUE;
}

gchar
*eel_format_size (guint64 size)
{
    return g_format_size (size);
}
