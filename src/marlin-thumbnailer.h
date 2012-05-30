/*-
 * Copyright (c) 2009-2011 Jannis Pohlmann <jannis@xfce.org>
 *
 * This program is free software; you can redistribute it and/or 
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of 
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

#ifndef __MARLIN_THUMBNAILER_H__
#define __MARLIN_THUMBNAILER_H__

#include "gof-file.h"

G_BEGIN_DECLS

typedef struct _MarlinThumbnailerClass MarlinThumbnailerClass;
typedef struct _MarlinThumbnailer      MarlinThumbnailer;

#define MARLIN_TYPE_THUMBNAILER            (marlin_thumbnailer_get_type ())
#define MARLIN_THUMBNAILER(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_TYPE_THUMBNAILER, MarlinThumbnailer))
#define MARLIN_THUMBNAILER_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass), MARLIN_TYPE_THUMBNAILER, MarlinThumbnailerClass))
#define MARLIN_IS_THUMBNAILER(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_TYPE_THUMBNAILER))
#define MARLIN_IS_THUMBNAILER_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), MARLIN_TYPE_THUMBNAILER))
#define MARLIN_THUMBNAILER_GET_CLASS(obj)  (G_TYPE_INSTANCE_GET_CLASS ((obj), MARLIN_TYPE_THUMBNAILER, MarlinThumbnailerClass))

GType              marlin_thumbnailer_get_type        (void) G_GNUC_CONST;

MarlinThumbnailer *marlin_thumbnailer_new             (void) G_GNUC_MALLOC;

MarlinThumbnailer *marlin_thumbnailer_get             (void) G_GNUC_MALLOC;

gboolean           marlin_thumbnailer_queue_file      (MarlinThumbnailer  *thumbnailer,
                                                       GOFFile            *file,
                                                       guint              *request,
                                                       gboolean large);
gboolean           marlin_thumbnailer_queue_files     (MarlinThumbnailer  *thumbnailer,
                                                       GList              *files,
                                                       guint              *request,
                                                       gboolean large);
void               marlin_thumbnailer_dequeue         (MarlinThumbnailer  *thumbnailer,
                                                       guint               request);

G_END_DECLS

#endif /* !__MARLIN_THUMBNAILER_H__ */
