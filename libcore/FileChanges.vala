/* Copyright 2019 elementary, Inc. (https://elementary.io)
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

namespace Files.FileChanges {
    const int CONSUME_CHANGES_MAX_CHUNK = 20;

    public enum Kind {
        INITIAL,
        ADDED,
        CHANGED,
        REMOVED,
        MOVED
    }

    [Compact]
    public class Change {
        public Kind kind;
        public GLib.File from;
        public GLib.File to;
        public bool is_internal;
    }

    private static GLib.Queue<Change> queue;
    private static GLib.Mutex queue_mutex;

    private static unowned GLib.Queue<Change> get_queue () {
        queue_mutex.@lock ();
        if (queue == null) {
            queue = new GLib.Queue<Change> ();
        }

        queue_mutex.unlock ();

        return queue;
    }

    private static void queue_add_common (owned Change new_item) {
        unowned GLib.Queue<Change> queue = get_queue ();
        queue_mutex.@lock ();
        unowned var last_item = queue.peek_head ();
        // Ignore sequential duplicate events
        if (last_item == null ||
            !(last_item.from.equal (new_item.from)) ||
            last_item.kind != new_item.kind) {

            queue.push_head ((owned) new_item);
        }

        queue_mutex.unlock ();
    }

    public static void queue_file_added (GLib.File location, bool internal_origin = true) {
        var new_item = new Change () {
            kind = Kind.ADDED,
            from = location,
            is_internal = internal_origin
        };

        queue_add_common ((owned) new_item);
    }

    public static void queue_file_changed (GLib.File location) {
        var new_item = new Change () {
            kind = Kind.CHANGED,
            from = location,
            is_internal = true
        };

        queue_add_common ((owned) new_item);
    }

    public static void queue_file_removed (GLib.File location) {
        var new_item = new Change () {
            kind = Kind.REMOVED,
            from = location,
            is_internal = true
        };

        queue_add_common ((owned) new_item);
    }

    public static void queue_file_moved (GLib.File from, GLib.File to) {
        var new_item = new Change () {
            kind = Kind.MOVED,
            from = from,
            to = to,
            is_internal = true
        };

        queue_add_common ((owned) new_item);
    }

    public static void consume_changes (bool consume_all) {
        unowned GLib.Queue<Change> queue = get_queue ();
        uint chunk_count;
        bool flush_needed;
        GLib.List<GLib.File>? changes = null;
        GLib.List<GLib.File>? deletions = null;
        GLib.List<GLib.Array<GLib.File>>? moves = null;
        GLib.List<Change>? additions = null;

        /* Consume changes from the queue, stuffing them into one of three lists,
         * keep doing it while the changes are of the same kind, then send them off.
         * This is to ensure that the changes get sent off in the same order that they
         * arrived.
         */
        for (chunk_count = 0; ; chunk_count++) {
            queue_mutex.@lock ();
            Change? change = queue.pop_tail ();
            queue_mutex.unlock ();

            /* figure out if we need to flush the pending changes that we collected sofar */

            if (change == null) {
                flush_needed = true;
                /* no changes left, flush everything */
            } else {
                flush_needed = additions != null
                    && change.kind != Files.FileChanges.Kind.ADDED;

                flush_needed |= changes != null
                    && change.kind != Files.FileChanges.Kind.CHANGED;

                flush_needed |= moves != null
                    && change.kind != Files.FileChanges.Kind.MOVED;

                flush_needed |= deletions != null
                    && change.kind != Files.FileChanges.Kind.REMOVED;

                flush_needed |= !consume_all && chunk_count >= CONSUME_CHANGES_MAX_CHUNK;
                /* we have reached the chunk maximum */
            }

            if (flush_needed) {
                /* Send changes we collected off.
                 * At one time we may only have one of the lists
                 * contain changes.
                 */

                if (deletions != null) {
                    deletions.reverse ();
                    Files.Directory.notify_files_removed (deletions);
                    deletions = null;
                }

                if (moves != null) {
                    moves.reverse ();
                    Files.Directory.notify_files_moved (moves);
                    moves = null;
                }

                if (additions != null) {
                    additions.reverse ();
                    Files.Directory.notify_changes_added (additions);
                    additions = null;
                }

                if (changes != null) {
                    changes.reverse ();
                    Files.Directory.notify_files_changed (changes);
                    changes = null;
                }
            }

            if (change == null) {
                /* we are done */
                return;
            }

            /* add the new change to the list */
            switch (change.kind) {
                case Files.FileChanges.Kind.ADDED:
                    if (additions == null) {
                        additions = new GLib.List<Change> ();
                    }

                    additions.prepend ((owned)change);
                    break;

                case Files.FileChanges.Kind.CHANGED:
                    if (changes == null) {
                        changes = new GLib.List<GLib.File> ();
                    }

                    changes.prepend (change.from);
                    break;

                case Files.FileChanges.Kind.REMOVED:
                    if (deletions == null) {
                        deletions = new GLib.List<GLib.File> ();
                    }

                    deletions.prepend (change.from);
                    break;

                case Files.FileChanges.Kind.MOVED:
                    if (moves == null) {
                        moves = new GLib.List<GLib.Array<GLib.File>> ();
                    }

                    var pair = new GLib.Array<GLib.File>.sized (false, false, sizeof (GLib.File), 2);
                    pair.append_val (change.from);
                    pair.append_val (change.to);
                    moves.prepend (pair);
                    break;

                default:
                    GLib.assert_not_reached ();
            }
        }
    }
}
