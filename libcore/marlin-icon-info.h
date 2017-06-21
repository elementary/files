/* nautilus-icon-info.c
 * Copyright (C) 2007  Red Hat, Inc.,  Alexander Larsson <alexl@redhat.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation, Inc.,; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
 * Boston, MA 02110-1335 USA.
 */

#ifndef MARLIN_ICON_INFO_H
#define MARLIN_ICON_INFO_H

#include <glib-object.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <gdk/gdk.h>
#include <gio/gio.h>
#include <gtk/gtk.h>

G_BEGIN_DECLS

typedef struct _MarlinIconInfo      MarlinIconInfo;
typedef struct _MarlinIconInfoClass MarlinIconInfoClass;


#define MARLIN_TYPE_ICON_INFO                 (marlin_icon_info_get_type ())
#define MARLIN_ICON_INFO(obj)                 (G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_TYPE_ICON_INFO, MarlinIconInfo))
#define MARLIN_ICON_INFO_CLASS(klass)         (G_TYPE_CHECK_CLASS_CAST ((klass), MARLIN_TYPE_ICON_INFO, MarlinIconInfoClass))
#define MARLIN_IS_ICON_INFO(obj)              (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_TYPE_ICON_INFO))
#define MARLIN_IS_ICON_INFO_CLASS(klass)      (G_TYPE_CHECK_CLASS_TYPE ((klass), MARLIN_TYPE_ICON_INFO))
#define MARLIN_ICON_INFO_GET_CLASS(obj)       (G_TYPE_INSTANCE_GET_CLASS ((obj), MARLIN_TYPE_ICON_INFO, MarlinIconInfoClass))


GType    marlin_icon_info_get_type (void) G_GNUC_CONST;

MarlinIconInfo *    marlin_icon_info_new_for_pixbuf             (GdkPixbuf      *pixbuf);
MarlinIconInfo *    marlin_icon_info_lookup                     (GIcon          *icon,
                                                                 int            size);

MarlinIconInfo *    marlin_icon_info_lookup_from_name           (const char     *name,
                                                                 int            size);
MarlinIconInfo *    marlin_icon_info_lookup_from_path           (const char     *path,
                                                                 int            size);
MarlinIconInfo *    marlin_icon_info_get_generic_icon           (int size);

gboolean            marlin_icon_info_is_fallback                (MarlinIconInfo *icon);
//GdkPixbuf *         marlin_icon_info_get_pixbuf                 (MarlinIconInfo *icon);
GdkPixbuf *         marlin_icon_info_get_pixbuf_nodefault       (MarlinIconInfo *icon);
GdkPixbuf *         marlin_icon_info_get_pixbuf_force_size      (MarlinIconInfo *icon,
                                                                 gint           size,
                                                                 gboolean       force_size);
/*GdkPixbuf *           marlin_icon_info_get_pixbuf_nodefault_at_size (MarlinIconInfo  *icon,
  gsize              forced_size);*/
GdkPixbuf *         marlin_icon_info_get_pixbuf_at_size         (MarlinIconInfo *icon,
                                                                 gsize          forced_size);

void                marlin_icon_info_clear_caches               (void);
void                marlin_icon_info_remove_cache               (const char *path, int size);

G_END_DECLS

#endif /* MARLIN_ICON_INFO_H */

