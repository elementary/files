/*
 * Copyright (C) 2011 ammonkey
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
 * Author: ammonkey <am.monkeyd@gmail.com>
 */

#include <fm-compact-view.h>
#include "fm-directory-view.h"
#include "marlin-global-preferences.h"
#include "eel-i18n.h"

static AtkObject   *fm_compact_view_get_accessible (GtkWidget *widget);
static void         fm_compact_view_zoom_normal (FMDirectoryView *view);
static void         fm_compact_view_zoom_level_changed (FMDirectoryView *view);


G_DEFINE_TYPE (FMCompactView, fm_compact_view, FM_TYPE_ABSTRACT_ICON_VIEW)


static void
fm_compact_view_class_init (FMCompactViewClass *klass)
{
    FMDirectoryViewClass    *fm_directory_view_class;
    GtkWidgetClass          *gtkwidget_class;

    gtkwidget_class = GTK_WIDGET_CLASS (klass);
    gtkwidget_class->get_accessible = fm_compact_view_get_accessible;

    fm_directory_view_class = FM_DIRECTORY_VIEW_CLASS (klass);
    fm_directory_view_class->zoom_normal = fm_compact_view_zoom_normal;
    fm_directory_view_class->zoom_level_changed = fm_compact_view_zoom_level_changed;
}

static void
fm_compact_view_init (FMCompactView *compact_view)
{
    FMAbstractIconView *view = FM_ABSTRACT_ICON_VIEW (compact_view);

    /* initialize the icon view properties */
    exo_icon_view_set_layout_mode (view->icons, EXO_ICON_VIEW_LAYOUT_COLS);
    exo_icon_view_set_row_spacing (view->icons, 0);
    exo_icon_view_set_margin (view->icons, 3);
   
    g_object_set (G_OBJECT (compact_view), "text-beside-icons", TRUE, NULL);
    
    /* setup the icon renderer */
    g_object_set (FM_DIRECTORY_VIEW (view)->icon_renderer, "ypad", 0u, NULL);

    /* setup the name renderer (wrap only very long names) */
    g_object_set (FM_DIRECTORY_VIEW (view)->name_renderer,
                  "wrap-mode", PANGO_WRAP_WORD_CHAR,
                  "wrap-width", 1280,
                  "xalign", 0.0f,
                  "yalign", 0.5f,
                  NULL);

    g_settings_bind (marlin_compact_view_settings, "zoom-level", 
                     compact_view, "zoom-level", 0);

}

static AtkObject*
fm_compact_view_get_accessible (GtkWidget *widget)
{
    AtkObject *object;

    /* query the atk object for the icon view class */
    object = (*GTK_WIDGET_CLASS (fm_compact_view_parent_class)->get_accessible) (widget);

    /* set custom Atk properties for the icon view */
    if (G_LIKELY (object != NULL))
    {
        atk_object_set_description (object, _("Compact directory listing"));
        atk_object_set_name (object, _("Compact view"));
        atk_object_set_role (object, ATK_ROLE_DIRECTORY_PANE);
    }

    return object;
}

static void
fm_compact_view_zoom_normal (FMDirectoryView *view)
{
    MarlinZoomLevel     zoom;

    zoom = g_settings_get_enum (marlin_compact_view_settings, "default-zoom-level");
    g_settings_set_enum (marlin_compact_view_settings, "zoom-level", zoom);
}

static void 
fm_compact_view_zoom_level_changed (FMDirectoryView *view)
{
    g_return_if_fail (FM_IS_DIRECTORY_VIEW (view));

    /* set the zoom lvl for the name_renderer */
    g_object_set (FM_DIRECTORY_VIEW (view)->name_renderer, "zoom-level", view->zoom_level, NULL);

    /* set the new "size" for the icon renderer */
    g_object_set (FM_DIRECTORY_VIEW (view)->icon_renderer, "size", marlin_zoom_level_to_icon_size (view->zoom_level), NULL);

    exo_icon_view_invalidate_sizes (FM_ABSTRACT_ICON_VIEW (view)->icons);
}

