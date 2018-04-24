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

public class PF.Progress.Info : GLib.Object {
    public signal void changed ();
    public signal void progress_changed ();
    public signal void started ();
    public signal void finished ();

    private const uint SIGNAL_DELAY_MSEC = 100;

    private GLib.Cancellable cancellable;

    private string title;
    private string status;
    private string details;
    private double progress;
    private double current;
    private double total;
    private bool activity_mode;
    private bool is_started;
    private bool is_finished;
    private bool is_paused;

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
        PF.Progress.InfoManager.get_instance ().add_new_info (this);
    }

    public string get_title () {
        if (title != null) {
            return title;
        } else if (details != null) {
            return details;
        } else {
            return _("Preparing");
        }
    }

    public string get_status () {
        if (status != null) {
            return status;
        } else {
            return _("Preparing");
        }
    }

    public string get_details () {
        if (details != null) {
            return details;
        } else {
            return _("Preparing");
        }
    }

    public GLib.Cancellable get_cancellable () {
        return cancellable;
    }

    public void cancel () {
        cancellable.cancel ();
    }

    public bool get_is_started () {
        return is_started;
    }

    public bool get_is_finished () {
        return is_finished;
    }

    public bool get_is_paused () {
        return is_paused;
    }

    public double get_progress () {
        if (activity_mode) {
            return -1;
        } else {
            return progress;
        }
    }

    public double get_current () {
        if (activity_mode) {
            return 0;
        } else {
            return current;
        }
    }

    public double get_total () {
        if (activity_mode) {
            return -1;
        } else {
            return total;
        }
    }

    public void start () {
        if (!is_started) {
            is_started = true;
            start_at_idle = true;

            queue_idle (true);
        }
    }

    public void finish () {
        if (!is_finished) {
            is_finished = true;

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

    public void set_status (string status) {
        take_status (status);
    }

    public void take_status (owned string status) {
        if (this.status != status) {
            this.status = status;
            changed_at_idle = true;
            queue_idle (false);
        }
    }

    public void set_details (string details) {
        take_details (details);
    }

    public void take_details (owned string details) {
        if (this.details != details) {
            this.details = details;
            changed_at_idle = true;
            queue_idle (false);
        }
    }

    public void set_progress (double current, double total) {
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
        progress = 0.0;
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
            finished ();
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
