/*
 * Copyright (C) 2010 Jaap Broekhuizen
 *
 * This library is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License
 * version 3.0 as published by the Free Software Foundation.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License version 3.0 for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library. If not, see
 * <http://www.gnu.org/licenses/>.
 *
 * Authors: Jaap Broekhuizen <jaapz.b@gmail.com>
 *          ammonkey <am.monkeyd@gmail.com>
 */

using Gtk;
using Gdk;
using Cairo;

namespace Marlin.View.Chrome {

    public class ColorWidget : Gtk.MenuItem {

        public Window win;
        private new bool has_focus;
        private int height;
        /*
         * ColorWidget constructor
         */
        public ColorWidget(Window window) {
            win = window;
            set_size_request(150, 20);
            height = 20;

            button_press_event.connect(button_pressed_cb);
            /*motion_notify_event.connect(motion_notify_cb);
            leave_notify_event.connect(leave_notify_cb);*/
            draw.connect(on_draw);

            select.connect(() => {
                has_focus = true;
            });
            deselect.connect(() => {
                has_focus = false;
            });
        }

        private bool button_pressed_cb ( EventButton event ) {
            determine_button_pressed_event (event);
            return true;
        }
        
        /*private bool motion_notify_cb ( Gdk.EventMotion event ) {
            //stdout.printf ("motion\n");
            determine_motion_event (event);
            return true;
        }
        
        private bool leave_notify_cb ( Gdk.EventCrossing event ) {
            stdout.printf ("leave\n");
            return true;
        }*/

        private void determine_button_pressed_event ( EventButton event) {
            int i;
            int btnw = 10;
            int btnh = 10;
            int y0 = (height - btnh) /2;
            int x0 = btnw+5;
            int xpad = 9;

            if (event.y >= y0 && event.y <= y0+btnh)
                for (i=1; i<=10; i++) {
                    if (event.x>= xpad+x0*i && event.x <= xpad+x0*i+btnw) {
                        win.colorize_current_tab_selection (i-1);
                        break;
                    }
                }
        }

        protected bool on_draw(Cairo.Context cr)
        {
            //int width = get_allocated_width();
            //height = get_allocated_height();

            int i;
            int btnw = 10;
            int btnh = 10;
            int y0 = (height - btnh) /2;
            int x0 = btnw+5;
            int xpad = 9;

            for (i=1; i<=10; i++) {
                if (i==1)
                    DrawCross(cr,xpad + x0*i, y0+1, btnw-2, btnh-2);
                else {
                    DrawRoundedRectangle(cr,xpad + x0*i, y0, btnw, btnh, "stroke", i-1);
                    DrawRoundedRectangle(cr,xpad + x0*i, y0, btnw, btnh, "fill", i-1);
                    DrawGradientOverlay(cr,xpad + x0*i, y0, btnw, btnh);
                }
            }

            return true;
        }
        
        private void DrawCross(Context cr, int x, int y, int w, int h) {
            cr.new_path();
            cr.set_line_width(2.0);
            cr.move_to ( x, y);
            cr.rel_line_to ( w, h);
            cr.move_to ( x, y+h);
            cr.rel_line_to ( w, -h);
            cr.set_source_rgba(0,0,0,0.6);
            cr.stroke();

            cr.close_path ();
        }
        
        /*
         * Create a rounded rectangle using the Bezier curve.
         * Adapted from http://cairographics.org/cookbook/roundedrectangles/
         */
        private void DrawRoundedRectangle(Context cr, int x, int y, int w, int h, string style, int color) {
            int radius_x=2;
            int radius_y=2;
            double ARC_TO_BEZIER = 0.55228475;

            if (radius_x > w - radius_x) {
                radius_x = w / 2;
            }
            if (radius_y > h - radius_y) {
                radius_y = h / 2;
            }

            //approximate (quite close) the arc using a bezier curve
            double ca = ARC_TO_BEZIER * radius_x;
            double cb = ARC_TO_BEZIER * radius_y;

            cr.new_path();
            cr.set_line_width(0.7);
            cr.set_tolerance(0.1);
            cr.move_to ( x + radius_x, y);
            cr.rel_line_to ( w - 2 * radius_x, 0.0);
            cr.rel_curve_to ( ca, 0.0, radius_x, cb, radius_x, radius_y);
            cr.rel_line_to ( 0, h - 2 * radius_y);
            cr.rel_curve_to ( 0.0, cb, ca - radius_x, radius_y, -radius_x, radius_y);
            cr.rel_line_to ( -w + 2 * radius_x, 0);
            cr.rel_curve_to ( -ca, 0, -radius_x, -cb, -radius_x, -radius_y);
            cr.rel_line_to (0, -h + 2 * radius_y);
            cr.rel_curve_to (0.0, -cb, radius_x - ca, -radius_y, radius_x, -radius_y);

            switch(style) {
            default:
            case "fill":
                Gdk.RGBA rgba = Gdk.RGBA();
                rgba.parse (GOF.Preferences.TAGS_COLORS[color]);
                //rgba.alpha = 0.7;
                cairo_set_source_rgba (cr, rgba);
                cr.fill(); 
                break;
            case "stroke":
                cr.set_source_rgba(0,0,0,0.5);
                cr.stroke();
                break;  
            }

            cr.close_path ();
        }

        /*
         * Draw the overlaying gradient
         */
        private void DrawGradientOverlay(Context cr, int x, int y, int w, int h) {
            var radial = new Cairo.Pattern.radial(w, h, 1, 0.0, 0.0, 0.0);
            radial.add_color_stop_rgba(0, 0.3, 0.3, 0.3,0.0);
            radial.add_color_stop_rgba(1, 0.0, 0.0, 0.0,0.5);

            cr.set_source(radial);
            cr.rectangle(x,y,w,h);
            cr.fill(); 
        }
    }
}
