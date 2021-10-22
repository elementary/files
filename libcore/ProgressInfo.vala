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

    public Gtk.Window? parent_window { get; construct; }
    public GLib.Cancellable cancellable { get; construct; }
    public uint inhibit_cookie { get; set; default = 0; }
    public string title { get; set; default = _("Preparing"); }
    public string status { get; private set; default = _("Preparing"); }
    public string details { get; set; default = _("Preparing"); }
    public double progress { get; private set; default = 0.0; }
    public double current { get; private set; default = 0.0; }
    public double total { get; private set; default = 0.0; }
    public bool activity_mode { get; private set; default = false; }
    public bool is_started { get; private set; default = false; }
    public bool is_finished { get; private set; default = false; }
    public bool is_paused { get; private set; default = false; }
    public bool is_cancelled { get { return cancellable.is_cancelled (); }}

    private GLib.Source idle_source;

    private bool source_is_now;
    private bool start_at_idle;
    private bool finish_at_idle;
    private bool changed_at_idle;
    private bool progress_at_idle;

    public Info (Gtk.Window parent_window) {
        Object (parent_window: parent_window);
    }

    construct {
        cancellable = new GLib.Cancellable ();
        /* Ensure info finishes if canceled by marlin-file-operations.
         * Using cancellable.connect () results in refcounting problem as it cannot be disconnected in its handler */
        cancellable.cancelled.connect (finish);
        Application.get_default ().hold ();
    }

    ~Info () {
        /* As the hold was placed on construction, we release it here to ensure matching count */
        /* Must ensure all references are released so Info is destroyed */
        warning ("INFO DESTRUCT");
        Application.get_default ().release ();
        uninhibit_power_manager ();
    }

    // public void cancel () {
    //     finish ();
    //     // cancellable.cancel ();
    // }

    public void start () {
        if (!is_started) {
            is_started = true;
            is_finished = false;
            start_at_idle = true;

            queue_idle (true);
        }
    }

    // The only place fileoperations should inhibit power manager
    public void inhibit_power_manager (string message) requires (inhibit_cookie == 0) {
        inhibit_cookie = ((Gtk.Application)(Application.get_default ())).inhibit (
            parent_window,
            Gtk.ApplicationInhibitFlags.LOGOUT | Gtk.ApplicationInhibitFlags.SUSPEND,
            message
        );
    }

    // The only place fileoperations should uninhibit power manager
    public void uninhibit_power_manager () requires (inhibit_cookie > 0) {
        ((Gtk.Application)(Application.get_default ())).uninhibit (inhibit_cookie);
    }

    public void finish () {
        cancellable.cancelled.disconnect (finish);
        if (!is_finished) { /* Should not queue finish twice */
            is_finished = true;
            is_started = false;
            is_paused = false;
            activity_mode = false;
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
        if (finish_at_idle) {
            finish_at_idle = false;
            /* Signal Progressinfo manager and ProgressUIManager info finished with.
             * This is the only place this signal is emitted so must always run. in
             * order for the info to be destroyed and the application released
             */
            finished ();

            return GLib.Source.REMOVE;
        }

        /* Protect against races where the source has
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
            started ();
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
