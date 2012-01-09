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
#include "marlin-clipboard-manager.h"
#include "marlin-icon-renderer.h"
#include "eel-gdk-pixbuf-extensions.h"


#define EXO_PARAM_READWRITE (G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS)

#define MARLIN_EMBLEM_SIZE 18


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


enum {
    PROP_0,
    PROP_PIXBUF,
    PROP_DROP_FILE,
    PROP_FILE,
    PROP_SIZE,
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

    gboolean emblems;
    gboolean follow_state;
    gboolean selection_helpers;

    MarlinClipboardManager *clipboard;
};


G_DEFINE_TYPE (MarlinIconRenderer, marlin_icon_renderer, GTK_TYPE_CELL_RENDERER)

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

    priv->clipboard = marlin_clipboard_manager_new_get_for_display (gdk_display_get_default ());
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

    g_object_class_install_property (object_class,
                                     PROP_PIXBUF,
                                     g_param_spec_object ("pixbuf",
                                                          "Pixbuf Object",
                                                          "The pixbuf to render",
                                                          GDK_TYPE_PIXBUF,
                                                          EXO_PARAM_READWRITE));

    g_object_class_install_property (object_class,
                                     PROP_SIZE,
                                     g_param_spec_enum ("size", "size", "size",
                                                        MARLIN_TYPE_ICON_SIZE,
                                                        MARLIN_ICON_SIZE_SMALL,
                                                        G_PARAM_CONSTRUCT | EXO_PARAM_READWRITE));

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

    if (priv->pixbuf)
        g_object_unref (priv->pixbuf);
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
    case PROP_PIXBUF:
        g_value_set_object (value, priv->pixbuf);
        break;
    case PROP_DROP_FILE:
        g_value_set_object (value, priv->drop_file);
        break;
    case PROP_FILE:
        g_value_set_object (value, priv->file);
        break;
    case PROP_SIZE:
        g_value_set_enum (value, priv->size);
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
    case PROP_PIXBUF:
        if (priv->pixbuf)
            g_object_unref (priv->pixbuf);
        priv->pixbuf = (GdkPixbuf*) g_value_dup_object (value);
        break;
    case PROP_DROP_FILE:
        if (G_LIKELY (priv->drop_file != NULL))
            g_object_unref (G_OBJECT (priv->drop_file));
        priv->drop_file = (gpointer) g_value_dup_object (value);
        break;
    case PROP_FILE:
        if (G_LIKELY (priv->file)) {
            g_object_unref (G_OBJECT (priv->file));
            priv->file = NULL;
        }
        if (priv->pixbuf) {
            g_object_unref (priv->pixbuf);
            priv->pixbuf = NULL;
        }
        priv->file = (GOFFile*) g_value_dup_object (value);
        //g_warning ("%s file %s %u", G_STRFUNC, priv->file->uri, G_OBJECT (priv->file)->ref_count);
        if (G_LIKELY (priv->file)) {
            gof_file_update_icon (priv->file, priv->size);
            priv->pixbuf = _g_object_ref0 (priv->file->pix);
            //g_object_notify (object, "pixbuf");
        } 
        break;
    case PROP_SIZE:
        priv->size = g_value_get_enum (value);
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

    g_return_if_fail (priv->pixbuf);

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

    if (width)
        *width = calc_width;

    if (height)
        *height = calc_height;
}

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

    //g_return_if_fail (priv->file && priv->pixbuf);
    if (!(priv->file && priv->pixbuf))
        return;

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
    
    pixbuf = _g_object_ref0 (priv->pixbuf);

    //g_debug ("%s %s %u %u\n", G_STRFUNC, priv->file->uri, G_OBJECT (priv->file)->ref_count, G_OBJECT (priv->pixbuf)->ref_count);
    //g_warning ("%s file %s %u", G_STRFUNC, priv->file->uri, G_OBJECT (priv->file)->ref_count);

    /* drop state */
    if (priv->file == priv->drop_file) {
        flags |= GTK_CELL_RENDERER_PRELIT;
        nicon = marlin_icon_info_lookup_from_name ("folder-drag-accept", priv->size);
        temp = marlin_icon_info_get_pixbuf_nodefault (nicon);
        g_object_unref (nicon);
        g_object_unref (pixbuf);
        pixbuf = temp;
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

    context = gtk_widget_get_style_context (widget);
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
                state = gtk_widget_has_focus (widget) ? GTK_STATE_FLAG_SELECTED : GTK_STATE_FLAG_ACTIVE;
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
    
    gtk_render_icon (context, cr, pixbuf,
                     pix_rect.x, pix_rect.y);

    gtk_style_context_restore (context);
    g_object_unref (pixbuf);

    /* add remove helpers +/- */
    GdkPixbuf *pix;

    if (priv->selection_helpers &&
        (flags & GTK_CELL_RENDERER_PRELIT) != 0 &&
        priv->file != priv->drop_file)
    {
        if ((flags & GTK_CELL_RENDERER_SELECTED) != 0)
            nicon = marlin_icon_info_lookup_from_name ("remove", 16);
        else
            nicon = marlin_icon_info_lookup_from_name ("add", 16);
        pix = marlin_icon_info_get_pixbuf_nodefault (nicon);
        gdk_cairo_set_source_pixbuf (cr, pix, pix_rect.x, pix_rect.y);
        cairo_paint (cr);
        
        g_object_unref (nicon);
        g_object_unref (pix);
    }

    /* check if we should render emblems as well */
    if (G_LIKELY (priv->emblems))
    {
        int position = 0;
        GList* emblems = g_list_first(priv->file->emblems_list);
        
        /* render the emblems */
        while(emblems != NULL && position < 4)
        {
            /* check if we have the emblem in the icon theme */
            nicon = marlin_icon_info_lookup_from_name (emblems->data, MARLIN_EMBLEM_SIZE);
            pix = marlin_icon_info_get_pixbuf_nodefault (nicon);
            if(pix == NULL) {
                g_warning ("Can't load icon %s", (char *) emblems->data);
                return;
            }

            /* determine the dimensions of the emblem */
            emblem_area.width = gdk_pixbuf_get_width (pix);
            emblem_area.height = gdk_pixbuf_get_height (pix);

            /* determine a good position for the emblem, depending on the position index */
            switch (position)
            {
            case 0: /* right/top */
                emblem_area.x = pix_rect.x + pix_rect.width - MARLIN_EMBLEM_SIZE;
                emblem_area.y = MAX(pix_rect.y - MARLIN_EMBLEM_SIZE, background_area->y);
                break;
            case 1: /* right/bottom */
                emblem_area.x = pix_rect.x + pix_rect.width - MARLIN_EMBLEM_SIZE;
                emblem_area.y = pix_rect.y + pix_rect.height - MARLIN_EMBLEM_SIZE;
                break;
            case 2: /* left/bottom */
                emblem_area.x = pix_rect.x;
                emblem_area.y = pix_rect.y + pix_rect.height - MARLIN_EMBLEM_SIZE;
                break;
            case 3: /* left/top */
                emblem_area.x = pix_rect.x;
                emblem_area.y = MAX(pix_rect.y - MARLIN_EMBLEM_SIZE, background_area->y);
                break;
            }

            gdk_cairo_set_source_pixbuf (cr, pix, emblem_area.x, emblem_area.y);
            cairo_paint (cr);
            
            position ++;

            emblems = g_list_next(emblems);
            g_object_unref (nicon);
            g_object_unref (pix);
        }
    }
}
