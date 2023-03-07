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

#include <glib/gstdio.h>
#include <gdk/gdk.h>
#include <gtk/gtk.h>
#include <gio/gio.h>
#include <glib.h>

#include "pantheon-files-core.h"

typedef struct _SourceInfo SourceInfo;
typedef struct _TransferInfo TransferInfo;

typedef void (* CountProgressCallback) (FilesFileOperationsCommonJob *job, SourceInfo *source_info);

typedef enum {
    OP_KIND_COPY,
    OP_KIND_MOVE,
    OP_KIND_DELETE
} OpKind;

struct _SourceInfo {
    int num_files;
    goffset num_bytes;
    int num_files_since_progress;
    OpKind op;
    CountProgressCallback count_callback;
};

struct _TransferInfo {
    int num_files;
    goffset num_bytes;
    guint64 last_report_time;
    int last_reported_files_left;
};

#define SECONDS_NEEDED_FOR_RELIABLE_TRANSFER_RATE 15
//#define NSEC_PER_SEC 1000000000
#define NSEC_PER_MSEC 1000000

#define MAXIMUM_DISPLAYED_FILE_NAME_LENGTH 50

#define IS_IO_ERROR(__error, KIND) (((__error)->domain == G_IO_ERROR && (__error)->code == G_IO_ERROR_ ## KIND))

static void scan_sources (GList *files,
                          SourceInfo *source_info,
                          CountProgressCallback count_callback,
                          FilesFileOperationsCommonJob *job,
                          OpKind kind);

static char * query_fs_type (GFile *file,
                             GCancellable *cancellable);

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

/* Since this happens on a thread we can't use the global prefs object */
static gboolean
should_confirm_trash (void)
{
    return files_preferences_get_confirm_trash (files_preferences_get_default ());
}

static void
report_delete_progress (FilesFileOperationsCommonJob *job,
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
        formated_time = files_file_utils_format_time (remaining_time, &formated_time_unit);

        /// TRANSLATORS: %s will expand to a time like "2 minutes". It must not be translated or removed.
        /// The singular/plural form will be used depending on the remaining time (i.e. the %s argument).
        time_left_s = g_strdup_printf (ngettext ("%s left",
                                                 "%s left",
                                                 formated_time_unit),
                                       formated_time);
        g_free (formated_time);

        details = g_strconcat (files_left_s, "\xE2\x80\x94", time_left_s, NULL); //FIXME Remove opaque hex
        pf_progress_info_take_details (job->progress, details);

        g_free (time_left_s);
    }

    g_free (files_left_s);

    if (source_info->num_files != 0) {
        pf_progress_info_update_progress (job->progress, transfer_info->num_files, source_info->num_files);
    }
}

static void delete_file (FilesFileOperationsDeleteJob *del_job, GFile *file,
                         gboolean *skipped_file,
                         SourceInfo *source_info,
                         TransferInfo *transfer_info,
                         gboolean toplevel);

static void
delete_dir (FilesFileOperationsDeleteJob *del_job, GFile *dir,
            gboolean *skipped_file,
            SourceInfo *source_info,
            TransferInfo *transfer_info,
            gboolean toplevel)
{
    FilesFileOperationsCommonJob *job = MARLIN_FILE_OPERATIONS_COMMON_JOB (del_job);
    GFileInfo *info;
    GError *error;
    GFile *file;
    GFileEnumerator *enumerator;
    char *primary, *secondary, *details;
    int response;
    gboolean skip_error;
    gboolean local_skipped_file;

    local_skipped_file = FALSE;

    skip_error = marlin_file_operations_common_job_should_skip_readdir_error (job, dir);
retry:
    error = NULL;
    enumerator = g_file_enumerate_children (dir,
                                            G_FILE_ATTRIBUTE_STANDARD_NAME,
                                            G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS,
                                            job->cancellable,
                                            &error);
    if (enumerator) {
        error = NULL;

        while (!marlin_file_operations_common_job_aborted (job) &&
               (info = g_file_enumerator_next_file (enumerator, job->cancellable, skip_error?NULL:&error)) != NULL) {
            file = g_file_get_child (dir,
                                     g_file_info_get_name (info));
            delete_file (del_job, file, &local_skipped_file, source_info, transfer_info, FALSE);
            g_object_unref (file);
            g_object_unref (info);
        }
        g_file_enumerator_close (enumerator, job->cancellable, NULL);
        g_object_unref (enumerator);

        if (error && IS_IO_ERROR (error, CANCELLED)) {
            g_error_free (error);
        } else if (error) {
            gchar *dir_basename = files_file_utils_custom_basename_from_file (dir);
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
            response = marlin_file_operations_common_job_run_warning (
                job,
                primary,
                secondary,
                details,
                FALSE,
                CANCEL, _("_Skip files"),
                NULL);

            g_error_free (error);

            if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
                marlin_file_operations_common_job_abort_job (job);
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
        gchar *dir_basename = files_file_utils_custom_basename_from_file (dir);
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
        response = marlin_file_operations_common_job_run_warning (
            job,
            primary,
            secondary,
            details,
            FALSE,
            CANCEL, SKIP, RETRY,
            NULL);

        g_error_free (error);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            marlin_file_operations_common_job_abort_job (job);
        } else if (response == 1) {
            /* Skip: Do Nothing  */
            local_skipped_file = TRUE;
        } else if (response == 2) {
            goto retry;
        } else {
            g_assert_not_reached ();
        }
    }

    if (!marlin_file_operations_common_job_aborted (job) &&
        /* Don't delete dir if there was a skipped file */
        !local_skipped_file) {
        if (!g_file_delete (dir, job->cancellable, &error)) {
            gchar *dir_basename;
            if (job->skip_all_error) {
                goto skip;
            }

            primary = g_strdup (_("Error while deleting."));
            dir_basename = files_file_utils_custom_basename_from_file (dir);
            /// TRANSLATORS: %s is a placeholder for the basename of a file.  It may change position but must not be translated or removed
            secondary = g_strdup_printf (_("Could not remove the folder %s."), dir_basename);
            g_free (dir_basename);

            details = error->message;

            response = marlin_file_operations_common_job_run_warning (
                job,
                primary,
                secondary,
                details,
                (source_info->num_files - transfer_info->num_files) > 1,
                CANCEL, SKIP_ALL, SKIP,
                NULL);

            if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
                marlin_file_operations_common_job_abort_job (job);
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
            files_file_changes_queue_file_removed (dir);
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
delete_file (FilesFileOperationsDeleteJob *del_job, GFile *file,
             gboolean *skipped_file,
             SourceInfo *source_info,
             TransferInfo *transfer_info,
             gboolean toplevel)
{
    FilesFileOperationsCommonJob *job = MARLIN_FILE_OPERATIONS_COMMON_JOB (del_job);
    GError *error;
    char *primary, *secondary, *details;
    int response;

    if (marlin_file_operations_common_job_should_skip_file (job, file)) {
        *skipped_file = TRUE;
        return;
    }

    error = NULL;
    if (g_file_delete (file, job->cancellable, &error)) {
        files_file_changes_queue_file_removed (file);
        transfer_info->num_files ++;
        report_delete_progress (job, source_info, transfer_info);
        return;
    }

    if (IS_IO_ERROR (error, NOT_EMPTY)) {
        g_error_free (error);
        delete_dir (del_job, file,
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
        dir_basename = files_file_utils_custom_basename_from_file (file);
        /// TRANSLATORS: %s is a placeholder for the basename of a file.  It may change position but must not be translated or removed
        secondary = g_strdup_printf (_("There was an error deleting %s."), dir_basename);
        g_free (dir_basename);
        details = error->message;

        response = marlin_file_operations_common_job_run_warning (
            job,
            primary,
            secondary,
            details,
            (source_info->num_files - transfer_info->num_files) > 1,
            CANCEL, SKIP_ALL, SKIP,
            NULL);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            marlin_file_operations_common_job_abort_job (job);
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
report_delete_count_progress (FilesFileOperationsDeleteJob *job,
                              SourceInfo *source_info)
{
    FilesFileOperationsCommonJob *common = MARLIN_FILE_OPERATIONS_COMMON_JOB (job);
    char *s;
    gchar *num_bytes_format;

    num_bytes_format = g_format_size (source_info->num_bytes);
    /// TRANSLATORS: %'d is a placeholder for a number. It must not be translated or removed.
    /// %s is a placeholder for a size like "2 bytes" or "3 MB".  It must not be translated or removed.
    /// So this represents something like "Preparing to delete 100 files (200 MB)"
    /// The order in which %'d and %s appear can be changed by using the right positional specifier.
    s = g_strdup_printf (ngettext("Preparing to delete %'d file (%s)",
                                  "Preparing to delete %'d files (%s)",
                                  source_info->num_files),
                         source_info->num_files, num_bytes_format);
    g_free (num_bytes_format);
    pf_progress_info_take_details (common->progress, s);
    pf_progress_info_pulse_progress (common->progress);
}

static void
delete_files (FilesFileOperationsDeleteJob *del_job, GList *files, int *files_skipped)
{
    GList *l;
    GFile *file;
    SourceInfo source_info;
    TransferInfo transfer_info;
    gboolean skipped_file;
    FilesFileOperationsCommonJob *job = MARLIN_FILE_OPERATIONS_COMMON_JOB (del_job);

    if (marlin_file_operations_common_job_aborted (job)) {
        return;
    }

    scan_sources (files,
                  &source_info,
                  (CountProgressCallback) report_delete_count_progress,
                  job,
                  OP_KIND_DELETE);
    if (marlin_file_operations_common_job_aborted (job)) {
        return;
    }

    g_timer_start (job->time);

    memset (&transfer_info, 0, sizeof (transfer_info));
    report_delete_progress (job, &source_info, &transfer_info);

    for (l = files;
         l != NULL && !marlin_file_operations_common_job_aborted (job);
         l = l->next) {
        file = l->data;

        skipped_file = FALSE;
        delete_file (del_job, file,
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
report_trash_progress (FilesFileOperationsDeleteJob *del_job,
                       int files_trashed,
                       int total_files)
{
    FilesFileOperationsCommonJob *job = MARLIN_FILE_OPERATIONS_COMMON_JOB (del_job);
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
trash_files (FilesFileOperationsDeleteJob *del_job, GList *files, int *files_skipped)
{
    GList *l;
    GFile *file;
    GList *to_delete;
    GError *error;
    GFileInfo *info;
    GFileInfo *parent_info;
    GFileInfo *fsinfo;
    FilesFileOperationsCommonJob *job = MARLIN_FILE_OPERATIONS_COMMON_JOB (del_job);
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

    if (marlin_file_operations_common_job_aborted (job)) {
        return;
    }

    total_files = g_list_length (files);
    files_trashed = 0;

    report_trash_progress (del_job, files_trashed, total_files);

    to_delete = NULL;
    for (l = files;
         l != NULL && !marlin_file_operations_common_job_aborted (job);
         l = l->next) {
        file = l->data;

        error = NULL;
        if (!G_IS_FILE (file)) {
            (*files_skipped)++;
            goto skip;
        }

        mtime = files_file_utils_get_file_modification_time (file);

        if (!g_file_trash (file, job->cancellable, &error)) {
            if (job->skip_all_error) {
                (*files_skipped)++;
                goto skip;
            }

            if (del_job->delete_all) {
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
                primary = g_strdup (_("Cannot move file to trash. Try to delete it?"));
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
                response = marlin_file_operations_common_job_run_question (
                    job,
                    primary,
                    secondary,
                    details,
                    (total_files - files_trashed) > 1,
                    CANCEL, SKIP_ALL, SKIP, DELETE_ALL, DELETE,
                    NULL);
            } else {
                response = marlin_file_operations_common_job_run_question (
                    job,
                    primary,
                    secondary,
                    details,
                    (total_files - files_trashed) > 1,
                    CANCEL, SKIP_ALL, SKIP,
                    NULL);

            }

            if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
                del_job->user_cancel = TRUE;
                marlin_file_operations_common_job_abort_job (job);
            } else if (response == 1) { /* skip all */
                (*files_skipped)++;
                job->skip_all_error = TRUE;
            } else if (response == 2) { /* skip */
                (*files_skipped)++;
            } else if (response == 3) { /* delete all */
                to_delete = g_list_prepend (to_delete, file);
                del_job->delete_all = TRUE;
            } else if (response == 4) { /* delete */
                to_delete = g_list_prepend (to_delete, file);
            }

skip:
            g_error_free (error);
            total_files--;
        } else {
            files_file_changes_queue_file_removed (file);

            // Start UNDO-REDO
            files_undo_action_data_add_trashed_file (job->undo_redo_data, file, mtime);
            // End UNDO-REDO

            files_trashed++;
            report_trash_progress (del_job, files_trashed, total_files);
        }
    }

    if (to_delete) {
        to_delete = g_list_reverse (to_delete);
        delete_files (del_job, to_delete, files_skipped);
        g_list_free (to_delete);
    }
}

static void
delete_job (GTask *task,
            gpointer source_object,
            gpointer task_data,
            GCancellable *cancellable)
{
    FilesFileOperationsDeleteJob *job = task_data;
    GList *to_trash_files;
    GList *to_delete_files;
    GList *l;
    GFile *file;
    gboolean confirmed;
    FilesFileOperationsCommonJob *common = MARLIN_FILE_OPERATIONS_COMMON_JOB (job);
    gboolean must_confirm_delete_in_trash;
    gboolean must_confirm_delete;
    int files_skipped;
    int job_files;

    pf_progress_info_start (common->progress);

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
            confirmed = !should_confirm_trash () || marlin_file_operations_delete_job_confirm_delete_from_trash (job, to_delete_files);
        } else if (must_confirm_delete) {
            confirmed = marlin_file_operations_delete_job_confirm_delete_directly (job, to_delete_files);
        }

        if (confirmed) {
            delete_files (job, to_delete_files, &files_skipped);
        } else {
            job->user_cancel = TRUE;
        }
    }

    if (to_trash_files != NULL) {
        to_trash_files = g_list_reverse (to_trash_files);

        trash_files (job, to_trash_files, &files_skipped);
    }

    g_list_free (to_trash_files);
    g_list_free (to_delete_files);

    if (files_skipped == job_files) {
        /* User has skipped all files, report user cancel */
        job->user_cancel = TRUE;
    }

    g_task_return_boolean (task, TRUE);
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

    GTask *task;
    FilesFileOperationsDeleteJob *job;
    FilesFileOperationsCommonJob *common;

    /* TODO: special case desktop icon link files ... */

    job = marlin_file_operations_delete_job_new (parent_window, files, try_trash);
    common = MARLIN_FILE_OPERATIONS_COMMON_JOB (job);

    if (try_trash) {
        marlin_file_operations_common_job_inhibit_power_manager (common, _("Trashing Files"));
    } else {
        marlin_file_operations_common_job_inhibit_power_manager (common, _("Deleting Files"));
    }

    if (try_trash) {
        common->undo_redo_data = files_undo_action_data_new (MARLIN_UNDO_MOVETOTRASH, g_list_length(files));
        GFile* src_dir = g_file_get_parent (files->data);
        files_undo_action_data_set_src_dir (common->undo_redo_data, src_dir);
    }

    task = g_task_new (NULL, cancellable, callback, user_data);
    g_task_set_task_data (task, job, (GDestroyNotify) marlin_file_operations_common_job_unref);
    g_task_run_in_thread (task, delete_job);
    g_object_unref (task);
}

gboolean
marlin_file_operations_delete_finish (GAsyncResult  *result,
                                      GError       **error)
{
    g_return_val_if_fail (g_task_is_valid (result, NULL), FALSE);

    return g_task_propagate_boolean (G_TASK (result), error);
}

static void
report_copy_move_count_progress (FilesFileOperationsCopyMoveJob *job,
                                 SourceInfo *source_info)
{
    FilesFileOperationsCommonJob *common = MARLIN_FILE_OPERATIONS_COMMON_JOB (job);
    char *s;
    gchar *num_bytes_format;

    if (!job->is_move) {
        num_bytes_format = g_format_size (source_info->num_bytes);
        /// TRANSLATORS: %'d is a placeholder for a number. It must not be translated or removed.
        /// %s is a placeholder for a size like "2 bytes" or "3 MB".  It must not be translated or removed.
        /// So this represents something like "Preparing to copy 100 files (200 MB)"
        /// The order in which %'d and %s appear can be changed by using the right positional specifier.
        s = g_strdup_printf (ngettext("Preparing to copy %'d file (%s)",
                                      "Preparing to copy %'d files (%s)",
                                      source_info->num_files),
                             source_info->num_files, num_bytes_format);
    } else {
        num_bytes_format = g_format_size (source_info->num_bytes);
        /// TRANSLATORS: %'d is a placeholder for a number. It must not be translated or removed.
        /// %s is a placeholder for a size like "2 bytes" or "3 MB".  It must not be translated or removed.
        /// So this represents something like "Preparing to move 100 files (200 MB)"
        /// The order in which %'d and %s appear can be changed by using the right positional specifier.
        s = g_strdup_printf (ngettext("Preparing to move %'d file (%s)",
                                      "Preparing to move %'d files (%s)",
                                      source_info->num_files),
                             source_info->num_files, num_bytes_format);
    }

    g_free (num_bytes_format);
    pf_progress_info_take_details (common->progress, s);
    pf_progress_info_pulse_progress (common->progress);
}

static void
count_file (GFileInfo *info,
            FilesFileOperationsCommonJob *job,
            SourceInfo *source_info)
{
    source_info->num_files += 1;
    source_info->num_bytes += g_file_info_get_size (info);

    if (source_info->num_files_since_progress++ > 100) {
        source_info->count_callback (job, source_info);
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
    }
}

static void
scan_dir (GFile *dir,
          SourceInfo *source_info,
          FilesFileOperationsCommonJob *job,
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
            gchar *dir_basename = files_file_utils_custom_basename_from_file (dir);
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
            response = marlin_file_operations_common_job_run_warning (
                job,
                primary,
                secondary,
                details,
                FALSE,
                CANCEL, RETRY, SKIP,
                NULL);

            g_error_free (error);

            if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
                marlin_file_operations_common_job_abort_job (job);
            } else if (response == 1) {
                *source_info = saved_info;
                goto retry;
            } else if (response == 2) {
                marlin_file_operations_common_job_skip_readdir_error (job, dir);
            } else {
                g_assert_not_reached ();
            }
        }

    } else if (job->skip_all_error) {
        g_error_free (error);
        marlin_file_operations_common_job_skip_file (job, dir);
    } else if (IS_IO_ERROR (error, CANCELLED)) {
        g_error_free (error);
    } else {
        gchar *dir_basename = files_file_utils_custom_basename_from_file (dir);
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
        response = marlin_file_operations_common_job_run_warning (
            job,
            primary,
            secondary,
            details,
            TRUE,
            CANCEL, SKIP_ALL, SKIP, RETRY,
            NULL);

        g_error_free (error);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            marlin_file_operations_common_job_abort_job (job);
        } else if (response == 1 || response == 2) {
            if (response == 1) {
                job->skip_all_error = TRUE;
            }
            marlin_file_operations_common_job_skip_file (job, dir);
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
           FilesFileOperationsCommonJob *job)
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
        marlin_file_operations_common_job_skip_file (job, file);
    } else if (IS_IO_ERROR (error, CANCELLED)) {
        g_error_free (error);
    } else {
        gchar *file_basename = files_file_utils_custom_basename_from_file (file);
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
        response = marlin_file_operations_common_job_run_warning (
            job,
            primary,
            secondary,
            details,
            TRUE,
            CANCEL, SKIP_ALL, SKIP, RETRY,
            NULL);

        g_error_free (error);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            marlin_file_operations_common_job_abort_job (job);
        } else if (response == 1 || response == 2) {
            if (response == 1) {
                job->skip_all_error = TRUE;
            }
            marlin_file_operations_common_job_skip_file (job, file);
        } else if (response == 3) {
            goto retry;
        } else {
            g_assert_not_reached ();
        }
    }

    while (!marlin_file_operations_common_job_aborted (job) &&
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
              CountProgressCallback count_callback,
              FilesFileOperationsCommonJob *job,
              OpKind kind)
{
    GList *l;
    GFile *file;

    memset (source_info, 0, sizeof (SourceInfo));
    source_info->op = kind;
    source_info->count_callback = count_callback;
    source_info->count_callback (job, source_info);

    for (l = files; l != NULL && !marlin_file_operations_common_job_aborted (job); l = l->next) {
        file = l->data;

        scan_file (file,
                   source_info,
                   job);
    }

    /* Make sure we report the final count */
    source_info->count_callback (job, source_info);
}

static void
report_copy_progress (FilesFileOperationsCopyMoveJob *copy_job,
                      SourceInfo *source_info,
                      TransferInfo *transfer_info)
{
    FilesFileOperationsCommonJob *job = MARLIN_FILE_OPERATIONS_COMMON_JOB (copy_job);
    gboolean is_move = copy_job->is_move;
    int files_left;
    goffset total_size;
    double elapsed, transfer_rate;
    int remaining_time;
    guint64 now = g_thread_gettime ();
    gchar *s = NULL;
    gchar *srcname = NULL;
    gchar *destname = NULL;

    if (transfer_info->last_report_time != 0 &&
        ABS ((gint64)(transfer_info->last_report_time - now)) < 100 * NSEC_PER_MSEC) {
        return;
    }

    /* See https://github.com/elementary/files/issues/464. The job data may become invalid, possibly
     * due to a race. */
    if (!G_IS_FILE (copy_job->files->data) || ! G_IS_FILE (copy_job->destination)) {
        return;
    } else {
        srcname = files_file_utils_custom_basename_from_file ((GFile *)copy_job->files->data);
        destname = files_file_utils_custom_basename_from_file (copy_job->destination);
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
        formated_remaining_time = files_file_utils_format_time (remaining_time, &formated_time_unit);


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
                             transfer_rate_format); //FIXME Remove opaque hex
        g_free (num_bytes_format);
        g_free (total_size_format);
        g_free (formated_remaining_time);
        g_free (transfer_rate_format);
        pf_progress_info_take_details (job->progress, s);
    }

    pf_progress_info_update_progress (job->progress, transfer_info->num_bytes, total_size);
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
    gboolean is_link = FALSE;
    GFileInfo *info;
    GFile *dest = NULL;
    int max_length;

    if (!G_IS_FILE (src) || !G_IS_FILE (dest_dir)) {
        g_critical ("get_unique_target_file:  %s %s is not a file", !G_IS_FILE (src) ? "src" : "",  !G_IS_FILE (dest_dir) ? "dest" : "");
        return NULL;
    }

    max_length = files_file_utils_get_max_name_length (dest_dir);

    info = g_file_query_info (
        src,
        G_FILE_ATTRIBUTE_STANDARD_EDIT_NAME ","
        G_FILE_ATTRIBUTE_STANDARD_TYPE,
        G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS,
        NULL,
        NULL
    );

    if (info != NULL) {
        editname = g_file_info_get_attribute_string (info, G_FILE_ATTRIBUTE_STANDARD_EDIT_NAME);
        is_link = g_file_info_get_file_type (info) == G_FILE_TYPE_SYMBOLIC_LINK;

        if (editname != NULL) {
            /*TODO Pass correct info to "is_link" parameter*/
            new_name = files_file_utils_get_duplicate_name (editname, count, max_length, is_link);
            files_file_utils_make_file_name_valid_for_dest_fs (&new_name, dest_fs_type);
            dest = g_file_get_child_for_display_name (dest_dir, new_name, NULL);
            g_free (new_name);
        }

        g_object_unref (info);
    }

    if (dest == NULL) {
        basename = g_file_get_basename (src);

        if (g_utf8_validate (basename, -1, NULL)) {
            /*TODO Pass correct info to "is_link" parameter*/
            new_name = files_file_utils_get_duplicate_name (basename, count, max_length, is_link);
            files_file_utils_make_file_name_valid_for_dest_fs (&new_name, dest_fs_type);
            dest = g_file_get_child_for_display_name (dest_dir, new_name, NULL);
            g_free (new_name);
        }

        if (dest == NULL) {
            end = strrchr (basename, '.');
            if (end != NULL) {
                count += atoi (end + 1);
            }
            new_name = g_strdup_printf ("%s.%d", basename, count);
            files_file_utils_make_file_name_valid_for_dest_fs (&new_name, dest_fs_type);
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

    max_length = files_file_utils_get_max_name_length (dest_dir);

    dest = NULL;
    info = g_file_query_info (src,
                              G_FILE_ATTRIBUTE_STANDARD_EDIT_NAME,
                              0, NULL, NULL);
    if (info != NULL) {
        editname = g_file_info_get_attribute_string (info, G_FILE_ATTRIBUTE_STANDARD_EDIT_NAME);

        if (editname != NULL) {
            new_name = files_file_utils_get_link_name (editname, count, max_length);
            files_file_utils_make_file_name_valid_for_dest_fs (&new_name, dest_fs_type);
            dest = g_file_get_child_for_display_name (dest_dir, new_name, NULL);
            g_free (new_name);
        }

        g_object_unref (info);
    }

    if (dest == NULL) {
        basename = g_file_get_basename (src);
        files_file_utils_make_file_name_valid_for_dest_fs (&basename, dest_fs_type);

        if (g_utf8_validate (basename, -1, NULL)) {
            new_name = files_file_utils_get_link_name (basename, count, max_length);
            files_file_utils_make_file_name_valid_for_dest_fs (&new_name, dest_fs_type);
            dest = g_file_get_child_for_display_name (dest_dir, new_name, NULL);
            g_free (new_name);
        }

        if (dest == NULL) {
            if (count == 1) {
                new_name = g_strdup_printf ("%s.lnk", basename);
            } else {
                new_name = g_strdup_printf ("%s.lnk%d", basename, count);
            }
            files_file_utils_make_file_name_valid_for_dest_fs (&new_name, dest_fs_type);
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
                files_file_utils_make_file_name_valid_for_dest_fs (&copyname, dest_fs_type);
                dest = g_file_get_child_for_display_name (dest_dir, copyname, NULL);
                g_free (copyname);
            }

            g_object_unref (info);
        }
    }

    if (dest == NULL) {
        basename = g_file_get_basename (src);
        files_file_utils_make_file_name_valid_for_dest_fs (&basename, dest_fs_type);
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

static void copy_move_file (FilesFileOperationsCopyMoveJob *job,
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
create_dest_dir (FilesFileOperationsCommonJob *job,
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

        response = marlin_file_operations_common_job_run_warning (
            job,
            primary,
            secondary,
            details,
            FALSE,
            CANCEL, SKIP, RETRY,
            NULL);

        g_error_free (error);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            marlin_file_operations_common_job_abort_job (job);
        } else if (response == 1) {
            /* Skip: Do Nothing  */
        } else if (response == 2) {
            goto retry;
        } else {
            g_assert_not_reached ();
        }
        return CREATE_DEST_DIR_FAILED;
    }

    files_file_changes_queue_file_added (*dest, TRUE);

    // Start UNDO-REDO
    files_undo_action_data_add_origin_target_pair (job->undo_redo_data, src, *dest);
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
copy_move_directory (FilesFileOperationsCopyMoveJob *copy_job,
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
    FilesFileOperationsCommonJob *job = MARLIN_FILE_OPERATIONS_COMMON_JOB (copy_job);
    GFileCopyFlags flags;

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

    skip_error = marlin_file_operations_common_job_should_skip_readdir_error (job, src);
retry:
    error = NULL;
    enumerator = g_file_enumerate_children (src,
                                            G_FILE_ATTRIBUTE_STANDARD_NAME,
                                            G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS,
                                            job->cancellable,
                                            &error);
    if (enumerator) {
        error = NULL;

        while (!marlin_file_operations_common_job_aborted (job) &&
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
            response = marlin_file_operations_common_job_run_warning (
                job,
                primary,
                secondary,
                details,
                FALSE,
                CANCEL, _("_Skip files"),
                NULL);

            g_error_free (error);

            if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
                marlin_file_operations_common_job_abort_job (job);
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
        response = marlin_file_operations_common_job_run_warning (
            job,
            primary,
            secondary,
            details,
            FALSE,
            CANCEL, SKIP, RETRY,
            NULL);

        g_error_free (error);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            marlin_file_operations_common_job_abort_job (job);
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

    if (!marlin_file_operations_common_job_aborted (job) && copy_job->is_move &&
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

            response = marlin_file_operations_common_job_run_warning (
                job,
                primary,
                secondary,
                details,
                (source_info->num_files - transfer_info->num_files) > 1,
                CANCEL, SKIP_ALL, SKIP,
                NULL);

            if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
                marlin_file_operations_common_job_abort_job (job);
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
remove_target_recursively (FilesFileOperationsCommonJob *job,
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

        while (!marlin_file_operations_common_job_aborted (job) &&
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
        response = marlin_file_operations_common_job_run_warning (
            job,
            primary,
            secondary,
            details,
            TRUE,
            CANCEL, SKIP_ALL, SKIP,
            NULL);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            marlin_file_operations_common_job_abort_job (job);
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
        response = marlin_file_operations_common_job_run_warning (
            job,
            primary,
            secondary,
            details,
            TRUE,
            CANCEL, SKIP_ALL, SKIP,
            NULL);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            marlin_file_operations_common_job_abort_job (job);
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
    files_file_changes_queue_file_removed (file);

    return TRUE;

}

typedef struct {
    FilesFileOperationsCopyMoveJob *job;
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
copy_move_file (FilesFileOperationsCopyMoveJob *copy_job,
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
    FilesFileOperationsCommonJob *job = MARLIN_FILE_OPERATIONS_COMMON_JOB (copy_job);
    gboolean res;
    int unique_name_nr;
    gboolean handled_invalid_filename;

    if (marlin_file_operations_common_job_should_skip_file (job, src)) {
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

        /*  the marlin_file_operations_common_job_run_warning() frees all strings passed in automatically  */
        primary = copy_job->is_move ? g_strdup (_("You cannot move a folder into itself."))
            : g_strdup (_("You cannot copy a folder into itself."));
        secondary = g_strdup (_("The destination folder is inside the source folder."));

        response = marlin_file_operations_common_job_run_warning (
            job,
            primary,
            secondary,
            NULL,
            (source_info->num_files - transfer_info->num_files) > 1,
            CANCEL, SKIP_ALL, SKIP,
            NULL);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            marlin_file_operations_common_job_abort_job (job);
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

        /*  the marlin_file_operations_common_job_run_warning() frees all strings passed in automatically  */
        primary = copy_job->is_move ? g_strdup (_("You cannot move a file over itself."))
            : g_strdup (_("You cannot copy a file over itself."));
        secondary = g_strdup (_("The source file would be overwritten by the destination."));

        response = marlin_file_operations_common_job_run_warning (
            job,
            primary,
            secondary,
            NULL,
            (source_info->num_files - transfer_info->num_files) > 1,
            CANCEL, SKIP_ALL, SKIP,
            NULL);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            marlin_file_operations_common_job_abort_job (job);
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
                //files_file_changes_queue_schedule_position_set (dest, *position, job->screen_num);
            } else {
                //files_file_changes_queue_schedule_position_remove (dest);
            }*/

            g_hash_table_replace (debuting_files, g_object_ref (dest), GINT_TO_POINTER (TRUE));
        }
        if (copy_job->is_move) {
            files_file_changes_queue_file_moved (src, dest);
        } else {
           files_file_changes_queue_file_added (dest, TRUE);
        }

        // Start UNDO-REDO
        files_undo_action_data_add_origin_target_pair (job->undo_redo_data, src, dest);
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
        gboolean apply_to_all;
        gchar *new_name;
        gint response;

        g_error_free (error);

        if (unique_names) {
            g_object_unref (dest);
            dest = get_unique_target_file (src, dest_dir, same_fs, *dest_fs_type, unique_name_nr++);
            goto retry;
        }

        is_merge = FALSE;

        if (files_file_utils_file_is_dir (dest) && files_file_utils_file_is_dir (src)) {
            is_merge = TRUE;
        }

        if ((is_merge && copy_job->merge_all) ||
            (!is_merge && copy_job->replace_all)) {
            overwrite = TRUE;
            goto retry;
        }

        if (copy_job->skip_all_conflict) {
            goto out;
        }

        if (copy_job->keep_all_newest) {
            if (files_file_utils_compare_modification_dates (src, dest) < 1) {
                goto out;
            } else {
                overwrite = TRUE;
                goto retry;
            }
        }

        response = marlin_file_operations_common_job_run_conflict_dialog (
            job, src, dest, dest_dir, &new_name, &apply_to_all);

        if (response == GTK_RESPONSE_CANCEL ||
            response == GTK_RESPONSE_DELETE_EVENT) {
            g_clear_pointer (&new_name, g_free);
            marlin_file_operations_common_job_abort_job (job);
            goto out;
        }

        if (response == FILES_FILE_CONFLICT_DIALOG_RESPONSE_TYPE_SKIP) {
            if (apply_to_all) {
                copy_job->skip_all_conflict = TRUE;
            }

            g_clear_pointer (&new_name, g_free);
        } else if (response == FILES_FILE_CONFLICT_DIALOG_RESPONSE_TYPE_REPLACE ||
                   response == FILES_FILE_CONFLICT_DIALOG_RESPONSE_TYPE_NEWEST) { /* merge/replace/newest */
            if (apply_to_all) {
                if (is_merge) {
                    copy_job->merge_all = TRUE;
                } else if (response == FILES_FILE_CONFLICT_DIALOG_RESPONSE_TYPE_NEWEST) {
                    copy_job->keep_all_newest = TRUE;
                } else {
                    copy_job->replace_all = TRUE;
                }
            }
            overwrite = TRUE;

            gboolean keep_dest;
            keep_dest = response == FILES_FILE_CONFLICT_DIALOG_RESPONSE_TYPE_NEWEST &&
                        files_file_utils_compare_modification_dates (src, dest) < 1;

            g_clear_pointer (&new_name, g_free);
            if (keep_dest) { /* destination is newer than source */
                goto out;/* Skip this one */
            } else {
                goto retry; /* Overwrite conflicting destination file */
            }
        } else if (response == FILES_FILE_CONFLICT_DIALOG_RESPONSE_TYPE_RENAME) {
            g_object_unref (dest);
            dest = get_target_file_for_display_name (dest_dir, new_name);
            g_clear_pointer (&new_name, g_free);
            goto retry;
        } else {
            /* Failsafe rather than crash */
            g_clear_pointer (&new_name, g_free);
            marlin_file_operations_common_job_abort_job (job);
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
                response = marlin_file_operations_common_job_run_warning (
                    job,
                    primary,
                    secondary,
                    details,
                    TRUE,
                    CANCEL, SKIP_ALL, SKIP,
                    NULL);

                g_error_free (error);

                if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
                    marlin_file_operations_common_job_abort_job (job);
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
            files_file_changes_queue_file_removed (dest);
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

        src_basename = files_file_utils_custom_basename_from_file (src);
        /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
        /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
        primary = g_strdup_printf (_("Cannot copy \"%s\" here."), src_basename);
        g_free (src_basename);

        dest_basename = files_file_utils_custom_basename_from_file (dest_dir);
        /// TRANSLATORS: %s is a placeholder for the basename of a file.  It may change position but must not be translated or removed
        secondary = g_strdup_printf (_("There was an error copying the file into %s."), dest_basename);
        g_free (dest_basename);
        details = error->message;

        response = marlin_file_operations_common_job_run_warning (
            job,
            primary,
            secondary,
            details,
            (source_info->num_files - transfer_info->num_files) > 1,
            CANCEL, SKIP_ALL, SKIP,
            NULL);

        g_error_free (error);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            marlin_file_operations_common_job_abort_job (job);
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
copy_files (FilesFileOperationsCopyMoveJob *job,
            const char *dest_fs_id,
            SourceInfo *source_info,
            TransferInfo *transfer_info)
{
    FilesFileOperationsCommonJob *common = MARLIN_FILE_OPERATIONS_COMMON_JOB (job);
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
         l != NULL && !marlin_file_operations_common_job_aborted (common);
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
                            &dest_fs_type,  //dest_fs_type always null?
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

static void
copy_job (GTask *task,
          gpointer source_object,
          gpointer task_data,
          GCancellable *cancellable)
{
    FilesFileOperationsCopyMoveJob *job = task_data;
    FilesFileOperationsCommonJob *common = MARLIN_FILE_OPERATIONS_COMMON_JOB (job);
    SourceInfo source_info;
    TransferInfo transfer_info;
    char *dest_fs_id = NULL;
    GFile *dest;

    pf_progress_info_start (common->progress);
    scan_sources (job->files,
                  &source_info,
                  (CountProgressCallback) report_copy_move_count_progress,
                  common,
                  OP_KIND_COPY);
    if (marlin_file_operations_common_job_aborted (common)) {
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

    marlin_file_operations_common_job_verify_destination (common,
                                                          dest,
                                                          &dest_fs_id,
                                                          source_info.num_bytes);
    g_object_unref (dest);
    if (marlin_file_operations_common_job_aborted (common)) {
        goto aborted;
    }

    g_timer_start (common->time);

    memset (&transfer_info, 0, sizeof (transfer_info));
    copy_files (job,
                dest_fs_id,
                &source_info, &transfer_info);

aborted:

    g_free (dest_fs_id);

    g_task_return_boolean (task, TRUE);
}

static void
marlin_file_operations_copy (GList               *files,
                             GFile               *target_dir,
                             GtkWindow           *parent_window,
                             GCancellable        *cancellable,
                             GAsyncReadyCallback  callback,
                             gpointer             user_data)
{
    GTask *task;
    FilesFileOperationsCopyMoveJob *job;
    FilesFileOperationsCommonJob *common;

    job = marlin_file_operations_copy_move_job_new (parent_window, files, target_dir);
    common = MARLIN_FILE_OPERATIONS_COMMON_JOB (job);

    marlin_file_operations_common_job_inhibit_power_manager (common, _("Copying Files"));

    // Start UNDO-REDO
    common->undo_redo_data = files_undo_action_data_new (MARLIN_UNDO_COPY, g_list_length(files));
    GFile* src_dir = g_file_get_parent (files->data);
    files_undo_action_data_set_src_dir (common->undo_redo_data, src_dir);
    g_object_ref (target_dir);
    files_undo_action_data_set_dest_dir (common->undo_redo_data, target_dir);
    // End UNDO-REDO

    task = g_task_new (NULL, cancellable, callback, user_data);
    g_task_set_task_data (task, job, (GDestroyNotify) marlin_file_operations_common_job_unref);
    g_task_run_in_thread (task, copy_job);
    g_object_unref (task);
}

static gboolean
marlin_file_operations_copy_finish (GAsyncResult  *result,
                                    GError       **error)
{
    g_return_val_if_fail (g_task_is_valid (result, NULL), FALSE);

    return g_task_propagate_boolean (G_TASK (result), error);
}

static void
report_move_progress (FilesFileOperationsCopyMoveJob *move_job, int total, int left)
{
    FilesFileOperationsCommonJob *job = MARLIN_FILE_OPERATIONS_COMMON_JOB (move_job);
    gchar *s, *dest_basename;

    dest_basename = files_file_utils_custom_basename_from_file (move_job->destination);
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
move_file_prepare (FilesFileOperationsCopyMoveJob *move_job,
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
    FilesFileOperationsCommonJob *job = MARLIN_FILE_OPERATIONS_COMMON_JOB (move_job);
    gboolean overwrite = FALSE;
    char *primary, *secondary, *details;
    int response;
    GFileCopyFlags flags;
    MoveFileCopyFallback *fallback;
    gboolean handled_invalid_filename= *dest_fs_type != NULL;

    dest = get_target_file (src, dest_dir, *dest_fs_type, same_fs);


    /* Don't allow recursive move/copy into itself.
     * (We would get a file system error if we proceeded but it is nicer to
     * detect and report it at this level) */
    if (test_dir_is_parent (dest_dir, src)) {
        if (job->skip_all_error) {
            goto out;
        }

        /*  the marlin_file_operations_common_job_run_warning() frees all strings passed in automatically  */
        primary = move_job->is_move ? g_strdup (_("You cannot move a folder into itself."))
            : g_strdup (_("You cannot copy a folder into itself."));
        secondary = g_strdup (_("The destination folder is inside the source folder."));

        response = marlin_file_operations_common_job_run_warning (
            job,
            primary,
            secondary,
            NULL,
            files_left > 1,
            CANCEL, SKIP_ALL, SKIP,
            NULL);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            marlin_file_operations_common_job_abort_job (job);
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

        files_file_changes_queue_file_moved (src, dest);

        /*if (position) {
            //files_file_changes_queue_schedule_position_set (dest, *position, job->screen_num);
        } else {
            files_file_changes_queue_schedule_position_remove (dest);
        }*/

        // Start UNDO-REDO
        files_undo_action_data_add_origin_target_pair (job->undo_redo_data, src, dest);
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
        gchar *new_name;
        gboolean apply_to_all;

        g_error_free (error);

        is_merge = FALSE;
        if (files_file_utils_file_is_dir (dest) && files_file_utils_file_is_dir (src)) {
            is_merge = TRUE;
        }

        if ((is_merge && move_job->merge_all) ||
            (!is_merge && move_job->replace_all)) {
            overwrite = TRUE;
            goto retry;
        }

        if (move_job->skip_all_conflict) {
            goto out;
        }

        response = marlin_file_operations_common_job_run_conflict_dialog (job, src, dest, dest_dir, &new_name, &apply_to_all);

        if (response == GTK_RESPONSE_CANCEL ||
            response == GTK_RESPONSE_DELETE_EVENT) {
            marlin_file_operations_common_job_abort_job (job);
            g_clear_pointer (&new_name, g_free);
            goto out;
        } else if (response == FILES_FILE_CONFLICT_DIALOG_RESPONSE_TYPE_SKIP) {
            if (apply_to_all) {
                move_job->skip_all_conflict = TRUE;
            }
            g_clear_pointer (&new_name, g_free);
        } else if (response == FILES_FILE_CONFLICT_DIALOG_RESPONSE_TYPE_REPLACE ||
                   response == FILES_FILE_CONFLICT_DIALOG_RESPONSE_TYPE_NEWEST) { /* merge/replace/newest */

            if (response == FILES_FILE_CONFLICT_DIALOG_RESPONSE_TYPE_NEWEST &&
                files_file_utils_compare_modification_dates (src, dest) < 1) { /* destination not olderZ */

                g_clear_pointer (&new_name, g_free);
                goto out;/* Skip this one */
            }

            if (apply_to_all) {
                if (is_merge) {
                    move_job->merge_all = TRUE;
                } else {
                    move_job->replace_all = TRUE;
                }
            }

            overwrite = TRUE;
            g_clear_pointer (&new_name, g_free);
            goto retry;
        } else if (response == FILES_FILE_CONFLICT_DIALOG_RESPONSE_TYPE_RENAME) {
            g_object_unref (dest);
            dest = get_target_file_for_display_name (dest_dir, new_name);
            g_clear_pointer (&new_name, g_free);
            goto retry;
        } else {
            /* Failsafe rather than crash */
            g_clear_pointer (&new_name, g_free);
            marlin_file_operations_common_job_abort_job (job);
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

        response = marlin_file_operations_common_job_run_warning (
            job,
            primary,
            secondary,
            details,
            files_left > 1,
            CANCEL, SKIP_ALL, SKIP,
            NULL);

        g_error_free (error);

        if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
            marlin_file_operations_common_job_abort_job (job);
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
move_files_prepare (FilesFileOperationsCopyMoveJob *job,
                    const char *dest_fs_id,
                    char **dest_fs_type,
                    GList **fallbacks)
{
    FilesFileOperationsCommonJob *common = MARLIN_FILE_OPERATIONS_COMMON_JOB (job);
    GList *l;
    GFile *src;
    gboolean same_fs;
    int i;
    int total, left;

    total = left = g_list_length (job->files);

    report_move_progress (job, total, left);

    i = 0;
    for (l = job->files;
         l != NULL && !marlin_file_operations_common_job_aborted (common);
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
move_files (FilesFileOperationsCopyMoveJob *job,
            GList *fallbacks,
            const char *dest_fs_id,
            char **dest_fs_type,
            SourceInfo *source_info,
            TransferInfo *transfer_info)
{
    FilesFileOperationsCommonJob *common = MARLIN_FILE_OPERATIONS_COMMON_JOB (job);
    GList *l;
    GFile *src;
    gboolean same_fs;
    int i;
    gboolean skipped_file;
    MoveFileCopyFallback *fallback;

    report_copy_progress (job, source_info, transfer_info);

    i = 0;
    for (l = fallbacks;
         l != NULL && !marlin_file_operations_common_job_aborted (common);
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

static void
move_job (GTask *task,
          gpointer source_object,
          gpointer task_data,
          GCancellable *cancellable)
{
    FilesFileOperationsCopyMoveJob *job = task_data;
    FilesFileOperationsCommonJob *common = MARLIN_FILE_OPERATIONS_COMMON_JOB (job);
    GList *fallbacks = NULL;
    SourceInfo source_info;
    TransferInfo transfer_info;
    char *dest_fs_id = NULL;
    char *dest_fs_type = NULL;
    GList *fallback_files;

    pf_progress_info_start (common->progress);
    marlin_file_operations_common_job_verify_destination (common,
                                                          job->destination,
                                                          &dest_fs_id,
                                                          -1);
    if (marlin_file_operations_common_job_aborted (common)) {
        goto aborted;
    }

    /* This moves all files that we can do without copy + delete */
    move_files_prepare (job, dest_fs_id, &dest_fs_type, &fallbacks);
    if (marlin_file_operations_common_job_aborted (common)) {
        goto aborted;
    }

    /* The rest we need to do deep copy + delete behind on,
       so scan for size */

    fallback_files = get_files_from_fallbacks (fallbacks);
    scan_sources (fallback_files,
                  &source_info,
                  (CountProgressCallback) report_copy_move_count_progress,
                  common,
                  OP_KIND_MOVE);

    g_list_free (fallback_files);

    if (marlin_file_operations_common_job_aborted (common)) {
        goto aborted;
    }

    marlin_file_operations_common_job_verify_destination (common,
                                                          job->destination,
                                                          NULL,
                                                          source_info.num_bytes);
    if (marlin_file_operations_common_job_aborted (common)) {
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

    g_task_return_boolean (task, TRUE);
}

static void
marlin_file_operations_move (GList               *files,
                             GFile               *target_dir,
                             GtkWindow           *parent_window,
                             GCancellable        *cancellable,
                             GAsyncReadyCallback  callback,
                             gpointer             user_data)
{
    GTask *task;
    FilesFileOperationsCopyMoveJob *job;
    FilesFileOperationsCommonJob *common;

    job = marlin_file_operations_copy_move_job_new_move (parent_window, files, target_dir);
    common = MARLIN_FILE_OPERATIONS_COMMON_JOB (job);

    marlin_file_operations_common_job_inhibit_power_manager (common, _("Moving Files"));
    // Start UNDO-REDO
    if (g_file_has_uri_scheme (g_list_first(files)->data, "trash")) {
        common->undo_redo_data = files_undo_action_data_new (MARLIN_UNDO_RESTOREFROMTRASH, g_list_length(files));
    } else {
        common->undo_redo_data = files_undo_action_data_new (MARLIN_UNDO_MOVE, g_list_length(files));
    }
    GFile* src_dir = g_file_get_parent (files->data);
    files_undo_action_data_set_src_dir (common->undo_redo_data, src_dir);
    g_object_ref (target_dir);
    files_undo_action_data_set_dest_dir (common->undo_redo_data, target_dir);
    // End UNDO-REDO

    task = g_task_new (NULL, cancellable, callback, user_data);
    g_task_set_task_data (task, job, (GDestroyNotify) marlin_file_operations_common_job_unref);
    g_task_run_in_thread (task, move_job);
    g_object_unref (task);
}

static gboolean
marlin_file_operations_move_finish (GAsyncResult  *result,
                                    GError       **error)
{
    g_return_val_if_fail (g_task_is_valid (result, NULL), FALSE);

    return g_task_propagate_boolean (G_TASK (result), error);
}

static void
report_link_progress (FilesFileOperationsCopyMoveJob *link_job, int total, int left)
{
    FilesFileOperationsCommonJob *job = MARLIN_FILE_OPERATIONS_COMMON_JOB (link_job);
    gchar *s;
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

static void
link_file (FilesFileOperationsCopyMoveJob *job,
           GFile *src, GFile *dest_dir,
           char **dest_fs_type,
           GHashTable *debuting_files,
           int files_left)
{
    GFile *src_dir, *dest, *new_dest;
    int count = 0;
    char *path;
    gboolean not_local;
    GError *error;
    FilesFileOperationsCommonJob *common = MARLIN_FILE_OPERATIONS_COMMON_JOB (job);
    char *primary, *secondary, *details;
    int response;
    gboolean handled_invalid_filename;

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

    path = files_file_utils_get_path_for_symlink (src);

    if (path == NULL) {
        not_local = TRUE;
    }

    if (!not_local && g_file_make_symbolic_link (dest,
                                          path,
                                          common->cancellable,
                                          &error)) {

        // Start UNDO-REDO
        files_undo_action_data_add_origin_target_pair (common->undo_redo_data, src, dest);
        // End UNDO-REDO

        g_free (path);

        if (debuting_files) {
            g_hash_table_replace (debuting_files, g_object_ref (dest), GINT_TO_POINTER (TRUE));
        }
       files_file_changes_queue_file_added (dest, TRUE);

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
        src_basename = files_file_utils_custom_basename_from_file (src);
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

        response = marlin_file_operations_common_job_run_warning (
            common,
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
            marlin_file_operations_common_job_abort_job (common);
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

static void
link_job (GTask *task,
          gpointer source_object,
          gpointer task_data,
          GCancellable *cancellable)
{
    FilesFileOperationsCopyMoveJob *job = task_data;
    FilesFileOperationsCommonJob *common = MARLIN_FILE_OPERATIONS_COMMON_JOB (job);
    GFile *src;
    char *dest_fs_type = NULL;
    int total, left;
    int i;
    GList *l;

    pf_progress_info_start (common->progress);
    marlin_file_operations_common_job_verify_destination (common,
                                                          job->destination,
                                                          NULL,
                                                          -1);
    if (marlin_file_operations_common_job_aborted (common)) {
        goto aborted;
    }

    total = left = g_list_length (job->files);

    report_link_progress (job, total, left);

    i = 0;
    for (l = job->files;
         l != NULL && !marlin_file_operations_common_job_aborted (common);
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

    g_task_return_boolean (task, TRUE);
}

static void
marlin_file_operations_link (GList               *files,
                             GFile               *target_dir,
                             GtkWindow           *parent_window,
                             GCancellable        *cancellable,
                             GAsyncReadyCallback  callback,
                             gpointer             user_data)
{
    GTask *task;
    FilesFileOperationsCopyMoveJob *job;
    FilesFileOperationsCommonJob *common;

    job = marlin_file_operations_copy_move_job_new (parent_window, files, target_dir);
    common = MARLIN_FILE_OPERATIONS_COMMON_JOB (job);

    // Start UNDO-REDO
    common->undo_redo_data = files_undo_action_data_new (MARLIN_UNDO_CREATELINK, g_list_length(files));
    GFile* src_dir = g_file_get_parent (files->data);
    files_undo_action_data_set_src_dir (common->undo_redo_data, src_dir);
    g_object_ref (target_dir);
    files_undo_action_data_set_dest_dir (common->undo_redo_data, target_dir);
    // End UNDO-REDO

    task = g_task_new (NULL, cancellable, callback, user_data);
    g_task_set_task_data (task, job, (GDestroyNotify) marlin_file_operations_common_job_unref);
    g_task_run_in_thread (task, link_job);
    g_object_unref (task);
}

static gboolean
marlin_file_operations_link_finish (GAsyncResult  *result,
                                    GError       **error)
{
    g_return_val_if_fail (g_task_is_valid (result, NULL), FALSE);

    return g_task_propagate_boolean (G_TASK (result), error);
}

static void
marlin_file_operations_duplicate (GList               *files,
                                  GtkWindow           *parent_window,
                                  GCancellable        *cancellable,
                                  GAsyncReadyCallback  callback,
                                  gpointer             user_data)
{
    GTask *task;
    FilesFileOperationsCopyMoveJob *job;
    FilesFileOperationsCommonJob *common;

    job = marlin_file_operations_copy_move_job_new (parent_window, files, NULL);
    common = MARLIN_FILE_OPERATIONS_COMMON_JOB (job);

    // Start UNDO-REDO
    common->undo_redo_data = files_undo_action_data_new (MARLIN_UNDO_DUPLICATE, g_list_length(files));
    GFile* src_dir = g_file_get_parent (files->data);
    files_undo_action_data_set_src_dir (common->undo_redo_data, src_dir);
    g_object_ref (src_dir);
    files_undo_action_data_set_dest_dir (common->undo_redo_data, src_dir);
    // End UNDO-REDO

    task = g_task_new (NULL, cancellable, callback, user_data);
    g_task_set_task_data (task, job, (GDestroyNotify) marlin_file_operations_common_job_unref);
    g_task_run_in_thread (task, copy_job);
    g_object_unref (task);
}

static gboolean
marlin_file_operations_duplicate_finish (GAsyncResult  *result,
                                         GError       **error)
{
    g_return_val_if_fail (g_task_is_valid (result, NULL), FALSE);

    return g_task_propagate_boolean (G_TASK (result), error);
}

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
    if (g_list_length (files) == 0) {
        g_task_return_new_error (task,
                                 G_IO_ERROR,
                                 G_IO_ERROR_FAILED,
                                 "%s", _("Zero files to process"));
        g_clear_object (&task);
        return;
    }

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
                                     _("It is not permitted to copy files into the trash"));
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
    g_return_val_if_fail (g_task_is_valid (result, NULL), FALSE);

    return g_task_propagate_boolean (G_TASK (result), error);
}

static void
create_job (GTask *task,
            gpointer source_object,
            gpointer task_data,
            GCancellable *cancellable)
{
    FilesFileOperationsCreateJob *job = task_data;
    FilesFileOperationsCommonJob *common = MARLIN_FILE_OPERATIONS_COMMON_JOB (job);
    int count;
    GFile *dest;
    char *filename, *filename2, *new_filename;
    char *dest_fs_type;
    GError *error;
    gboolean res;
    gboolean filename_is_utf8;
    char *primary, *secondary, *details;
    int response;
    guint8 *data;
    int length;
    GFileOutputStream *out;
    gboolean handled_invalid_filename;
    int max_length;

    pf_progress_info_start (common->progress);

    handled_invalid_filename = FALSE;

    dest_fs_type = NULL;
    filename = NULL;
    dest = NULL;

    max_length = files_file_utils_get_max_name_length (job->dest_dir);

    marlin_file_operations_common_job_verify_destination (common,
                                                          job->dest_dir,
                                                          NULL, -1);
    if (marlin_file_operations_common_job_aborted (common)) {
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

    files_file_utils_make_file_name_valid_for_dest_fs (&filename, dest_fs_type); //FIXME No point - dest_fs_type always null?
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
            files_undo_action_data_set_create_data(common->undo_redo_data,
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
                files_undo_action_data_set_create_data(common->undo_redo_data,
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
                        files_undo_action_data_set_create_data(common->undo_redo_data,
                                                                 g_file_get_uri(dest),
                                                                 g_memdup(data, length));
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
       files_file_changes_queue_file_added (dest, TRUE);
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
                    new_filename = files_file_utils_shorten_utf8_string (filename2, strlen (filename2) - max_length);
                }

                if (new_filename == NULL) {
                    new_filename = g_strdup (filename2);
                }

                g_free (filename2);
            } else {
                /*We are not creating link*/
                new_filename = files_file_utils_get_duplicate_name (filename, count, max_length, FALSE);
            }

            if (files_file_utils_make_file_name_valid_for_dest_fs (&new_filename, dest_fs_type)) {
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
                    new_filename = files_file_utils_shorten_utf8_string (filename2, strlen (filename2) - max_length);
                    if (new_filename != NULL) {
                        g_free (filename2);
                        filename2 = new_filename;
                    }
                }
            } else {
                /*We are not creating link*/
                filename2 = files_file_utils_get_duplicate_name (filename, count++, max_length, FALSE);
            }
            files_file_utils_make_file_name_valid_for_dest_fs (&filename2, dest_fs_type);
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
            gchar *dest_basename = files_file_utils_custom_basename_from_file (dest);
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

            response = marlin_file_operations_common_job_run_warning (
                common,
                primary,
                secondary,
                details,
                FALSE,
                CANCEL, SKIP,
                NULL);

            g_error_free (error);

            if (response == 0 || response == GTK_RESPONSE_DELETE_EVENT) {
                marlin_file_operations_common_job_abort_job (common);
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
    g_task_return_pointer (task, g_steal_pointer (&job->created_file), g_object_unref);
}

void
marlin_file_operations_new_folder (GtkWidget           *parent_view,
                                   GFile               *parent_dir,
                                   GCancellable        *cancellable,
                                   GAsyncReadyCallback  callback,
                                   gpointer             user_data)
{
    GTask *task;
    FilesFileOperationsCreateJob *job;
    GtkWindow *parent_window;

    parent_window = NULL;
    if (parent_view) {
        parent_window = (GtkWindow *)gtk_widget_get_ancestor (parent_view, GTK_TYPE_WINDOW);
    }

    job = marlin_file_operations_create_job_new_folder (parent_window, parent_dir);

    task = g_task_new (NULL, cancellable, callback, user_data);
    g_task_set_task_data (task, job, (GDestroyNotify) marlin_file_operations_common_job_unref);
    g_task_run_in_thread (task, create_job);
    g_object_unref (task);
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
    GTask *task;
    FilesFileOperationsCreateJob *job;
    GtkWindow *parent_window = NULL;

    if (parent_view) {
        parent_window = (GtkWindow *)gtk_widget_get_ancestor (parent_view, GTK_TYPE_WINDOW);
    }

    job = marlin_file_operations_create_job_new_file_from_template (parent_window,
                                                                    parent_dir,
                                                                    target_filename,
                                                                    template);

    task = g_task_new (NULL, cancellable, callback, user_data);
    g_task_set_task_data (task, job, (GDestroyNotify) marlin_file_operations_common_job_unref);
    g_task_run_in_thread (task, create_job);
    g_object_unref (task);
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
    GTask *task;
    FilesFileOperationsCreateJob *job;
    GtkWindow *parent_window = NULL;

    if (parent_view) {
        parent_window = (GtkWindow *)gtk_widget_get_ancestor (parent_view, GTK_TYPE_WINDOW);
    }

    GFile *dest_dir = g_file_new_for_uri (parent_dir);
    job = marlin_file_operations_create_job_new_file (parent_window,
                                                      dest_dir,
                                                      target_filename,
                                                      (guint8 *)initial_contents,
                                                      length);
    g_object_unref (dest_dir);

    task = g_task_new (NULL, cancellable, callback, user_data);
    g_task_set_task_data (task, job, (GDestroyNotify) marlin_file_operations_common_job_unref);
    g_task_run_in_thread (task, create_job);
    g_object_unref (task);
}

GFile *
marlin_file_operations_new_file_finish (GAsyncResult  *result,
                                        GError       **error)
{
    g_return_val_if_fail (g_task_is_valid (result, NULL), NULL);

    return g_task_propagate_pointer (G_TASK (result), error);
}
