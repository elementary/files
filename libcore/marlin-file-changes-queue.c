/*
 * Copyright (C) 1999, 2000, 2001 Eazel, Inc.
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
 * Author: Pavel Cisler <pavel@eazel.com>
 */

#include "marlin-file-changes-queue.h"
#include "pantheon-files-core.h"

typedef enum {
    CHANGE_FILE_INITIAL,
    CHANGE_FILE_ADDED,
    CHANGE_FILE_CHANGED,
    CHANGE_FILE_REMOVED,
    CHANGE_FILE_MOVED
} MarlinFileChangeKind;

typedef struct {
    MarlinFileChangeKind kind;
    GFile *from;
    GFile *to;
    GdkPoint point;
    int screen;
} MarlinFileChange;

typedef struct {
    GList *head;
    GList *tail;
    GMutex mutex;
} MarlinFileChangesQueue;

static MarlinFileChangesQueue *
marlin_file_changes_queue_new (void)
{
    MarlinFileChangesQueue *result;

    result = g_new0 (MarlinFileChangesQueue, 1);
    g_mutex_init (&result->mutex);

    return result;
}

static MarlinFileChangesQueue *
marlin_file_changes_queue_get (void)
{
    static MarlinFileChangesQueue *file_changes_queue;

    if (file_changes_queue == NULL) {
        file_changes_queue = marlin_file_changes_queue_new ();
    }

    return file_changes_queue;
}

static void
marlin_file_changes_queue_add_common (MarlinFileChangesQueue *queue,
                                      MarlinFileChange *new_item)
{
    /* enqueue the new queue item while locking down the list */
    g_mutex_lock (&queue->mutex);

    queue->head = g_list_prepend (queue->head, new_item);
    if (queue->tail == NULL)
        queue->tail = queue->head;

    g_mutex_unlock (&queue->mutex);
}

void
marlin_file_changes_queue_file_added (GFile *location)
{
    MarlinFileChange *new_item;
    MarlinFileChangesQueue *queue;
    queue = marlin_file_changes_queue_get();

    new_item = g_new0 (MarlinFileChange, 1);
    new_item->kind = CHANGE_FILE_ADDED;
    new_item->from = g_object_ref (location);
    marlin_file_changes_queue_add_common (queue, new_item);
}

void
marlin_file_changes_queue_file_changed (GFile *location)
{
    MarlinFileChange *new_item;
    MarlinFileChangesQueue *queue;

    queue = marlin_file_changes_queue_get();

    new_item = g_new0 (MarlinFileChange, 1);
    new_item->kind = CHANGE_FILE_CHANGED;
    new_item->from = g_object_ref (location);
    marlin_file_changes_queue_add_common (queue, new_item);
}

void
marlin_file_changes_queue_file_removed (GFile *location)
{
    MarlinFileChange *new_item;
    MarlinFileChangesQueue *queue;

    queue = marlin_file_changes_queue_get();

    new_item = g_new0 (MarlinFileChange, 1);
    new_item->kind = CHANGE_FILE_REMOVED;
    new_item->from = g_object_ref (location);
    marlin_file_changes_queue_add_common (queue, new_item);
}

void
marlin_file_changes_queue_file_moved (GFile *from,
                                      GFile *to)
{
    MarlinFileChange *new_item;
    MarlinFileChangesQueue *queue;

    queue = marlin_file_changes_queue_get ();

    new_item = g_new (MarlinFileChange, 1);
    new_item->kind = CHANGE_FILE_MOVED;
    new_item->from = g_object_ref (from);
    new_item->to = g_object_ref (to);
    marlin_file_changes_queue_add_common (queue, new_item);
}

static MarlinFileChange *
marlin_file_changes_queue_get_change (MarlinFileChangesQueue *queue)
{
    GList *new_tail;
    MarlinFileChange *result;

    g_assert (queue != NULL);
    /* dequeue the tail item while locking down the list */
    g_mutex_lock (&queue->mutex);

    if (queue->tail == NULL) {
        result = NULL;
    } else {
        new_tail = queue->tail->prev;
        result = queue->tail->data;
        queue->head = g_list_remove_link (queue->head,
                                          queue->tail);
        g_list_free_1 (queue->tail);
        queue->tail = new_tail;
    }

    g_mutex_unlock (&queue->mutex);

    return result;
}

enum {
    CONSUME_CHANGES_MAX_CHUNK = 20
};

static void
pairs_list_free (GList *pairs)
{
    GList *p;
    GArray *pair;

    /* deep delete the list of pairs */

    for (p = pairs; p != NULL; p = p->next) {
        /* delete the strings in each pair */
        pair = p->data;
        GFile *from = g_array_index (pair, GFile *, 0);
        GFile *to = g_array_index (pair, GFile *, 1);
        g_object_unref (from);
        g_object_unref (to);
        g_array_free (pair, TRUE);
    }

    /* delete the list and the now empty pair structs */
    g_list_free (pairs);
}

/* go through changes in the change queue, send ones with the same kind
 * in a list to the different marlin_directory_notify calls
 */
void
marlin_file_changes_consume_changes (gboolean consume_all)
{
    MarlinFileChange *change;
    GList *additions, *changes, *deletions, *moves;
    GArray *pair;
    guint chunk_count;
    MarlinFileChangesQueue *queue;
    gboolean flush_needed;

    additions = NULL;
    changes = NULL;
    deletions = NULL;
    moves = NULL;

    queue = marlin_file_changes_queue_get();

    /* Consume changes from the queue, stuffing them into one of three lists,
     * keep doing it while the changes are of the same kind, then send them off.
     * This is to ensure that the changes get sent off in the same order that they
     * arrived.
     */
    for (chunk_count = 0; ; chunk_count++) {
        change = marlin_file_changes_queue_get_change (queue);

        /* figure out if we need to flush the pending changes that we collected sofar */

        if (change == NULL) {
            flush_needed = TRUE;
            /* no changes left, flush everything */
        } else {
            flush_needed = additions != NULL
                && change->kind != CHANGE_FILE_ADDED;

            flush_needed |= changes != NULL
                && change->kind != CHANGE_FILE_CHANGED;

            flush_needed |= moves != NULL
                && change->kind != CHANGE_FILE_MOVED;

            flush_needed |= deletions != NULL
                && change->kind != CHANGE_FILE_REMOVED;

            /*flush_needed |= position_set_requests != NULL
                && change->kind != CHANGE_POSITION_SET
                && change->kind != CHANGE_POSITION_REMOVE
                && change->kind != CHANGE_FILE_ADDED
                && change->kind != CHANGE_FILE_MOVED;*/

            flush_needed |= !consume_all && chunk_count >= CONSUME_CHANGES_MAX_CHUNK;
            /* we have reached the chunk maximum */
        }

        if (flush_needed) {
            /* Send changes we collected off.
             * At one time we may only have one of the lists
             * contain changes.
             */

            if (deletions != NULL) {
                deletions = g_list_reverse (deletions);
                gof_directory_async_notify_files_removed (deletions);
                g_list_free_full (deletions, g_object_unref);
                deletions = NULL;
            }
            if (moves != NULL) {
                moves = g_list_reverse (moves);
                gof_directory_async_notify_files_moved (moves);
                pairs_list_free (moves);
                moves = NULL;
            }
            if (additions != NULL) {
                additions = g_list_reverse (additions);
                gof_directory_async_notify_files_added (additions);
                g_list_free_full (additions, g_object_unref);
                additions = NULL;
            }
            if (changes != NULL) {
                changes = g_list_reverse (changes);
                gof_directory_async_notify_files_changed (changes);
                g_list_free_full (changes, g_object_unref);
                changes = NULL;
            }
        }

        if (change == NULL) {
            /* we are done */
            return;
        }

        /* add the new change to the list */
        switch (change->kind) {
        case CHANGE_FILE_ADDED:
            additions = g_list_prepend (additions, change->from);
            break;

        case CHANGE_FILE_CHANGED:
            changes = g_list_prepend (changes, change->from);
            break;

        case CHANGE_FILE_REMOVED:
            deletions = g_list_prepend (deletions, change->from);
            break;

        case CHANGE_FILE_MOVED:
            pair = g_array_sized_new (FALSE, FALSE, sizeof (GFile *), 2);
            g_array_append_val (pair, change->from);
            g_array_append_val (pair, change->to);
            moves = g_list_prepend (moves, pair);
            break;

        default:
            g_assert_not_reached ();
            break;
        }

        g_free (change);
    }
}
