/* $Id$ */
/*-
 * Imported from thunar
 * Copyright (c) 2005 Benedikt Meurer <benny@xfce.org>
 * Copyright (c) 2009 Jannis Pohlmann <jannis@xfce.org>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2 of the License, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program; if not, write to the Free Software Foundation, Inc., 59 Temple
 * Place, Suite 330, Boston, MA  02111-1307  USA
 */

#ifndef __MARLIN_CLIPBOARD_MANAGER_H__
#define __MARLIN_CLIPBOARD_MANAGER_H__

#include <glib-object.h>
#include <gtk/gtk.h>
#include <gdk/gdk.h>
#include "gof-file.h"

typedef struct _MarlinClipboardManagerClass MarlinClipboardManagerClass;
typedef struct _MarlinClipboardManager      MarlinClipboardManager;

#define MARLIN_TYPE_CLIPBOARD_MANAGER             (marlin_clipboard_manager_get_type ())
#define MARLIN_CLIPBOARD_MANAGER(obj)             (G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_TYPE_CLIPBOARD_MANAGER, MarlinClipboardManager))
#define MARLIN_CLIPBOARD_MANAGER_CLASS(klass)     (G_TYPE_CHECK_CLASS_CAST ((obj), MARLIN_TYPE_CLIPBOARD_MANAGER, MarlinClipboardManagerClass))
#define MARLIN_IS_CLIPBOARD_MANAGER(obj)          (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_TYPE_CLIPBOARD_MANAGER))
#define MARLIN_IS_CLIPBAORD_MANAGER_CLASS(klass)  (G_TYPE_CHECK_CLASS_TYPE ((klass), MARLIN_TYPE_CLIPBOARD_MANAGER))
#define MARLIN_CLIPBOARD_MANAGER_GET_CLASS(obj)   (G_TYPE_INSTANCE_GET_CLASS ((obj), MARLIN_TYPE_CLIPBAORD_MANAGER, MarlinClipboardManagerClass))

GType                   marlin_clipboard_manager_get_type        (void) G_GNUC_CONST;

MarlinClipboardManager *marlin_clipboard_manager_new_get_for_display (GdkDisplay *display);

gboolean                marlin_clipboard_manager_get_can_paste   (MarlinClipboardManager *manager);

gboolean                marlin_clipboard_manager_has_cutted_file (MarlinClipboardManager *manager,
                                                                  const GOFFile          *file);

gboolean                marlin_clipboard_manager_has_file (MarlinClipboardManager *manager,
                                                           const GOFFile          *file);

void                    marlin_clipboard_manager_copy_files      (MarlinClipboardManager *manager,
                                                                  GList                  *files);
void                    marlin_clipboard_manager_cut_files       (MarlinClipboardManager *manager,
                                                                  GList                  *files);
void                    marlin_clipboard_manager_paste_files     (MarlinClipboardManager *manager,
                                                                  GFile                  *target_file,
                                                                  GtkWidget              *widget,
                                                                  GClosure               *new_files_closure);


#endif /* !__MARLIN_CLIPBOARD_MANAGER_H__ */
