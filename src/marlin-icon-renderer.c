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



static void marlin_icon_renderer_get_property  (GObject                    *object,
                                                guint                       param_id,
                                                GValue                     *value,
                                                GParamSpec                 *pspec);
static void marlin_icon_renderer_set_property  (GObject                    *object,
                                                guint                       param_id,
                                                const GValue               *value,
                                                GParamSpec                 *pspec);
static void marlin_icon_renderer_finalize   (GObject                    *object);
static void marlin_icon_renderer_create_stock_pixbuf (MarlinIconRenderer *cellpixbuf,
                                                      GtkWidget             *widget);
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
    PROP_FILE,
    PROP_SIZE,
    PROP_STOCK_ID,
    PROP_STOCK_SIZE,
    PROP_STOCK_DETAIL,
    PROP_EMBLEMS,
    PROP_FOLLOW_STATE,
    PROP_SELECTION_HELPERS,
    PROP_ICON_NAME,
    PROP_GICON
};


struct _MarlinIconRendererPrivate
{
    GdkPixbuf *pixbuf;
    GOFFile   *file;
    gint      size;

    GIcon *gicon;

    GtkIconSize stock_size;

    gboolean emblems;
    gboolean follow_state;
    gboolean selection_helpers;

    gchar *stock_id;
    gchar *stock_detail;
    gchar *icon_name;

    MarlinClipboardManager *clipboard;
};


G_DEFINE_TYPE (MarlinIconRenderer, marlin_icon_renderer, GTK_TYPE_CELL_RENDERER)


static void
marlin_icon_renderer_init (MarlinIconRenderer *cellpixbuf)
{
    MarlinIconRendererPrivate *priv;

    cellpixbuf->priv = G_TYPE_INSTANCE_GET_PRIVATE (cellpixbuf,
                                                    MARLIN_TYPE_ICON_RENDERER,
                                                    MarlinIconRendererPrivate);
    priv = cellpixbuf->priv;

    priv->stock_size = GTK_ICON_SIZE_MENU;
    priv->clipboard = marlin_clipboard_manager_new_get_for_display (gdk_display_get_default ());
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
                                     PROP_FILE,
                                     g_param_spec_object ("file", "file", "file",
                                                          GOF_TYPE_FILE,
                                                          EXO_PARAM_READWRITE));

    g_object_class_install_property (object_class,
                                     PROP_STOCK_ID,
                                     g_param_spec_string ("stock-id",
                                                          "Stock ID",
                                                          "The stock ID of the stock icon to render",
                                                          NULL,
                                                          EXO_PARAM_READWRITE));

    g_object_class_install_property (object_class,
                                     PROP_STOCK_SIZE,
                                     g_param_spec_uint ("stock-size",
                                                        "Size",
                                                        "The GtkIconSize value that specifies the size of the rendered icon",
                                                        0,
                                                        G_MAXUINT,
                                                        GTK_ICON_SIZE_MENU,
                                                        EXO_PARAM_READWRITE));

    g_object_class_install_property (object_class,
                                     PROP_STOCK_DETAIL,
                                     g_param_spec_string ("stock-detail",
                                                          "Detail",
                                                          "Render detail to pass to the theme engine",
                                                          NULL,
                                                          EXO_PARAM_READWRITE));


    /**
     * MarlinIconRenderer:icon-name:
     *
     * The name of the themed icon to display.
     * This property only has an effect if not overridden by "stock_id" 
     * or "pixbuf" properties.
     *
     * Since: 2.8 
     */
    g_object_class_install_property (object_class,
                                     PROP_ICON_NAME,
                                     g_param_spec_string ("icon-name",
                                                          "Icon Name",
                                                          "The name of the icon from the icon theme",
                                                          NULL,
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
    /**
     * MarlinIconRenderer:gicon:
     *
     * The GIcon representing the icon to display.
     * If the icon theme is changed, the image will be updated
     * automatically.
     *
     * Since: 2.14
     */
    g_object_class_install_property (object_class,
                                     PROP_GICON,
                                     g_param_spec_object ("gicon",
                                                          "Icon",
                                                          "The GIcon being displayed",
                                                          G_TYPE_ICON,
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

    g_free (priv->stock_id);
    g_free (priv->stock_detail);
    g_free (priv->icon_name);

    if (priv->gicon)
        g_object_unref (priv->gicon);

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
    case PROP_FILE:
        g_value_set_object (value, priv->file);
        break;
    case PROP_SIZE:
        g_value_set_enum (value, priv->size);
        break;
    case PROP_STOCK_ID:
        g_value_set_string (value, priv->stock_id);
        break;
    case PROP_STOCK_SIZE:
        g_value_set_uint (value, priv->stock_size);
        break;
    case PROP_STOCK_DETAIL:
        g_value_set_string (value, priv->stock_detail);
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
    case PROP_ICON_NAME:
        g_value_set_string (value, priv->icon_name);
        break;
    case PROP_GICON:
        g_value_set_object (value, priv->gicon);
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
        if (priv->pixbuf)
        {
            if (priv->stock_id)
            {
                g_free (priv->stock_id);
                priv->stock_id = NULL;
                g_object_notify (object, "stock-id");
            }
            if (priv->icon_name)
            {
                g_free (priv->icon_name);
                priv->icon_name = NULL;
                g_object_notify (object, "icon-name");
            }
            if (priv->gicon)
            {
                g_object_unref (priv->gicon);
                priv->gicon = NULL;
                g_object_notify (object, "gicon");
            }
        }
        break;
    case PROP_FILE:
        if (G_LIKELY (priv->file != NULL)) {
            g_object_unref (G_OBJECT (priv->file));
        }
        if (priv->pixbuf) {
            g_object_unref (priv->pixbuf);
            priv->pixbuf = NULL;
        }
        priv->file = (gpointer) g_value_dup_object (value);
        if (G_LIKELY (priv->file != NULL)) {
            gof_file_update_icon (priv->file, priv->size);
            priv->pixbuf = g_object_ref (priv->file->pix);
        } 
        break;
    case PROP_SIZE:
        priv->size = g_value_get_enum (value);
        break;
    case PROP_STOCK_ID:
        if (priv->stock_id)
        {
            if (priv->pixbuf)
            {
                g_object_unref (priv->pixbuf);
                priv->pixbuf = NULL;
                g_object_notify (object, "pixbuf");
            }
            g_free (priv->stock_id);
        }
        priv->stock_id = g_value_dup_string (value);
        if (priv->stock_id)
        {
            if (priv->pixbuf)
            {
                g_object_unref (priv->pixbuf);
                priv->pixbuf = NULL;
                g_object_notify (object, "pixbuf");
            }
            if (priv->icon_name)
            {
                g_free (priv->icon_name);
                priv->icon_name = NULL;
                g_object_notify (object, "icon-name");
            }
            if (priv->gicon)
            {
                g_object_unref (priv->gicon);
                priv->gicon = NULL;
                g_object_notify (object, "gicon");
            }
        }
        break;
    case PROP_STOCK_SIZE:
        priv->stock_size = g_value_get_uint (value);
        break;
    case PROP_STOCK_DETAIL:
        g_free (priv->stock_detail);
        priv->stock_detail = g_value_dup_string (value);
        break;
    case PROP_ICON_NAME:
        if (priv->icon_name)
        {
            if (priv->pixbuf)
            {
                g_object_unref (priv->pixbuf);
                priv->pixbuf = NULL;
                g_object_notify (object, "pixbuf");
            }
            g_free (priv->icon_name);
        }
        priv->icon_name = g_value_dup_string (value);
        if (priv->icon_name)
        {
            if (priv->pixbuf)
            {
                g_object_unref (priv->pixbuf);
                priv->pixbuf = NULL;
                g_object_notify (object, "pixbuf");
            }
            if (priv->stock_id)
            {
                g_free (priv->stock_id);
                priv->stock_id = NULL;
                g_object_notify (object, "stock-id");
            }
            if (priv->gicon)
            {
                g_object_unref (priv->gicon);
                priv->gicon = NULL;
                g_object_notify (object, "gicon");
            }
        }
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
    case PROP_GICON:
        if (priv->gicon)
        {
            if (priv->pixbuf)
            {
                g_object_unref (priv->pixbuf);
                priv->pixbuf = NULL;
                g_object_notify (object, "pixbuf");
            }
            g_object_unref (priv->gicon);
        }
        priv->gicon = (GIcon *) g_value_dup_object (value);
        if (priv->gicon)
        {
            if (priv->pixbuf)
            {
                g_object_unref (priv->pixbuf);
                priv->pixbuf = NULL;
                g_object_notify (object, "pixbuf");
            }
            if (priv->stock_id)
            {
                g_free (priv->stock_id);
                priv->stock_id = NULL;
                g_object_notify (object, "stock-id");
            }
            if (priv->icon_name)
            {
                g_free (priv->icon_name);
                priv->icon_name = NULL;
                g_object_notify (object, "icon-name");
            }
        }
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
marlin_icon_renderer_create_stock_pixbuf (MarlinIconRenderer *cellpixbuf,
                                          GtkWidget             *widget)
{
    MarlinIconRendererPrivate *priv = cellpixbuf->priv;

    if (priv->pixbuf)
        g_object_unref (priv->pixbuf);

    priv->pixbuf = gtk_widget_render_icon_pixbuf (widget,
                                                  priv->stock_id,
                                                  priv->stock_size);

    g_object_notify (G_OBJECT (cellpixbuf), "pixbuf");
}

static void 
marlin_icon_renderer_create_themed_pixbuf (MarlinIconRenderer *cellpixbuf,
                                           GtkWidget             *widget)
{
    MarlinIconRendererPrivate *priv = cellpixbuf->priv;
    GdkScreen *screen;
    GtkIconTheme *icon_theme;
    GtkSettings *settings;
    gint width, height;
    GtkIconInfo *info;

    if (priv->pixbuf)
    {
        g_object_unref (priv->pixbuf);
        priv->pixbuf = NULL;
    }

    screen = gtk_widget_get_screen (GTK_WIDGET (widget));
    icon_theme = gtk_icon_theme_get_for_screen (screen);
    settings = gtk_settings_get_for_screen (screen);

    if (!gtk_icon_size_lookup_for_settings (settings,
                                            priv->stock_size,
                                            &width, &height))
    {
        g_warning ("Invalid icon size %u\n", priv->stock_size);
        width = height = 24;
    }

    if (priv->icon_name)
        info = gtk_icon_theme_lookup_icon (icon_theme,
                                           priv->icon_name,
                                           MIN (width, height),
                                           GTK_ICON_LOOKUP_USE_BUILTIN);
    else if (priv->gicon)
        info = gtk_icon_theme_lookup_by_gicon (icon_theme,
                                               priv->gicon,
                                               MIN (width, height),
                                               GTK_ICON_LOOKUP_USE_BUILTIN);
    else
        info = NULL;

    if (info)
    {
        GtkStyleContext *context;

        context = gtk_widget_get_style_context (GTK_WIDGET (widget));
        priv->pixbuf = gtk_icon_info_load_symbolic_for_context (info,
                                                                context,
                                                                NULL,
                                                                NULL);
        gtk_icon_info_free (info);
    }

    g_object_notify (G_OBJECT (cellpixbuf), "pixbuf");
}

static GdkPixbuf *
create_symbolic_pixbuf (MarlinIconRenderer *cellpixbuf,
                        GtkWidget             *widget,
                        GtkStateFlags          state)
{
    MarlinIconRendererPrivate *priv = cellpixbuf->priv;
    GdkScreen *screen;
    GtkIconTheme *icon_theme;
    GtkSettings *settings;
    gint width, height;
    GtkIconInfo *info;
    GdkPixbuf *pixbuf;
    gboolean is_symbolic;

    screen = gtk_widget_get_screen (GTK_WIDGET (widget));
    icon_theme = gtk_icon_theme_get_for_screen (screen);
    settings = gtk_settings_get_for_screen (screen);

    if (!gtk_icon_size_lookup_for_settings (settings,
                                            priv->stock_size,
                                            &width, &height))
    {
        g_warning ("Invalid icon size %u\n", priv->stock_size);
        width = height = 24;
    }


    if (priv->icon_name)
        info = gtk_icon_theme_lookup_icon (icon_theme,
                                           priv->icon_name,
                                           MIN (width, height),
                                           GTK_ICON_LOOKUP_USE_BUILTIN);
    else if (priv->gicon)
        info = gtk_icon_theme_lookup_by_gicon (icon_theme,
                                               priv->gicon,
                                               MIN (width, height),
                                               GTK_ICON_LOOKUP_USE_BUILTIN);
    else
        return NULL;

    if (info)
    {
        GtkStyleContext *context;

        context = gtk_widget_get_style_context (GTK_WIDGET (widget));

        gtk_style_context_save (context);
        gtk_style_context_set_state (context, state);
        pixbuf = gtk_icon_info_load_symbolic_for_context (info,
                                                          context,
                                                          &is_symbolic,
                                                          NULL);

        gtk_style_context_restore (context);
        gtk_icon_info_free (info);

        if (!is_symbolic)
            g_clear_object (&pixbuf);

        return pixbuf;
    }

    return NULL;
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

    if (!priv->pixbuf)
    {
        if (priv->stock_id)
            marlin_icon_renderer_create_stock_pixbuf (cellpixbuf, widget);
        else if (priv->icon_name || priv->gicon)
            marlin_icon_renderer_create_themed_pixbuf (cellpixbuf, widget);
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

    if (width)
        *width = calc_width;

    if (height)
        *height = calc_height;
}

static GdkPixbuf *
transform_pixbuf_state (GdkPixbuf *pixbuf,
                        GtkStyleContext *context)
{
    GtkIconSource *source;
    GdkPixbuf *retval;

    source = gtk_icon_source_new ();
    gtk_icon_source_set_pixbuf (source, pixbuf);
    /* The size here is arbitrary; since size isn't
     * wildcarded in the source, it isn't supposed to be
     * scaled by the engine function
     */
    gtk_icon_source_set_size (source, GTK_ICON_SIZE_SMALL_TOOLBAR);
    gtk_icon_source_set_size_wildcarded (source, FALSE);

    retval = gtk_render_icon_pixbuf (context, source,
                                     (GtkIconSize) -1);

    gtk_icon_source_free (source);

    return retval;
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
    GdkRectangle draw_rect;
    gint xpad, ypad;
    GtkStateFlags state;

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

    pixbuf = priv->pixbuf;
    if (!pixbuf)
        return;

    g_object_ref (pixbuf);

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
    NautilusIconInfo *nicon;

    if (priv->selection_helpers &&
        (flags & GTK_CELL_RENDERER_PRELIT) != 0)
    {
        if ((flags & GTK_CELL_RENDERER_SELECTED) != 0)
            nicon = nautilus_icon_info_lookup_from_name ("remove", 16);
        else
            nicon = nautilus_icon_info_lookup_from_name ("add", 16);
        pix = nautilus_icon_info_get_pixbuf_nodefault (nicon);
        gdk_cairo_set_source_pixbuf (cr, pix, pix_rect.x, pix_rect.y);
        cairo_paint (cr);
        
        _g_object_unref0 (pix);
    }

}

//TODO emblem code snipped waiting to be integrated
#if 0
    /* check if we should render emblems as well */
    if (G_LIKELY (icon_renderer->emblems))
    {
        /* display the primary emblem as well (if any) */
        emblems = thunar_file_get_emblem_names (icon_renderer->file);
        if (G_UNLIKELY (emblems != NULL))
        {
            /* render up to four emblems for sizes from 48 onwards, else up to 2 emblems */
            max_emblems = (icon_renderer->size < 48) ? 2 : 4;

            /* render the emblems */
            for (lp = emblems, position = 0; lp != NULL && position < max_emblems; lp = lp->next)
            {
                /* check if we have the emblem in the icon theme */
                emblem = thunar_icon_factory_load_icon (icon_factory, lp->data, icon_renderer->size, NULL, FALSE);
                if (G_UNLIKELY (emblem == NULL))
                    continue;

                /* determine the dimensions of the emblem */
                emblem_area.width = gdk_pixbuf_get_width (emblem);
                emblem_area.height = gdk_pixbuf_get_height (emblem);

                /* shrink insane emblems */
                if (G_UNLIKELY (MAX (emblem_area.width, emblem_area.height) > (gint) MIN ((2 * icon_renderer->size) / 3, 36)))
                {
                    /* scale down the emblem */
                    temp = exo_gdk_pixbuf_scale_ratio (emblem, MIN ((2 * icon_renderer->size) / 3, 36));
                    g_object_unref (G_OBJECT (emblem));
                    emblem = temp;

                    /* determine the size again */
                    emblem_area.width = gdk_pixbuf_get_width (emblem);
                    emblem_area.height = gdk_pixbuf_get_height (emblem);
                }

                /* determine a good position for the emblem, depending on the position index */
                switch (position)
                {
                case 0: /* right/bottom */
                    emblem_area.x = MIN (icon_area.x + icon_area.width - emblem_area.width / 2,
                                         cell_area->x + cell_area->width - emblem_area.width);
                    emblem_area.y = MIN (icon_area.y + icon_area.height - emblem_area.height / 2,
                                         cell_area->y + cell_area->height -emblem_area.height);
                    break;

                case 1: /* left/bottom */
                    emblem_area.x = MAX (icon_area.x - emblem_area.width / 2,
                                         cell_area->x);
                    emblem_area.y = MIN (icon_area.y + icon_area.height - emblem_area.height / 2,
                                         cell_area->y + cell_area->height -emblem_area.height);
                    break;

                case 2: /* left/top */
                    emblem_area.x = MAX (icon_area.x - emblem_area.width / 2,
                                         cell_area->x);
                    emblem_area.y = MAX (icon_area.y - emblem_area.height / 2,
                                         cell_area->y);
                    break;

                case 3: /* right/top */
                    emblem_area.x = MIN (icon_area.x + icon_area.width - emblem_area.width / 2,
                                         cell_area->x + cell_area->width - emblem_area.width);
                    emblem_area.y = MAX (icon_area.y - emblem_area.height / 2,
                                         cell_area->y);
                    break;

                default:
                    _thunar_assert_not_reached ();
                }

                /* render the emblem */
                if (gdk_rectangle_intersect (expose_area, &emblem_area, &draw_area))
                {
                    gdk_draw_pixbuf (window, widget->style->black_gc, emblem,
                                     draw_area.x - emblem_area.x, draw_area.y - emblem_area.y,
                                     draw_area.x, draw_area.y, draw_area.width, draw_area.height,
                                     GDK_RGB_DITHER_NORMAL, 0, 0);
                }

                /* release the emblem */
                g_object_unref (G_OBJECT (emblem));

                /* advance the position index */
                ++position;
            }

            /* release the emblem name list */
            g_list_free (emblems);
        }
    }

    /* release our reference on the icon factory */
    g_object_unref (G_OBJECT (icon_factory));
#endif

