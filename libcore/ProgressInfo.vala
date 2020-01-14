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
    private const uint SIGNAL_DELAY_MSEC = 100;

    public double progress { get; private set; default = 0; }
    public double current { get; private set; default = -1; }
    public double total { get; private set; default = -1; }
    public bool activity_mode { get; private set; default = true; }

    public uint inhibit_cookie { get; set; default = 0; }
    public string details { get; private set; default = _("Preparing"); }
    public string status { get; private set; default = _("Preparing"); }
    public string title { get; set; default = _("Preparing"); }
    public bool is_started { get; private set; }
    public bool is_finished { get; private set; }
    public bool is_paused { get; private set; }
    public GLib.Cancellable cancellable { get; construct; }
    public bool is_cancelled = false;

    private GLib.Source idle_source;
    private bool source_is_now;

    private bool start_at_idle;
    private bool finish_at_idle;
    private bool changed_at_idle;
    private bool progress_at_idle;

    public signal void changed ();
    public signal void progress_changed ();
    public signal void progress_started ();
    public signal void progress_finished ();

    ~Info () {
        debug ("INFO DESTRUCTOR");
    }

    construct {
        cancellable = new GLib.Cancellable ();
    }

    public void cancel () {
        cancellable.cancel ();
        is_cancelled = true;
        /* Ensure uninhibited even if operation blocked */
        if (inhibit_cookie > 0) {
            ((Gtk.Application)(Application.get_default ())).uninhibit (inhibit_cookie);
            inhibit_cookie = 0;
        }
    }

    public void start () {
        if (!is_started) {
            is_started = true;
            start_at_idle = true;

            queue_idle (true);
        }
    }

    /* Called (only) by marlin-file-operations when job finalized
     * after completion OR cancellation */
    public void operation_finalized (bool was_cancelled) {
        if (inhibit_cookie > 0) {
            ((Gtk.Application)(Application.get_default ())).uninhibit (inhibit_cookie);
            inhibit_cookie = 0;
        }

        finish_at_idle = true;
        queue_idle (true);
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

    public void take_status (owned string status) {
        if (this.status != status) {
            this.status = status;
            changed_at_idle = true;
            queue_idle (false);
        }
    }

    public void take_details (owned string details) {
        if (this.details != details) {
            this.details = details;
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
        current = 0.0;
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
        if (finish_at_idle) {
            finish_at_idle = false;
            /* Signal Progressinfo manager and ProgressUIManager info finished with.
             * This is the only place this signal is emitted so must always run.
             */
            progress_finished (); //Signal progressinfo manager and ProgressUIManager
            return GLib.Source.REMOVE;
        }


        /* Protect agains races where the source has
         * been destroyed on another thread while it
         * was being dispatched.
         * Similar to what gdk_threads_add_idle does.
         */
        weak GLib.Source source = GLib.MainContext.current_source ();
        if (source.is_destroyed ()) {
            return GLib.Source.REMOVE;
        }

        assert (source == idle_source);
        idle_source = null;

        if (start_at_idle) {
            start_at_idle = false;
            progress_started ();
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
