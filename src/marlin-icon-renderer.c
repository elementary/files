/*
 * Copyright (C) 2000  Red Hat, Inc.,  Jonathan Blandford <jrb@redhat.com>
 * Copyright (c) 2011  ammonkey <am.monkeyd@gmail.com>
 *
 * Originaly Written in gtk+: gtkcellrendererpixbuf.h
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <glib-object.h>
#include <gtk/gtk.h>
#include "marlin-icon-renderer.h"
#include "eel-gdk-pixbuf-extensions.h"
#include "marlin-vala.h"


#define EXO_PARAM_READWRITE (G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS)

#define MARLIN_EMBLEM_SIZE 16

static void marlin_icon_renderer_get_property  (GObject                    *object,
                                                guint                       param_id,
                                                GValue                     *value,
                                                GParamSpec                 *pspec);
static void marlin_icon_renderer_set_property  (GObject                    *object,
                                                guint                       param_id,
                                                const GValue               *value,
                                                GParamSpec                 *pspec);
static void marlin_icon_renderer_finalize   (GObject                    *object);
static void marlin_icon_renderer_get_size   (GtkCellRenderer            *cell,
                                             GtkWidget                  *widget,
                                             const GdkRectangle         *rectangle,
                                             gint                       *x_offset,
                                             gint                       *y_offset,
                                             gint                       *width,
                                             gint                       *height);
static void marlin_icon_renderer_render     (GtkCellRenderer            *cell,
                                             cairo_t                    *cr,
                                             GtkWidget                  *widget,
                                             const GdkRectangle         *background_area,
                                             const GdkRectangle         *cell_area,
                                             GtkCellRendererState        flags);
static inline gboolean thumbnail_needs_frame   (const GdkPixbuf             *thumbnail,
                                                gint                        width,
                                                gint                        height);


enum {
    PROP_0,
    //PROP_PIXBUF,
    PROP_DROP_FILE,
    PROP_FILE,
    PROP_SIZE,
    PROP_ZOOM_LEVEL,
    PROP_EMBLEMS,
    PROP_FOLLOW_STATE,
    PROP_SELECTION_HELPERS,
};


struct _MarlinIconRendererPrivate
{
    GdkPixbuf *pixbuf;
    GOFFile   *file;
    GOFFile   *drop_file;
    gint      size;
    gint      helper_size;
    MarlinZoomLevel zoom_level;
    double scale;

    gboolean emblems;
    gboolean follow_state;
    gboolean selection_helpers;

    MarlinClipboardManager *clipboard;
};


G_DEFINE_TYPE (MarlinIconRenderer, marlin_icon_renderer, GTK_TYPE_CELL_RENDERER);

static gpointer _g_object_ref0 (gpointer self) {
    return self ? g_object_ref (self) : NULL;
}

static void
marlin_icon_renderer_init (MarlinIconRenderer *cellpixbuf)
{
    MarlinIconRendererPrivate *priv;

    cellpixbuf->priv = G_TYPE_INSTANCE_GET_PRIVATE (cellpixbuf,
                                                    MARLIN_TYPE_ICON_RENDERER,
                                                    MarlinIconRendererPrivate);
    priv = cellpixbuf->priv;

    priv->clipboard = marlin_clipboard_manager_get_for_display (gdk_display_get_default ());
    priv->emblems = TRUE;
}

static void
marlin_icon_renderer_class_init (MarlinIconRendererClass *class)
{
    GObjectClass *object_class = G_OBJECT_CLASS (class);
    GtkCellRendererClass *cell_class = GTK_CELL_RENDERER_CLASS (class);

    object_class->finalize = marlin_icon_renderer_finalize;

    object_class->get_property = marlin_icon_renderer_get_property;
    object_class->set_property = marlin_icon_renderer_set_property;

    cell_class->get_size = marlin_icon_renderer_get_size;
    cell_class->render = marlin_icon_renderer_render;

    /*g_object_class_install_property (object_class,
      PROP_PIXBUF,
      g_param_spec_object ("pixbuf",
      "Pixbuf Object",
      "The pixbuf to render",
      GDK_TYPE_PIXBUF,
      EXO_PARAM_READWRITE));*/

    g_object_class_install_property (object_class,
                                     PROP_SIZE,
                                     g_param_spec_enum ("size", "size", "size",
                                                        MARLIN_TYPE_ICON_SIZE,
                                                        MARLIN_ICON_SIZE_SMALL,
                                                        G_PARAM_CONSTRUCT | EXO_PARAM_READWRITE));

    g_object_class_install_property (object_class,
                                     PROP_ZOOM_LEVEL,
                                     g_param_spec_enum ("zoom-level", "zoom-level", "zoom-level",
                                                        MARLIN_TYPE_ZOOM_LEVEL,
                                                        MARLIN_ZOOM_LEVEL_NORMAL,
                                                        EXO_PARAM_READWRITE));

    g_object_class_install_property (object_class,
                                     PROP_DROP_FILE,
                                     g_param_spec_object ("drop-file", "drop-file", "drop-file",
                                                          GOF_TYPE_FILE,
                                                          EXO_PARAM_READWRITE));

    g_object_class_install_property (object_class,
                                     PROP_FILE,
                                     g_param_spec_object ("file", "file", "file",
                                                          GOF_TYPE_FILE,
                                                          EXO_PARAM_READWRITE));


    /**
     * MarlinIconRenderer:emblems:
     *
     * Specifies whether to render emblems in addition to the file icons.
     */
    g_object_class_install_property (object_class,
                                     PROP_EMBLEMS,
                                     g_param_spec_boolean ("emblems",
                                                           "emblems",
                                                           "emblems",
                                                           TRUE,
                                                           EXO_PARAM_READWRITE));

    /**
     * MarlinIconRenderer:follow-state:
     *
     * Specifies whether the rendered pixbuf should be colorized
     * according to the #GtkCellRendererState.
     *
     * Since: 2.8
     */
    g_object_class_install_property (object_class,
                                     PROP_FOLLOW_STATE,
                                     g_param_spec_boolean ("follow-state",
                                                           "Follow State",
                                                           "Whether the rendered pixbuf should be "
                                                           "colorized according to the state",
                                                           FALSE,
                                                           EXO_PARAM_READWRITE));

    g_object_class_install_property (object_class,
                                     PROP_SELECTION_HELPERS,
                                     g_param_spec_boolean ("selection-helpers",
                                                           "Selection Helpers",
                                                           "Whether the selection helpers +/- aree rendered",
                                                           FALSE,
                                                           EXO_PARAM_READWRITE));


    g_type_class_add_private (object_class, sizeof (MarlinIconRendererPrivate));
}

static void
marlin_icon_renderer_finalize (GObject *object)
{
    MarlinIconRenderer *cellpixbuf = MARLIN_ICON_RENDERER (object);
    MarlinIconRendererPrivate *priv = cellpixbuf->priv;

    /*if (priv->pixbuf)
      g_object_unref (priv->pixbuf);*/
    if (priv->file)
        g_object_unref (priv->file);
    if (priv->drop_file)
        g_object_unref (priv->drop_file);

    g_object_unref (priv->clipboard);

    G_OBJECT_CLASS (marlin_icon_renderer_parent_class)->finalize (object);
}

static void
marlin_icon_renderer_get_property (GObject        *object,
                                   guint           param_id,
                                   GValue         *value,
                                   GParamSpec     *pspec)
{
    MarlinIconRenderer *cellpixbuf = MARLIN_ICON_RENDERER (object);
    MarlinIconRendererPrivate *priv = cellpixbuf->priv;

    switch (param_id)
    {
        /*case PROP_PIXBUF:
          g_value_set_object (value, priv->pixbuf);
          break;*/
    case PROP_DROP_FILE:
        g_value_set_object (value, priv->drop_file);
        break;
    case PROP_FILE:
        g_value_set_object (value, priv->file);
        break;
    case PROP_SIZE:
        g_value_set_enum (value, priv->size);
        break;
    case PROP_ZOOM_LEVEL:
        g_value_set_enum (value, priv->zoom_level);
        break;
    case PROP_EMBLEMS:
        g_value_set_boolean (value, priv->emblems);
        break;
    case PROP_FOLLOW_STATE:
        g_value_set_boolean (value, priv->follow_state);
        break;
    case PROP_SELECTION_HELPERS:
        g_value_set_boolean (value, priv->selection_helpers);
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, param_id, pspec);
        break;
    }
}

static void
marlin_icon_renderer_set_property (GObject      *object,
                                   guint         param_id,
                                   const GValue *value,
                                   GParamSpec   *pspec)
{
    MarlinIconRenderer *cellpixbuf = MARLIN_ICON_RENDERER (object);
    MarlinIconRendererPrivate *priv = cellpixbuf->priv;

    switch (param_id)
    {
        /*case PROP_PIXBUF:
          if (priv->pixbuf)
          g_object_unref (priv->pixbuf);
          priv->pixbuf = (GdkPixbuf*) g_value_dup_object (value);
          break;*/
    case PROP_DROP_FILE:
        if (G_LIKELY (priv->drop_file != NULL))
            g_object_unref (G_OBJECT (priv->drop_file));
        priv->drop_file = (gpointer) g_value_dup_object (value);
        break;
    case PROP_FILE:
        //_g_object_unref0 (priv->pixbuf);
        _g_object_unref0 (priv->file);
        priv->file = (GOFFile*) g_value_dup_object (value);
        if (priv->file) {
            gof_file_update_icon (priv->file, priv->size);
            priv->pixbuf = priv->file->pix;
        }
        break;
    case PROP_SIZE:
        priv->size = g_value_get_enum (value);
        break;
    case PROP_ZOOM_LEVEL:
        priv->zoom_level = g_value_get_enum (value);
        priv->helper_size = (priv->zoom_level > MARLIN_ZOOM_LEVEL_NORMAL) ? 24 : 16;
        break;
    case PROP_EMBLEMS:
        priv->emblems = g_value_get_boolean (value);
        break;
    case PROP_FOLLOW_STATE:
        priv->follow_state = g_value_get_boolean (value);
        break;
    case PROP_SELECTION_HELPERS:
        priv->selection_helpers = g_value_get_boolean (value);
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, param_id, pspec);
        break;
    }
}

/**
 * marlin_icon_renderer_new:
 *
 * Creates a new #MarlinIconRenderer. Adjust rendering
 * parameters using object properties. Object properties can be set
 * globally (with g_object_set()). Also, with #GtkTreeViewColumn, you
 * can bind a property to a value in a #GtkTreeModel. For example, you
 * can bind the "pixbuf" property on the cell renderer to a pixbuf value
 * in the model, thus rendering a different image in each row of the
 * #GtkTreeView.
 *
 * Return value: the new cell renderer
**/
GtkCellRenderer *
marlin_icon_renderer_new (void)
{
    return g_object_new (MARLIN_TYPE_ICON_RENDERER, NULL);
}

static void
invalidate_size (gint *width, gint *height)
{
    if (width)
        *width = -1;
    if (height)
        *height = -1;
}

guint
marlin_icon_renderer_get_helper_size (MarlinIconRenderer *renderer) {
    return renderer->priv->helper_size;
}

static void
marlin_icon_renderer_get_size (GtkCellRenderer    *cell,
                               GtkWidget          *widget,
                               const GdkRectangle *cell_area,
                               gint               *x_offset,
                               gint               *y_offset,
                               gint               *width,
                               gint               *height)
{
    MarlinIconRenderer *cellpixbuf = (MarlinIconRenderer *) cell;
    MarlinIconRendererPrivate *priv = cellpixbuf->priv;
    gint pixbuf_width  = 0;
    gint pixbuf_height = 0;
    gint calc_width;
    gint calc_height;
    gint xpad, ypad;

    //g_return_if_fail (priv->pixbuf);
    if (!(priv->pixbuf && GDK_IS_PIXBUF (priv->pixbuf))) {
        invalidate_size (width, height);
        return;
    }

    if (priv->pixbuf)
    {
        pixbuf_width  = gdk_pixbuf_get_width (priv->pixbuf);
        pixbuf_height = gdk_pixbuf_get_height (priv->pixbuf);
    }

    gtk_cell_renderer_get_padding (cell, &xpad, &ypad);
    calc_width  = (gint) xpad * 2 + pixbuf_width;
    calc_height = (gint) ypad * 2 + pixbuf_height;

    if (cell_area && pixbuf_width > 0 && pixbuf_height > 0)
    {
        gfloat xalign, yalign;

        gtk_cell_renderer_get_alignment (cell, &xalign, &yalign);
        if (x_offset)
        {
            *x_offset = (((gtk_widget_get_direction (widget) == GTK_TEXT_DIR_RTL) ?
                          (1.0 - xalign) : xalign) *
                         (cell_area->width - calc_width));
            *x_offset = MAX (*x_offset, 0);
        }
        if (y_offset)
        {
            *y_offset = (yalign *
                         (cell_area->height - calc_height));
            *y_offset = MAX (*y_offset, 0);
        }
    }
    else
    {
        if (x_offset) *x_offset = 0;
        if (y_offset) *y_offset = 0;
    }

    /* Even if the last new pixbuf corresponding to the last requested size isn't generated
       yet, we can still determine its dimensions. This allow to asyncronously load the thumbnails
       pixbuf */
    int s = MAX (pixbuf_width, pixbuf_height);
    priv->scale = MIN (1, (double)priv->size / s);

    if (width)
        *width = calc_width * priv->scale;

    if (height)
        *height = calc_height * priv->scale;

}

static void
cairo_make_shadow_for_rect (cairo_t* cr,
                            gdouble x1, gdouble y1, gdouble w, gdouble h,
                            gdouble rad, gdouble r, gdouble g, gdouble b, gdouble size);

static void
marlin_icon_renderer_render (GtkCellRenderer      *cell,
                             cairo_t              *cr,
                             GtkWidget            *widget,
                             const GdkRectangle   *background_area,
                             const GdkRectangle   *cell_area,
                             GtkCellRendererState  flags)

{
    MarlinIconRenderer *cellpixbuf = (MarlinIconRenderer *) cell;
    MarlinIconRendererPrivate *priv = cellpixbuf->priv;
    GtkStyleContext *context;
    GdkPixbuf *pixbuf, *stated;
    GdkPixbuf *temp;
    GdkRectangle pix_rect;
    GdkRectangle emblem_area;
    GdkRectangle draw_rect;
    gint xpad, ypad;
    GtkStateFlags state;
    MarlinIconInfo *nicon;

    if (!(priv->file && priv->pixbuf))
      return;  /* return silently - this is not an error - could be rendering blank line (e.g. expanded empty subdirectory */

    g_return_if_fail (GDK_IS_PIXBUF (priv->pixbuf));
    g_return_if_fail (priv->size >= 1);


    marlin_icon_renderer_get_size (cell, widget, (GdkRectangle *) cell_area,
                                   &pix_rect.x,
                                   &pix_rect.y,
                                   &pix_rect.width,
                                   &pix_rect.height);

    gtk_cell_renderer_get_padding (cell, &xpad, &ypad);
    pix_rect.x += cell_area->x + xpad;
    pix_rect.y += cell_area->y + ypad;
    pix_rect.width -= xpad * 2;
    pix_rect.height -= ypad * 2;

    if (!gdk_rectangle_intersect (cell_area, &pix_rect, &draw_rect))
        return;

    pixbuf = g_object_ref (priv->pixbuf);

    //g_debug ("%s %s %u %u\n", G_STRFUNC, priv->file->uri, G_OBJECT (priv->file)->ref_count, G_OBJECT (priv->pixbuf)->ref_count);

    /* drop state */
    if (priv->file == priv->drop_file) {
        flags |= GTK_CELL_RENDERER_PRELIT;
        nicon = marlin_icon_info_lookup_from_name ("folder-drag-accept", priv->size);
        temp = marlin_icon_info_get_pixbuf_nodefault (nicon);
        g_object_unref (nicon);
        g_object_unref (pixbuf);
        pixbuf = temp;
    } else if (priv->file->is_directory) {
        if (priv->file->is_expanded) {
            nicon = marlin_icon_info_lookup_from_name ("folder-open", priv->size);
            temp = marlin_icon_info_get_pixbuf_nodefault (nicon);
            g_object_unref (nicon);
            g_object_unref (pixbuf);
            pixbuf = temp;
        }
    }

    /* clipboard */
    if (marlin_clipboard_manager_has_cutted_file (priv->clipboard, priv->file))
    {
        /* 50% translucent for cutted files */
        temp = eel_gdk_pixbuf_lucent (pixbuf, 50);
        g_object_unref (pixbuf);
        pixbuf = temp;
    }
    else if (priv->file->is_hidden)
    {
        /* 75% translucent for hidden files */
        temp = eel_gdk_pixbuf_lucent (pixbuf, 75);
        g_object_unref (pixbuf);
        pixbuf = temp;
    }

    context = gtk_widget_get_style_context (gtk_widget_get_parent (widget));
    gtk_style_context_save (context);
    state = GTK_STATE_FLAG_NORMAL;

    if (!gtk_widget_get_sensitive (widget) ||
        !gtk_cell_renderer_get_sensitive (cell))
        state |= GTK_STATE_FLAG_INSENSITIVE;
    else if (priv->follow_state &&
             (flags & (GTK_CELL_RENDERER_SELECTED |
                       GTK_CELL_RENDERER_PRELIT)) != 0) {
        if ((flags & GTK_CELL_RENDERER_SELECTED) != 0)
        {
            state = GTK_STATE_FLAG_SELECTED;
            /* compute the state with the state of the widget; this way we handle the backdrop */
            state |= gtk_widget_get_state_flags (widget);
            GdkRGBA color;
            gtk_style_context_get_background_color (context, state, &color);
            temp = eel_create_colorized_pixbuf (pixbuf, &color);
            g_object_unref (pixbuf);
            pixbuf = temp;
        }

        if ((flags & GTK_CELL_RENDERER_PRELIT) != 0)
        {
            temp = eel_create_spotlight_pixbuf (pixbuf);
            g_object_unref (pixbuf);
            pixbuf = temp;
        }

        //state = gtk_cell_renderer_get_state (cell, widget, flags);
    }

    /*if (state != GTK_STATE_FLAG_NORMAL)
      {
      stated = create_symbolic_pixbuf (cellpixbuf, widget, state);

      if (!stated)
      stated = transform_pixbuf_state (pixbuf, context);

      g_object_unref (pixbuf);
      pixbuf = stated;
      }*/

    if (pixbuf != NULL) {
        if (priv->file->flags == GOF_FILE_THUMB_STATE_READY
            && gof_file_get_thumbnail_path (priv->file)
            && gof_file_thumb_can_frame (priv->file)
            && thumbnail_needs_frame (pixbuf, pix_rect.width, pix_rect.height))
        {
            cairo_make_shadow_for_rect (cr, pix_rect.x+4, pix_rect.y+4,
                                        pix_rect.width-4, pix_rect.height-6,
                                        4, 0, 0, 0, 8);
        }

        gtk_render_icon (context, cr, pixbuf,
                         pix_rect.x, pix_rect.y);

        /* let the theme draw a frame for loaded thumbnails */
        if (priv->file->flags == GOF_FILE_THUMB_STATE_READY
            && gof_file_get_thumbnail_path (priv->file)
            && gof_file_thumb_can_frame (priv->file))
        {
            gtk_render_frame (context, cr,
                              pix_rect.x, pix_rect.y,
                              pix_rect.width, pix_rect.height);
        }

        gtk_style_context_restore (context);
        g_object_unref (pixbuf);
    }

    /* add remove helpers +/- */
    GdkPixbuf *pix;

    /* Do not show selection helpers or emblems for very small icons */
    if (priv->selection_helpers &&
        (flags & (GTK_CELL_RENDERER_PRELIT | GTK_CELL_RENDERER_SELECTED)) != 0 &&
        priv->file != priv->drop_file)
    {
        if((flags & GTK_CELL_RENDERER_SELECTED) != 0 && (flags & GTK_CELL_RENDERER_PRELIT) != 0)
            nicon = marlin_icon_info_lookup_from_name ("selection-remove", priv->helper_size);
        else if ((flags & GTK_CELL_RENDERER_SELECTED) != 0)
            nicon = marlin_icon_info_lookup_from_name ("selection-checked", priv->helper_size);
        else if ((flags & GTK_CELL_RENDERER_PRELIT) != 0)
            nicon = marlin_icon_info_lookup_from_name ("selection-add", priv->helper_size);

        pix = marlin_icon_info_get_pixbuf_nodefault (nicon);
        if (pix != NULL) {
            gdk_cairo_set_source_pixbuf (cr, pix, pix_rect.x, pix_rect.y);
            cairo_paint (cr);
            g_object_unref (pix);
        }

        g_object_unref (nicon);

    }

    /* check if we should render emblems as well */
    /* Still show emblems when selection helpers hidden in double click mode */
    if (G_LIKELY (priv->emblems)) 
    {
        int position = 0;
        GList* emblems = g_list_first(priv->file->emblems_list);

        /* render the emblems
         * show number of emblems depending on the zoom lvl. */
        while (emblems != NULL && priv->zoom_level > 0 && position < priv->zoom_level)
        {
            /* check if we have the emblem in the icon theme */
            nicon = marlin_icon_info_lookup_from_name (emblems->data, MARLIN_EMBLEM_SIZE);
            pix = marlin_icon_info_get_pixbuf_nodefault (nicon);
            if (pix == NULL) {
                g_warning ("Can't load icon %s", (char *) emblems->data);
                return;
            }

            /* determine the dimensions of the emblem */
            emblem_area.width = gdk_pixbuf_get_width (pix);
            emblem_area.height = gdk_pixbuf_get_height (pix);

            /* stack emblem on a vertical line begging from the bottom */
            guint overlap = MIN (8 + priv->zoom_level, pix_rect.width / 4);
            emblem_area.x = pix_rect.x + pix_rect.width - overlap;
            emblem_area.y = pix_rect.y + pix_rect.height - emblem_area.width * (position + 1);
            /* don't show cutted emblems */
            if (emblem_area.y < background_area->y)
                break;

#if 0
            /* nice square shape */
            /* determine a good position for the emblem, depending on the position index */
            switch (position)
            {
            case 0: /* bottom/right */
                emblem_area.x = MIN (pix_rect.x + pix_rect.width - emblem_area.width/2, background_area->x + background_area->width - emblem_area.width);
                emblem_area.y = pix_rect.y + pix_rect.height - emblem_area.width;
                break;
            case 1: /* top/right */
                emblem_area.x = MIN (pix_rect.x + pix_rect.width - emblem_area.width/2, background_area->x + background_area->width - emblem_area.width);
                emblem_area.y = pix_rect.y + pix_rect.height - emblem_area.width * 2;
                break;
            case 2: /* bottom/left */
                emblem_area.x = MIN (pix_rect.x + pix_rect.width - emblem_area.width/2 - emblem_area.width, background_area->x + background_area->width - 2 * emblem_area.width);
                emblem_area.y = pix_rect.y + pix_rect.height - emblem_area.width;
                break;
            case 3: /* top/left */
                emblem_area.x = MIN (pix_rect.x + pix_rect.width - emblem_area.width/2 - emblem_area.width, background_area->x + background_area->width - 2 * emblem_area.width);
                emblem_area.y = pix_rect.y + pix_rect.height - emblem_area.width * 2;
                break;
            }
#endif

            gdk_cairo_set_source_pixbuf (cr, pix, emblem_area.x, emblem_area.y);
            cairo_paint (cr);

            position ++;

            emblems = g_list_next(emblems);
            g_object_unref (nicon);
            g_object_unref (pix);
        }
    }

    /* The render call should always be preceded by a set_property call from
       GTK. It should be safe to unreference or free the allocate memory
       here. */
    _g_object_unref0 (priv->file);
    _g_object_unref0 (priv->drop_file);
}

/*
 * Shadows code snippet took from synapse (ui/utils.vala) and converted to C.
 * Authored by Michal Hruby <michal.mhr@gmail.com>
 *             Alberto Aldegheri <albyrock87+dev@gmail.com>
 */

#define _cairo_pattern_destroy0(var) ((var == NULL) ? NULL : (var = (cairo_pattern_destroy (var), NULL)))

static void
add_shadow_stops (cairo_pattern_t* pat, gdouble r, gdouble g, gdouble b, gdouble size, gdouble alpha)
{
    g_return_if_fail (pat != NULL);

    cairo_pattern_add_color_stop_rgba (pat, 1.0, r, g, b, (gdouble) 0);
    cairo_pattern_add_color_stop_rgba (pat, 0.8, r, g, b, alpha * 0.07);
    cairo_pattern_add_color_stop_rgba (pat, 0.6, r, g, b, alpha * 0.24);
    cairo_pattern_add_color_stop_rgba (pat, 0.4, r, g, b, alpha * 0.46);
    cairo_pattern_add_color_stop_rgba (pat, 0.2, r, g, b, alpha * 0.77);
    cairo_pattern_add_color_stop_rgba (pat, 0.0, r, g, b, alpha);
}


static void
cairo_make_shadow_for_rect (cairo_t* cr,
                            gdouble x1, gdouble y1, gdouble w, gdouble h,
                            gdouble rad, gdouble r, gdouble g, gdouble b, gdouble size)
{
    gdouble a;
    gdouble x2;
    gdouble x3;
    gdouble x4;
    gdouble y2;
    gdouble y3;
    gdouble y4;
    gdouble thick;
    cairo_pattern_t* pat = NULL;

    g_return_if_fail (cr != NULL);
    if (size < ((gdouble) 1))
        return;

    cairo_save (cr);
    a = 0.25;
    cairo_translate (cr, 0.5, 0.5);
    w -= 1;
    h -= 1;
    x2 = x1 + rad;
    x3 = x1 + w - rad;
    x4 = x1 + w;
    y2 = y1 + rad;
    y3 = y1 + h - rad;
    y4 = y1 + h;
    thick = size + rad;

    /* Top left corner */
    cairo_save (cr);
    _cairo_pattern_destroy0 (pat);
    pat = cairo_pattern_create_radial (x2, y2, rad, x2, y2, thick);
    add_shadow_stops (pat, r, g, b, size, a);
    cairo_set_source (cr, pat);
    cairo_rectangle (cr, x1-size, y1-size, thick, thick);
    cairo_clip (cr);
    cairo_paint (cr);
    cairo_restore (cr);

    /* Bottom left corner */
    cairo_save (cr);
    _cairo_pattern_destroy0 (pat);
    pat = cairo_pattern_create_radial (x2, y3, rad, x2, y3, thick);
    add_shadow_stops (pat, r, g, b, size, a);
    cairo_set_source (cr, pat);
    cairo_rectangle (cr, x1-size, y3, thick, thick);
    cairo_clip (cr);
    cairo_paint (cr);
    cairo_restore (cr);

    /* Top right corner */
    cairo_save (cr);
    _cairo_pattern_destroy0 (pat);
    pat = cairo_pattern_create_radial (x3, y2, rad, x3, y2, thick);
    add_shadow_stops (pat, r, g, b, size, a);
    cairo_set_source (cr, pat);
    cairo_rectangle (cr, x3, y1-size, thick, thick);
    cairo_clip (cr);
    cairo_paint (cr);
    cairo_restore (cr);

    /* Bottom right corner */
    cairo_save (cr);
    _cairo_pattern_destroy0 (pat);
    pat = cairo_pattern_create_radial (x3, y3, rad, x3, y3, thick);
    add_shadow_stops (pat, r, g, b, size, a);
    cairo_set_source (cr, pat);
    cairo_rectangle (cr, x3, y3, thick, thick);
    cairo_clip (cr);
    cairo_paint (cr);
    cairo_restore (cr);

    /* Right */
    cairo_save (cr);
    _cairo_pattern_destroy0 (pat);
    pat = cairo_pattern_create_linear (x4, 0, x4+size, 0);
    add_shadow_stops (pat, r, g, b, size, a);
    cairo_set_source (cr, pat);
    cairo_rectangle (cr, x4, y2, size, y3-y2);
    cairo_clip (cr);
    cairo_paint (cr);
    cairo_restore (cr);

    /* Left */
    cairo_save (cr);
    _cairo_pattern_destroy0 (pat);
    pat = cairo_pattern_create_linear (x1, 0, x1-size, 0);
    add_shadow_stops (pat, r, g, b, size, a);
    cairo_set_source (cr, pat);
    cairo_rectangle (cr, x1-size, y2, size, y3-y2);
    cairo_clip (cr);
    cairo_paint (cr);
    cairo_restore (cr);

    /* Bottom */
    cairo_save (cr);
    _cairo_pattern_destroy0 (pat);
    pat = cairo_pattern_create_linear (0, y4, 0, y4+size);
    add_shadow_stops (pat, r, g, b, size, a);
    cairo_set_source (cr, pat);
    cairo_rectangle (cr, x2, y4, x3-x2, size);
    cairo_clip (cr);
    cairo_paint (cr);
    cairo_restore (cr);

    /* Top */
    cairo_save (cr);
    _cairo_pattern_destroy0 (pat);
    pat = cairo_pattern_create_linear (0, y1, 0, y1-size);
    add_shadow_stops (pat, r, g, b, size, a);
    cairo_set_source (cr, pat);
    cairo_rectangle (cr, x2, y1-size, x3-x2, size);
    cairo_clip (cr);
    cairo_paint (cr);
    cairo_restore (cr);

    cairo_restore (cr);
    _cairo_pattern_destroy0 (pat);
}

static inline gboolean
thumbnail_needs_frame (const GdkPixbuf *thumbnail,
                       gint             width,
                       gint             height)
{
  const guchar *pixels;
  gint          rowstride;
  gint          n;

  /* don't add frames to small thumbnails */
  if (width < 48 && height < 48)
    return FALSE;

  /* always add a frame to thumbnails w/o alpha channel */
  if (G_LIKELY (!gdk_pixbuf_get_has_alpha (thumbnail)))
    return TRUE;

  /* get a pointer to the thumbnail data */
  pixels = gdk_pixbuf_get_pixels (thumbnail);

  /* check if we have a transparent pixel on the first row */
  for (n = width * 4; n > 0; n -= 4)
    if (pixels[n - 1] < 255u)
      return FALSE;
  g_debug("transparent pixel");

  /* determine the rowstride */
  rowstride = gdk_pixbuf_get_rowstride (thumbnail);

  /* skip the first row */
  pixels += rowstride;

  /* check if we have a transparent pixel in the first or last column */
  for (n = height - 2; n > 0; --n, pixels += rowstride)
    if (pixels[3] < 255u || pixels[width * 4 - 1] < 255u)
      return FALSE;

  /* check if we have a transparent pixel on the last row */
  for (n = width * 4; n > 0; n -= 4)
    if (pixels[n - 1] < 255u)
      return FALSE;

  return TRUE;
}
