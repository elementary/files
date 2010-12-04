/* eel-gdk-pixbuf-extensions.c: Routines to augment what's in gdk-pixbuf.
 *
 * Copyright (C) 2000 Eazel, Inc.
 *
 * The Gnome Library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * The Gnome Library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with the Gnome Library; see the file COPYING.LIB.  If not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authors: Darin Adler <darin@eazel.com>
 *          Ramiro Estrugo <ramiro@eazel.com>
 *          Andy Hertzfeld <andy@eazel.com>
 */

#include <config.h>
#include "eel-gdk-pixbuf-extensions.h"

#define EEL_RGB_COLOR_RED	0xFF0000
#define EEL_RGB_COLOR_GREEN	0x00FF00
#define EEL_RGB_COLOR_BLUE	0x0000FF
#define EEL_RGB_COLOR_WHITE	0xFFFFFF
#define EEL_RGB_COLOR_BLACK	0x000000

#define EEL_RGBA_COLOR_OPAQUE_RED	0xFFFF0000
#define EEL_RGBA_COLOR_OPAQUE_GREEN	0xFF00FF00
#define EEL_RGBA_COLOR_OPAQUE_BLUE	0xFF0000FF
#define EEL_RGBA_COLOR_OPAQUE_WHITE	0xFFFFFFFF
#define EEL_RGBA_COLOR_OPAQUE_BLACK	0xFF000000

/* Access the individual RGBA components */
#define EEL_RGBA_COLOR_GET_R(color) (((color) >> 16) & 0xff)
#define EEL_RGBA_COLOR_GET_G(color) (((color) >> 8) & 0xff)
#define EEL_RGBA_COLOR_GET_B(color) (((color) >> 0) & 0xff)
#define EEL_RGBA_COLOR_GET_A(color) (((color) >> 24) & 0xff)


/* shared utility to create a new pixbuf from the passed-in one */

static GdkPixbuf *
create_new_pixbuf (GdkPixbuf *src)
{
	g_assert (gdk_pixbuf_get_colorspace (src) == GDK_COLORSPACE_RGB);
	g_assert ((!gdk_pixbuf_get_has_alpha (src)
			       && gdk_pixbuf_get_n_channels (src) == 3)
			      || (gdk_pixbuf_get_has_alpha (src)
				  && gdk_pixbuf_get_n_channels (src) == 4));

	return gdk_pixbuf_new (gdk_pixbuf_get_colorspace (src),
			       gdk_pixbuf_get_has_alpha (src),
			       gdk_pixbuf_get_bits_per_sample (src),
			       gdk_pixbuf_get_width (src),
			       gdk_pixbuf_get_height (src));
}

/* utility routine to bump the level of a color component with pinning */

static guchar
lighten_component (guchar cur_value)
{
	int new_value = cur_value;
	new_value += 24 + (new_value >> 3);
	if (new_value > 255) {
		new_value = 255;
	}
	return (guchar) new_value;
}

GdkPixbuf *
eel_create_spotlight_pixbuf (GdkPixbuf* src)
{
	GdkPixbuf *dest;
	int i, j;
	int width, height, has_alpha, src_row_stride, dst_row_stride;
	guchar *target_pixels, *original_pixels;
	guchar *pixsrc, *pixdest;

	g_return_val_if_fail (gdk_pixbuf_get_colorspace (src) == GDK_COLORSPACE_RGB, NULL);
	g_return_val_if_fail ((!gdk_pixbuf_get_has_alpha (src)
			       && gdk_pixbuf_get_n_channels (src) == 3)
			      || (gdk_pixbuf_get_has_alpha (src)
				  && gdk_pixbuf_get_n_channels (src) == 4), NULL);
	g_return_val_if_fail (gdk_pixbuf_get_bits_per_sample (src) == 8, NULL);

	dest = create_new_pixbuf (src);
	
	has_alpha = gdk_pixbuf_get_has_alpha (src);
	width = gdk_pixbuf_get_width (src);
	height = gdk_pixbuf_get_height (src);
	dst_row_stride = gdk_pixbuf_get_rowstride (dest);
	src_row_stride = gdk_pixbuf_get_rowstride (src);
	target_pixels = gdk_pixbuf_get_pixels (dest);
	original_pixels = gdk_pixbuf_get_pixels (src);

	for (i = 0; i < height; i++) {
		pixdest = target_pixels + i * dst_row_stride;
		pixsrc = original_pixels + i * src_row_stride;
		for (j = 0; j < width; j++) {		
			*pixdest++ = lighten_component (*pixsrc++);
			*pixdest++ = lighten_component (*pixsrc++);
			*pixdest++ = lighten_component (*pixsrc++);
			if (has_alpha) {
				*pixdest++ = *pixsrc++;
			}
		}
	}
	return dest;
}


/* the following routine was stolen from the panel to darken a pixbuf, by manipulating the saturation */

/* saturation is 0-255, darken is 0-255 */

GdkPixbuf *
eel_create_darkened_pixbuf (GdkPixbuf *src, int saturation, int darken)
{
    gint i, j;
    gint width, height, src_row_stride, dest_row_stride;
    gboolean has_alpha;
    guchar *target_pixels, *original_pixels;
    guchar *pixsrc, *pixdest;
    guchar intensity;
    guchar alpha;
    guchar negalpha;
    guchar r, g, b;
    GdkPixbuf *dest;

    g_return_val_if_fail (gdk_pixbuf_get_colorspace (src) == GDK_COLORSPACE_RGB, NULL);
    g_return_val_if_fail ((!gdk_pixbuf_get_has_alpha (src)
                           && gdk_pixbuf_get_n_channels (src) == 3)
                          || (gdk_pixbuf_get_has_alpha (src)
                              && gdk_pixbuf_get_n_channels (src) == 4), NULL);
    g_return_val_if_fail (gdk_pixbuf_get_bits_per_sample (src) == 8, NULL);

    dest = create_new_pixbuf (src);

    has_alpha = gdk_pixbuf_get_has_alpha (src);
    width = gdk_pixbuf_get_width (src);
    height = gdk_pixbuf_get_height (src);
    dest_row_stride = gdk_pixbuf_get_rowstride (dest);
    src_row_stride = gdk_pixbuf_get_rowstride (src);
    target_pixels = gdk_pixbuf_get_pixels (dest);
    original_pixels = gdk_pixbuf_get_pixels (src);

    for (i = 0; i < height; i++) {
        pixdest = target_pixels + i * dest_row_stride;
        pixsrc = original_pixels + i * src_row_stride;
        for (j = 0; j < width; j++) {
            r = *pixsrc++;
            g = *pixsrc++;
            b = *pixsrc++;
            intensity = (r * 77 + g * 150 + b * 28) >> 8;
            negalpha = ((255 - saturation) * darken) >> 8;
            alpha = (saturation * darken) >> 8;
            *pixdest++ = (negalpha * intensity + alpha * r) >> 8;
            *pixdest++ = (negalpha * intensity + alpha * g) >> 8;
            *pixdest++ = (negalpha * intensity + alpha * b) >> 8;
            if (has_alpha) {
                *pixdest++ = *pixsrc++;
            }
        }
    }
    return dest;
}

/* this routine colorizes the passed-in pixbuf by multiplying each pixel with the passed in color */

GdkPixbuf *
eel_create_colorized_pixbuf (GdkPixbuf *src,
                             int red_value,
                             int green_value,
                             int blue_value)
{
    int i, j;
    int width, height, has_alpha, src_row_stride, dst_row_stride;
    guchar *target_pixels;
    guchar *original_pixels;
    guchar *pixsrc;
    guchar *pixdest;
    GdkPixbuf *dest;

    g_return_val_if_fail (gdk_pixbuf_get_colorspace (src) == GDK_COLORSPACE_RGB, NULL);
    g_return_val_if_fail ((!gdk_pixbuf_get_has_alpha (src)
                           && gdk_pixbuf_get_n_channels (src) == 3)
                          || (gdk_pixbuf_get_has_alpha (src)
                              && gdk_pixbuf_get_n_channels (src) == 4), NULL);
    g_return_val_if_fail (gdk_pixbuf_get_bits_per_sample (src) == 8, NULL);

    dest = create_new_pixbuf (src);

    has_alpha = gdk_pixbuf_get_has_alpha (src);
    width = gdk_pixbuf_get_width (src);
    height = gdk_pixbuf_get_height (src);
    src_row_stride = gdk_pixbuf_get_rowstride (src);
    dst_row_stride = gdk_pixbuf_get_rowstride (dest);
    target_pixels = gdk_pixbuf_get_pixels (dest);
    original_pixels = gdk_pixbuf_get_pixels (src);

    for (i = 0; i < height; i++) {
        pixdest = target_pixels + i*dst_row_stride;
        pixsrc = original_pixels + i*src_row_stride;
        for (j = 0; j < width; j++) {		
            *pixdest++ = (*pixsrc++ * red_value) >> 8;
            *pixdest++ = (*pixsrc++ * green_value) >> 8;
            *pixdest++ = (*pixsrc++ * blue_value) >> 8;
            if (has_alpha) {
                *pixdest++ = *pixsrc++;
            }
        }
    }
    return dest;
}

static guchar
eel_gdk_pixbuf_lighten_pixbuf_component (guchar cur_value,
                                         guint lighten_value)
{
	int new_value = cur_value;
	if (lighten_value > 0) {
		new_value += lighten_value + (new_value >> 3);
		if (new_value > 255) {
			new_value = 255;
		}
	}
	return (guchar) new_value;
}

static GdkPixbuf *
eel_gdk_pixbuf_lighten (GdkPixbuf* src,
                        guint lighten_value)
{
	GdkPixbuf *dest;
	int i, j;
	int width, height, has_alpha, src_row_stride, dst_row_stride;
	guchar *target_pixels, *original_pixels;
	guchar *pixsrc, *pixdest;

	g_assert (gdk_pixbuf_get_colorspace (src) == GDK_COLORSPACE_RGB);
	g_assert ((!gdk_pixbuf_get_has_alpha (src)
			       && gdk_pixbuf_get_n_channels (src) == 3)
			      || (gdk_pixbuf_get_has_alpha (src)
				  && gdk_pixbuf_get_n_channels (src) == 4));
	g_assert (gdk_pixbuf_get_bits_per_sample (src) == 8);

	dest = gdk_pixbuf_new (gdk_pixbuf_get_colorspace (src),
			       gdk_pixbuf_get_has_alpha (src),
			       gdk_pixbuf_get_bits_per_sample (src),
			       gdk_pixbuf_get_width (src),
			       gdk_pixbuf_get_height (src));
	
	has_alpha = gdk_pixbuf_get_has_alpha (src);
	width = gdk_pixbuf_get_width (src);
	height = gdk_pixbuf_get_height (src);
	dst_row_stride = gdk_pixbuf_get_rowstride (dest);
	src_row_stride = gdk_pixbuf_get_rowstride (src);
	target_pixels = gdk_pixbuf_get_pixels (dest);
	original_pixels = gdk_pixbuf_get_pixels (src);

	for (i = 0; i < height; i++) {
		pixdest = target_pixels + i * dst_row_stride;
		pixsrc = original_pixels + i * src_row_stride;
		for (j = 0; j < width; j++) {		
			*pixdest++ = eel_gdk_pixbuf_lighten_pixbuf_component (*pixsrc++, lighten_value);
			*pixdest++ = eel_gdk_pixbuf_lighten_pixbuf_component (*pixsrc++, lighten_value);
			*pixdest++ = eel_gdk_pixbuf_lighten_pixbuf_component (*pixsrc++, lighten_value);
			if (has_alpha) {
				*pixdest++ = *pixsrc++;
			}
		}
	}
	return dest;
}

GdkPixbuf *
eel_gdk_pixbuf_render (GdkPixbuf *pixbuf,
                       guint render_mode,
                       guint saturation,
                       guint brightness,
                       guint lighten_value,
                       guint color)
{
    GdkPixbuf *temp_pixbuf, *old_pixbuf;

    if (render_mode == 1) {
        /* lighten icon */
        temp_pixbuf = eel_create_spotlight_pixbuf (pixbuf);
    }
    else if (render_mode == 2) {
        /* colorize icon */
        temp_pixbuf = eel_create_colorized_pixbuf (pixbuf,
                                                   EEL_RGBA_COLOR_GET_R (color),
                                                   EEL_RGBA_COLOR_GET_G (color),
                                                   EEL_RGBA_COLOR_GET_B (color));
    } else if (render_mode == 3) {
        /* monochromely colorize icon */
        old_pixbuf = eel_create_darkened_pixbuf (pixbuf, 0, 255);		
        temp_pixbuf = eel_create_colorized_pixbuf (old_pixbuf,
                                                   EEL_RGBA_COLOR_GET_R (color),
                                                   EEL_RGBA_COLOR_GET_G (color),
                                                   EEL_RGBA_COLOR_GET_B (color));
        g_object_unref (old_pixbuf);
    } else {
        temp_pixbuf = NULL;
    }

    if (saturation < 255 || brightness < 255 || temp_pixbuf == NULL) { // temp_pixbuf == NULL just for safer code (return copy)
        old_pixbuf = temp_pixbuf;
        temp_pixbuf = eel_create_darkened_pixbuf (temp_pixbuf ? temp_pixbuf : pixbuf, saturation, brightness);
        if (old_pixbuf) {
            g_object_unref (old_pixbuf);
        }
    }

    if (lighten_value > 0) {
        old_pixbuf = temp_pixbuf;
        temp_pixbuf = eel_gdk_pixbuf_lighten (temp_pixbuf ? temp_pixbuf : pixbuf, lighten_value);
        if (old_pixbuf) {
            g_object_unref (old_pixbuf);
        }
    }

    return temp_pixbuf;
}
