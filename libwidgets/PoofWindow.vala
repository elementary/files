//
//  Copyright (C) 2011-2012 Robert Dyer, Rico Tzschichholz
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

namespace Marlin.Animation
{
    /**
     * An animated window that draws a 'poof' animation.
     * Used when dragging items off the dock.
     */
    public class PoofWindow : Gtk.Window {
        const int POOF_SIZE = 128;
        const int POOF_FRAMES = 5;
        const int MSEC_PER_FRAME = 150;
        int frame_number = 0;

        static PoofWindow? instance = null;

        public static unowned PoofWindow get_default () {
            if (instance == null)
                instance = new PoofWindow ();

            return instance;
        }

        Gdk.Pixbuf poof_image;

        uint animation_timer = 0;

        /**
         * Creates a new poof window at the screen-relative coordinates specified.
         */
        public PoofWindow () {
            GLib.Object (type: Gtk.WindowType.TOPLEVEL, type_hint: Gdk.WindowTypeHint.DOCK);
        }

        construct {
            app_paintable = true;
            decorated = false;
            resizable = false;
            double_buffered = false;

            unowned Gdk.Screen screen = get_screen ();
            set_visual (screen.get_rgba_visual () ?? screen.get_system_visual ());
            accept_focus = false;
            can_focus = false;
            set_keep_above (true);

            try {
                poof_image = new Gdk.Pixbuf.from_file ("%s/poof.png".printf (Config.PIXMAP_DIR));
            } catch {
                poof_image = new Gdk.Pixbuf (Gdk.Colorspace.RGB, true, 8, 128, 640);
                warning ("Unable to load poof animation image");
            }

            set_size_request (POOF_SIZE, POOF_SIZE);
        }

        ~PoofWindow () {
            if (animation_timer > 0) {
                GLib.Source.remove (animation_timer);
                animation_timer = 0;
            }
        }

        /**
         * Show the animated poof-window at the given coordinates
         *
         * @param x the x position of the poof window
         * @param y the y position of the poof window
         */
        public void show_at (int x, int y) {
            if (animation_timer > 0)
                GLib.Source.remove (animation_timer);

            frame_number = 0;

            show ();
            move (x - (POOF_SIZE / 2), y - (POOF_SIZE / 2));

            animation_timer = Gdk.threads_add_timeout (MSEC_PER_FRAME, () => {
                if (frame_number++ < POOF_FRAMES) {
                    queue_draw ();
                    return true;
                }

                animation_timer = 0;
                hide ();
                return false;
            });
        }

        public override bool draw (Cairo.Context cr) {
            cr.set_operator (Cairo.Operator.SOURCE);
            Gdk.cairo_set_source_pixbuf (cr,
                                         poof_image,
                                         0,
                                         -POOF_SIZE * frame_number);
            cr.paint ();

            return true;
        }
    }
}
