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

namespace PF.PixbufUtils {
    private uint8 lighten_component (uint8 cur_value) {
        uint new_value = cur_value;
        new_value += 24 + (new_value >> 3);
        if (new_value > uint8.MAX) {
            new_value = uint8.MAX;
        }

        return (uint8) new_value;
    }

    public Gdk.Pixbuf lighten (Gdk.Pixbuf src) {
        GLib.return_val_if_fail ((!src.has_alpha && src.n_channels == 3) || (src.has_alpha && src.n_channels == 4),
                                 src);
        GLib.return_val_if_fail (src.bits_per_sample == 8, src);

        var width = src.width;
        var height = src.height;
        var channels = src.n_channels;
        var has_alpha = src.has_alpha;
        var dest = new Gdk.Pixbuf (src.colorspace, src.has_alpha, src.bits_per_sample, width, height);
        var dst_row_stride = dest.rowstride;
        var src_row_stride = src.rowstride;
        unowned uint8[] target_pix = (uint8[])dest.pixels;
        unowned uint8[] original_pix = (uint8[])src.pixels;
        for (int i = 0; i < height; i++) {
            int src_row = i * src_row_stride;
            int dst_row = i * dst_row_stride;
            for (int j = 0; j < width; j++) {
                var width_offset = j * channels;
                target_pix[dst_row + width_offset] = lighten_component (original_pix[src_row + width_offset]);
                target_pix[dst_row + width_offset + 1] = lighten_component (original_pix[src_row + width_offset + 1]);
                target_pix[dst_row + width_offset + 2] = lighten_component (original_pix[src_row + width_offset + 2]);
                if (has_alpha) {
                    target_pix[dst_row + width_offset + 3] = original_pix[src_row + width_offset + 3];
                }
            }
        }

        return dest;
    }

    public Gdk.Pixbuf darken (Gdk.Pixbuf src, uint8 saturation, uint8 darken) {
        GLib.return_val_if_fail ((!src.has_alpha && src.n_channels == 3) || (src.has_alpha && src.n_channels == 4),
                                 src);
        GLib.return_val_if_fail (src.bits_per_sample == 8, src);

        var width = src.width;
        var height = src.height;
        var has_alpha = src.has_alpha;
        var channels = src.n_channels;
        var dest = new Gdk.Pixbuf (src.colorspace, has_alpha, src.bits_per_sample, width, height);
        var dst_row_stride = dest.rowstride;
        var src_row_stride = src.rowstride;
        unowned uint8[] target_pix = (uint8[])dest.pixels;
        unowned uint8[] original_pix = (uint8[])src.pixels;
        for (int i = 0; i < height; i++) {
            int src_row = i * src_row_stride;
            int dst_row = i * dst_row_stride;
            for (int j = 0; j < width; j++) {
                var width_offset = j * channels;
                uint8 r = original_pix[src_row + width_offset];
                uint8 g = original_pix[src_row + width_offset + 1];
                uint8 b = original_pix[src_row + width_offset + 2];
                uint8 intensity = (r * 77 + g * 150 + b * 28) >> 8;
                uint8 negalpha = ((uint8.MAX - saturation) * darken) >> 8;
                uint8 alpha = (saturation * darken) >> 8;
                target_pix[dst_row + width_offset] = (negalpha * intensity + alpha * r) >> 8;
                target_pix[dst_row + width_offset + 1] = (negalpha * intensity + alpha * g) >> 8;
                target_pix[dst_row + width_offset + 2] = (negalpha * intensity + alpha * b) >> 8;
                if (has_alpha) {
                    target_pix[dst_row + width_offset + 3] = original_pix[src_row + width_offset + 3];
                }
            }
        }

        return dest;
    }

    /* this routine colorizes the passed-in pixbuf by multiplying each pixel with the passed in color */
    public Gdk.Pixbuf colorize (Gdk.Pixbuf src, Gdk.RGBA color) {
        GLib.return_val_if_fail ((!src.has_alpha && src.n_channels == 3) || (src.has_alpha && src.n_channels == 4),
                                 src);

        GLib.return_val_if_fail (src.bits_per_sample == 8, src);

        var red_value = (uint8) GLib.Math.floor (color.red * uint8.MAX);
        var green_value = (uint8) GLib.Math.floor (color.green * uint8.MAX);
        var blue_value = (uint8) GLib.Math.floor (color.blue * uint8.MAX);

        var width = src.width;
        var height = src.height;
        var has_alpha = src.has_alpha;
        var channels = src.n_channels;
        var dest = new Gdk.Pixbuf (src.colorspace, has_alpha, src.bits_per_sample, width, height);
        var dst_row_stride = dest.rowstride;
        var src_row_stride = src.rowstride;
        unowned uint8[] target_pix = (uint8[])dest.pixels;
        unowned uint8[] original_pix = (uint8[])src.pixels;
        for (int i = 0; i < height; i++) {
            int src_row = i * src_row_stride;
            int dst_row = i * dst_row_stride;
            for (int j = 0; j < width; j++) {
                var width_offset = j * channels;
                target_pix[dst_row + width_offset] = (original_pix[src_row + width_offset] * red_value) >> 8;
                target_pix[dst_row + width_offset + 1] = (original_pix[src_row + width_offset + 1] * green_value) >> 8;
                target_pix[dst_row + width_offset + 2] = (original_pix[src_row + width_offset + 2] * blue_value) >> 8;
                if (has_alpha) {
                    target_pix[dst_row + width_offset + 3] = original_pix[src_row + width_offset + 3];
                }
            }
        }

        return dest;
    }

    public Gdk.Pixbuf lucent (Gdk.Pixbuf src, uint percent) {
        GLib.return_val_if_fail (percent <= 100, src);

        var width = src.width;
        var height = src.height;
        var has_alpha = src.has_alpha;
        var dest = new Gdk.Pixbuf (src.colorspace, true, src.bits_per_sample, width, height);
        var dst_row_stride = dest.rowstride;
        var src_row_stride = src.rowstride;
        unowned uint8[] target_pix = (uint8[])dest.pixels;
        unowned uint8[] original_pix = (uint8[])src.pixels;
        if (has_alpha) {
            var ratio = (double)percent / 100;
            for (int i = 0; i < height; i++) {
                int src_row = i * src_row_stride;
                int dst_row = i * dst_row_stride;
                for (int j = 0; j < width; j++) {
                    var dr = dst_row + j * 4;
                    var sr = src_row + j * 4;
                    target_pix[dr++] = original_pix[sr++];
                    target_pix[dr++] = original_pix[sr++];
                    target_pix[dr++] = original_pix[sr++];
                    target_pix[dr] = (uint8)(original_pix[sr] * ratio);
                }
            }
        } else {
            percent = (255u * percent) / 100u;
            for (int i = 0; i < height; i++) {
                int src_row = i * src_row_stride;
                int dst_row = i * dst_row_stride;
                for (int j = 0; j < width; j++) {
                    var dr = dst_row + j * 4;
                    var sr = src_row + j * 3;
                    target_pix[dr++] = original_pix[sr++];
                    target_pix[dr++] = original_pix[sr++];
                    target_pix[dr++] = original_pix[sr++];
                    target_pix[dr] = (uint8)percent;
                }
            }
        }

        return dest;
    }
}
