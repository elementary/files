/* nautilus-file-conflict-dialog: dialog that handles file conflicts
 * during transfer operations.
 *
 * Copyright (C) 2008, Cosimo Cecchi
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, Inc.,; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
 * Boston, MA 02110-1335 USA.
 *
 * Authors: Cosimo Cecchi <cosimoc@gnome.org>
 */

#ifndef MARLIN_FILE_CONFLICT_DIALOG_H
#define MARLIN_FILE_CONFLICT_DIALOG_H

#include <glib-object.h>
#include <gio/gio.h>
#include <gtk/gtk.h>

#define MARLIN_TYPE_FILE_CONFLICT_DIALOG \
    (marlin_file_conflict_dialog_get_type ())
#define MARLIN_FILE_CONFLICT_DIALOG(o) \
    (G_TYPE_CHECK_INSTANCE_CAST ((o), MARLIN_TYPE_FILE_CONFLICT_DIALOG,\
                                 MarlinFileConflictDialog))
#define MARLIN_FILE_CONFLICT_DIALOG_CLASS(k) \
    (G_TYPE_CHECK_CLASS_CAST((k), MARLIN_TYPE_FILE_CONFLICT_DIALOG,\
                             MarlinFileConflictDialogClass))
#define MARLIN_IS_FILE_CONFLICT_DIALOG(o) \
    (G_TYPE_CHECK_INSTANCE_TYPE ((o), MARLIN_TYPE_FILE_CONFLICT_DIALOG))
#define MARLIN_IS_FILE_CONFLICT_DIALOG_CLASS(k) \
    (G_TYPE_CHECK_CLASS_TYPE ((k), MARLIN_TYPE_FILE_CONFLICT_DIALOG))
#define MARLIN_FILE_CONFLICT_DIALOG_GET_CLASS(o) \
    (G_TYPE_INSTANCE_GET_CLASS ((o), MARLIN_TYPE_FILE_CONFLICT_DIALOG,\
                                MarlinFileConflictDialogClass))

typedef struct _MarlinFileConflictDialog        MarlinFileConflictDialog;
typedef struct _MarlinFileConflictDialogClass   MarlinFileConflictDialogClass;
typedef struct _MarlinFileConflictDialogDetails MarlinFileConflictDialogDetails;

struct _MarlinFileConflictDialog {
    GtkDialog parent;
    MarlinFileConflictDialogDetails *details;
};

struct _MarlinFileConflictDialogClass {
    GtkDialogClass parent_class;
};

enum
{
    CONFLICT_RESPONSE_SKIP = 1,
    CONFLICT_RESPONSE_REPLACE = 2,
    CONFLICT_RESPONSE_RENAME = 3,
};

GType marlin_file_conflict_dialog_get_type (void) G_GNUC_CONST;

GtkWidget* marlin_file_conflict_dialog_new              (GtkWindow *parent,
                                                         GFile *source,
                                                         GFile *destination,
                                                         GFile *dest_dir);
char*      marlin_file_conflict_dialog_get_new_name     (MarlinFileConflictDialog *dialog);
gboolean   marlin_file_conflict_dialog_get_apply_to_all (MarlinFileConflictDialog *dialog);

#endif /* MARLIN_FILE_CONFLICT_DIALOG_H */
