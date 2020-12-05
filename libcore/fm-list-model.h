/* fm-list-model.h - a GtkTreeModel for file lists.
 *
 * Copyright (C) 2001, 2002 Anders Carlsson
 * Copyright (C) 2003, Soeren Sandmann
 * Copyright (C) 2004, Novell, Inc.
 *
 * The Gnome Library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License as
 * published by the Free Software Foundation, Inc.,; either version 2 of the
 * License, or (at your option) any later version.
 *
 * The Gnome Library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with the Gnome Library; see the file COPYING.LIB.  If not,
 * write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
 * Boston, MA 02110-1335 USA.
 *
 * Authors: Anders Carlsson <andersca@gnu.org>,
 *          Soeren Sandmann (sandmann@daimi.au.dk),
 *          Dave Camp <dave@ximian.com>
 */

#ifndef FM_LIST_MODEL_H
#define FM_LIST_MODEL_H

#include <gtk/gtk.h>
#include <gdk/gdk.h>

typedef struct _GOFFile GOFFile;
typedef struct _GOFDirectoryAsync GOFDirectoryAsync;

#define FM_TYPE_LIST_MODEL fm_list_model_get_type()
G_DECLARE_DERIVABLE_TYPE (FMListModel, fm_list_model, FM, LIST_MODEL, GObject)

typedef enum {
    FM_LIST_MODEL_FILE_COLUMN,
    FM_LIST_MODEL_COLOR,
    FM_LIST_MODEL_PIXBUF,
    FM_LIST_MODEL_FILENAME,
    FM_LIST_MODEL_SIZE,
    FM_LIST_MODEL_TYPE,
    FM_LIST_MODEL_MODIFIED,
    FM_LIST_MODEL_NUM_COLUMNS
} FMListModelColumnID;

struct _FMListModelClass
{
  GObjectClass parent_class;

  void (* subdirectory_unloaded) (FMListModel *model,
                                  GOFDirectoryAsync *subdirectory);
};

gboolean fm_list_model_add_file                          (FMListModel *model, GOFFile *file, GOFDirectoryAsync *directory);
void     fm_list_model_file_changed                      (FMListModel *model, GOFFile *file, GOFDirectoryAsync *directory);
gboolean fm_list_model_is_empty                          (FMListModel *model);
guint    fm_list_model_get_length                        (FMListModel *model);
gboolean fm_list_model_remove_file                       (FMListModel       *model,
                                                          GOFFile           *file,
                                                          GOFDirectoryAsync *directory);
void     fm_list_model_clear                             (FMListModel *model);
gboolean fm_list_model_get_tree_iter_from_file           (FMListModel        *model,
                                                          GOFFile            *file,
                                                          GOFDirectoryAsync  *directory,
                                                          GtkTreeIter        *iter);
GList *  fm_list_model_get_all_iters_for_file            (FMListModel *model, GOFFile *file);
gboolean fm_list_model_get_first_iter_for_file           (FMListModel *model, GOFFile *file, GtkTreeIter *iter);
void     fm_list_model_set_should_sort_directories_first (FMListModel *model, gboolean sort_directories_first);

GOFFile *       fm_list_model_file_for_path (FMListModel *model, GtkTreePath *path);
GOFFile *       fm_list_model_file_for_iter (FMListModel *model, GtkTreeIter *iter);
gboolean        fm_list_model_get_directory_file (FMListModel *model, GtkTreePath *path,
                                                  GOFDirectoryAsync **directory, GOFFile **file);
gboolean        fm_list_model_load_subdirectory (FMListModel *model, GtkTreePath *path, GOFDirectoryAsync **directory);
void            fm_list_model_unload_subdirectory (FMListModel *model, GtkTreeIter *iter);

const gchar *       fm_list_model_column_id_to_string (FMListModelColumnID id);
FMListModelColumnID fm_list_model_column_id_from_string (const gchar *colstr);

#endif /* FM_LIST_MODEL_H */
