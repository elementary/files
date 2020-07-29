/* nautilus-file-operations: execute file operations.
 *
 * Copyright (C) 1999, 2000 Free Software Foundation, Inc.,
 * Copyright (C) 2000, 2001 Eazel, Inc.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, Inc.,; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
 * Boston, MA 02110-1335 USA.
 *
 * Authors: Ettore Perazzoli <ettore@gnu.org>,
 *          Pavel Cisler <pavel@eazel.com>
 */

#include <string.h>
#include <stdio.h>
#include <stdarg.h>
#include <locale.h>
#include <math.h>
#include <unistd.h>
#include <sys/types.h>
#include <stdlib.h>

#include "marlin-file-operations.h"

#include <glib/gi18n.h>
#include <glib/gstdio.h>
#include <gdk/gdk.h>
#include <gtk/gtk.h>
#include <gio/gio.h>
#include <glib.h>

#include "pantheon-files-core.h"

typedef void (* MarlinCopyCallback)      (gpointer    callback_data);
typedef void (* MarlinUnmountCallback)   (gpointer    callback_data);
typedef void (* MarlinOpCallback)        (gpointer    callback_data);

typedef struct {
    GIOSchedulerJob *io_job;
    GTimer *time;
    GtkWindow *parent_window;
    int inhibit_cookie;
    PFProgressInfo *progress;
    GCancellable *cancellable;
    GHashTable *skip_files;
    GHashTable *skip_readdir_error;
    gboolean skip_all_error;
    gboolean skip_all_conflict;
    gboolean merge_all;
    gboolean replace_all;
    gboolean keep_all_newest;
    gboolean delete_all;
    MarlinUndoActionData *undo_redo_data;
} CommonJob;

typedef struct {
    CommonJob common;
    gboolean is_move;
    GList *files;
    GFile *destination;
    GHashTable *debuting_files;
    GTask *task;
} CopyMoveJob;

typedef struct {
    CommonJob common;
    GList *files;
    gboolean try_trash;
    gboolean user_cancel;
    GTask *task;
} DeleteJob;

typedef struct {
    CommonJob common;
    GFile *dest_dir;
    char *filename;
    gboolean make_dir;
    GFile *src;
    char *src_data;
    int length;
    GFile *created_file;
    GTask *task;
} CreateJob;

typedef enum {
    OP_KIND_COPY,
    OP_KIND_MOVE,
    OP_KIND_DELETE,
    OP_KIND_TRASH
} OpKind;

typedef struct {
    int num_files;
    goffset num_bytes;
    int num_files_since_progress;
    OpKind op;
} SourceInfo;

typedef struct {
    int num_files;
    goffset num_bytes;
    OpKind op;
    guint64 last_report_time;
    int last_reported_files_left;
} TransferInfo;

#define SECONDS_NEEDED_FOR_RELIABLE_TRANSFER_RATE 15
//#define NSEC_PER_SEC 1000000000
#define NSEC_PER_MSEC 1000000

#define MAXIMUM_DISPLAYED_FILE_NAME_LENGTH 50

#define IS_IO_ERROR(__error, KIND) (((__error)->domain == G_IO_ERROR && (__error)->code == G_IO_ERROR_ ## KIND))

static void scan_sources (GList *files,
                          SourceInfo *source_info,
                          CommonJob *job,
                          OpKind kind);

static char * query_fs_type (GFile *file,
                             GCancellable *cancellable);

static char *
format_time (int seconds, int *time_unit)
{
    int minutes;
    int hours;

    if (seconds < 0) {
        /* Just to make sure... */
        seconds = 0;
    }

    if (seconds < 60) {
        if (time_unit) {
            *time_unit = seconds;
        }

        return g_strdup_printf (ngettext ("%'d second","%'d seconds", seconds), seconds);
    }

    if (seconds < 60*60) {
        minutes = seconds / 60;
        if (time_unit) {
            *time_unit = minutes;
        }

        return g_strdup_printf (ngettext ("%'d minute", "%'d minutes", minutes), minutes);
    }

    hours = seconds / (60*60);

    if (seconds < 60*60*4) {
        char *h, *m, *res;

        minutes = (seconds - hours * 60 * 60) / 60;
        if (time_unit) {
            *time_unit = minutes + hours;
        }

        h = g_strdup_printf (ngettext ("%'d hour", "%'d hours", hours), hours);
        m = g_strdup_printf (ngettext ("%'d minute", "%'d minutes", minutes), minutes);
        res = g_strconcat (h, ", ", m, NULL);
        g_free (h);
        g_free (m);
        return res;
    }

    if (time_unit) {
        *time_unit = hours;
    }

    return g_strdup_printf (ngettext ("approximately %'d hour",
                                      "approximately %'d hours",
                                      hours), hours);
}

static char *
shorten_utf8_string (const char *base, int reduce_by_num_bytes)
{
    int len;
    char *ret;
    const char *p;

    len = strlen (base);
    len -= reduce_by_num_bytes;

    if (len <= 0) {
        return NULL;
    }

    ret = g_new (char, len + 1);

    p = base;
    while (len) {
        char *next;
        next = g_utf8_next_char (p);
        if (next - p > len || *next == '\0') {
            break;
        }

        len -= next - p;
        p = next;
    }

    if (p - base == 0) {
        g_free (ret);
        return NULL;
    } else {
        memcpy (ret, base, p - base);
        ret[p - base] = '\0';
        return ret;
    }
}

/* Note that we have these two separate functions with separate format
 * strings for ease of localization.
 */

static char *
get_link_name (const char *name, int count, int max_length)
{
    const char *format;
    char *result;
    int unshortened_length;
    gboolean use_count;

    g_assert (name != NULL);

    if (count < 0) {
        g_warning ("bad count in get_link_name");
        count = 0;
    }

    if (count <= 2) {
        /* Handle special cases for low numbers.
         * Perhaps for some locales we will need to add more.
         */
        switch (count) {
        default:
            g_assert_not_reached ();
            /* fall through */
        case 0:
            /* duplicate original file name */
            format = "%s";
            break;
        case 1:
            /* appended to new link file */
            format = _("Link to %s");
            break;
        case 2:
            /* appended to new link file */
            format = _("Another link to %s");
            break;
        }

        use_count = FALSE;
    } else {
        /* Handle special cases for the first few numbers of each ten.
         * For locales where getting this exactly right is difficult,
         * these can just be made all the same as the general case below.
         */
        switch (count % 10) {
        case 1:
            /* Localizers: Feel free to leave out the "st" suffix
             * if there's no way to do that nicely for a
             * particular language.
             */
            format = _("%'dst link to %s");
            break;
        case 2:
            /* appended to new link file */
            format = _("%'dnd link to %s");
            break;
        case 3:
            /* appended to new link file */
            format = _("%'drd link to %s");
            break;
        default:
            /* appended to new link file */
            format = _("%'dth link to %s");
            break;
        }

        use_count = TRUE;
    }

    if (use_count)
        result = g_strdup_printf (format, count, name);
    else
        result = g_strdup_printf (format, name);

    if (max_length > 0 && (unshortened_length = strlen (result)) > max_length) {
        char *new_name;

        new_name = shorten_utf8_string (name, unshortened_length - max_length);
        if (new_name) {
            g_free (result);

            if (use_count)
                result = g_strdup_printf (format, count, new_name);
            else
                result = g_strdup_printf (format, new_name);

            g_assert (strlen (result) <= max_length);
            g_free (new_name);
        }
    }

    return result;
}

/* Localizers:
 * Feel free to leave out the st, nd, rd and th suffix or
 * make some or all of them match.
 */

/* localizers: tag used to detect the first copy of a file */
static const char untranslated_copy_duplicate_tag[] = N_(" (copy)");
/* localizers: tag used to detect the second copy of a file */
static const char untranslated_another_copy_duplicate_tag[] = N_(" (another copy)");

/* localizers: tag used to detect the x11th copy of a file */
static const char untranslated_x11th_copy_duplicate_tag[] = N_("th copy)");
/* localizers: tag used to detect the x12th copy of a file */
static const char untranslated_x12th_copy_duplicate_tag[] = N_("th copy)");
/* localizers: tag used to detect the x13th copy of a file */
static const char untranslated_x13th_copy_duplicate_tag[] = N_("th copy)");

/* localizers: tag used to detect the x1st copy of a file */
static const char untranslated_st_copy_duplicate_tag[] = N_("st copy)");
/* localizers: tag used to detect the x2nd copy of a file */
static const char untranslated_nd_copy_duplicate_tag[] = N_("nd copy)");
/* localizers: tag used to detect the x3rd copy of a file */
static const char untranslated_rd_copy_duplicate_tag[] = N_("rd copy)");

/* localizers: tag used to detect the xxth copy of a file */
static const char untranslated_th_copy_duplicate_tag[] = N_("th copy)");

#define COPY_DUPLICATE_TAG _(untranslated_copy_duplicate_tag)
#define ANOTHER_COPY_DUPLICATE_TAG _(untranslated_another_copy_duplicate_tag)
#define X11TH_COPY_DUPLICATE_TAG _(untranslated_x11th_copy_duplicate_tag)
#define X12TH_COPY_DUPLICATE_TAG _(untranslated_x12th_copy_duplicate_tag)
#define X13TH_COPY_DUPLICATE_TAG _(untranslated_x13th_copy_duplicate_tag)

#define ST_COPY_DUPLICATE_TAG _(untranslated_st_copy_duplicate_tag)
#define ND_COPY_DUPLICATE_TAG _(untranslated_nd_copy_duplicate_tag)
#define RD_COPY_DUPLICATE_TAG _(untranslated_rd_copy_duplicate_tag)
#define TH_COPY_DUPLICATE_TAG _(untranslated_th_copy_duplicate_tag)

/* localizers: appended to first file copy */
static const char untranslated_first_copy_duplicate_format[] = N_("%s (copy)%s");
/* localizers: appended to second file copy */
static const char untranslated_second_copy_duplicate_format[] = N_("%s (another copy)%s");

/* localizers: appended to x11th file copy */
static const char untranslated_x11th_copy_duplicate_format[] = N_("%s (%'dth copy)%s");
/* localizers: appended to x12th file copy */
static const char untranslated_x12th_copy_duplicate_format[] = N_("%s (%'dth copy)%s");
/* localizers: appended to x13th file copy */
static const char untranslated_x13th_copy_duplicate_format[] = N_("%s (%'dth copy)%s");

/* localizers: if in your language there's no difference between 1st, 2nd, 3rd and nth
 * plurals, you can leave the st, nd, rd suffixes out and just make all the translated
 * strings look like "%s (copy %'d)%s".
 */

/* localizers: appended to x1st file copy */
static const char untranslated_st_copy_duplicate_format[] = N_("%s (%'dst copy)%s");
/* localizers: appended to x2nd file copy */
static const char untranslated_nd_copy_duplicate_format[] = N_("%s (%'dnd copy)%s");
/* localizers: appended to x3rd file copy */
static const char untranslated_rd_copy_duplicate_format[] = N_("%s (%'drd copy)%s");
/* localizers: appended to xxth file copy */
static const char untranslated_th_copy_duplicate_format[] = N_("%s (%'dth copy)%s");

#define FIRST_COPY_DUPLICATE_FORMAT _(untranslated_first_copy_duplicate_format)
#define SECOND_COPY_DUPLICATE_FORMAT _(untranslated_second_copy_duplicate_format)
#define X11TH_COPY_DUPLICATE_FORMAT _(untranslated_x11th_copy_duplicate_format)
#define X12TH_COPY_DUPLICATE_FORMAT _(untranslated_x12th_copy_duplicate_format)
#define X13TH_COPY_DUPLICATE_FORMAT _(untranslated_x13th_copy_duplicate_format)

#define ST_COPY_DUPLICATE_FORMAT _(untranslated_st_copy_duplicate_format)
#define ND_COPY_DUPLICATE_FORMAT _(untranslated_nd_copy_duplicate_format)
#define RD_COPY_DUPLICATE_FORMAT _(untranslated_rd_copy_duplicate_format)
#define TH_COPY_DUPLICATE_FORMAT _(untranslated_th_copy_duplicate_format)

static char *
extract_string_until (const char *original, const char *until_substring)
{
    char *result;

    g_assert ((int) strlen (original) >= until_substring - original);
    g_assert (until_substring - original >= 0);

    result = g_malloc (until_substring - original + 1);
    strncpy (result, original, until_substring - original);
    result[until_substring - original] = '\0';

    return result;
}

/* Dismantle a file name, separating the base name, the file suffix and removing any
 * (xxxcopy), etc. string. Figure out the count that corresponds to the given
 * (xxxcopy) substring.
 */
static void
parse_previous_duplicate_name (const char *name,
                               char **name_base,
                               const char **suffix,
                               int *count)
{
    const char *tag;

    g_assert (name[0] != '\0');

    *suffix = strchr (name + 1, '.');
    if (*suffix == NULL || (*suffix)[1] == '\0') {
        /* no suffix */
        *suffix = "";
    }

    tag = strstr (name, COPY_DUPLICATE_TAG);
    if (tag != NULL) {
        if (tag > *suffix) {
            /* handle case "foo. (copy)" */
            *suffix = "";
        }
        *name_base = extract_string_until (name, tag);
        *count = 1;
        return;
    }


    tag = strstr (name, ANOTHER_COPY_DUPLICATE_TAG);
    if (tag != NULL) {
        if (tag > *suffix) {
            /* handle case "foo. (another copy)" */
            *suffix = "";
        }
        *name_base = extract_string_until (name, tag);
        *count = 2;
        return;
    }


    /* Check to see if we got one of st, nd, rd, th. */
    tag = strstr (name, X11TH_COPY_DUPLICATE_TAG);

    if (tag == NULL) {
        tag = strstr (name, X12TH_COPY_DUPLICATE_TAG);
    }
    if (tag == NULL) {
        tag = strstr (name, X13TH_COPY_DUPLICATE_TAG);
    }

    if (tag == NULL) {
        tag = strstr (name, ST_COPY_DUPLICATE_TAG);
    }
    if (tag == NULL) {
        tag = strstr (name, ND_COPY_DUPLICATE_TAG);
    }
    if (tag == NULL) {
        tag = strstr (name, RD_COPY_DUPLICATE_TAG);
    }
    if (tag == NULL) {
        tag = strstr (name, TH_COPY_DUPLICATE_TAG);
    }

    /* If we got one of st, nd, rd, th, fish out the duplicate number. */
    if (tag != NULL) {
        /* localizers: opening parentheses to match the "th copy)" string */
        tag = strstr (name, _(" ("));
        if (tag != NULL) {
            if (tag > *suffix) {
                /* handle case "foo. (22nd copy)" */
                *suffix = "";
            }
            *name_base = extract_string_until (name, tag);
            /* localizers: opening parentheses of the "th copy)" string */
            if (sscanf (tag, _(" (%'d"), count) == 1) {
                if (*count < 1 || *count > 1000000) {
                    /* keep the count within a reasonable range */
                    *count = 0;
                }
                return;
            }
            *count = 0;
            return;
        }
    }


    *count = 0;
    if (**suffix != '\0') {
        *name_base = extract_string_until (name, *suffix);
    } else {
        *name_base = g_strdup (name);
    }
}

static char *
make_next_duplicate_name (const char *base, const char *suffix, int count, int max_length)
{
    const char *format;
    char *result;
    int unshortened_length;
    gboolean use_count;

    if (count < 1) {
        g_warning ("bad count %d in get_duplicate_name", count);
        count = 1;
    }

    if (count <= 2) {

        /* Handle special cases for low numbers.
         * Perhaps for some locales we will need to add more.
         */
        switch (count) {
        default:
            g_assert_not_reached ();
            /* fall through */
        case 1:
            format = FIRST_COPY_DUPLICATE_FORMAT;
            break;
        case 2:
            format = SECOND_COPY_DUPLICATE_FORMAT;
            break;

        }

        use_count = FALSE;
    } else {

        /* Handle special cases for the first few numbers of each ten.
         * For locales where getting this exactly right is difficult,
         * these can just be made all the same as the general case below.
         */

        /* Handle special cases for x11th - x20th.
        */
        switch (count % 100) {
        case 11:
            format = X11TH_COPY_DUPLICATE_FORMAT;
            break;
        case 12:
            format = X12TH_COPY_DUPLICATE_FORMAT;
            break;
        case 13:
            format = X13TH_COPY_DUPLICATE_FORMAT;
            break;
        default:
            format = NULL;
            break;
        }

        if (format == NULL) {
            switch (count % 10) {
            case 1:
                format = ST_COPY_DUPLICATE_FORMAT;
                break;
            case 2:
                format = ND_COPY_DUPLICATE_FORMAT;
                break;
            case 3:
                format = RD_COPY_DUPLICATE_FORMAT;
                break;
            default:
                /* The general case. */
                format = TH_COPY_DUPLICATE_FORMAT;
                break;
            }
        }

        use_count = TRUE;

    }

    if (use_count)
        result = g_strdup_printf (format, base, count, suffix);
    else
        result = g_strdup_printf (format, base, suffix);

    if (max_length > 0 && (unshortened_length = strlen (result)) > max_length) {
        char *new_base;

        new_base = shorten_utf8_string (base, unshortened_length - max_length);
        if (new_base) {
            g_free (result);

            if (use_count)
                result = g_strdup_printf (format, new_base, count, suffix);
            else
                result = g_strdup_printf (format, new_base, suffix);

            g_assert (strlen (result) <= max_length);
            g_free (new_base);
        }
    }

    return result;
}

static char *
get_duplicate_name (const char *name, int count_increment, int max_length)
{
    char *result;
    char *name_base;
    const char *suffix;
    int count;

    parse_previous_duplicate_name (name, &name_base, &suffix, &count);
    result = make_next_duplicate_name (name_base, suffix, count + count_increment, max_length);

    g_free (name_base);

    return result;
}

static gboolean
has_invalid_xml_char (char *str)
{
    gunichar c;

    while (*str != 0) {
        c = g_utf8_get_char (str);
        /* characters XML permits */
        if (!(c == 0x9 ||
              c == 0xA ||
              c == 0xD ||
              (c >= 0x20 && c <= 0xD7FF) ||
              (c >= 0xE000 && c <= 0xFFFD) ||
              (c >= 0x10000 && c <= 0x10FFFF))) {
            return TRUE;
        }
        str = g_utf8_next_char (str);
    }
    return FALSE;
}

static char *
eel_str_middle_truncate (const char *string,
                         guint truncate_length)
{
    char *truncated;
    guint length;
    guint num_left_chars;
    guint num_right_chars;

    const char delimter[] = "…";
    const guint delimter_length = strlen (delimter);
    const guint min_truncate_length = delimter_length + 2;

    if (string == NULL) {
        return NULL;
    }

    /* It doesnt make sense to truncate strings to less than
     * the size of the delimiter plus 2 characters (one on each
     * side)
     */
    if (truncate_length < min_truncate_length) {
        return g_strdup (string);
    }

    length = g_utf8_strlen (string, -1);

    /* Make sure the string is not already small enough. */
    if (length <= truncate_length) {
        return g_strdup (string);
    }

    /* Find the 'middle' where the truncation will occur. */
    num_left_chars = (truncate_length - delimter_length) / 2;
    num_right_chars = truncate_length - num_left_chars - delimter_length;

    truncated = g_new (char, strlen (string) + 1);

    g_utf8_strncpy (truncated, string, num_left_chars);
    strcat (truncated, delimter);
    strcat (truncated, g_utf8_offset_to_pointer  (string, length - num_right_chars));

    return truncated;
}

static char *
custom_basename_from_file (GFile *file) {
    GFileInfo *info;
    char *name, *basename, *tmp;

    if (!G_IS_FILE (file)) {
        g_critical ("Invalid file");
        return strdup ("");
    }

    info = g_file_query_info (file,
                              G_FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME,
                              0,
                              g_cancellable_get_current (),
                              NULL);

    name = NULL;
    if (info) {
        name = g_strdup (g_file_info_get_display_name (info));
        g_object_unref (info);
    }

    if (name == NULL) {
        basename = g_file_get_basename (file);
        if (g_utf8_validate (basename, -1, NULL)) {
            name = basename;
        } else {
            name = g_uri_escape_string (basename, G_URI_RESERVED_CHARS_ALLOWED_IN_PATH, TRUE);
            g_free (basename);
        }
    }

    /* Some chars can't be put in the markup we use for the dialogs... */
    if (has_invalid_xml_char (name)) {
        tmp = name;
        name = g_uri_escape_string (name, G_URI_RESERVED_CHARS_ALLOWED_IN_PATH, TRUE);
        g_free (tmp);
    }

    /* Finally, if the string is too long, truncate it. */
    if (name != NULL) {
        tmp = name;
        name = eel_str_middle_truncate (tmp, MAXIMUM_DISPLAYED_FILE_NAME_LENGTH);
        g_free (tmp);
    }


    return name;
}

#define op_job_new(__type, parent_window) ((__type *)(init_common (sizeof(__type), parent_window)))

static gpointer
init_common (gsize job_size,
             GtkWindow *parent_window)
{
    CommonJob *common;

    common = g_malloc0 (job_size); /* Booleans default to false (0) */

    if (parent_window) {
        common->parent_window = parent_window;
        g_object_add_weak_pointer (parent_window, &common->parent_window);
    }

    common->progress = pf_progress_info_new ();
    // ProgressInfo cancellable is now a property, therefore unowned - do not unref.
    common->cancellable = pf_progress_info_get_cancellable (common->progress);
    common->time = g_timer_new ();
    common->inhibit_cookie = -1;

    return common;
}

static void
finalize_common (CommonJob *common)
{
    pf_progress_info_finish (common->progress);
    if (common->inhibit_cookie != -1) {
        gtk_application_uninhibit (GTK_APPLICATION (g_application_get_default ()),
                                   common->inhibit_cookie);
    }

    common->inhibit_cookie = -1;
    g_timer_destroy (common->time);

    if (common->parent_window) {
        g_object_remove_weak_pointer (common->parent_window, &common->parent_window);
    }

    if (common->skip_files) {
        g_hash_table_destroy (common->skip_files);
    }
    if (common->skip_readdir_error) {
        g_hash_table_destroy (common->skip_readdir_error);
    }

    // Start UNDO-REDO
    marlin_undo_manager_add_action (marlin_undo_manager_instance(), common->undo_redo_data);
    // End UNDO-REDO

    g_object_unref (common->progress);
    g_free (common);
}

static void
skip_file (CommonJob *common,
           GFile *file)
{
    if (common->skip_files == NULL) {
        common->skip_files =
            g_hash_table_new_full (g_file_hash, (GEqualFunc)g_file_equal, g_object_unref, NULL);
    }

    g_hash_table_insert (common->skip_files, g_object_ref (file), file);
}

static void
skip_readdir_error (CommonJob *common,
                    GFile *dir)
{
    if (common->skip_readdir_error == NULL) {
        common->skip_readdir_error =
            g_hash_table_new_full (g_file_hash, (GEqualFunc)g_file_equal, g_object_unref, NULL);
    }

    g_hash_table_insert (common->skip_readdir_error, g_object_ref (dir), dir);
}

static gboolean
should_skip_file (CommonJob *common,
                  GFile *file)
{
    if (common->skip_files != NULL) {
        return g_hash_table_lookup (common->skip_files, file) != NULL;
    }
    return FALSE;
}

static gboolean
should_skip_readdir_error (CommonJob *common,
                           GFile *dir)
{
    if (common->skip_readdir_error != NULL) {
        return g_hash_table_lookup (common->skip_readdir_error, dir) != NULL;
    }
    return FALSE;
}

static gboolean
can_delete_without_confirm (GFile *file)
{
    if (g_file_has_uri_scheme (file, "burn") ||
        g_file_has_uri_scheme (file, "x-nautilus-desktop") ||
        g_file_has_uri_scheme (file, "trash")) {
        return TRUE;
    }

    return FALSE;
}

static gboolean
do_run_simple_dialog (gpointer _data)
{
    MarlinRunSimpleDialogData *data = _data;

    data->result = pf_dialogs_run_simple_file_operation_dialog (data);

    return FALSE;
}

/* NOTE: This frees the primary / secondary strings, in order to
   avoid doing that everywhere. So, make sure they are strduped */

static int
run_simple_dialog_va (CommonJob *job,
                      gboolean ignore_close_box,
                      GtkMessageType message_type,
                      char *primary_text,
                      char *secondary_text,
                      const char *details_text,
                      gboolean show_all,
                      va_list varargs)
{
    MarlinRunSimpleDialogData *data;
    int res;
    int n_titles;
    const char *button_title;
    GPtrArray *ptr_array;

    g_timer_stop (job->time);

    data = g_new0 (MarlinRunSimpleDialogData, 1);
    data->parent_window = GTK_WINDOW (job->parent_window);
    data->ignore_close_box = ignore_close_box;
    data->message_type = message_type;
    data->primary_text = primary_text;
    data->secondary_text = secondary_text;
    data->details_text = details_text;
    data->show_all = show_all;

    ptr_array = g_ptr_array_new ();
    n_titles = 0;
    while ((button_title = va_arg (varargs, const char *)) != NULL) {
        g_ptr_array_add (ptr_array, (char *)button_title);
        n_titles++;
    }
    g_ptr_array_add (ptr_array, NULL);
    data->button_titles = (const char **)g_ptr_array_free (ptr_array, FALSE);
    data->button_titles_length1 = n_titles;

    pf_progress_info_pause (job->progress);
    g_io_scheduler_job_send_to_mainloop (job->io_job,
                                         do_run_simple_dialog,
                                         data,
                                         NULL);
    pf_progress_info_resume (job->progress);
    res = data->result;

    g_free (data->button_titles);
    g_free (data);

    g_timer_continue (job->time);

    g_free (primary_text);
    g_free (secondary_text);

    return res;
}

static int
run_error (CommonJob *job,
           char *primary_text,
           char *secondary_text,
           const char *details_text,
           gboolean show_all,
           ...)
{
    va_list varargs;
    int res;

    va_start (varargs, show_all);
    res = run_simple_dialog_va (job,
                                FALSE,
                                GTK_MESSAGE_ERROR,
                                primary_text,
                                secondary_text,
                                details_text,
                                show_all,
                                varargs);
    va_end (varargs);
    return res;
}

static int
run_warning (CommonJob *job,
             char *primary_text,
             char *secondary_text,
             const char *details_text,
             gboolean show_all,
             ...)
{
    va_list varargs;
    int res;

    va_start (varargs, show_all);
    res = run_simple_dialog_va (job,
                                FALSE,
                                GTK_MESSAGE_WARNING,
                                primary_text,
                                secondary_text,
                                details_text,
                                show_all,
                                varargs);
    va_end (varargs);
    return res;
}

static int
run_question (CommonJob *job,
              char *primary_text,
              char *secondary_text,
              const char *details_text,
              gboolean show_all,
              ...)
{
    va_list varargs;
    int res;

    va_start (varargs, show_all);
    res = run_simple_dialog_va (job,
                                FALSE,
                                GTK_MESSAGE_QUESTION,
                                primary_text,
                                secondary_text,
                                details_text,
                                show_all,
                                varargs);
    va_end (varargs);
    return res;
}

static void
inhibit_power_manager (CommonJob *job, const char *message)
{
    job->inhibit_cookie = gtk_application_inhibit (GTK_APPLICATION (g_application_get_default ()),
                                                   GTK_WINDOW (job->parent_window),
                                                   GTK_APPLICATION_INHIBIT_LOGOUT |
                                                   GTK_APPLICATION_INHIBIT_SUSPEND,
                                                   message);
}

static void
abort_job (CommonJob *job)
{
    g_cancellable_cancel (job->cancellable);

}

static gboolean
job_aborted (CommonJob *job)
{
    return g_cancellable_is_cancelled (job->cancellable);
}

/* Since this happens on a thread we can't use the global prefs object */
static gboolean
should_confirm_trash (void)
{
    return gof_preferences_get_confirm_trash (gof_preferences_get_default ());
}

static gboolean
confirm_delete_from_trash (CommonJob *job,
                           GList *files)
{
    char *prompt;
    int file_count;
    int response;

    file_count = g_list_length (files);
    g_assert (file_count > 0);

    /* Only called if confirmation known to be required - do not second guess */

    if (file_count == 1) {
        gchar *basename = custom_basename_from_file (files->data);
        /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
        /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
        prompt = g_strdup_printf (_("Are you sure you want to permanently delete \"%s\" "
                                  "from the trash?"), basename);
        g_free (basename);
    } else {
        prompt = g_strdup_printf (ngettext("Are you sure you want to permanently delete "
                                           "the %'d selected item from the trash?",
                                           "Are you sure you want to permanently delete "
                                           "the %'d selected items from the trash?",
                                           file_count),
                                  file_count);
    }

    response = run_warning (job,
                            prompt,
                            g_strdup (_("If you delete an item, it will be permanently lost.")),
                            NULL,
                            FALSE,
                            CANCEL, DELETE,
                            NULL);

    return (response == 1);
}

static gboolean
confirm_delete_directly (CommonJob *job,
                         GList *files)
{
    char *prompt;
    int file_count;
    int response;

    /* Only called if confirmation known to be required - do not second guess */

    file_count = g_list_length (files);
    g_assert (file_count > 0);

    if (file_count == 1) {
        gchar *basename = custom_basename_from_file (files->data);
        /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
        /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
        prompt = g_strdup_printf (_("Permanently delete “%s”?"), basename);
        g_free (basename);
    } else {
        prompt = g_strdup_printf (ngettext("Are you sure you want to permanently delete "
                                           "the %'d selected item?",
                                           "Are you sure you want to permanently delete "
                                           "the %'d selected items?", file_count),
                                  file_count);
    }

    response = run_warning (job,
                            prompt,
                            g_strdup (_("Deleted items are not sent to Trash and are not recoverable.")),
                            NULL,
                            FALSE,
                            CANCEL, DELETE,
                            NULL);

    return response == 1;
}

static void
report_delete_progress (CommonJob *job,
                        SourceInfo *source_info,
                        TransferInfo *transfer_info)
{
    int files_left;
    double elapsed, transfer_rate;
    int remaining_time;
    guint64 now;
    char *files_left_s;

    now = g_thread_gettime ();
    if (transfer_info->last_report_time != 0 &&
        ABS ((gint64)(transfer_info->last_report_time - now)) < 100 * NSEC_PER_MSEC) {
        return;
    }
    transfer_info->last_report_time = now;

    files_left = source_info->num_files - transfer_info->num_files;

    /* Races and whatnot could cause this to be negative... */
    if (files_left < 0) {
        files_left = 1;
    }

    files_left_s = g_strdup_printf (ngettext ("%'d file left to delete",
                                              "%'d files left to delete",
                                              files_left),
                                    files_left);

    pf_progress_info_take_status (job->progress, g_strdup (_("Deleting files")));

    elapsed = g_timer_elapsed (job->time, NULL);
    if (elapsed < SECONDS_NEEDED_FOR_RELIABLE_TRANSFER_RATE) {
        pf_progress_info_set_details (job->progress, files_left_s);
    } else {
        char *details, *time_left_s;
        gchar *formated_time;
        transfer_rate = transfer_info->num_files / elapsed;
        remaining_time = files_left / transfer_rate;
        int formated_time_unit;
        formated_time = format_time (remaining_time, &formated_time_unit);

        /// TRANSLATORS: %s will expand to a time like "2 minutes". It must not be translated or removed.
        /// The singular/plural form will be used depending on the remaining time (i.e. the %s argument).
        time_left_s = g_strdup_printf (ngettext ("%s left",
                                                 "%s left",
                                                 formated_time_unit),
                                       formated_time);
        g_free (formated_time);

        details = g_strconcat (files_left_s, "\xE2\x80\x94", time_left_s, NULL);
        pf_progress_info_take_details (job->progress, details);

        g_free (time_left_s);
    }

    g_free (files_left_s);

    if (source_info->num_files != 0) {
        pf_progress_info_update_progress (job->progress, transfer_info->num_files, source_info->num_files);
    }
}

static void delete_file (CommonJob *job, GFile *file,
                         gboolean *skipped_file,
                         SourceInfo *source_info,
                         TransferInfo *transfer_info,
                         gboolean toplevel);

static void
delete_dir (CommonJob *job, GFile *dir,
            gboolean *skipped_file,
            SourceInfo *source_info,
            TransferInfo *transfer_info,
            gboolean toplevel)
{
    GFileInfo *info;
    GError *error;
    GFile *file;
    GFileEnumerator *enumerator;
    char *primary, *secondary, *details;
    int response;
    gboolean skip_error;
    gboolean local_skipped_file;

    local_skipped_file = FALSE;

    skip_error = should_skip_readdir_error (job, dir);
retry:
    error = NULL;
    enumerator = g_file_enumerate_children (dir,
                                            G_FILE_ATTRIBUTE_STANDARD_NAME,
                                            G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS,
                                            job->cancellable,
                                            &error);
    if (enumerator) {
        error = NULL;

        while (!job_aborted (job) &&
               (info = g_file_enumerator_next_file (enumerator, job->cancellable, skip_error?NULL:&error)) != NULL) {
            file = g_file_get_child (dir,
                                     g_file_info_get_name (info));
            delete_file (job, file, &local_skipped_file, source_info, transfer_info, FALSE);
            g_object_unref (file);
            g_object_unref (info);
        }
        g_file_enumerator_close (enumerator, job->cancellable, NULL);
        g_object_unref (enumerator);

        if (error && IS_IO_ERROR (error, CANCELLED)) {
            g_error_free (error);
        } else if (error) {
            gchar *dir_basename = custom_basename_from_file (dir);
            primary = g_strdup (_("Error while deleting."));
            details = NULL;

            if (IS_IO_ERROR (error, PERMISSION_DENIED)) {
                /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
                /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
                secondary = g_strdup_printf (_("Files in the folder \"%s\" cannot be deleted because you do "
                                             "not have permissions to see them."), dir_basename);
            } else {
                /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
                /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
                secondary = g_strdup_printf (_("There was an error getting information about the files in the folder \"%s\"."), dir_basename);
                details = error->message;
            }

            g_free (dir_basename);
            response = run_warning (job,
                                    primary,
                                    secondary,
                                    details,
                                    FALSE,
                                    CANCEL, _("_Skip files"),
                                    NULL);

            g_error_free (error);

            if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
                abort_job (job);
            } else if (response == 1) {
                /* Skip: Do Nothing */
                local_skipped_file = TRUE;
            } else {
                g_assert_not_reached ();
            }
        }

    } else if (IS_IO_ERROR (error, CANCELLED)) {
        g_error_free (error);
    } else {
        gchar *dir_basename = custom_basename_from_file (dir);
        primary = g_strdup (_("Error while deleting."));
        details = NULL;
        if (IS_IO_ERROR (error, PERMISSION_DENIED)) {
            /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
            /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
            secondary = g_strdup_printf (_("The folder \"%s\" cannot be deleted because you do not have "
                             "permissions to read it."), dir_basename);
        } else {
            /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
            /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
            secondary = g_strdup_printf (_("There was an error reading the folder \"%s\"."), dir_basename);
            details = error->message;
        }

        g_free (dir);
        response = run_warning (job,
                                primary,
                                secondary,
                                details,
                                FALSE,
                                CANCEL, SKIP, RETRY,
                                NULL);

        g_error_free (error);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            abort_job (job);
        } else if (response == 1) {
            /* Skip: Do Nothing  */
            local_skipped_file = TRUE;
        } else if (response == 2) {
            goto retry;
        } else {
            g_assert_not_reached ();
        }
    }

    if (!job_aborted (job) &&
        /* Don't delete dir if there was a skipped file */
        !local_skipped_file) {
        if (!g_file_delete (dir, job->cancellable, &error)) {
            gchar *dir_basename;
            if (job->skip_all_error) {
                goto skip;
            }

            primary = g_strdup (_("Error while deleting."));
            dir_basename = custom_basename_from_file (dir);
            /// TRANSLATORS: %s is a placeholder for the basename of a file.  It may change position but must not be translated or removed
            secondary = g_strdup_printf (_("Could not remove the folder %s."), dir_basename);
            g_free (dir_basename);

            details = error->message;

            response = run_warning (job,
                                    primary,
                                    secondary,
                                    details,
                                    (source_info->num_files - transfer_info->num_files) > 1,
                                    CANCEL, SKIP_ALL, SKIP,
                                    NULL);

            if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
                abort_job (job);
            } else if (response == 1) { /* skip all */
                job->skip_all_error = TRUE;
                local_skipped_file = TRUE;
            } else if (response == 2) { /* skip */
                local_skipped_file = TRUE;
            } else {
                g_assert_not_reached ();
            }

skip:
            g_error_free (error);
        } else {
            marlin_file_changes_queue_file_removed (dir);
            transfer_info->num_files ++;
            report_delete_progress (job, source_info, transfer_info);
            return;
        }
    }

    if (local_skipped_file) {
        *skipped_file = TRUE;
    }
}

static void
delete_file (CommonJob *job, GFile *file,
             gboolean *skipped_file,
             SourceInfo *source_info,
             TransferInfo *transfer_info,
             gboolean toplevel)
{
    GError *error;
    char *primary, *secondary, *details;
    int response;

    if (should_skip_file (job, file)) {
        *skipped_file = TRUE;
        return;
    }

    error = NULL;
    if (g_file_delete (file, job->cancellable, &error)) {
        marlin_file_changes_queue_file_removed (file);
        transfer_info->num_files ++;
        report_delete_progress (job, source_info, transfer_info);
        return;
    }

    if (IS_IO_ERROR (error, NOT_EMPTY)) {
        g_error_free (error);
        delete_dir (job, file,
                    skipped_file,
                    source_info, transfer_info,
                    toplevel);
        return;

    } else if (IS_IO_ERROR (error, CANCELLED)) {
        g_error_free (error);

    } else {
        gchar *dir_basename;
        if (job->skip_all_error) {
            goto skip;
        }
        primary = g_strdup (_("Error while deleting."));
        dir_basename = custom_basename_from_file (file);
        /// TRANSLATORS: %s is a placeholder for the basename of a file.  It may change position but must not be translated or removed
        secondary = g_strdup_printf (_("There was an error deleting %s."), dir_basename);
        g_free (dir_basename);
        details = error->message;

        response = run_warning (job,
                                primary,
                                secondary,
                                details,
                                (source_info->num_files - transfer_info->num_files) > 1,
                                CANCEL, SKIP_ALL, SKIP,
                                NULL);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            abort_job (job);
        } else if (response == 1) { /* skip all */
            job->skip_all_error = TRUE;
        } else if (response == 2) { /* skip */
            /* do nothing */
        } else {
            g_assert_not_reached ();
        }
skip:
        g_error_free (error);
    }

    *skipped_file = TRUE;
}

static void
delete_files (CommonJob *job, GList *files, int *files_skipped)
{
    GList *l;
    GFile *file;
    SourceInfo source_info;
    TransferInfo transfer_info;
    gboolean skipped_file;

    if (job_aborted (job)) {
        return;
    }

    scan_sources (files,
                  &source_info,
                  job,
                  OP_KIND_DELETE);
    if (job_aborted (job)) {
        return;
    }

    g_timer_start (job->time);

    memset (&transfer_info, 0, sizeof (transfer_info));
    report_delete_progress (job, &source_info, &transfer_info);

    for (l = files;
         l != NULL && !job_aborted (job);
         l = l->next) {
        file = l->data;

        skipped_file = FALSE;
        delete_file (job, file,
                     &skipped_file,
                     &source_info, &transfer_info,
                     TRUE);
        if (skipped_file) {
            (*files_skipped)++;
        }
    }

    PFSoundManager *sm;
    sm = pf_sound_manager_get_instance (); /* returns unowned instance - no need to unref */
    pf_sound_manager_play_delete_sound (sm);
}

static void
report_trash_progress (CommonJob *job,
                       int files_trashed,
                       int total_files)
{
    int files_left;
    char *s;

    files_left = total_files - files_trashed;

    pf_progress_info_take_status (job->progress,
                                  g_strdup (_("Moving files to trash")));

    s = g_strdup_printf (ngettext ("%'d file left to trash",
                                   "%'d files left to trash",
                                   files_left),
                         files_left);
    pf_progress_info_take_details (job->progress, s);

    if (total_files != 0) {
        pf_progress_info_update_progress (job->progress, files_trashed, total_files);
    }
}


static void
trash_files (CommonJob *job, GList *files, int *files_skipped)
{
    GList *l;
    GFile *file;
    GList *to_delete;
    GError *error;
    GFileInfo *info;
    GFileInfo *parent_info;
    GFileInfo *fsinfo;
    int total_files, files_trashed;
    char *primary, *secondary, *details;
    int response;
    guint64 mtime;
    gboolean can_delete;
    gboolean can_write;
    gboolean is_folder;
    gboolean parent_can_write;
    gboolean readonly_fs;
    gboolean have_info;
    gboolean have_parent_info;
    gboolean have_filesystem_info;

    if (job_aborted (job)) {
        return;
    }

    total_files = g_list_length (files);
    files_trashed = 0;

    report_trash_progress (job, files_trashed, total_files);

    to_delete = NULL;
    for (l = files;
         l != NULL && !job_aborted (job);
         l = l->next) {
        file = l->data;

        error = NULL;
        if (!G_IS_FILE (file)) {
            (*files_skipped)++;
            goto skip;
        }

        mtime = pf_file_utils_get_file_modification_time (file);

        if (!g_file_trash (file, job->cancellable, &error)) {
            if (job->skip_all_error) {
                (*files_skipped)++;
                goto skip;
            }

            if (job->delete_all) {
                to_delete = g_list_prepend (to_delete, file);
                goto skip;
            }

            info = g_file_query_info (file, "access::can-write,standard::type", 0, NULL, NULL);
            parent_info = g_file_query_info (g_file_get_parent (file), "access::can-write", 0, NULL, NULL);
            fsinfo = g_file_query_filesystem_info (file, "filesystem::readonly", NULL, NULL);

            if (info != NULL) {
                can_write = g_file_info_get_attribute_boolean (info, "access::can-write");
                is_folder = (g_file_info_get_file_type (info) == G_FILE_TYPE_DIRECTORY);
                have_info = TRUE;
                g_object_unref (info);
            } else
                have_info = FALSE;

            if (parent_info != NULL) {
                parent_can_write = g_file_info_get_attribute_boolean (parent_info, "access::can-write");
                have_parent_info = TRUE;
                g_object_unref (parent_info);
            } else
                have_parent_info = FALSE;

            if (fsinfo != NULL) {
                readonly_fs = g_file_info_get_attribute_boolean (fsinfo, "filesystem::readonly");
                have_filesystem_info = TRUE;
                g_object_unref (fsinfo);
            } else
                have_filesystem_info = FALSE;

            if (have_info) {
                can_delete = FALSE;
                if (have_filesystem_info && readonly_fs) {
                    primary = g_strdup (_("Cannot move file to trash or delete it"));
                    secondary = g_strdup (_("It is not permitted to trash or delete files on a read only filesystem."));
                } else if (have_parent_info && !parent_can_write) {
                    primary = g_strdup (_("Cannot move file to trash or delete it"));
                    secondary = g_strdup (_("It is not permitted to trash or delete files inside folders for which you do not have write privileges."));
                } else if (is_folder && !can_write ) {
                    primary = g_strdup (_("Cannot move file to trash or delete it"));
                    secondary = g_strdup (_("It is not permitted to trash or delete folders for which you do not have write privileges."));
                } else {
                    primary = g_strdup (_("Cannot move file to trash. Try to delete it immediately?"));
                    secondary = g_strdup (_("This file could not be moved to trash. See details below for further information."));
                    can_delete = TRUE;
                }
            } else {
                primary = g_strdup (_("Cannot move file to trash.  Try to delete it?"));
                secondary = g_strdup (_("This file could not be moved to trash. You may not be able to delete it either."));
                can_delete = TRUE;
            }

            if (can_delete) {
                gchar *old_secondary = g_steal_pointer (&secondary);
                secondary = g_strconcat (old_secondary, _("\n Deleting a file removes it permanently"), NULL);
                g_free (old_secondary);
            }

            details = NULL;
            details = error->message;

            /* Note primary and secondary text is freed by run_simple_dialog_va */
            if (can_delete) {
                response = run_question (job,
                                         primary,
                                         secondary,
                                         details,
                                         (total_files - files_trashed) > 1,
                                         CANCEL, SKIP_ALL, SKIP, DELETE_ALL, DELETE,
                                         NULL);
            } else {
                response = run_question (job,
                                         primary,
                                         secondary,
                                         details,
                                         (total_files - files_trashed) > 1,
                                         CANCEL, SKIP_ALL, SKIP,
                                         NULL);

            }

            if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
                ((DeleteJob *) job)->user_cancel = TRUE;
                abort_job (job);
            } else if (response == 1) { /* skip all */
                (*files_skipped)++;
                job->skip_all_error = TRUE;
            } else if (response == 2) { /* skip */
                (*files_skipped)++;
            } else if (response == 3) { /* delete all */
                to_delete = g_list_prepend (to_delete, file);
                job->delete_all = TRUE;
            } else if (response == 4) { /* delete */
                to_delete = g_list_prepend (to_delete, file);
            }

skip:
            g_error_free (error);
            total_files--;
        } else {
            marlin_file_changes_queue_file_removed (file);

            // Start UNDO-REDO
            marlin_undo_action_data_add_trashed_file (job->undo_redo_data, file, mtime);
            // End UNDO-REDO

            files_trashed++;
            report_trash_progress (job, files_trashed, total_files);
        }
    }

    if (to_delete) {
        to_delete = g_list_reverse (to_delete);
        delete_files (job, to_delete, files_skipped);
        g_list_free (to_delete);
    }
}

static gboolean
delete_job_done (gpointer user_data)
{
    DeleteJob *job = user_data;

    g_list_free_full (job->files, g_object_unref);
    g_task_return_boolean (job->task, TRUE);
    g_clear_object (&job->task);

    finalize_common ((CommonJob *)job);

    marlin_file_changes_consume_changes (TRUE);

    return FALSE;
}

static gboolean
delete_job (GIOSchedulerJob *io_job,
            GCancellable *cancellable,
            gpointer user_data)
{
    DeleteJob *job = user_data;
    GList *to_trash_files;
    GList *to_delete_files;
    GList *l;
    GFile *file;
    gboolean confirmed;
    CommonJob *common;
    gboolean must_confirm_delete_in_trash;
    gboolean must_confirm_delete;
    int files_skipped;
    int job_files;

    common = (CommonJob *)job;
    common->io_job = io_job;

    pf_progress_info_start (job->common.progress);

    to_trash_files = NULL;
    to_delete_files = NULL;

    must_confirm_delete_in_trash = FALSE;
    must_confirm_delete = FALSE;
    files_skipped = 0;
    job_files = 0;

    for (l = job->files; l != NULL; l = l->next) {
        file = l->data;

        job_files++;

        if (job->try_trash && g_file_has_uri_scheme (file, "trash")) {
            must_confirm_delete_in_trash = TRUE;
            to_delete_files = g_list_prepend (to_delete_files, file);
        } else if (can_delete_without_confirm (file)) {
            to_delete_files = g_list_prepend (to_delete_files, file);
        } else {
            if (job->try_trash &&
                !g_file_has_uri_scheme (file, "smb")) {
                to_trash_files = g_list_prepend (to_trash_files, file);
            } else {
                must_confirm_delete = TRUE;
                to_delete_files = g_list_prepend (to_delete_files, file);
            }
        }
    }

    if (to_delete_files != NULL) {
        to_delete_files = g_list_reverse (to_delete_files);
        confirmed = TRUE;
        if (must_confirm_delete_in_trash) {
            confirmed = !should_confirm_trash () || confirm_delete_from_trash (common, to_delete_files);
        } else if (must_confirm_delete) {
            confirmed = confirm_delete_directly (common, to_delete_files);
        }

        if (confirmed) {
            delete_files (common, to_delete_files, &files_skipped);
        } else {
            job->user_cancel = TRUE;
        }
    }

    if (to_trash_files != NULL) {
        to_trash_files = g_list_reverse (to_trash_files);

        trash_files (common, to_trash_files, &files_skipped);
    }

    g_list_free (to_trash_files);
    g_list_free (to_delete_files);

    if (files_skipped == job_files) {
        /* User has skipped all files, report user cancel */
        job->user_cancel = TRUE;
    }

    g_io_scheduler_job_send_to_mainloop_async (io_job,
                                               delete_job_done,
                                               job,
                                               NULL);

    return FALSE;
}

void
marlin_file_operations_delete (GList               *files,
                               GtkWindow           *parent_window,
                               gboolean             try_trash,
                               GCancellable        *cancellable,
                               GAsyncReadyCallback  callback,
                               gpointer             user_data)
{
    g_return_if_fail (files != NULL);

    DeleteJob *job;

    /* TODO: special case desktop icon link files ... */

    job = op_job_new (DeleteJob, parent_window);
    job->files = g_list_copy_deep (files, (GCopyFunc) g_object_ref, NULL);
    job->try_trash = try_trash;
    job->user_cancel = FALSE;
    job->task = g_task_new (NULL, cancellable, callback, user_data);

    if (try_trash) {
        inhibit_power_manager ((CommonJob *)job, _("Trashing Files"));
    } else {
        inhibit_power_manager ((CommonJob *)job, _("Deleting Files"));
    }

    if (try_trash) {
        job->common.undo_redo_data = marlin_undo_action_data_new (MARLIN_UNDO_MOVETOTRASH, g_list_length(files));
        GFile* src_dir = g_file_get_parent (files->data);
        marlin_undo_action_data_set_src_dir (job->common.undo_redo_data, src_dir);
    }

    g_io_scheduler_push_job (delete_job,
                             job,
                             NULL,
                             0,
                             NULL);
}

gboolean
marlin_file_operations_delete_finish (GAsyncResult  *result,
                                      GError       **error)
{
    g_return_val_if_fail (g_task_is_valid (result, NULL), NULL);

    return g_task_propagate_boolean (G_TASK (result), error);
}

static void
report_count_progress (CommonJob *job,
                       SourceInfo *source_info)
{
    char *s;
    gchar *num_bytes_format;

    switch (source_info->op) {
    default:
    case OP_KIND_COPY:
        num_bytes_format = g_format_size (source_info->num_bytes);
        /// TRANSLATORS: %'d is a placeholder for a number. It must be translated or removed.
        /// %s is a placeholder for a size like "2 bytes" or "3 MB".  It must not be translated or removed.
        /// So this represents something like "Preparing to copy 100 files (200 MB)"
        /// The order in which %'d and %s appear can be changed by using the right positional specifier.
        s = g_strdup_printf (ngettext("Preparing to copy %'d file (%s)",
                                      "Preparing to copy %'d files (%s)",
                                      source_info->num_files),
                             source_info->num_files, num_bytes_format);
        g_free (num_bytes_format);
        break;
    case OP_KIND_MOVE:
        num_bytes_format = g_format_size (source_info->num_bytes);
        /// TRANSLATORS: %'d is a placeholder for a number. It must be translated or removed.
        /// %s is a placeholder for a size like "2 bytes" or "3 MB".  It must not be translated or removed.
        /// So this represents something like "Preparing to move 100 files (200 MB)"
        /// The order in which %'d and %s appear can be changed by using the right positional specifier.
        s = g_strdup_printf (ngettext("Preparing to move %'d file (%s)",
                                      "Preparing to move %'d files (%s)",
                                      source_info->num_files),
                             source_info->num_files, num_bytes_format);
        g_free (num_bytes_format);
        break;
    case OP_KIND_DELETE:
        num_bytes_format = g_format_size (source_info->num_bytes);
        /// TRANSLATORS: %'d is a placeholder for a number. It must be translated or removed.
        /// %s is a placeholder for a size like "2 bytes" or "3 MB".  It must not be translated or removed.
        /// So this represents something like "Preparing to delete 100 files (200 MB)"
        /// The order in which %'d and %s appear can be changed by using the right positional specifier.
        s = g_strdup_printf (ngettext("Preparing to delete %'d file (%s)",
                                      "Preparing to delete %'d files (%s)",
                                      source_info->num_files),
                             source_info->num_files, num_bytes_format);
        g_free (num_bytes_format);
        break;
    case OP_KIND_TRASH:
        s = g_strdup_printf (ngettext("Preparing to trash %'d file",
                                      "Preparing to trash %'d files",
                                      source_info->num_files),
                             source_info->num_files);
        break;
    }

    pf_progress_info_take_details (job->progress, s);
    pf_progress_info_pulse_progress (job->progress);
}

static void
count_file (GFileInfo *info,
            CommonJob *job,
            SourceInfo *source_info)
{
    source_info->num_files += 1;
    source_info->num_bytes += g_file_info_get_size (info);

    if (source_info->num_files_since_progress++ > 100) {
        report_count_progress (job, source_info);
        source_info->num_files_since_progress = 0;
    }
}

static char *
get_scan_primary (OpKind kind)
{
    switch (kind) {
    default:
    case OP_KIND_COPY:
        return g_strdup (_("Error while copying."));
    case OP_KIND_MOVE:
        return g_strdup (_("Error while moving."));
    case OP_KIND_DELETE:
        return g_strdup (_("Error while deleting."));
    case OP_KIND_TRASH:
        return g_strdup (_("Error while moving files to trash."));
    }
}

static void
scan_dir (GFile *dir,
          SourceInfo *source_info,
          CommonJob *job,
          GQueue *dirs)
{
    GFileInfo *info;
    GError *error;
    GFile *subdir;
    GFileEnumerator *enumerator;
    char *primary, *secondary, *details;
    int response;
    SourceInfo saved_info;

    saved_info = *source_info;

retry:
    error = NULL;
    enumerator = g_file_enumerate_children (dir,
                                            G_FILE_ATTRIBUTE_STANDARD_NAME","
                                            G_FILE_ATTRIBUTE_STANDARD_TYPE","
                                            G_FILE_ATTRIBUTE_STANDARD_SIZE,
                                            G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS,
                                            job->cancellable,
                                            &error);
    if (enumerator) {
        error = NULL;
        while ((info = g_file_enumerator_next_file (enumerator, job->cancellable, &error)) != NULL) {
            count_file (info, job, source_info);

            if (g_file_info_get_file_type (info) == G_FILE_TYPE_DIRECTORY) {
                subdir = g_file_get_child (dir,
                                           g_file_info_get_name (info));

                /* Push to head, since we want depth-first */
                g_queue_push_head (dirs, subdir);
            }

            g_object_unref (info);
        }
        g_file_enumerator_close (enumerator, job->cancellable, NULL);
        g_object_unref (enumerator);

        if (error && IS_IO_ERROR (error, CANCELLED)) {
            g_error_free (error);
        } else if (error) {
            gchar *dir_basename = custom_basename_from_file (dir);
            primary = get_scan_primary (source_info->op);
            details = NULL;

            if (IS_IO_ERROR (error, PERMISSION_DENIED)) {
                /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
                /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
                secondary = g_strdup_printf (_("Files in the folder \"%s\" cannot be handled because you do "
                                             "not have permissions to see them."), dir_basename);
            } else {
                /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
                /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
                secondary = g_strdup_printf (_("There was an error getting information about the files in the folder \"%s\"."), dir_basename);
                details = error->message;
            }

            g_free (dir_basename);
            response = run_warning (job,
                                    primary,
                                    secondary,
                                    details,
                                    FALSE,
                                    CANCEL, RETRY, SKIP,
                                    NULL);

            g_error_free (error);

            if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
                abort_job (job);
            } else if (response == 1) {
                *source_info = saved_info;
                goto retry;
            } else if (response == 2) {
                skip_readdir_error (job, dir);
            } else {
                g_assert_not_reached ();
            }
        }

    } else if (job->skip_all_error) {
        g_error_free (error);
        skip_file (job, dir);
    } else if (IS_IO_ERROR (error, CANCELLED)) {
        g_error_free (error);
    } else {
        gchar *dir_basename = custom_basename_from_file (dir);
        primary = get_scan_primary (source_info->op);
        details = NULL;

        if (IS_IO_ERROR (error, PERMISSION_DENIED)) {
            /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
            /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
            secondary = g_strdup_printf (_("The folder \"%s\" cannot be handled because you do not have "
                                         "permissions to read it."), dir_basename);
        } else {
            /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
            /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
            secondary = g_strdup_printf (_("There was an error reading the folder \"%s\"."), dir_basename);
            details = error->message;
        }

        g_free (dir_basename);
        /* set show_all to TRUE here, as we don't know how many
         * files we'll end up processing yet.
         */
        response = run_warning (job,
                                primary,
                                secondary,
                                details,
                                TRUE,
                                CANCEL, SKIP_ALL, SKIP, RETRY,
                                NULL);

        g_error_free (error);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            abort_job (job);
        } else if (response == 1 || response == 2) {
            if (response == 1) {
                job->skip_all_error = TRUE;
            }
            skip_file (job, dir);
        } else if (response == 3) {
            goto retry;
        } else {
            g_assert_not_reached ();
        }
    }
}

static void
scan_file (GFile *file,
           SourceInfo *source_info,
           CommonJob *job)
{
    GFileInfo *info;
    GError *error;
    GQueue *dirs;
    GFile *dir;
    char *primary;
    char *secondary;
    char *details;
    int response;

    dirs = g_queue_new ();
retry:
    error = NULL;
    info = NULL;

    if (G_IS_FILE (file)) {
        info = g_file_query_info (file,
                                  G_FILE_ATTRIBUTE_STANDARD_TYPE","
                                  G_FILE_ATTRIBUTE_STANDARD_SIZE,
                                  G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS,
                                  job->cancellable,
                                  &error);
    }

    if (info) {
        count_file (info, job, source_info);

        if (g_file_info_get_file_type (info) == G_FILE_TYPE_DIRECTORY) {
            g_queue_push_head (dirs, g_object_ref (file));
        }

        g_object_unref (info);
    } else if (job->skip_all_error) {
        g_error_free (error);
        skip_file (job, file);
    } else if (IS_IO_ERROR (error, CANCELLED)) {
        g_error_free (error);
    } else {
        gchar *file_basename = custom_basename_from_file (file);
        primary = get_scan_primary (source_info->op);
        details = NULL;

        if (IS_IO_ERROR (error, PERMISSION_DENIED)) {
            /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
            /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
            secondary = g_strdup_printf (_("The file \"%s\" cannot be handled because you do not have "
                                         "permissions to read it."), file_basename);
        } else {
            /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
            /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
            secondary = g_strdup_printf (_("There was an error getting information about \"%s\"."), file_basename);
            details = error->message;
        }

        g_free (file_basename);
        /* set show_all to TRUE here, as we don't know how many
         * files we'll end up processing yet.
         */
        response = run_warning (job,
                                primary,
                                secondary,
                                details,
                                TRUE,
                                CANCEL, SKIP_ALL, SKIP, RETRY,
                                NULL);

        g_error_free (error);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            abort_job (job);
        } else if (response == 1 || response == 2) {
            if (response == 1) {
                job->skip_all_error = TRUE;
            }
            skip_file (job, file);
        } else if (response == 3) {
            goto retry;
        } else {
            g_assert_not_reached ();
        }
    }

    while (!job_aborted (job) &&
           (dir = g_queue_pop_head (dirs)) != NULL) {
        scan_dir (dir, source_info, job, dirs);
        g_object_unref (dir);
    }

    /* Free all from queue if we exited early */
    g_queue_foreach (dirs, (GFunc)g_object_unref, NULL);
    g_queue_free (dirs);
}

static void
scan_sources (GList *files,
              SourceInfo *source_info,
              CommonJob *job,
              OpKind kind)
{
    GList *l;
    GFile *file;

    memset (source_info, 0, sizeof (SourceInfo));
    source_info->op = kind;

    report_count_progress (job, source_info);

    for (l = files; l != NULL && !job_aborted (job); l = l->next) {
        file = l->data;

        scan_file (file,
                   source_info,
                   job);
    }

    /* Make sure we report the final count */
    report_count_progress (job, source_info);
}

static void
verify_destination (CommonJob *job,
                    GFile *dest,
                    char **dest_fs_id,
                    goffset required_size)
{
    GFileInfo *info, *fsinfo;
    GError *error;
    guint64 free_size;
    char *primary, *secondary, *details;
    int response;
    GFileType file_type;

    if (dest_fs_id) {
        *dest_fs_id = NULL;
    }

retry:

    error = NULL;
    info = g_file_query_info (dest,
                              G_FILE_ATTRIBUTE_STANDARD_TYPE","
                              G_FILE_ATTRIBUTE_ID_FILESYSTEM,
                              0,
                              job->cancellable,
                              &error);

    if (info == NULL) {
        gchar *dest_basename;
        if (IS_IO_ERROR (error, CANCELLED)) {
            g_error_free (error);
            return;
        }

        dest_basename = custom_basename_from_file (dest);
        /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
        /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
        primary = g_strdup_printf (_("Error while copying to \"%s\"."), dest_basename);
        g_free (dest_basename);
        details = NULL;

        if (IS_IO_ERROR (error, PERMISSION_DENIED)) {
            secondary = g_strdup (_("You do not have permissions to access the destination folder."));
        } else {
            secondary = g_strdup (_("There was an error getting information about the destination."));
            details = error->message;
        }

        response = run_error (job,
                              primary,
                              secondary,
                              details,
                              FALSE,
                              CANCEL, RETRY,
                              NULL);

        g_error_free (error);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            abort_job (job);
        } else if (response == 1) {
            goto retry;
        } else {
            g_assert_not_reached ();
        }

        return;
    }

    file_type = g_file_info_get_file_type (info);

    if (dest_fs_id) {
        *dest_fs_id =
            g_strdup (g_file_info_get_attribute_string (info,
                                                        G_FILE_ATTRIBUTE_ID_FILESYSTEM));
    }

    g_object_unref (info);

    if (file_type != G_FILE_TYPE_DIRECTORY) {
        gchar *dest_name = g_file_get_parse_name (dest);
        /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
        /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
        primary = g_strdup_printf (_("Error while copying to \"%s\"."), dest_name);
        secondary = g_strdup (_("The destination is not a folder."));
        g_free (dest_name);

        response = run_error (job,
                              primary,
                              secondary,
                              NULL,
                              FALSE,
                              CANCEL,
                              NULL);

        abort_job (job);
        return;
    }

    fsinfo = g_file_query_filesystem_info (dest,
                                           G_FILE_ATTRIBUTE_FILESYSTEM_FREE","
                                           G_FILE_ATTRIBUTE_FILESYSTEM_READONLY,
                                           job->cancellable,
                                           NULL);
    if (fsinfo == NULL) {
        /* All sorts of things can go wrong getting the fs info (like not supported)
         * only check these things if the fs returns them
         */
        return;
    }

    if (required_size > 0 &&
        g_file_info_has_attribute (fsinfo, G_FILE_ATTRIBUTE_FILESYSTEM_FREE)) {
        free_size = g_file_info_get_attribute_uint64 (fsinfo,
                                                      G_FILE_ATTRIBUTE_FILESYSTEM_FREE);

        if (free_size < required_size) {
            gchar *free_size_format, *required_size_format;
            gchar *dest_name = g_file_get_parse_name (dest);
            /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
            /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
            primary = g_strdup_printf (_("Error while copying to \"%s\"."), dest_name);
            g_free (dest_name);
            secondary = g_strdup (_("There is not enough space on the destination. Try to remove files to make space."));

            free_size_format = g_format_size (free_size);
            required_size_format = g_format_size (required_size);
            /// TRANSLATORS: %s is a placeholder for a size like "2 bytes" or "3 MB".  It must not be translated or removed.
            /// So this represents something like "There is 100 MB available, but 150 MB is required".
            details = g_strdup_printf (_("There is %s available, but %s is required."), free_size_format, required_size_format);
            g_free (free_size_format);
            g_free (required_size_format);

            response = run_warning (job,
                                    primary,
                                    secondary,
                                    details,
                                    FALSE,
                                    CANCEL,
                                    COPY_FORCE,
                                    RETRY,
                                    NULL);

            if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
                abort_job (job);
            } else if (response == 2) {
                goto retry;
            } else if (response == 1) {
                /* We are forced to copy - just fall through ... */
            } else {
                g_assert_not_reached ();
            }
        }
    }

    if (!job_aborted (job) &&
        g_file_info_get_attribute_boolean (fsinfo,
                                           G_FILE_ATTRIBUTE_FILESYSTEM_READONLY)) {
        gchar *dest_name = g_file_get_parse_name (dest);
        /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
        /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
        primary = g_strdup_printf (_("Error while copying to \"%s\"."), dest_name);
        g_free (dest_name);
        secondary = g_strdup (_("The destination is read-only."));

        response = run_error (job,
                              primary,
                              secondary,
                              NULL,
                              FALSE,
                              CANCEL,
                              NULL);

        g_error_free (error);

        abort_job (job);
    }

    g_object_unref (fsinfo);
}

static void
report_copy_progress (CopyMoveJob *copy_job,
                      SourceInfo *source_info,
                      TransferInfo *transfer_info)
{
    CommonJob *job;
    gboolean is_move;
    int files_left;
    goffset total_size;
    double elapsed, transfer_rate;
    int remaining_time;
    guint64 now;
    gchar *s = NULL;
    gchar *srcname = NULL;
    gchar *destname = NULL;

    job = (CommonJob *)copy_job;

    is_move = copy_job->is_move;

    now = g_thread_gettime ();

    if (transfer_info->last_report_time != 0 &&
        ABS ((gint64)(transfer_info->last_report_time - now)) < 100 * NSEC_PER_MSEC) {
        return;
    }

    /* See https://github.com/elementary/files/issues/464. The job data may become invalid, possibly
     * due to a race. */
    if (!G_IS_FILE (copy_job->files->data) || ! G_IS_FILE (copy_job->destination)) {
        return;
    } else {
        srcname = custom_basename_from_file ((GFile *)copy_job->files->data);
        destname = custom_basename_from_file (copy_job->destination);
    }

    transfer_info->last_report_time = now;

    files_left = source_info->num_files - transfer_info->num_files;

    /* Races and whatnot could cause this to be negative... */
    if (files_left < 0) {
        return;
    }

    if (files_left != transfer_info->last_reported_files_left ||
        transfer_info->last_reported_files_left == 0) {
        /* Avoid changing this unless files_left changed since last time */
        transfer_info->last_reported_files_left = files_left;

        if (source_info->num_files == 1) {
            if (copy_job->destination != NULL) {
                /// TRANSLATORS: \"%s\" is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed.
                /// \" is an escaped quotation mark.  This may be replaced with another suitable character (escaped if necessary).
                s = g_strdup_printf (is_move ? _("Moving \"%s\" to \"%s\"") :
                       _("Copying \"%s\" to \"%s\""), srcname, destname);
            } else {
                /// TRANSLATORS: \"%s\" is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed.
                /// \" is an escaped quotation mark.  This may be replaced with another suitable character (escaped if necessary).
                s = g_strdup_printf (_("Duplicating \"%s\""), srcname);
            }
        } else if (copy_job->files != NULL && copy_job->files->next == NULL) {
            if (copy_job->destination != NULL) {
                /// TRANSLATORS: \"%s\" is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed.
                /// \" is an escaped quotation mark.  This may be replaced with another suitable character (escaped if necessary).
                /// %'d is a placeholder for a number. It must not be translated or removed.
                /// Placeholders must appear in the same order but otherwise may change position.
                s = g_strdup_printf (is_move ? ngettext ("Moving %'d file (in \"%s\") to \"%s\"",
                                                         "Moving %'d files (in \"%s\") to \"%s\"",
                                                          files_left) :
                                               ngettext ("Copying %'d file (in \"%s\") to \"%s\"",
                                                         "Copying %'d files (in \"%s\") to \"%s\"",
                                                         files_left),
                                     files_left,
                                     srcname,
                                     destname);
            } else {
                /// TRANSLATORS: \"%s\" is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed.
                /// \" is an escaped quotation mark.  This may be replaced with another suitable character (escaped if necessary).
                s = g_strdup_printf (ngettext ("Duplicating %'d file (in \"%s\")",
                                               "Duplicating %'d files (in \"%s\")",
                                               files_left),
                                     files_left,
                                     destname);
            }
        } else {
            if (copy_job->destination != NULL) {
                /// TRANSLATORS: \"%s\" is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed.
                /// \" is an escaped quotation mark.  This may be replaced with another suitable character (escaped if necessary).
                /// %'d is a placeholder for a number. It must not be translated or removed.
                /// Placeholders must appear in the same order but otherwise may change position.
                s = g_strdup_printf (is_move ? ngettext ("Moving %'d file to \"%s\"",
                                                         "Moving %'d files to \"%s\"",
                                                         files_left) :
                                               ngettext ("Copying %'d file to \"%s\"",
                                                         "Copying %'d files to \"%s\"",
                                                         files_left),
                                     files_left,
                                     destname);
            } else {
                s = g_strdup_printf (ngettext ("Duplicating %'d file",
                                               "Duplicating %'d files",
                                               files_left),
                                     files_left);
            }
        }
    }

    if (s != NULL)
    {
        pf_progress_info_take_status (job->progress, s);
    }

    g_free (srcname);
    g_free (destname);

    total_size = MAX (source_info->num_bytes, transfer_info->num_bytes);

    elapsed = g_timer_elapsed (job->time, NULL);
    transfer_rate = 0;
    if (elapsed > 0) {
        transfer_rate = transfer_info->num_bytes / elapsed;
    }

    if (elapsed < SECONDS_NEEDED_FOR_RELIABLE_TRANSFER_RATE &&
        transfer_rate > 0) {
        char *s;
        gchar *num_bytes_format = g_format_size (transfer_info->num_bytes);
        gchar *total_size_format = g_format_size (total_size);
        /// TRANSLATORS: %s is a placeholder for a size like "2 bytes" or "3 MB".  It must not be translated or removed. So this represents something like "4 kb of 4 MB".
        s = g_strdup_printf (_("%s of %s"), num_bytes_format, total_size_format);
        g_free (num_bytes_format);
        g_free (total_size_format);
        pf_progress_info_take_details (job->progress, s);
    } else {
        char *s, *formated_remaining_time;
        gchar *num_bytes_format = g_format_size (transfer_info->num_bytes);
        gchar *total_size_format = g_format_size (total_size);
        gchar *transfer_rate_format = g_format_size (transfer_rate);
        remaining_time = (total_size - transfer_info->num_bytes) / transfer_rate;
        int formated_time_unit;
        formated_remaining_time = format_time (remaining_time, &formated_time_unit);


        /// TRANSLATORS: The two first %s and the last %s will expand to a size
        /// like "2 bytes" or "3 MB", the third %s to a time duration like
        /// "2 minutes". It must not be translated or removed.
        /// So the whole thing will be something like "2 kb of 4 MB -- 2 hours left (4kb/sec)"
        /// The singular/plural form will be used depending on the remaining time (i.e. the "%s left" part).
        /// The order in which %s appear can be changed by using the right positional specifier.
        s = g_strdup_printf (ngettext ("%s of %s \xE2\x80\x94 %s left (%s/sec)",
                                       "%s of %s \xE2\x80\x94 %s left (%s/sec)",
                                       formated_time_unit),
                             num_bytes_format, total_size_format,
                             formated_remaining_time,
                             transfer_rate_format);
        g_free (num_bytes_format);
        g_free (total_size_format);
        g_free (formated_remaining_time);
        g_free (transfer_rate_format);
        pf_progress_info_take_details (job->progress, s);
    }

    pf_progress_info_update_progress (job->progress, transfer_info->num_bytes, total_size);
}

static int
get_max_name_length (GFile *file_dir)
{
    int max_length;
    char *dir;
    long max_path;
    long max_name;

    max_length = -1;

    if (!g_file_has_uri_scheme (file_dir, "file"))
        return max_length;

    dir = g_file_get_path (file_dir);
    if (!dir)
        return max_length;

    max_path = pathconf (dir, _PC_PATH_MAX);
    max_name = pathconf (dir, _PC_NAME_MAX);

    if (max_name == -1 && max_path == -1) {
        max_length = -1;
    } else if (max_name == -1 && max_path != -1) {
        max_length = max_path - (strlen (dir) + 1);
    } else if (max_name != -1 && max_path == -1) {
        max_length = max_name;
    } else {
        int leftover;

        leftover = max_path - (strlen (dir) + 1);

        max_length = MIN (leftover, max_name);
    }

    g_free (dir);

    return max_length;
}

#define FAT_FORBIDDEN_CHARACTERS "/:;*?\"<>"

static gboolean
str_replace (char *str,
             const char *chars_to_replace,
             char replacement)
{
    gboolean success;
    int i;

    success = FALSE;
    for (i = 0; str[i] != '\0'; i++) {
        if (strchr (chars_to_replace, str[i])) {
            success = TRUE;
            str[i] = replacement;
        }
    }

    return success;
}

static gboolean
make_file_name_valid_for_dest_fs (char *filename,
                                  const char *dest_fs_type)
{
    if (dest_fs_type != NULL && filename != NULL) {
        if (!strcmp (dest_fs_type, "fat")  ||
            !strcmp (dest_fs_type, "vfat") ||
            !strcmp (dest_fs_type, "msdos") ||
            !strcmp (dest_fs_type, "msdosfs")) {
            gboolean ret;
            int i, old_len;

            ret = str_replace (filename, FAT_FORBIDDEN_CHARACTERS, '_');

            old_len = strlen (filename);
            for (i = 0; i < old_len; i++) {
                if (filename[i] != ' ') {
                    g_strchomp (filename);
                    ret |= (old_len != strlen (filename));
                    break;
                }
            }

            return ret;
        }
    }

    return FALSE;
}

static GFile *
get_unique_target_file (GFile *src,
                        GFile *dest_dir,
                        gboolean same_fs,
                        const char *dest_fs_type,
                        int count)
{
    const char *editname, *end;
    char *basename, *new_name;
    GFileInfo *info;
    GFile *dest = NULL;
    int max_length;

    if (!G_IS_FILE (src) || !G_IS_FILE (dest_dir)) {
        g_critical ("get_unique_target_file:  %s %s is not a file", !G_IS_FILE (src) ? "src" : "",  !G_IS_FILE (dest_dir) ? "dest" : "");
        return NULL;
    }

    max_length = get_max_name_length (dest_dir);

    info = g_file_query_info (src,
                              G_FILE_ATTRIBUTE_STANDARD_EDIT_NAME,
                              0, NULL, NULL);
    if (info != NULL) {
        editname = g_file_info_get_attribute_string (info, G_FILE_ATTRIBUTE_STANDARD_EDIT_NAME);

        if (editname != NULL) {
            new_name = get_duplicate_name (editname, count, max_length);
            make_file_name_valid_for_dest_fs (new_name, dest_fs_type);
            dest = g_file_get_child_for_display_name (dest_dir, new_name, NULL);
            g_free (new_name);
        }

        g_object_unref (info);
    }

    if (dest == NULL) {
        basename = g_file_get_basename (src);

        if (g_utf8_validate (basename, -1, NULL)) {
            new_name = get_duplicate_name (basename, count, max_length);
            make_file_name_valid_for_dest_fs (new_name, dest_fs_type);
            dest = g_file_get_child_for_display_name (dest_dir, new_name, NULL);
            g_free (new_name);
        }

        if (dest == NULL) {
            end = strrchr (basename, '.');
            if (end != NULL) {
                count += atoi (end + 1);
            }
            new_name = g_strdup_printf ("%s.%d", basename, count);
            make_file_name_valid_for_dest_fs (new_name, dest_fs_type);
            dest = g_file_get_child (dest_dir, new_name);
            g_free (new_name);
        }

        g_free (basename);
    }

    return dest;
}

static GFile *
get_target_file_for_link (GFile *src,
                          GFile *dest_dir,
                          const char *dest_fs_type,
                          int count)
{
    const char *editname;
    char *basename, *new_name;
    GFileInfo *info;
    GFile *dest;
    int max_length;

    max_length = get_max_name_length (dest_dir);

    dest = NULL;
    info = g_file_query_info (src,
                              G_FILE_ATTRIBUTE_STANDARD_EDIT_NAME,
                              0, NULL, NULL);
    if (info != NULL) {
        editname = g_file_info_get_attribute_string (info, G_FILE_ATTRIBUTE_STANDARD_EDIT_NAME);

        if (editname != NULL) {
            new_name = get_link_name (editname, count, max_length);
            make_file_name_valid_for_dest_fs (new_name, dest_fs_type);
            dest = g_file_get_child_for_display_name (dest_dir, new_name, NULL);
            g_free (new_name);
        }

        g_object_unref (info);
    }

    if (dest == NULL) {
        basename = g_file_get_basename (src);
        make_file_name_valid_for_dest_fs (basename, dest_fs_type);

        if (g_utf8_validate (basename, -1, NULL)) {
            new_name = get_link_name (basename, count, max_length);
            make_file_name_valid_for_dest_fs (new_name, dest_fs_type);
            dest = g_file_get_child_for_display_name (dest_dir, new_name, NULL);
            g_free (new_name);
        }

        if (dest == NULL) {
            if (count == 1) {
                new_name = g_strdup_printf ("%s.lnk", basename);
            } else {
                new_name = g_strdup_printf ("%s.lnk%d", basename, count);
            }
            make_file_name_valid_for_dest_fs (new_name, dest_fs_type);
            dest = g_file_get_child (dest_dir, new_name);
            g_free (new_name);
        }

        g_free (basename);
    }

    return dest;
}

static GFile *
get_target_file (GFile *src,
                 GFile *dest_dir,
                 const char *dest_fs_type,
                 gboolean same_fs)
{
    char *basename;
    GFile *dest;
    GFileInfo *info;
    char *copyname;

    dest = NULL;

    if (!G_IS_FILE (src) || !G_IS_FILE (dest_dir)) {
        g_critical ("get_target_file: %s %s is not a file", !G_IS_FILE (src) ? "src" : "",  G_IS_FILE (src) ? "dest" : "");
        return NULL;
    }

    if (!same_fs) {
        info = g_file_query_info (src,
                                  G_FILE_ATTRIBUTE_STANDARD_COPY_NAME,
                                  0, NULL, NULL);

        if (info) {
            copyname = g_strdup (g_file_info_get_attribute_string (info, G_FILE_ATTRIBUTE_STANDARD_COPY_NAME));

            if (copyname) {
                make_file_name_valid_for_dest_fs (copyname, dest_fs_type);
                dest = g_file_get_child_for_display_name (dest_dir, copyname, NULL);
                g_free (copyname);
            }

            g_object_unref (info);
        }
    }

    if (dest == NULL) {
        basename = g_file_get_basename (src);
        make_file_name_valid_for_dest_fs (basename, dest_fs_type);
        dest = g_file_get_child (dest_dir, basename);
        g_free (basename);
    }

    return dest;
}

static gboolean
has_fs_id (GFile *file, const char *fs_id)
{
    const char *id;
    GFileInfo *info;
    gboolean res;

    res = FALSE;
    info = g_file_query_info (file,
                              G_FILE_ATTRIBUTE_ID_FILESYSTEM,
                              G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS,
                              NULL, NULL);

    if (info) {
        id = g_file_info_get_attribute_string (info, G_FILE_ATTRIBUTE_ID_FILESYSTEM);

        if (id && strcmp (id, fs_id) == 0) {
            res = TRUE;
        }

        g_object_unref (info);
    }

    return res;
}

static gboolean
is_dir (GFile *file)
{
    GFileInfo *info;
    gboolean res;

    res = FALSE;
    info = g_file_query_info (file,
                              G_FILE_ATTRIBUTE_STANDARD_TYPE,
                              G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS,
                              NULL, NULL);
    if (info) {
        res = g_file_info_get_file_type (info) == G_FILE_TYPE_DIRECTORY;
        g_object_unref (info);
    }

    return res;
}

static void copy_move_file (CopyMoveJob *job,
                            GFile *src,
                            GFile *dest_dir,
                            gboolean same_fs,
                            gboolean unique_names,
                            char **dest_fs_type,
                            SourceInfo *source_info,
                            TransferInfo *transfer_info,
                            GHashTable *debuting_files,
                            gboolean overwrite,
                            gboolean *skipped_file,
                            gboolean readonly_source_fs);

typedef enum {
    CREATE_DEST_DIR_RETRY,
    CREATE_DEST_DIR_FAILED,
    CREATE_DEST_DIR_SUCCESS
} CreateDestDirResult;

static CreateDestDirResult
create_dest_dir (CommonJob *job,
                 GFile *src,
                 GFile **dest,
                 gboolean same_fs,
                 char **dest_fs_type)
{
    GError *error;
    GFile *new_dest, *dest_dir;
    char *primary, *secondary, *details;
    int response;
    gboolean handled_invalid_filename;

    handled_invalid_filename = *dest_fs_type != NULL;

retry:
    /* First create the directory, then copy stuff to it before
       copying the attributes, because we need to be sure we can write to it */

    if (!G_IS_FILE (*dest)) {
        return CREATE_DEST_DIR_FAILED;
    }

    error = NULL;
    if (!g_file_make_directory (*dest, job->cancellable, &error)) {
        gchar *src_name;
        if (IS_IO_ERROR (error, CANCELLED)) {
            g_error_free (error);
            return CREATE_DEST_DIR_FAILED;
        } else if (IS_IO_ERROR (error, INVALID_FILENAME) &&
                   !handled_invalid_filename) {
            handled_invalid_filename = TRUE;

            g_assert (*dest_fs_type == NULL);

            dest_dir = g_file_get_parent (*dest);

            if (dest_dir != NULL) {
                *dest_fs_type = query_fs_type (dest_dir, job->cancellable);

                new_dest = get_target_file (src, dest_dir, *dest_fs_type, same_fs);
                g_object_unref (dest_dir);

                if (!g_file_equal (*dest, new_dest)) {
                    g_object_unref (*dest);
                    *dest = new_dest;
                    g_error_free (error);
                    return CREATE_DEST_DIR_RETRY;
                } else {
                    g_object_unref (new_dest);
                }
            }
        }

        primary = g_strdup (_("Error while copying."));
        details = NULL;

        src_name = g_file_get_parse_name (src);
        if (IS_IO_ERROR (error, PERMISSION_DENIED)) {
            /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
            /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
            secondary = g_strdup_printf (_("The folder \"%s\" cannot be copied because you do not have "
                                         "permissions to create it in the destination."), src_name);
        } else {
            /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
            /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
            secondary = g_strdup_printf (_("There was an error creating the folder \"%s\"."), src_name);
            details = error->message;
        }

        g_free (src_name);

        response = run_warning (job,
                                primary,
                                secondary,
                                details,
                                FALSE,
                                CANCEL, SKIP, RETRY,
                                NULL);

        g_error_free (error);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            abort_job (job);
        } else if (response == 1) {
            /* Skip: Do Nothing  */
        } else if (response == 2) {
            goto retry;
        } else {
            g_assert_not_reached ();
        }
        return CREATE_DEST_DIR_FAILED;
    }

    marlin_file_changes_queue_file_added (*dest);

    // Start UNDO-REDO
    marlin_undo_action_data_add_origin_target_pair (job->undo_redo_data, src, *dest);
    // End UNDO-REDO

    return CREATE_DEST_DIR_SUCCESS;
}

/* a return value of FALSE means retry, i.e.
 * the destination has changed and the source
 * is expected to re-try the preceeding
 * g_file_move() or g_file_copy() call with
 * the new destination.
 */
static gboolean
copy_move_directory (CopyMoveJob *copy_job,
                     GFile *src,
                     GFile **dest,
                     gboolean same_fs,
                     gboolean create_dest,
                     char **parent_dest_fs_type,
                     SourceInfo *source_info,
                     TransferInfo *transfer_info,
                     GHashTable *debuting_files,
                     gboolean *skipped_file,
                     gboolean readonly_source_fs)
{
    GFileInfo *info;
    GError *error;
    GFile *src_file;
    GFileEnumerator *enumerator;
    char *primary, *secondary, *details;
    char *dest_fs_type;
    int response;
    gboolean skip_error;
    gboolean local_skipped_file;
    CommonJob *job;
    GFileCopyFlags flags;

    job = (CommonJob *)copy_job;

    if (create_dest) {
        switch (create_dest_dir (job, src, dest, same_fs, parent_dest_fs_type)) {
        case CREATE_DEST_DIR_RETRY:
            /* next time copy_move_directory() is called,
             * create_dest will be FALSE if a directory already
             * exists under the new name (i.e. WOULD_RECURSE)
             */
            return FALSE;

        case CREATE_DEST_DIR_FAILED:
            *skipped_file = TRUE;
            return TRUE;

        case CREATE_DEST_DIR_SUCCESS:
        default:
            break;
        }

        if (debuting_files) {
            g_hash_table_replace (debuting_files, g_object_ref (*dest), GINT_TO_POINTER (TRUE));
        }

    }

    local_skipped_file = FALSE;
    dest_fs_type = NULL;

    skip_error = should_skip_readdir_error (job, src);
retry:
    error = NULL;
    enumerator = g_file_enumerate_children (src,
                                            G_FILE_ATTRIBUTE_STANDARD_NAME,
                                            G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS,
                                            job->cancellable,
                                            &error);
    if (enumerator) {
        error = NULL;

        while (!job_aborted (job) &&
               (info = g_file_enumerator_next_file (enumerator, job->cancellable, skip_error?NULL:&error)) != NULL) {
            src_file = g_file_get_child (src,
                                         g_file_info_get_name (info));
            copy_move_file (copy_job, src_file, *dest, same_fs, FALSE, &dest_fs_type,
                            source_info, transfer_info, NULL, FALSE, &local_skipped_file,
                            readonly_source_fs);
            g_object_unref (src_file);
            g_object_unref (info);
        }
        g_file_enumerator_close (enumerator, job->cancellable, NULL);
        g_object_unref (enumerator);

        if (error && IS_IO_ERROR (error, CANCELLED)) {
            g_error_free (error);
        } else if (error) {
            gchar *src_name;
            if (copy_job->is_move) {
                primary = g_strdup (_("Error while moving."));
            } else {
                primary = g_strdup (_("Error while copying."));
            }
            details = NULL;

            src_name = g_file_get_parse_name (src);
            if (IS_IO_ERROR (error, PERMISSION_DENIED)) {
                /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
                /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
                secondary = g_strdup_printf (_("Files in the folder \"%s\" cannot be copied because you do "
                                             "not have permissions to see them."), src_name);
            } else {
                /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
                /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
                secondary = g_strdup_printf (_("There was an error getting information about the files in the folder \"%s\"."), src_name);
                details = error->message;
            }

            g_free (src_name);
            response = run_warning (job,
                                    primary,
                                    secondary,
                                    details,
                                    FALSE,
                                    CANCEL, _("_Skip files"),
                                    NULL);

            g_error_free (error);

            if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
                abort_job (job);
            } else if (response == 1) {
                /* Skip: Do Nothing */
                local_skipped_file = TRUE;
            } else {
                g_assert_not_reached ();
            }
        }

        /* Count the copied directory as a file */
        transfer_info->num_files ++;
        report_copy_progress (copy_job, source_info, transfer_info);

        if (debuting_files) {
            g_hash_table_replace (debuting_files, g_object_ref (*dest), GINT_TO_POINTER (create_dest));
        }
    } else if (IS_IO_ERROR (error, CANCELLED)) {
        g_error_free (error);
    } else {
        gchar *src_name;
        if (copy_job->is_move) {
            primary = g_strdup (_("Error while moving."));
        } else {
            primary = g_strdup (_("Error while copying."));
        }
        details = NULL;

        src_name = g_file_get_parse_name (src);
        if (IS_IO_ERROR (error, PERMISSION_DENIED)) {
            /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
            /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
            secondary = g_strdup_printf (_("The folder \"%s\" cannot be copied because you do not have "
                                         "permissions to read it."), src_name);
        } else {
            /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
            /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
            secondary = g_strdup_printf (_("There was an error reading the folder \"%s\"."), src_name);
            details = error->message;
        }

        g_free (src_name);
        response = run_warning (job,
                                primary,
                                secondary,
                                details,
                                FALSE,
                                CANCEL, SKIP, RETRY,
                                NULL);

        g_error_free (error);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            abort_job (job);
        } else if (response == 1) {
            /* Skip: Do Nothing  */
            local_skipped_file = TRUE;
        } else if (response == 2) {
            goto retry;
        } else {
            g_assert_not_reached ();
        }
    }

    if (create_dest) {
        flags = (readonly_source_fs) ? G_FILE_COPY_NOFOLLOW_SYMLINKS | G_FILE_COPY_TARGET_DEFAULT_PERMS
            : G_FILE_COPY_NOFOLLOW_SYMLINKS;
        /* Ignore errors here. Failure to copy metadata is not a hard error */
        g_file_copy_attributes (src, *dest,
                                flags,
                                job->cancellable, NULL);
    }

    if (!job_aborted (job) && copy_job->is_move &&
        /* Don't delete source if there was a skipped file */
        !local_skipped_file) {
        if (!g_file_delete (src, job->cancellable, &error)) {
            gchar *src_name;
            if (job->skip_all_error) {
                goto skip;
            }

            src_name = g_file_get_parse_name (src);
            /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
            /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
            primary = g_strdup_printf (_("Error while moving \"%s\"."), src_name);
            g_free (src_name);
            secondary = g_strdup (_("Could not remove the source folder."));
            details = error->message;

            response = run_warning (job,
                                    primary,
                                    secondary,
                                    details,
                                    (source_info->num_files - transfer_info->num_files) > 1,
                                    CANCEL, SKIP_ALL, SKIP,
                                    NULL);

            if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
                abort_job (job);
            } else if (response == 1) { /* skip all */
                job->skip_all_error = TRUE;
                local_skipped_file = TRUE;
            } else if (response == 2) { /* skip */
                local_skipped_file = TRUE;
            } else {
                g_assert_not_reached ();
            }

skip:
            g_error_free (error);
        }
    }

    if (local_skipped_file) {
        *skipped_file = TRUE;
    }

    g_free (dest_fs_type);
    return TRUE;
}

static gboolean
remove_target_recursively (CommonJob *job,
                           GFile *src,
                           GFile *toplevel_dest,
                           GFile *file)
{
    GFileEnumerator *enumerator;
    GError *error;
    GFile *child;
    gboolean stop;
    char *primary, *secondary, *details;
    int response;
    GFileInfo *info;

    stop = FALSE;

    error = NULL;
    enumerator = g_file_enumerate_children (file,
                                            G_FILE_ATTRIBUTE_STANDARD_NAME,
                                            G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS,
                                            job->cancellable,
                                            &error);
    if (enumerator) {
        error = NULL;

        while (!job_aborted (job) &&
               (info = g_file_enumerator_next_file (enumerator, job->cancellable, &error)) != NULL) {
            child = g_file_get_child (file,
                                      g_file_info_get_name (info));
            if (!remove_target_recursively (job, src, toplevel_dest, child)) {
                stop = TRUE;
                break;
            }
            g_object_unref (child);
            g_object_unref (info);
        }
        g_file_enumerator_close (enumerator, job->cancellable, NULL);
        g_object_unref (enumerator);

    } else if (IS_IO_ERROR (error, NOT_DIRECTORY)) {
        /* Not a dir, continue */
        g_error_free (error);

    } else if (IS_IO_ERROR (error, CANCELLED)) {
        g_error_free (error);
    } else {
        gchar *file_name, *src_name;
        if (job->skip_all_error) {
            goto skip1;
        }

        src_name = g_file_get_parse_name (src);
        /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
        /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
        primary = g_strdup_printf (_("Error while copying \"%s\"."), src_name);
        g_free (src_name);

        file_name = g_file_get_parse_name (file);
        /// TRANSLATORS: %s is a placeholder for the full path of a file.  It may change position but must not be translated or removed
        secondary = g_strdup_printf (_("Could not remove files from the already existing folder %s."), file_name);
        g_free (file_name);
        details = error->message;

        /* set show_all to TRUE here, as we don't know how many
         * files we'll end up processing yet.
         */
        response = run_warning (job,
                                primary,
                                secondary,
                                details,
                                TRUE,
                                CANCEL, SKIP_ALL, SKIP,
                                NULL);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            abort_job (job);
        } else if (response == 1) { /* skip all */
            job->skip_all_error = TRUE;
        } else if (response == 2) { /* skip */
            /* do nothing */
        } else {
            g_assert_not_reached ();
        }
skip1:
        g_error_free (error);

        stop = TRUE;
    }

    if (stop) {
        return FALSE;
    }

    error = NULL;

    if (!g_file_delete (file, job->cancellable, &error)) {
        gchar *file_name, *src_name;
        if (job->skip_all_error ||
            IS_IO_ERROR (error, CANCELLED)) {
            goto skip2;
        }

        src_name = g_file_get_parse_name (src);
        /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
        /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
        primary = g_strdup_printf (_("Error while copying \"%s\"."), src_name);
        g_free (src_name);

        file_name = g_file_get_parse_name (file);
        /// TRANSLATORS: %s is a placeholder for the full path of a file.  It may change position but must not be translated or removed
        secondary = g_strdup_printf (_("Could not remove the already existing file %s."), file_name);
        g_free (file_name);
        details = error->message;

        /* set show_all to TRUE here, as we don't know how many
         * files we'll end up processing yet.
         */
        response = run_warning (job,
                                primary,
                                secondary,
                                details,
                                TRUE,
                                CANCEL, SKIP_ALL, SKIP,
                                NULL);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            abort_job (job);
        } else if (response == 1) { /* skip all */
            job->skip_all_error = TRUE;
        } else if (response == 2) { /* skip */
            /* do nothing */
        } else {
            g_assert_not_reached ();
        }

skip2:
        g_error_free (error);

        return FALSE;
    }
    marlin_file_changes_queue_file_removed (file);

    return TRUE;

}

typedef struct {
    CopyMoveJob *job;
    goffset last_size;
    SourceInfo *source_info;
    TransferInfo *transfer_info;
} ProgressData;

static void
copy_file_progress_callback (goffset current_num_bytes,
                             goffset total_num_bytes,
                             gpointer user_data)
{
    ProgressData *pdata;
    goffset new_size;

    pdata = user_data;

    new_size = current_num_bytes - pdata->last_size;

    if (new_size > 0) {
        pdata->transfer_info->num_bytes += new_size;
        pdata->last_size = current_num_bytes;
        report_copy_progress (pdata->job,
                              pdata->source_info,
                              pdata->transfer_info);
    }
}

static gboolean
test_dir_is_parent (GFile *child, GFile *root)
{
    GFile *f = child;
    GFile *prev = NULL;
    GFileInfo *info;
    GFile *target;
    gboolean result = FALSE;

    if (g_file_equal (child, root)) {
        return TRUE;
    }

    while ((f = g_file_get_parent (f))) {
        if (prev) g_object_unref (prev);

        if (g_file_equal (f, root)) {
            g_object_unref (f);
            return TRUE;
        }

        prev = f;
    }

    /* Check if child is a symlink to root or one of its descendants */
    info = g_file_query_info (child,
                              "standard::*",
                              G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS,
                              g_cancellable_get_current (),
                              NULL);

    if (g_file_info_get_is_symlink (info)) {
        target = g_file_new_for_path (
                    g_file_info_get_attribute_byte_string (info, G_FILE_ATTRIBUTE_STANDARD_SYMLINK_TARGET)
                 );

        if (g_file_equal (target, root)) {
            result = TRUE;
        } else {
            f = target;
            while ((f = g_file_get_parent (f))) {
                if (prev) g_object_unref (prev);

                if (g_file_equal (f, root)) {
                    g_object_unref (f);
                    result = TRUE;
                    break;
                }

                prev = f;
            }
        }

        g_object_unref (target);
    }

    if (prev) g_object_unref (prev);

    g_object_unref (info);

    return result;
}

static char *
query_fs_type (GFile *file,
               GCancellable *cancellable)
{
    GFileInfo *fsinfo;
    char *ret;

    ret = NULL;

    fsinfo = g_file_query_filesystem_info (file,
                                           G_FILE_ATTRIBUTE_FILESYSTEM_TYPE,
                                           cancellable,
                                           NULL);
    if (fsinfo != NULL) {
        ret = g_strdup (g_file_info_get_attribute_string (fsinfo, G_FILE_ATTRIBUTE_FILESYSTEM_TYPE));
        g_object_unref (fsinfo);
    }

    if (ret == NULL) {
        /* ensure that we don't attempt to query
         * the FS type for each file in a given
         * directory, if it can't be queried. */
        ret = g_strdup ("");
    }

    return ret;
}

typedef struct {
    int id;
    char *new_name;
    gboolean apply_to_all;
} ConflictResponseData;

typedef struct {
    GFile *src;
    GFile *dest;
    GFile *dest_dir;
    GtkWindow *parent;
    ConflictResponseData *resp_data;
} ConflictDialogData;

static gboolean
do_run_conflict_dialog (gpointer _data)
{
    ConflictDialogData *data = _data;
    GtkWidget *dialog;
    int response;

    dialog = marlin_file_conflict_dialog_new (data->parent,
                                              data->src,
                                              data->dest,
                                              data->dest_dir);
    response = gtk_dialog_run (GTK_DIALOG (dialog));

    if (response == MARLIN_FILE_CONFLICT_DIALOG_RESPONSE_TYPE_RENAME) {
        data->resp_data->new_name =
            marlin_file_conflict_dialog_get_new_name (MARLIN_FILE_CONFLICT_DIALOG (dialog));
    } else if (response != GTK_RESPONSE_CANCEL ||
               response != GTK_RESPONSE_NONE) {
        data->resp_data->apply_to_all =
            marlin_file_conflict_dialog_get_apply_to_all
            (MARLIN_FILE_CONFLICT_DIALOG (dialog));
    }

    data->resp_data->id = response;

    gtk_widget_destroy (dialog);

    return FALSE;
}

static ConflictResponseData *
run_conflict_dialog (CommonJob *job,
                     GFile *src,
                     GFile *dest,
                     GFile *dest_dir)
{
    ConflictDialogData *data;
    ConflictResponseData *resp_data;

    g_timer_stop (job->time);

    data = g_slice_new0 (ConflictDialogData);
    data->parent = job->parent_window;
    data->src = src;
    data->dest = dest;
    data->dest_dir = dest_dir;

    resp_data = g_slice_new0 (ConflictResponseData);
    resp_data->new_name = NULL;
    data->resp_data = resp_data;

    pf_progress_info_pause (job->progress);
    g_io_scheduler_job_send_to_mainloop (job->io_job,
                                         do_run_conflict_dialog,
                                         data,
                                         NULL);

    pf_progress_info_resume (job->progress);
    g_slice_free (ConflictDialogData, data);
    g_timer_continue (job->time);

    return resp_data;
}

static void
conflict_response_data_free (ConflictResponseData *data)
{
    g_free (data->new_name);
    g_slice_free (ConflictResponseData, data);
}

static GFile *
get_target_file_for_display_name (GFile *dir,
                                  char *name)
{
    GFile *dest;

    dest = NULL;
    dest = g_file_get_child_for_display_name (dir, name, NULL);

    if (dest == NULL) {
        dest = g_file_get_child (dir, name);
    }

    return dest;
}

/* Debuting files is non-NULL only for toplevel items */
static void
copy_move_file (CopyMoveJob *copy_job,
                GFile *src,
                GFile *dest_dir,
                gboolean same_fs,
                gboolean unique_names,
                char **dest_fs_type,
                SourceInfo *source_info,
                TransferInfo *transfer_info,
                GHashTable *debuting_files,
                gboolean overwrite,
                gboolean *skipped_file,
                gboolean readonly_source_fs)
{
    GFile *dest, *new_dest;
    GError *error;
    GFileCopyFlags flags;
    char *primary, *secondary, *details;
    int response;
    ProgressData pdata;
    gboolean would_recurse, is_merge;
    CommonJob *job;
    gboolean res;
    int unique_name_nr;
    gboolean handled_invalid_filename;

    job = (CommonJob *)copy_job;

    if (should_skip_file (job, src)) {
        *skipped_file = TRUE;
        return;
    }

    unique_name_nr = 1;

    /* another file in the same directory might have handled the invalid
     * filename condition for us
     */
    handled_invalid_filename = *dest_fs_type != NULL;

    //amtest
    if (unique_names) {
        dest = get_unique_target_file (src, dest_dir, same_fs, *dest_fs_type, unique_name_nr++);
    } else {
        dest = get_target_file (src, dest_dir, *dest_fs_type, same_fs);
    }

    if (dest == NULL) {
        *skipped_file = TRUE; /* Or aborted, but same-same */
        return;
    }

    /* Don't allow recursive move/copy into itself.
     * (We would get a file system error if we proceeded but it is nicer to
     * detect and report it at this level) */
    if (test_dir_is_parent (dest_dir, src)) {
        if (job->skip_all_error) {
            goto out;
        }

        /*  the run_warning() frees all strings passed in automatically  */
        primary = copy_job->is_move ? g_strdup (_("You cannot move a folder into itself."))
            : g_strdup (_("You cannot copy a folder into itself."));
        secondary = g_strdup (_("The destination folder is inside the source folder."));

        response = run_warning (job,
                                primary,
                                secondary,
                                NULL,
                                (source_info->num_files - transfer_info->num_files) > 1,
                                CANCEL, SKIP_ALL, SKIP,
                                NULL);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            abort_job (job);
        } else if (response == 1) { /* skip all */
            job->skip_all_error = TRUE;
        } else if (response == 2) { /* skip */
            /* do nothing */
        } else {
            g_assert_not_reached ();
        }

        goto out;
    }

    /* Don't allow copying over the source or one of the parents of the source.
    */
    if (test_dir_is_parent (src, dest)) {
        if (job->skip_all_error) {
            goto out;
        }

        /*  the run_warning() frees all strings passed in automatically  */
        primary = copy_job->is_move ? g_strdup (_("You cannot move a file over itself."))
            : g_strdup (_("You cannot copy a file over itself."));
        secondary = g_strdup (_("The source file would be overwritten by the destination."));

        response = run_warning (job,
                                primary,
                                secondary,
                                NULL,
                                (source_info->num_files - transfer_info->num_files) > 1,
                                CANCEL, SKIP_ALL, SKIP,
                                NULL);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            abort_job (job);
        } else if (response == 1) { /* skip all */
            job->skip_all_error = TRUE;
        } else if (response == 2) { /* skip */
            /* do nothing */
        } else {
            g_assert_not_reached ();
        }

        goto out;
    }


retry:

    error = NULL;
    flags = G_FILE_COPY_NOFOLLOW_SYMLINKS;
    if (overwrite) {
        flags |= G_FILE_COPY_OVERWRITE;
    }
    if (readonly_source_fs) {
        flags |= G_FILE_COPY_TARGET_DEFAULT_PERMS;
    }

    pdata.job = copy_job;
    pdata.last_size = 0;
    pdata.source_info = source_info;
    pdata.transfer_info = transfer_info;

    if (copy_job->is_move) {
        res = g_file_move (src, dest,
                           flags,
                           job->cancellable,
                           copy_file_progress_callback,
                           &pdata,
                           &error);
    } else {
        res = g_file_copy (src, dest,
                           flags,
                           job->cancellable,
                           copy_file_progress_callback,
                           &pdata,
                           &error);
    }

    /* NOTE Result is false if file being moved is a folder and the target is on a Samba share even if
     * the file is successfully copied, so the change will not be notified to the view.
     * The view will need to be refreshed anyway */

    if (res) {
        transfer_info->num_files ++;
        report_copy_progress (copy_job, source_info, transfer_info);

        if (debuting_files) {
            /*if (position) {
                //marlin_file_changes_queue_schedule_position_set (dest, *position, job->screen_num);
            } else {
                //marlin_file_changes_queue_schedule_position_remove (dest);
            }*/

            g_hash_table_replace (debuting_files, g_object_ref (dest), GINT_TO_POINTER (TRUE));
        }
        if (copy_job->is_move) {
            marlin_file_changes_queue_file_moved (src, dest);
        } else {
           marlin_file_changes_queue_file_added (dest);
        }

        // Start UNDO-REDO
        marlin_undo_action_data_add_origin_target_pair (job->undo_redo_data, src, dest);
        // End UNDO-REDO

        g_object_unref (dest);
        return;
    }

    if (!handled_invalid_filename &&
        IS_IO_ERROR (error, INVALID_FILENAME)) {
        handled_invalid_filename = TRUE;

        g_assert (*dest_fs_type == NULL);
        *dest_fs_type = query_fs_type (dest_dir, job->cancellable);

        if (unique_names) {
            new_dest = get_unique_target_file (src, dest_dir, same_fs, *dest_fs_type, unique_name_nr);
        } else {
            new_dest = get_target_file (src, dest_dir, *dest_fs_type, same_fs);
        }

        if (!g_file_equal (dest, new_dest)) {
            g_object_unref (dest);
            dest = new_dest;

            g_error_free (error);
            goto retry;
        } else {
            g_object_unref (new_dest);
        }
    }

    /* Conflict */
    if (!overwrite &&
        IS_IO_ERROR (error, EXISTS)) {
        gboolean is_merge;
        ConflictResponseData *response;

        g_error_free (error);

        if (unique_names) {
            g_object_unref (dest);
            dest = get_unique_target_file (src, dest_dir, same_fs, *dest_fs_type, unique_name_nr++);
            goto retry;
        }

        is_merge = FALSE;

        if (is_dir (dest) && is_dir (src)) {
            is_merge = TRUE;
        }

        if ((is_merge && job->merge_all) ||
            (!is_merge && job->replace_all)) {
            overwrite = TRUE;
            goto retry;
        }

        if (job->skip_all_conflict) {
            goto out;
        }

        if (job->keep_all_newest) {
            if (pf_file_utils_compare_modification_dates (src, dest) < 1) {
                goto out;
            } else {
                overwrite = TRUE;
                goto retry;
            }
        }

        response = run_conflict_dialog (job, src, dest, dest_dir);

        if (response->id == GTK_RESPONSE_CANCEL ||
            response->id == GTK_RESPONSE_DELETE_EVENT) {
            conflict_response_data_free (response);
            abort_job (job);
            goto out;
        }

        if (response->id == MARLIN_FILE_CONFLICT_DIALOG_RESPONSE_TYPE_SKIP) {
            if (response->apply_to_all) {
                job->skip_all_conflict = TRUE;
            }
            conflict_response_data_free (response);
        } else if (response->id == MARLIN_FILE_CONFLICT_DIALOG_RESPONSE_TYPE_REPLACE ||
                   response->id == MARLIN_FILE_CONFLICT_DIALOG_RESPONSE_TYPE_NEWEST) { /* merge/replace/newest */

            if (response->apply_to_all) {
                if (is_merge) {
                    job->merge_all = TRUE;
                } else if (response->id == MARLIN_FILE_CONFLICT_DIALOG_RESPONSE_TYPE_NEWEST) {
                    job->keep_all_newest = TRUE;
                } else {
                    job->replace_all = TRUE;
                }
            }
            overwrite = TRUE;

            gboolean keep_dest;
            keep_dest = response->id == MARLIN_FILE_CONFLICT_DIALOG_RESPONSE_TYPE_NEWEST &&
                        pf_file_utils_compare_modification_dates (src, dest) < 1;

            conflict_response_data_free (response);

            if (keep_dest) { /* destination is newer than source */
                goto out;/* Skip this one */
            } else {
                goto retry; /* Overwrite conflicting destination file */
            }
        } else if (response->id == MARLIN_FILE_CONFLICT_DIALOG_RESPONSE_TYPE_RENAME) {
            g_object_unref (dest);
            dest = get_target_file_for_display_name (dest_dir,
                                                     response->new_name);
            conflict_response_data_free (response);
            goto retry;
        } else {
            /* Failsafe rather than crash */
            conflict_response_data_free (response);
            abort_job (job);
            goto out;
        }
    } else if (overwrite &&
             IS_IO_ERROR (error, IS_DIRECTORY)) {

        g_error_free (error);

        if (remove_target_recursively (job, src, dest, dest)) {
            goto retry;
        }
    } else if (IS_IO_ERROR (error, WOULD_RECURSE) ||
             IS_IO_ERROR (error, WOULD_MERGE)) { /* Needs to recurse */

        is_merge = error->code == G_IO_ERROR_WOULD_MERGE;
        would_recurse = error->code == G_IO_ERROR_WOULD_RECURSE;
        g_error_free (error);

        if (overwrite && would_recurse) {
            error = NULL;

            /* Copying a dir onto file, first remove the file */
            if (!g_file_delete (dest, job->cancellable, &error) &&
                !IS_IO_ERROR (error, NOT_FOUND)) {
                gchar *file_name;
                if (job->skip_all_error) {
                    g_error_free (error);
                    goto out;
                }

                file_name = g_file_get_parse_name (src);
                if (copy_job->is_move) {
                    /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
                    /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
                    primary = g_strdup_printf (_("Error while moving \"%s\"."), file_name);
                } else {
                    /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
                    /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
                    primary = g_strdup_printf (_("Error while copying \"%s\"."), file_name);
                }
                g_free (file_name);

                file_name = g_file_get_parse_name (dest);
                /// TRANSLATORS: %s is a placeholder for the full path of a file.  It may change position but must not be translated or removed
                secondary = g_strdup_printf (_("Could not remove the already existing file with the same name in %s."), file_name);
                g_free (file_name);
                details = error->message;

                /* setting TRUE on show_all here, as we could have
                 * another error on the same file later.
                 */
                response = run_warning (job,
                                        primary,
                                        secondary,
                                        details,
                                        TRUE,
                                        CANCEL, SKIP_ALL, SKIP,
                                        NULL);

                g_error_free (error);

                if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
                    abort_job (job);
                } else if (response == 1) { /* skip all */
                    job->skip_all_error = TRUE;
                } else if (response == 2) { /* skip */
                    /* do nothing */
                } else {
                    g_assert_not_reached ();
                }
                goto out;

            }
            if (error) {
                g_error_free (error);
                error = NULL;
            }
            marlin_file_changes_queue_file_removed (dest);
        }

        if (is_merge) {
            /* On merge we now write in the target directory, which may not
               be in the same directory as the source, even if the parent is
               (if the merged directory is a mountpoint). This could cause
               problems as we then don't transcode filenames.
               We just set same_fs to FALSE which is safe but a bit slower. */
            same_fs = FALSE;
        }

        if (!copy_move_directory (copy_job, src, &dest, same_fs,
                                  would_recurse, dest_fs_type,
                                  source_info, transfer_info,
                                  debuting_files, skipped_file,
                                  readonly_source_fs)) {
            /* destination changed, since it was an invalid file name */
            g_assert (*dest_fs_type != NULL);
            handled_invalid_filename = TRUE;
            goto retry;
        }

        g_object_unref (dest);
        return;
    } else if (IS_IO_ERROR (error, CANCELLED)) {
        g_error_free (error);
    } else { /* Other error */
        gchar *src_basename, *dest_basename;
        if (job->skip_all_error) {
            g_error_free (error);
            goto out;
        }

        src_basename = custom_basename_from_file (src);
        /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
        /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
        primary = g_strdup_printf (_("Cannot copy \"%s\" here."), src_basename);
        g_free (src_basename);

        dest_basename = custom_basename_from_file (dest_dir);
        /// TRANSLATORS: %s is a placeholder for the basename of a file.  It may change position but must not be translated or removed
        secondary = g_strdup_printf (_("There was an error copying the file into %s."), dest_basename);
        g_free (dest_basename);
        details = error->message;

        response = run_warning (job,
                                primary,
                                secondary,
                                details,
                                (source_info->num_files - transfer_info->num_files) > 1,
                                CANCEL, SKIP_ALL, SKIP,
                                NULL);

        g_error_free (error);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            abort_job (job);
        } else if (response == 1) { /* skip all */
            job->skip_all_error = TRUE;
        } else if (response == 2) { /* skip */
            /* do nothing */
        } else {
            g_assert_not_reached ();
        }
    }
out:
    *skipped_file = TRUE; /* Or aborted, but same-same */
    g_object_unref (dest);
}

static void
copy_files (CopyMoveJob *job,
            const char *dest_fs_id,
            SourceInfo *source_info,
            TransferInfo *transfer_info)
{
    CommonJob *common;
    GList *l;
    GFile *src;
    gboolean same_fs;
    int i;
    gboolean skipped_file;
    gboolean unique_names;
    GFile *dest;
    GFile *source_dir;
    char *dest_fs_type;
    GFileInfo *inf;
    gboolean readonly_source_fs;

    dest_fs_type = NULL;
    readonly_source_fs = FALSE;

    common = &job->common;

    report_copy_progress (job, source_info, transfer_info);

    /* Query the source dir, not the file because if its a symlink we'll follow it */
    source_dir = g_file_get_parent ((GFile *) job->files->data);
    if (source_dir) {
        inf = g_file_query_filesystem_info (source_dir, G_FILE_ATTRIBUTE_FILESYSTEM_READONLY, NULL, NULL);
        if (inf != NULL) {
            readonly_source_fs = g_file_info_get_attribute_boolean (inf, G_FILE_ATTRIBUTE_FILESYSTEM_READONLY);
            g_object_unref (inf);
        }
        g_object_unref (source_dir);
    }

    unique_names = (job->destination == NULL); /* Duplicating files */
    i = 0;
    for (l = job->files;
         l != NULL && !job_aborted (common);
         l = l->next) {
        src = l->data;

        same_fs = FALSE;
        if (dest_fs_id) {
            same_fs = has_fs_id (src, dest_fs_id);
        }

        if (job->destination) {
            dest = g_object_ref (job->destination);
        } else {
            dest = g_file_get_parent (src);

        }

        if (dest) {
            skipped_file = FALSE;
            copy_move_file (job, src, dest,
                            same_fs, unique_names,
                            &dest_fs_type,
                            source_info, transfer_info,
                            job->debuting_files,
                            FALSE, &skipped_file,
                            readonly_source_fs);
            g_object_unref (dest);
        }
        i++;
    }

    g_free (dest_fs_type);
}

static gboolean
copy_job_done (gpointer user_data)
{
    CopyMoveJob *job;

    job = user_data;
    g_task_return_boolean (job->task, TRUE);
    g_clear_object (&job->task);

    g_list_free_full (job->files, g_object_unref);
    job->files = NULL;
    g_clear_object (&job->destination);
    g_clear_pointer (&job->debuting_files, g_hash_table_unref);

    finalize_common ((CommonJob *)job);

    marlin_file_changes_consume_changes (TRUE);
    return FALSE;
}

static gboolean
copy_job (GIOSchedulerJob *io_job,
          GCancellable *cancellable,
          gpointer user_data)
{
    CopyMoveJob *job;
    CommonJob *common;
    SourceInfo source_info;
    TransferInfo transfer_info;
    char *dest_fs_id;
    GFile *dest;

    job = user_data;
    common = &job->common;
    common->io_job = io_job;

    dest_fs_id = NULL;

    pf_progress_info_start (job->common.progress);
    scan_sources (job->files,
                  &source_info,
                  common,
                  OP_KIND_COPY);
    if (job_aborted (common)) {
        goto aborted;
    }

    if (job->destination) {
        dest = g_object_ref (job->destination);
    } else {
        /* Duplication, no dest,
         * use source for free size, etc
         */
        dest = g_file_get_parent (job->files->data);
    }

    verify_destination (&job->common,
                        dest,
                        &dest_fs_id,
                        source_info.num_bytes);
    g_object_unref (dest);
    if (job_aborted (common)) {
        goto aborted;
    }

    g_timer_start (job->common.time);

    memset (&transfer_info, 0, sizeof (transfer_info));
    copy_files (job,
                dest_fs_id,
                &source_info, &transfer_info);

aborted:

    g_free (dest_fs_id);

    g_io_scheduler_job_send_to_mainloop_async (io_job,
                                               copy_job_done,
                                               job,
                                               NULL);

    return FALSE;
}

static void
marlin_file_operations_copy (GList               *files,
                             GFile               *target_dir,
                             GtkWindow           *parent_window,
                             GCancellable        *cancellable,
                             GAsyncReadyCallback  callback,
                             gpointer             user_data)
{

    CopyMoveJob *job;
    job = op_job_new (CopyMoveJob, parent_window);
    job->task = g_task_new (NULL, cancellable, callback, user_data);
    job->files = g_list_copy_deep (files, (GCopyFunc) g_object_ref, NULL);
    job->destination = g_object_ref (target_dir);
    job->debuting_files = g_hash_table_new_full (g_file_hash, (GEqualFunc)g_file_equal, g_object_unref, NULL);

    inhibit_power_manager ((CommonJob *)job, _("Copying Files"));

    // Start UNDO-REDO
    job->common.undo_redo_data = marlin_undo_action_data_new (MARLIN_UNDO_COPY, g_list_length(files));
    GFile* src_dir = g_file_get_parent (files->data);
    marlin_undo_action_data_set_src_dir (job->common.undo_redo_data, src_dir);
    g_object_ref (target_dir);
    marlin_undo_action_data_set_dest_dir (job->common.undo_redo_data, target_dir);
    // End UNDO-REDO

    g_io_scheduler_push_job (copy_job,
                             job,
                             NULL, /* destroy notify */
                             0,
                             job->common.cancellable);
}

static gboolean
marlin_file_operations_copy_finish (GAsyncResult  *result,
                                    GError       **error)
{
    g_return_val_if_fail (g_task_is_valid (result, NULL), NULL);

    return g_task_propagate_boolean (G_TASK (result), error);
}

static void
report_move_progress (CopyMoveJob *move_job, int total, int left)
{
    CommonJob *job;
    gchar *s, *dest_basename;

    job = (CommonJob *)move_job;
    dest_basename = custom_basename_from_file (move_job->destination);
    /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
    /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
    s = g_strdup_printf (_("Preparing to move to \"%s\""), dest_basename);
    g_free (dest_basename);

    pf_progress_info_take_status (job->progress, s);
    pf_progress_info_take_details (job->progress,
                                       g_strdup_printf (ngettext ("Preparing to move %'d file",
                                                                  "Preparing to move %'d files",
                                                                  left), left));

    pf_progress_info_pulse_progress (job->progress);
}

typedef struct {
    GFile *file;
    gboolean overwrite;
    gboolean has_position;
    GdkPoint position;
} MoveFileCopyFallback;

static MoveFileCopyFallback *
move_copy_file_callback_new (GFile *file,
                             gboolean overwrite)
{
    MoveFileCopyFallback *fallback;

    fallback = g_new (MoveFileCopyFallback, 1);
    fallback->file = file;
    fallback->overwrite = overwrite;

    return fallback;
}

static GList *
get_files_from_fallbacks (GList *fallbacks)
{
    MoveFileCopyFallback *fallback;
    GList *res, *l;

    res = NULL;
    for (l = fallbacks; l != NULL; l = l->next) {
        fallback = l->data;
        res = g_list_prepend (res, fallback->file);
    }
    return g_list_reverse (res);
}

static void
move_file_prepare (CopyMoveJob *move_job,
                   GFile *src,
                   GFile *dest_dir,
                   gboolean same_fs,
                   char **dest_fs_type,
                   GHashTable *debuting_files,
                   GList **fallback_files,
                   int files_left)
{
    GFile *dest, *new_dest;
    GError *error;
    CommonJob *job;
    gboolean overwrite, renamed;
    char *primary, *secondary, *details;
    int response;
    GFileCopyFlags flags;
    MoveFileCopyFallback *fallback;
    gboolean handled_invalid_filename;

    overwrite = FALSE;
    renamed = FALSE;
    handled_invalid_filename = *dest_fs_type != NULL;

    job = (CommonJob *)move_job;

    dest = get_target_file (src, dest_dir, *dest_fs_type, same_fs);


    /* Don't allow recursive move/copy into itself.
     * (We would get a file system error if we proceeded but it is nicer to
     * detect and report it at this level) */
    if (test_dir_is_parent (dest_dir, src)) {
        if (job->skip_all_error) {
            goto out;
        }

        /*  the run_warning() frees all strings passed in automatically  */
        primary = move_job->is_move ? g_strdup (_("You cannot move a folder into itself."))
            : g_strdup (_("You cannot copy a folder into itself."));
        secondary = g_strdup (_("The destination folder is inside the source folder."));

        response = run_warning (job,
                                primary,
                                secondary,
                                NULL,
                                files_left > 1,
                                CANCEL, SKIP_ALL, SKIP,
                                NULL);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            abort_job (job);
        } else if (response == 1) { /* skip all */
            job->skip_all_error = TRUE;
        } else if (response == 2) { /* skip */
            /* do nothing */
        } else {
            g_assert_not_reached ();
        }

        goto out;
    }

retry:

    flags = G_FILE_COPY_NOFOLLOW_SYMLINKS | G_FILE_COPY_NO_FALLBACK_FOR_MOVE;
    if (overwrite) {
        flags |= G_FILE_COPY_OVERWRITE;
    }

    error = NULL;
    if (g_file_move (src, dest,
                     flags,
                     job->cancellable,
                     NULL,
                     NULL,
                     &error)) {

        if (debuting_files) {
            g_hash_table_replace (debuting_files, g_object_ref (dest), GINT_TO_POINTER (TRUE));
        }

        marlin_file_changes_queue_file_moved (src, dest);

        /*if (position) {
            //marlin_file_changes_queue_schedule_position_set (dest, *position, job->screen_num);
        } else {
            marlin_file_changes_queue_schedule_position_remove (dest);
        }*/

        // Start UNDO-REDO
        marlin_undo_action_data_add_origin_target_pair (job->undo_redo_data, src, dest);
        // End UNDO-REDO

        return;
    }

    if (IS_IO_ERROR (error, INVALID_FILENAME) &&
        !handled_invalid_filename) {
        handled_invalid_filename = TRUE;

        g_assert (*dest_fs_type == NULL);
        *dest_fs_type = query_fs_type (dest_dir, job->cancellable);

        new_dest = get_target_file (src, dest_dir, *dest_fs_type, same_fs);
        if (!g_file_equal (dest, new_dest)) {
            g_object_unref (dest);
            dest = new_dest;
            goto retry;
        } else {
            g_object_unref (new_dest);
        }
    }

    /* Conflict */
    else if (!overwrite &&
             IS_IO_ERROR (error, EXISTS)) {
        gboolean is_merge;
        ConflictResponseData *response;

        g_error_free (error);

        is_merge = FALSE;
        if (is_dir (dest) && is_dir (src)) {
            is_merge = TRUE;
        }

        if ((is_merge && job->merge_all) ||
            (!is_merge && job->replace_all)) {
            overwrite = TRUE;
            goto retry;
        }

        if (job->skip_all_conflict) {
            goto out;
        }

        response = run_conflict_dialog (job, src, dest, dest_dir);

        if (response->id == GTK_RESPONSE_CANCEL ||
            response->id == GTK_RESPONSE_DELETE_EVENT) {
            conflict_response_data_free (response);
            abort_job (job);
            goto out;
        } else if (response->id == MARLIN_FILE_CONFLICT_DIALOG_RESPONSE_TYPE_SKIP) {
            if (response->apply_to_all) {
                job->skip_all_conflict = TRUE;
            }
            conflict_response_data_free (response);
        } else if (response->id == MARLIN_FILE_CONFLICT_DIALOG_RESPONSE_TYPE_REPLACE ||
                   response->id == MARLIN_FILE_CONFLICT_DIALOG_RESPONSE_TYPE_NEWEST) { /* merge/replace/newest */

            if (response->id == MARLIN_FILE_CONFLICT_DIALOG_RESPONSE_TYPE_NEWEST &&
                pf_file_utils_compare_modification_dates (src, dest) < 1) { /* destination not older */

                goto out;/* Skip this one */
            }

            if (response->apply_to_all) {
                if (is_merge) {
                    job->merge_all = TRUE;
                } else {
                    job->replace_all = TRUE;
                }
            }
            overwrite = TRUE;
            conflict_response_data_free (response);
            goto retry;
        } else if (response->id == MARLIN_FILE_CONFLICT_DIALOG_RESPONSE_TYPE_RENAME) {
            g_object_unref (dest);
            dest = get_target_file_for_display_name (dest_dir,
                                                     response->new_name);
            renamed = TRUE;
            conflict_response_data_free (response);
            goto retry;
        } else {
            /* Failsafe rather than crash */
            conflict_response_data_free (response);
            abort_job (job);
            goto out;
        }
    } else if (IS_IO_ERROR (error, WOULD_RECURSE) ||
             IS_IO_ERROR (error, WOULD_MERGE) ||
             IS_IO_ERROR (error, NOT_SUPPORTED) ||
             (overwrite && IS_IO_ERROR (error, IS_DIRECTORY))) {
        g_error_free (error);

        fallback = move_copy_file_callback_new (src, overwrite);
        *fallback_files = g_list_prepend (*fallback_files, fallback);
    } else if (IS_IO_ERROR (error, CANCELLED)) {
        g_error_free (error);
    } else { /* Other error */
        gchar *src_name, *dest_name;
        if (job->skip_all_error) {
            goto out;
        }
        src_name = g_file_get_parse_name (src);
        /// TRANSLATORS: \"%s\" is a placeholder for the quoted full path of a file.  It may change position but must not be translated or removed
        /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
        primary = g_strdup_printf (_("Error while moving \"%s\"."), src_name);
        g_free (src_name);
        dest_name = g_file_get_parse_name (dest_dir);
        /// TRANSLATORS: %s is a placeholder for the full path of a file.  It may change position but must not be translated or removed
        secondary = g_strdup_printf (_("There was an error moving the file into %s."), dest_name);
        g_free (dest_name);
        details = error->message;

        response = run_warning (job,
                                primary,
                                secondary,
                                details,
                                files_left > 1,
                                CANCEL, SKIP_ALL, SKIP,
                                NULL);

        g_error_free (error);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            abort_job (job);
        } else if (response == 1) { /* skip all */
            job->skip_all_error = TRUE;
        } else if (response == 2) { /* skip */
            /* do nothing */
        } else {
            g_assert_not_reached ();
        }
    }

out:
    g_object_unref (dest);
}

static void
move_files_prepare (CopyMoveJob *job,
                    const char *dest_fs_id,
                    char **dest_fs_type,
                    GList **fallbacks)
{
    CommonJob *common;
    GList *l;
    GFile *src;
    gboolean same_fs;
    int i;
    int total, left;

    common = &job->common;

    total = left = g_list_length (job->files);

    report_move_progress (job, total, left);

    i = 0;
    for (l = job->files;
         l != NULL && !job_aborted (common);
         l = l->next) {
        src = l->data;

        same_fs = FALSE;
        if (dest_fs_id) {
            same_fs = has_fs_id (src, dest_fs_id);
        }

        move_file_prepare (job, src, job->destination,
                           same_fs, dest_fs_type,
                           job->debuting_files,
                           fallbacks,
                           left);
        report_move_progress (job, total, --left);
        i++;
    }

    *fallbacks = g_list_reverse (*fallbacks);


}

static void
move_files (CopyMoveJob *job,
            GList *fallbacks,
            const char *dest_fs_id,
            char **dest_fs_type,
            SourceInfo *source_info,
            TransferInfo *transfer_info)
{
    CommonJob *common;
    GList *l;
    GFile *src;
    gboolean same_fs;
    int i;
    gboolean skipped_file;
    MoveFileCopyFallback *fallback;
    common = &job->common;

    report_copy_progress (job, source_info, transfer_info);

    i = 0;
    for (l = fallbacks;
         l != NULL && !job_aborted (common);
         l = l->next) {
        fallback = l->data;
        src = fallback->file;

        same_fs = FALSE;
        if (dest_fs_id) {
            same_fs = has_fs_id (src, dest_fs_id);
        }

        /* Set overwrite to true, as the user has
           selected overwrite on all toplevel items */
        skipped_file = FALSE;
        copy_move_file (job, src, job->destination,
                        same_fs, FALSE, dest_fs_type,
                        source_info, transfer_info,
                        job->debuting_files,
                        fallback->overwrite, &skipped_file, FALSE);
        i++;
    }
}

static gboolean
move_job_done (gpointer user_data)
{
    CopyMoveJob *job;

    job = user_data;
    g_task_return_boolean (job->task, TRUE);
    g_clear_object (&job->task);

    g_list_free_full (job->files, g_object_unref);
    job->files = NULL;
    g_clear_object (&job->destination);
    g_clear_pointer (&job->debuting_files, g_hash_table_unref);

    finalize_common ((CommonJob *)job);

    marlin_file_changes_consume_changes (TRUE);
    return FALSE;
}

static gboolean
move_job (GIOSchedulerJob *io_job,
          GCancellable *cancellable,
          gpointer user_data)
{
    CopyMoveJob *job;
    CommonJob *common;
    GList *fallbacks;
    SourceInfo source_info;
    TransferInfo transfer_info;
    char *dest_fs_id;
    char *dest_fs_type;
    GList *fallback_files;

    job = user_data;
    common = &job->common;
    common->io_job = io_job;

    dest_fs_id = NULL;
    dest_fs_type = NULL;

    fallbacks = NULL;

    pf_progress_info_start (job->common.progress);
    verify_destination (&job->common,
                        job->destination,
                        &dest_fs_id,
                        -1);
    if (job_aborted (common)) {
        goto aborted;
    }

    /* This moves all files that we can do without copy + delete */
    move_files_prepare (job, dest_fs_id, &dest_fs_type, &fallbacks);
    if (job_aborted (common)) {
        goto aborted;
    }

    /* The rest we need to do deep copy + delete behind on,
       so scan for size */

    fallback_files = get_files_from_fallbacks (fallbacks);
    scan_sources (fallback_files,
                  &source_info,
                  common,
                  OP_KIND_MOVE);

    g_list_free (fallback_files);

    if (job_aborted (common)) {
        goto aborted;
    }

    verify_destination (&job->common,
                        job->destination,
                        NULL,
                        source_info.num_bytes);
    if (job_aborted (common)) {
        goto aborted;
    }

    memset (&transfer_info, 0, sizeof (transfer_info));
    move_files (job,
                fallbacks,
                dest_fs_id, &dest_fs_type,
                &source_info, &transfer_info);

aborted:
    g_list_free_full (fallbacks, g_free);

    g_free (dest_fs_id);
    g_free (dest_fs_type);

    g_io_scheduler_job_send_to_mainloop (io_job,
                                         move_job_done,
                                         job,
                                         NULL);

    return FALSE;
}

static void
marlin_file_operations_move (GList               *files,
                             GFile               *target_dir,
                             GtkWindow           *parent_window,
                             GCancellable        *cancellable,
                             GAsyncReadyCallback  callback,
                             gpointer             user_data)
{

    CopyMoveJob *job;
    job = op_job_new (CopyMoveJob, parent_window);
    job->is_move = TRUE;
    job->task = g_task_new (NULL, cancellable, callback, user_data);
    job->files = g_list_copy_deep (files, (GCopyFunc) g_object_ref, NULL);
    job->destination = g_object_ref (target_dir);
    job->debuting_files = g_hash_table_new_full (g_file_hash, (GEqualFunc)g_file_equal, g_object_unref, NULL);

    inhibit_power_manager ((CommonJob *)job, _("Moving Files"));
    // Start UNDO-REDO
    if (g_file_has_uri_scheme (g_list_first(files)->data, "trash")) {
        job->common.undo_redo_data = marlin_undo_action_data_new (MARLIN_UNDO_RESTOREFROMTRASH, g_list_length(files));
    } else {
        job->common.undo_redo_data = marlin_undo_action_data_new (MARLIN_UNDO_MOVE, g_list_length(files));
    }
    GFile* src_dir = g_file_get_parent (files->data);
    marlin_undo_action_data_set_src_dir (job->common.undo_redo_data, src_dir);
    g_object_ref (target_dir);
    marlin_undo_action_data_set_dest_dir (job->common.undo_redo_data, target_dir);
    // End UNDO-REDO

    g_io_scheduler_push_job (move_job,
                             job,
                             NULL, /* destroy notify */
                             0,
                             job->common.cancellable);
}

static gboolean
marlin_file_operations_move_finish (GAsyncResult  *result,
                                    GError       **error)
{
    g_return_val_if_fail (g_task_is_valid (result, NULL), NULL);

    return g_task_propagate_boolean (G_TASK (result), error);
}

static void
report_link_progress (CopyMoveJob *link_job, int total, int left)
{
    CommonJob *job;
    gchar *s;

    job = (CommonJob *)link_job;
    gchar *dest_name = g_file_get_parse_name (link_job->destination);
    /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
    /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
    s = g_strdup_printf (_("Creating links in \"%s\""), dest_name);
    g_free (dest_name);

    pf_progress_info_take_status (job->progress, s);
    pf_progress_info_take_details (job->progress,
                                   g_strdup_printf (ngettext ("Making link to %'d file",
                                                              "Making links to %'d files",
                                                              left), left));

    pf_progress_info_update_progress (job->progress, left, total);
}

static char *
get_abs_path_for_symlink (GFile *file)
{
    GFile *root, *parent;
    char *relative, *abs;

    if (g_file_is_native (file)) {
        return g_file_get_path (file);
    }

    root = g_object_ref (file);
    while ((parent = g_file_get_parent (root)) != NULL) {
        g_object_unref (root);
        root = parent;
    }

    relative = g_file_get_relative_path (root, file);
    g_object_unref (root);
    abs = g_strconcat ("/", relative, NULL);
    g_free (relative);
    return abs;
}


static void
link_file (CopyMoveJob *job,
           GFile *src, GFile *dest_dir,
           char **dest_fs_type,
           GHashTable *debuting_files,
           int files_left)
{
    GFile *src_dir, *dest, *new_dest;
    int count;
    char *path;
    gboolean not_local;
    GError *error;
    CommonJob *common;
    char *primary, *secondary, *details;
    int response;
    gboolean handled_invalid_filename;

    common = (CommonJob *)job;

    count = 0;

    src_dir = g_file_get_parent (src);
    if (g_file_equal (src_dir, dest_dir)) {
        count = 1;
    }
    g_object_unref (src_dir);

    handled_invalid_filename = *dest_fs_type != NULL;

    dest = get_target_file_for_link (src, dest_dir, *dest_fs_type, count);

retry:
    error = NULL;
    not_local = FALSE;

    path = get_abs_path_for_symlink (src);
    char *scheme;
    scheme = g_file_get_uri_scheme (src);

    if (path == NULL || !g_str_has_prefix (scheme, "file"))
        not_local = TRUE;

    g_free (scheme);

    if (!not_local && g_file_make_symbolic_link (dest,
                                          path,
                                          common->cancellable,
                                          &error)) {

        // Start UNDO-REDO
        marlin_undo_action_data_add_origin_target_pair (common->undo_redo_data, src, dest);
        // End UNDO-REDO

        g_free (path);

        if (debuting_files) {
            g_hash_table_replace (debuting_files, g_object_ref (dest), GINT_TO_POINTER (TRUE));
        }
       marlin_file_changes_queue_file_added (dest);

        g_object_unref (dest);

        return;
    }
    g_free (path);

    if (error != NULL &&
        IS_IO_ERROR (error, INVALID_FILENAME) &&
        !handled_invalid_filename) {
        handled_invalid_filename = TRUE;

        g_assert (*dest_fs_type == NULL);
        *dest_fs_type = query_fs_type (dest_dir, common->cancellable);

        new_dest = get_target_file_for_link (src, dest_dir, *dest_fs_type, count);

        if (!g_file_equal (dest, new_dest)) {
            g_object_unref (dest);
            dest = new_dest;
            g_error_free (error);

            goto retry;
        } else {
            g_object_unref (new_dest);
        }
    }
    /* Conflict */
    if (error != NULL && IS_IO_ERROR (error, EXISTS)) {
        g_object_unref (dest);
        dest = get_target_file_for_link (src, dest_dir, *dest_fs_type, count++);
        g_error_free (error);
        goto retry;
    }

    else if (error != NULL && IS_IO_ERROR (error, CANCELLED)) {
        g_error_free (error);
    }

    /* Other error */
    else {
        gchar *src_basename;
        if (common->skip_all_error) {
            goto out;
        }
        src_basename = custom_basename_from_file (src);
        /// TRANSLATORS: %s is a placeholder for the basename of a file.  It may change position but must not be translated or removed
        primary = g_strdup_printf (_("Error while creating link to %s."), src_basename);
        g_free (src_basename);
        if (not_local) {
            secondary = g_strdup (_("Symbolic links only supported for local files"));
            details = NULL;
        } else if (IS_IO_ERROR (error, NOT_SUPPORTED)) {
            secondary = g_strdup (_("The target doesn't support symbolic links."));
            details = NULL;
        } else {
            gchar *dest_dir_name = g_file_get_parse_name (dest_dir);
            /// TRANSLATORS: %s is a placeholder for the full path of a file.  It may change position but must not be translated or removed
            secondary = g_strdup_printf (_("There was an error creating the symlink in %s."), dest_dir_name);
            g_free (dest_dir_name);
            details = error->message;
        }

        response = run_warning (common,
                                primary,
                                secondary,
                                details,
                                files_left > 1,
                                CANCEL, SKIP_ALL, SKIP,
                                NULL);

        if (error) {
            g_error_free (error);
        }

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            abort_job (common);
        } else if (response == 1) { /* skip all */
            common->skip_all_error = TRUE;
        } else if (response == 2) { /* skip */
            /* do nothing */
        } else {
            g_assert_not_reached ();
        }
    }

out:
    g_object_unref (dest);
}

static gboolean
link_job_done (gpointer user_data)
{
    CopyMoveJob *job;

    job = user_data;
    g_task_return_boolean (job->task, TRUE);
    g_clear_object (&job->task);

    g_list_free_full (job->files, g_object_unref);
    job->files = NULL;
    g_clear_object (&job->destination);
    g_clear_pointer (&job->debuting_files, g_hash_table_unref);

    finalize_common ((CommonJob *)job);

    marlin_file_changes_consume_changes (TRUE);
    return FALSE;
}

static gboolean
link_job (GIOSchedulerJob *io_job,
          GCancellable *cancellable,
          gpointer user_data)
{
    CopyMoveJob *job;
    CommonJob *common;
    GFile *src;
    char *dest_fs_type;
    int total, left;
    int i;
    GList *l;

    job = user_data;
    common = &job->common;
    common->io_job = io_job;

    dest_fs_type = NULL;

    pf_progress_info_start (job->common.progress);
    verify_destination (&job->common,
                        job->destination,
                        NULL,
                        -1);
    if (job_aborted (common)) {
        goto aborted;
    }

    total = left = g_list_length (job->files);

    report_link_progress (job, total, left);

    i = 0;
    for (l = job->files;
         l != NULL && !job_aborted (common);
         l = l->next) {
        src = l->data;


        link_file (job, src, job->destination,
                   &dest_fs_type, job->debuting_files,
                   left);
        report_link_progress (job, total, --left);
        i++;

    }

aborted:
    g_free (dest_fs_type);

    g_io_scheduler_job_send_to_mainloop (io_job,
                                         link_job_done,
                                         job,
                                         NULL);

    return FALSE;
}

static void
marlin_file_operations_link (GList               *files,
                             GFile               *target_dir,
                             GtkWindow           *parent_window,
                             GCancellable        *cancellable,
                             GAsyncReadyCallback  callback,
                             gpointer             user_data)
{
    CopyMoveJob *job;

    job = op_job_new (CopyMoveJob, parent_window);
    job->task = g_task_new (NULL, cancellable, callback, user_data);
    job->files = g_list_copy_deep (files, (GCopyFunc) g_object_ref, NULL);
    job->destination = g_object_ref (target_dir);
    job->debuting_files = g_hash_table_new_full (g_file_hash, (GEqualFunc)g_file_equal, g_object_unref, NULL);

    // Start UNDO-REDO
    job->common.undo_redo_data = marlin_undo_action_data_new (MARLIN_UNDO_CREATELINK, g_list_length(files));
    GFile* src_dir = g_file_get_parent (files->data);
    marlin_undo_action_data_set_src_dir (job->common.undo_redo_data, src_dir);
    g_object_ref (target_dir);
    marlin_undo_action_data_set_dest_dir (job->common.undo_redo_data, target_dir);
    // End UNDO-REDO

    g_io_scheduler_push_job (link_job,
                             job,
                             NULL, /* destroy notify */
                             0,
                             job->common.cancellable);
}

static gboolean
marlin_file_operations_link_finish (GAsyncResult  *result,
                                    GError       **error)
{
    g_return_val_if_fail (g_task_is_valid (result, NULL), NULL);

    return g_task_propagate_boolean (G_TASK (result), error);
}

static void
marlin_file_operations_duplicate (GList               *files,
                                  GtkWindow           *parent_window,
                                  GCancellable        *cancellable,
                                  GAsyncReadyCallback  callback,
                                  gpointer             user_data)
{
    CopyMoveJob *job;

    job = op_job_new (CopyMoveJob, parent_window);
    job->task = g_task_new (NULL, cancellable, callback, user_data);
    job->files = g_list_copy_deep (files, (GCopyFunc) g_object_ref, NULL);
    job->destination = NULL;
    job->debuting_files = g_hash_table_new_full (g_file_hash, (GEqualFunc)g_file_equal, g_object_unref, NULL);

    // Start UNDO-REDO
    job->common.undo_redo_data = marlin_undo_action_data_new (MARLIN_UNDO_DUPLICATE, g_list_length(files));
    GFile* src_dir = g_file_get_parent (files->data);
    marlin_undo_action_data_set_src_dir (job->common.undo_redo_data, src_dir);
    g_object_ref (src_dir);
    marlin_undo_action_data_set_dest_dir (job->common.undo_redo_data, src_dir);
    // End UNDO-REDO

    g_io_scheduler_push_job (copy_job,
                             job,
                             NULL, /* destroy notify */
                             0,
                             job->common.cancellable);
}

static gboolean
marlin_file_operations_duplicate_finish (GAsyncResult  *result,
                                         GError       **error)
{
    g_return_val_if_fail (g_task_is_valid (result, NULL), NULL);

    return g_task_propagate_boolean (G_TASK (result), error);
}

#if 0  /* TODO: Implement recursive permissions in PropertiesWindow.vala - may use this code */
static gboolean
set_permissions_job_done (gpointer user_data)
{
    SetPermissionsJob *job;

    job = user_data;

    g_object_unref (job->file);

    if (job->done_callback) {
        job->done_callback (job->done_callback_data);
    }

    finalize_common ((CommonJob *)job);
    return FALSE;
}

static void
set_permissions_file (SetPermissionsJob *job,
                      GFile *file,
                      GFileInfo *info)
{
    CommonJob *common;
    GFileInfo *child_info;
    gboolean free_info;
    guint32 current;
    guint32 value;
    guint32 mask;
    GFileEnumerator *enumerator;
    GFile *child;

    common = (CommonJob *)job;

    pf_progress_info_pulse_progress (common->progress);
    free_info = FALSE;
    if (info == NULL) {
        free_info = TRUE;
        info = g_file_query_info (file,
                                  G_FILE_ATTRIBUTE_STANDARD_TYPE","
                                  G_FILE_ATTRIBUTE_UNIX_MODE,
                                  G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS,
                                  common->cancellable,
                                  NULL);
        /* Ignore errors */
        if (info == NULL) {
            return;
        }
    }

    if (g_file_info_get_file_type (info) == G_FILE_TYPE_DIRECTORY) {
        value = job->dir_permissions;
        mask = job->dir_mask;
    } else {
        value = job->file_permissions;
        mask = job->file_mask;
    }


    if (!job_aborted (common) &&
        g_file_info_has_attribute (info, G_FILE_ATTRIBUTE_UNIX_MODE)) {
        current = g_file_info_get_attribute_uint32 (info, G_FILE_ATTRIBUTE_UNIX_MODE);

        // Start UNDO-REDO
        marlin_undo_action_data_add_file_permissions(common->undo_redo_data, file, current);
        // End UNDO-REDO

        current = (current & ~mask) | value;

        g_file_set_attribute_uint32 (file, G_FILE_ATTRIBUTE_UNIX_MODE,
                                     current, G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS,
                                     common->cancellable, NULL);
    }

    if (!job_aborted (common) &&
        g_file_info_get_file_type (info) == G_FILE_TYPE_DIRECTORY) {
        enumerator = g_file_enumerate_children (file,
                                                G_FILE_ATTRIBUTE_STANDARD_NAME","
                                                G_FILE_ATTRIBUTE_STANDARD_TYPE","
                                                G_FILE_ATTRIBUTE_UNIX_MODE,
                                                G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS,
                                                common->cancellable,
                                                NULL);
        if (enumerator) {
            while (!job_aborted (common) &&
                   (child_info = g_file_enumerator_next_file (enumerator, common->cancellable, NULL)) != NULL) {
                child = g_file_get_child (file,
                                          g_file_info_get_name (child_info));
                set_permissions_file (job, child, child_info);
                g_object_unref (child);
                g_object_unref (child_info);
            }
            g_file_enumerator_close (enumerator, common->cancellable, NULL);
            g_object_unref (enumerator);
        }
    }
    if (free_info) {
        g_object_unref (info);
    }
}


static gboolean
set_permissions_job (GIOSchedulerJob *io_job,
                     GCancellable *cancellable,
                     gpointer user_data)
{
    SetPermissionsJob *job = user_data;
    CommonJob *common;

    common = (CommonJob *)job;
    common->io_job = io_job;

    pf_progress_info_start (job->common.progress);
    pf_progress_info_set_status (common->progress, _("Setting permissions"));
    set_permissions_file (job, job->file, NULL);

    g_io_scheduler_job_send_to_mainloop_async (io_job,
                                               set_permissions_job_done,
                                               job,
                                               NULL);

    return FALSE;
}



void
marlin_file_set_permissions_recursive (const char *directory,
                                       guint32         file_permissions,
                                       guint32         file_mask,
                                       guint32         dir_permissions,
                                       guint32         dir_mask,
                                       MarlinOpCallback  callback,
                                       gpointer  callback_data)
{
    SetPermissionsJob *job;

    job = op_job_new (SetPermissionsJob, NULL);
    job->file = g_file_new_for_uri (directory);
    job->file_permissions = file_permissions;
    job->file_mask = file_mask;
    job->dir_permissions = dir_permissions;
    job->dir_mask = dir_mask;
    job->done_callback = callback;
    job->done_callback_data = callback_data;

    // Start UNDO-REDO
    job->common.undo_redo_data = marlin_undo_action_data_new (MARLIN_UNDO_RECURSIVESETPERMISSIONS, 1);
    g_object_ref (job->file);
    marlin_undo_action_data_set_dest_dir (job->common.undo_redo_data, job->file);
    marlin_undo_action_data_set_recursive_permissions(job->common.undo_redo_data, file_permissions, file_mask, dir_permissions, dir_mask);
    // End UNDO-REDO

    g_io_scheduler_push_job (set_permissions_job,
                             job,
                             NULL,
                             0,
                             NULL);
}
#endif


void
copy_move_link_delete_finish (GObject *source_object,
                              GAsyncResult *res,
                              gpointer user_data)
{
    GTask *task = user_data;
    GError *error = NULL;
    gboolean result;

    result = marlin_file_operations_delete_finish (res, &error);
    if (error != NULL) {
        g_task_return_error (task, g_steal_pointer (&error));
    } else {
        g_task_return_boolean (task, result);
    }

    g_clear_object (&task);
}

static void
copy_move_link_duplicate_finish (GObject *source_object,
                                 GAsyncResult *res,
                                 gpointer user_data)
{
    GTask *task = user_data;
    GError *error = NULL;
    gboolean result;

    result = marlin_file_operations_duplicate_finish (res, &error);
    if (error != NULL) {
        g_task_return_error (task, g_steal_pointer (&error));
    } else {
        g_task_return_boolean (task, result);
    }

    g_clear_object (&task);
}

static void
copy_move_link_copy_finish (GObject *source_object,
                            GAsyncResult *res,
                            gpointer user_data)
{
    GTask *task = user_data;
    GError *error = NULL;
    gboolean result;

    result = marlin_file_operations_copy_finish (res, &error);
    if (error != NULL) {
        g_task_return_error (task, g_steal_pointer (&error));
    } else {
        g_task_return_boolean (task, result);
    }

    g_clear_object (&task);
}

static void
copy_move_link_move_finish (GObject *source_object,
                            GAsyncResult *res,
                            gpointer user_data)
{
    GTask *task = user_data;
    GError *error = NULL;
    gboolean result;

    result = marlin_file_operations_move_finish (res, &error);
    if (error != NULL) {
        g_task_return_error (task, g_steal_pointer (&error));
    } else {
        g_task_return_boolean (task, result);
    }

    g_clear_object (&task);
}

static void
copy_move_link_link_finish (GObject *source_object,
                            GAsyncResult *res,
                            gpointer user_data)
{
    GTask *task = user_data;
    GError *error = NULL;
    gboolean result;

    result = marlin_file_operations_link_finish (res, &error);
    if (error != NULL) {
        g_task_return_error (task, g_steal_pointer (&error));
    } else {
        g_task_return_boolean (task, result);
    }

    g_clear_object (&task);
}

void
marlin_file_operations_copy_move_link (GList               *files,
                                       GFile               *target_dir,
                                       GdkDragAction        copy_action,
                                       GtkWidget           *parent_view,
                                       GCancellable        *cancellable,
                                       GAsyncReadyCallback  callback,
                                       gpointer             user_data)
{
    GTask *task;
    GList *p;
    GFile *src_dir;
    GtkWindow *parent_window;
    gboolean target_is_mapping;
    gboolean have_nonmapping_source;

    target_is_mapping = FALSE;
    have_nonmapping_source = FALSE;

    if (g_file_has_uri_scheme (target_dir, "burn")) {
        target_is_mapping = TRUE;
    }

    for (p = files; p != NULL; p = p->next) {
        if (!g_file_has_uri_scheme ((GFile* )p->data, "burn")) {
            have_nonmapping_source = TRUE;
            break;
        }
    }

    if (target_is_mapping && have_nonmapping_source && copy_action == GDK_ACTION_MOVE) {
        /* never move to "burn:///", but fall back to copy.
         * This is a workaround, because otherwise the source files would be removed.
         */
        copy_action = GDK_ACTION_COPY;
    }

    parent_window = NULL;
    if (parent_view) {
        parent_window = (GtkWindow *)gtk_widget_get_ancestor (parent_view, GTK_TYPE_WINDOW);
    }

    task = g_task_new (NULL, cancellable, callback, user_data);
    if (copy_action == GDK_ACTION_COPY) {
        if (g_file_has_uri_scheme (target_dir, "trash")) {
            char *primary = g_strdup (_("Cannot copy into trash."));
            char *secondary = g_strdup (_("It is not permitted to copy files into the trash"));
            pf_dialogs_show_error_dialog (primary,
                                          secondary,
                                          parent_window);

            g_task_return_new_error (task,
                                     G_IO_ERROR,
                                     G_IO_ERROR_FAILED,
                                     _("It is not permitted to copy files into the trash"),
                                     NULL);
            g_clear_object (&task);
            return;
        }

        /* done_callback is (or should be) a CopyCallBack or null in this case */
        src_dir = g_file_get_parent (files->data);
        if (target_dir == NULL ||
            (src_dir != NULL &&
             g_file_equal (src_dir, target_dir))) {

             marlin_file_operations_duplicate (files,
                                               parent_window,
                                               cancellable,
                                               copy_move_link_duplicate_finish,
                                               g_steal_pointer (&task));
        } else {
            marlin_file_operations_copy (files,
                                         target_dir,
                                         parent_window,
                                         cancellable,
                                         copy_move_link_copy_finish,
                                         g_steal_pointer (&task));
        }
        if (src_dir) {
            g_object_unref (src_dir);
        }

    } else if (copy_action == GDK_ACTION_MOVE) {
        if (g_file_has_uri_scheme (target_dir, "trash")) {
            /* done_callback is (or should be) a DeleteCallBack or null in this case */

            marlin_file_operations_delete (files,
                                           parent_window,
                                           TRUE,
                                           cancellable,
                                           copy_move_link_delete_finish,
                                           g_steal_pointer (&task));
        } else {
            /* done_callback is (or should be) a CopyCallBack or null in this case */
            marlin_file_operations_move (files,
                                         target_dir,
                                         parent_window,
                                         cancellable,
                                         copy_move_link_move_finish,
                                         g_steal_pointer (&task));
        }
    } else {
        marlin_file_operations_link (files,
                                     target_dir,
                                     parent_window,
                                     cancellable,
                                     copy_move_link_link_finish,
                                     g_steal_pointer (&task));
    }
}


gboolean
marlin_file_operations_copy_move_link_finish (GAsyncResult  *result,
                                              GError       **error)
{
    g_return_val_if_fail (g_task_is_valid (result, NULL), NULL);

    return g_task_propagate_boolean (G_TASK (result), error);
}

static gboolean
create_job_done (gpointer user_data)
{
    CreateJob *job = user_data;
    g_task_return_pointer (job->task, g_steal_pointer (&job->created_file), g_object_unref);
    g_clear_object (&job->dest_dir);
    g_clear_object (&job->src);
    g_clear_pointer (&job->src_data, g_free);
    g_clear_pointer (&job->filename, g_free);
    g_clear_object (&job->task);

    finalize_common ((CommonJob *)job);

    marlin_file_changes_consume_changes (TRUE);
    return FALSE;
}

static gboolean
create_job (GIOSchedulerJob *io_job,
            GCancellable *cancellable,
            gpointer user_data)
{
    CreateJob *job;
    CommonJob *common;
    int count;
    GFile *dest;
    char *filename, *filename2, *new_filename;
    char *dest_fs_type;
    GError *error;
    gboolean res;
    gboolean filename_is_utf8;
    char *primary, *secondary, *details;
    int response;
    char *data;
    int length;
    GFileOutputStream *out;
    gboolean handled_invalid_filename;
    int max_length;

    job = user_data;
    common = &job->common;
    common->io_job = io_job;

    pf_progress_info_start (job->common.progress);

    handled_invalid_filename = FALSE;

    dest_fs_type = NULL;
    filename = NULL;
    dest = NULL;

    max_length = get_max_name_length (job->dest_dir);

    verify_destination (common,
                        job->dest_dir,
                        NULL, -1);
    if (job_aborted (common)) {
        goto aborted;
    }

    filename = g_strdup (job->filename);
    filename_is_utf8 = FALSE;
    if (filename) {
        filename_is_utf8 = g_utf8_validate (filename, -1, NULL);
    }
    if (filename == NULL) {
        if (job->make_dir) {
            /* localizers: the initial name of a new folder  */
            filename = g_strdup (_("untitled folder"));
            filename_is_utf8 = TRUE; /* Pass in utf8 */
        } else {
            if (job->src != NULL) {
                filename = g_file_get_basename (job->src);
            }
            if (filename == NULL) {
                /* localizers: the initial name of a new empty file */
                filename = g_strdup (_("new file"));
                filename_is_utf8 = TRUE; /* Pass in utf8 */
            }
        }
    }

    make_file_name_valid_for_dest_fs (filename, dest_fs_type);
    if (filename_is_utf8) {
        dest = g_file_get_child_for_display_name (job->dest_dir, filename, NULL);
    }
    if (dest == NULL) {
        dest = g_file_get_child (job->dest_dir, filename);
    }
    count = 1;

retry:

    error = NULL;
    if (job->make_dir) {
        res = g_file_make_directory (dest,
                                     common->cancellable,
                                     &error);
        // Start UNDO-REDO
        if (res) {
            marlin_undo_action_data_set_create_data(common->undo_redo_data,
                                                     g_file_get_uri(dest),
                                                     NULL);
        }
        // End UNDO-REDO
    } else {
        if (job->src) {
            res = g_file_copy (job->src,
                               dest,
                               G_FILE_COPY_NONE,
                               common->cancellable,
                               NULL, NULL,
                               &error);
            // Start UNDO-REDO
            if (res) {
                marlin_undo_action_data_set_create_data(common->undo_redo_data,
                                                         g_file_get_uri(dest),
                                                         g_file_get_uri(job->src));
            }
            // End UNDO-REDO
        } else {
            data = "";
            length = 0;
            if (job->src_data) {
                data = job->src_data;
                length = job->length;
            }

            out = g_file_create (dest,
                                 G_FILE_CREATE_NONE,
                                 common->cancellable,
                                 &error);
            if (out) {
                res = g_output_stream_write_all (G_OUTPUT_STREAM (out),
                                                 data, length,
                                                 NULL,
                                                 common->cancellable,
                                                 &error);
                if (res) {
                    res = g_output_stream_close (G_OUTPUT_STREAM (out),
                                                 common->cancellable,
                                                 &error);
                    // Start UNDO-REDO
                    if (res) {
                        marlin_undo_action_data_set_create_data(common->undo_redo_data,
                                                                 g_file_get_uri(dest),
                                                                 g_strdup(data));
                    }
                }

                /* This will close if the write failed and we didn't close */
                g_object_unref (out);
            } else {
                res = FALSE;
            }
        }
    }

    if (res) {
        job->created_file = g_object_ref (dest);
       marlin_file_changes_queue_file_added (dest);
    } else {
        g_assert (error != NULL);

        if (IS_IO_ERROR (error, INVALID_FILENAME) &&
            !handled_invalid_filename) {
            handled_invalid_filename = TRUE;

            g_assert (dest_fs_type == NULL);
            dest_fs_type = query_fs_type (job->dest_dir, common->cancellable);

            g_object_unref (dest);

            if (count == 1) {
                new_filename = g_strdup (filename);
            } else if (job->make_dir) {
                filename2 = g_strdup_printf ("%s %d", filename, count);

                new_filename = NULL;
                if (max_length > 0 && strlen (filename2) > max_length) {
                    new_filename = shorten_utf8_string (filename2, strlen (filename2) - max_length);
                }

                if (new_filename == NULL) {
                    new_filename = g_strdup (filename2);
                }

                g_free (filename2);
            } else {
                new_filename = get_duplicate_name (filename, count, max_length);
            }

            if (make_file_name_valid_for_dest_fs (new_filename, dest_fs_type)) {
                g_object_unref (dest);

                if (filename_is_utf8) {
                    dest = g_file_get_child_for_display_name (job->dest_dir, new_filename, NULL);
                }
                if (dest == NULL) {
                    dest = g_file_get_child (job->dest_dir, new_filename);
                }

                g_free (new_filename);
                g_error_free (error);
                goto retry;
            }
            g_free (new_filename);
        } else if (IS_IO_ERROR (error, EXISTS)) {
            g_object_unref (dest);
            dest = NULL;
            if (job->make_dir) {
                filename2 = g_strdup_printf ("%s %d", filename, ++count);
                if (max_length > 0 && strlen (filename2) > max_length) {
                    new_filename = shorten_utf8_string (filename2, strlen (filename2) - max_length);
                    if (new_filename != NULL) {
                        g_free (filename2);
                        filename2 = new_filename;
                    }
                }
            } else {
                filename2 = get_duplicate_name (filename, count++, max_length);
            }
            make_file_name_valid_for_dest_fs (filename2, dest_fs_type);
            if (filename_is_utf8) {
                dest = g_file_get_child_for_display_name (job->dest_dir, filename2, NULL);
            }
            if (dest == NULL) {
                dest = g_file_get_child (job->dest_dir, filename2);
            }
            g_free (filename2);
            g_error_free (error);
            goto retry;
        }

        else if (IS_IO_ERROR (error, CANCELLED)) {
            g_error_free (error);
        }

        /* Other error */
        else {
            gchar *dest_basename = custom_basename_from_file (dest);
            if (job->make_dir) {
                /// TRANSLATORS: %s is a placeholder for the basename of a file.  It may change position but must not be translated or removed
                primary = g_strdup_printf (_("Error while creating directory %s."), dest_basename);
            } else {
                /// TRANSLATORS: %s is a placeholder for the basename of a file.  It may change position but must not be translated or removed
                primary = g_strdup_printf (_("Error while creating file %s."), dest_basename);
            }
            g_free (dest_basename);

            gchar *dest_dir_name = g_file_get_parse_name (job->dest_dir);
            /// TRANSLATORS: %s is a placeholder for the full path of a file.  It may change position but must not be translated or removed
            secondary = g_strdup_printf (_("There was an error creating the directory in %s."), dest_dir_name);
            g_free (dest_dir_name);
            details = error->message;

            response = run_warning (common,
                                    primary,
                                    secondary,
                                    details,
                                    FALSE,
                                    CANCEL, SKIP,
                                    NULL);

            g_error_free (error);

            if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
                abort_job (common);
            } else if (response == 1) { /* skip */
                /* do nothing */
            } else {
                g_assert_not_reached ();
            }
        }
    }

aborted:
    if (dest) {
        g_object_unref (dest);
    }
    g_free (filename);
    g_free (dest_fs_type);
    g_io_scheduler_job_send_to_mainloop_async (io_job,
                                               create_job_done,
                                               job,
                                               NULL);

    return FALSE;
}

void
marlin_file_operations_new_folder (GtkWidget           *parent_view,
                                   GFile               *parent_dir,
                                   GCancellable        *cancellable,
                                   GAsyncReadyCallback  callback,
                                   gpointer             user_data)
{
    CreateJob *job;
    GtkWindow *parent_window;

    parent_window = NULL;
    if (parent_view) {
        parent_window = (GtkWindow *)gtk_widget_get_ancestor (parent_view, GTK_TYPE_WINDOW);
    }

    job = op_job_new (CreateJob, parent_window);
    job->dest_dir = g_object_ref (parent_dir);
    job->make_dir = TRUE;
    job->task = g_task_new (NULL, cancellable, callback, user_data);

    // Start UNDO-REDO
    job->common.undo_redo_data = marlin_undo_action_data_new (MARLIN_UNDO_CREATEFOLDER, 1);
    // End UNDO-REDO

    g_io_scheduler_push_job (create_job,
                             job,
                             NULL, /* destroy notify */
                             0,
                             job->common.cancellable);
}

GFile *
marlin_file_operations_new_folder_finish (GAsyncResult  *result,
                                          GError       **error)
{
    g_return_val_if_fail (g_task_is_valid (result, NULL), NULL);

    return g_task_propagate_pointer (G_TASK (result), error);
}

void
marlin_file_operations_new_file_from_template (GtkWidget           *parent_view,
                                               GFile               *parent_dir,
                                               const char          *target_filename,
                                               GFile               *template,
                                               GCancellable        *cancellable,
                                               GAsyncReadyCallback  callback,
                                               gpointer             user_data)
{
    CreateJob *job;
    GtkWindow *parent_window;

    parent_window = NULL;
    if (parent_view) {
        parent_window = (GtkWindow *)gtk_widget_get_ancestor (parent_view, GTK_TYPE_WINDOW);
    }

    job = op_job_new (CreateJob, parent_window);
    g_object_ref (parent_dir); /* job->dest_dir unref'd in create_job done */
    job->dest_dir = parent_dir;
    job->task = g_task_new (NULL, cancellable, callback, user_data);
    job->filename = g_strdup (target_filename);

    if (template) {
        g_object_ref (template); /* job->src unref'd in create_job done */
        job->src = template;
    }

    // Start UNDO-REDO
    job->common.undo_redo_data = marlin_undo_action_data_new (MARLIN_UNDO_CREATEFILEFROMTEMPLATE, 1);
    // End UNDO-REDO

    g_io_scheduler_push_job (create_job,
                             job,
                             NULL, /* destroy notify */
                             0,
                             job->common.cancellable);
}

GFile *
marlin_file_operations_new_file_from_template_finish (GAsyncResult  *result,
                                                      GError       **error)
{
    g_return_val_if_fail (g_task_is_valid (result, NULL), NULL);

    return g_task_propagate_pointer (G_TASK (result), error);
}

void
marlin_file_operations_new_file (GtkWidget           *parent_view,
                                 const char          *parent_dir,
                                 const char          *target_filename,
                                 const char          *initial_contents,
                                 int                  length,
                                 GCancellable        *cancellable,
                                 GAsyncReadyCallback  callback,
                                 gpointer             user_data)
{
    CreateJob *job;
    GtkWindow *parent_window = NULL;
    if (parent_view) {
        parent_window = (GtkWindow *)gtk_widget_get_ancestor (parent_view, GTK_TYPE_WINDOW);
    }

    job = op_job_new (CreateJob, parent_window);
    job->dest_dir = g_file_new_for_uri (parent_dir);
    job->task = g_task_new (NULL, cancellable, callback, user_data);
    job->src_data = g_memdup (initial_contents, length);
    job->length = length;
    job->filename = g_strdup (target_filename);

    // Start UNDO-REDO
    job->common.undo_redo_data = marlin_undo_action_data_new (MARLIN_UNDO_CREATEEMPTYFILE, 1);
    // End UNDO-REDO

    g_io_scheduler_push_job (create_job,
                             job,
                             NULL, /* destroy notify */
                             0,
                             job->common.cancellable);
}

GFile *
marlin_file_operations_new_file_finish (GAsyncResult  *result,
                                        GError       **error)
{
    g_return_val_if_fail (g_task_is_valid (result, NULL), NULL);

    return g_task_propagate_pointer (G_TASK (result), error);
}
