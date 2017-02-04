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

#include "eel-gdk-pixbuf-extensions.h"
//#include "eel-glib-extensions.h"
#include <math.h>

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

    g_return_val_if_fail (gdk_pixbuf_get_colorspace (src) == GDK_COLORSPACE_RGB, src);
    g_return_val_if_fail ((!gdk_pixbuf_get_has_alpha (src)
                           && gdk_pixbuf_get_n_channels (src) == 3)
                          || (gdk_pixbuf_get_has_alpha (src)
                              && gdk_pixbuf_get_n_channels (src) == 4), src);
    g_return_val_if_fail (gdk_pixbuf_get_bits_per_sample (src) == 8, src);

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

    g_return_val_if_fail (gdk_pixbuf_get_colorspace (src) == GDK_COLORSPACE_RGB, src);
    g_return_val_if_fail ((!gdk_pixbuf_get_has_alpha (src)
                           && gdk_pixbuf_get_n_channels (src) == 3)
                          || (gdk_pixbuf_get_has_alpha (src)
                              && gdk_pixbuf_get_n_channels (src) == 4), src);
    g_return_val_if_fail (gdk_pixbuf_get_bits_per_sample (src) == 8, src);

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
                             GdkRGBA *color)
{
    int i, j;
    int width, height, has_alpha, src_row_stride, dst_row_stride;
    guchar *target_pixels;
    guchar *original_pixels;
    guchar *pixsrc;
    guchar *pixdest;
    GdkPixbuf *dest;
    gint red_value, green_value, blue_value;

    g_return_val_if_fail (gdk_pixbuf_get_colorspace (src) == GDK_COLORSPACE_RGB, src);
    g_return_val_if_fail ((!gdk_pixbuf_get_has_alpha (src)
                           && gdk_pixbuf_get_n_channels (src) == 3)
                          || (gdk_pixbuf_get_has_alpha (src)
                              && gdk_pixbuf_get_n_channels (src) == 4), src);
    g_return_val_if_fail (gdk_pixbuf_get_bits_per_sample (src) == 8, src);

    red_value = (gint) floor (color->red * 255);
    green_value = (gint) floor (color->green * 255);
    blue_value = (gint) floor (color->blue * 255);

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


/**
 * imported from exo_gdk_pixbuf_lucent:
 * @source  : the source #GdkPixbuf.
 * @percent : the percentage of translucency.
 *
 * Returns a version of @source, whose pixels translucency is
 * @percent of the original @source pixels.
 *
 * The caller is responsible to free the returned object
 * using g_object_unref() when no longer needed.
 *
 * Returns: a translucent version of @source.
 *
 * Since: 0.3.1.3
 **/
GdkPixbuf*
eel_gdk_pixbuf_lucent (GdkPixbuf *source,
                       guint percent)
{
  GdkPixbuf *dst;
  guchar    *dst_pixels;
  guchar    *src_pixels;
  guchar    *pixdst;
  guchar    *pixsrc;
  gint       dst_row_stride;
  gint       src_row_stride;
  gint       width;
  gint       height;
  gint       i, j;

  g_return_val_if_fail ((gint) percent >= 0 && percent <= 100, source);

  /* determine source parameters */
  width = gdk_pixbuf_get_width (source);
  height = gdk_pixbuf_get_height (source);

  /* allocate the destination pixbuf */
  dst = gdk_pixbuf_new (gdk_pixbuf_get_colorspace (source), TRUE, gdk_pixbuf_get_bits_per_sample (source), width, height);

  /* determine row strides on src/dst */
  dst_row_stride = gdk_pixbuf_get_rowstride (dst);
  src_row_stride = gdk_pixbuf_get_rowstride (source);

  /* determine pixels on src/dst */
  dst_pixels = gdk_pixbuf_get_pixels (dst);
  src_pixels = gdk_pixbuf_get_pixels (source);

  /* check if the source already contains an alpha channel */
  if (G_LIKELY (gdk_pixbuf_get_has_alpha (source)))
    {
      for (i = height; --i >= 0; )
        {
          pixdst = dst_pixels + i * dst_row_stride;
          pixsrc = src_pixels + i * src_row_stride;

          for (j = width; --j >= 0; )
            {
              *pixdst++ = *pixsrc++;
              *pixdst++ = *pixsrc++;
              *pixdst++ = *pixsrc++;
              *pixdst++ = ((guint) *pixsrc++ * percent) / 100u;
            }
        }
    }
  else
    {
      /* pre-calculate the alpha value */
      percent = (255u * percent) / 100u;

      for (i = height; --i >= 0; )
        {
          pixdst = dst_pixels + i * dst_row_stride;
          pixsrc = src_pixels + i * src_row_stride;

          for (j = width; --j >= 0; )
            {
              *pixdst++ = *pixsrc++;
              *pixdst++ = *pixsrc++;
              *pixdst++ = *pixsrc++;
              *pixdst++ = percent;
            }
        }
    }

  return dst;
}



