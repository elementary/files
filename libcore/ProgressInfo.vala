/* Copyright (c) 2018 elementary LLC (https://elementary.io)
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

/* Intermediary between a FileOperation and the ProgressUIHandler allowing the UI to show the progress
 * of the operation and also to cancel that operation. */
public class PF.Progress.Info : GLib.Object {
    public signal void changed ();
    public signal void progress_changed ();
    public signal void started ();
    public signal void finished ();

    private const uint SIGNAL_DELAY_MSEC = 100;

    public GLib.Cancellable cancellable { get; construct; }

    public string title { get; set; default = _("Preparing"); }
    public string status { get; private set; default = _("Preparing"); }
    public string details { get; set; default = _("Preparing"); }
    public double progress { get; private set; default = 0.0; }
    public double current { get; private set; default = 0.0; }
    public double total { get; private set; default = 0.0; }
    public bool activity_mode { get; private set; default = true; }
    public bool is_started { get; private set; }
    public bool is_finished { get; private set; }
    public bool is_paused { get; private set; }
    public bool is_cancelled { get { return cancellable.is_cancelled (); }}

    private GLib.Source idle_source;

    private bool source_is_now;
    private bool start_at_idle;
    private bool finish_at_idle;
    private bool changed_at_idle;
    private bool progress_at_idle;

    public Info () {

    }

    construct {
        cancellable = new GLib.Cancellable ();
        /* Ensure info finishes if canceled by marlin-file-operations.
         * Using cancellable.connect () results in refcounting problem as it cannot be disconnected in its handler */
        cancellable.cancelled.connect (finish);
        PF.Progress.InfoManager.get_instance ().add_new_info (this);
        warning ("construct info - hold application");
        Application.get_default ().hold ();
    }

    ~Info () {
        /* As the hold was placed on construction, we release it here to ensure matching count */
        /* Must ensure all references are released so Info is destroyed */
        Application.get_default ().release ();
    }

    public void cancel () {
        cancellable.cancel ();
    }

    public void start () {
        if (!is_started) {
            is_started = true;
            start_at_idle = true;

            queue_idle (true);
        }
    }

    public void finish () {
        if (!is_finished) { /* Should not queue finish twice */
            is_finished = true;
            cancellable.cancelled.disconnect (finish);
            finish_at_idle = true;
            queue_idle (true);
        }
    }

    public void pause () {
        if (!is_paused) {
            is_paused = true;
        }
    }

    public void resume () {
        if (is_paused) {
            is_paused = false;
        }
    }

    public void take_status (owned string _status) {
        if (status != _status) {
            status = _status;
            changed_at_idle = true;
            queue_idle (false);
        }
    }

    public void take_details (owned string _details) {
        if (details != _details) {
            details = _details;
            changed_at_idle = true;
            queue_idle (false);
        }
    }

    public void update_progress (double current, double total) {
        double current_percent = 1.0;

        if (total > 0) {
            current_percent = double.min (current / total, 1);
            current_percent = double.max (current_percent, 0);
        }

        /*
         * Emit on switch from activity mode
         * Emit on change of 0.5 percent
         */
        if (activity_mode || (current_percent - progress).abs () > 0.005) {
            activity_mode = false;
            progress = current_percent;
            this.current = current;
            this.total = total;
            progress_at_idle = true;
            queue_idle (false);
        }
    }

    public void pulse_progress () {
        activity_mode = true;
        progress = -1.0;
        progress_at_idle = true;
        queue_idle (false);
    }

    private void queue_idle (bool now) {
        if (idle_source == null || (now && !source_is_now)) {
            if (idle_source != null) {
                idle_source.destroy ();
                idle_source = null;
            }

            source_is_now = now;
            if (now) {
                idle_source = new GLib.IdleSource ();
            } else {
                idle_source = new GLib.TimeoutSource (SIGNAL_DELAY_MSEC);
            }

            idle_source.set_callback (idle_callback);
            idle_source.attach (null);
        }
    }

    private bool idle_callback () {
        weak GLib.Source source = GLib.MainContext.current_source ();
        /* Protect agains races where the source has
         * been destroyed on another thread while it
         * was being dispatched.
         * Similar to what gdk_threads_add_idle does.
         */
        if (source.is_destroyed ()) {
            critical ("Source destroyed on another thread");
            return GLib.Source.REMOVE;
        }

        assert (source == idle_source);
        idle_source = null;

        if (start_at_idle) {
            start_at_idle = false;
            started ();
        }

        if (finish_at_idle) {
            finish_at_idle = false;
            /* Only place the finish signal is emitted */
            /* Must be emitted to update ProgressUIHandler */
            finished ();
            PF.Progress.InfoManager.get_instance ().remove_finished_info (this);
        }

        if (changed_at_idle) {
            changed ();
            changed_at_idle = false;
        }

        if (progress_at_idle) {
            progress_changed ();
            progress_at_idle = false;
        }

        return GLib.Source.REMOVE;
    }
}
