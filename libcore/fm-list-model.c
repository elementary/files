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

#include <string.h>
#include <gtk/gtk.h>
#include <glib.h>
#include "fm-list-model.h"
#include "pantheon-files-core.h"

enum {
    SUBDIRECTORY_UNLOADED,
    LAST_SIGNAL
};

enum {
    PROP_0,
    PROP_HAS_CHILD,
    PROP_SIZE,
};

static GQuark attribute_name_q,
              attribute_modification_date_q,
              attribute_date_modified_q;

static guint list_model_signals[LAST_SIGNAL] = { 0 };

static void     fm_list_model_get_property (GObject    *object,
                                            guint       prop_id,
                                            GValue     *value,
                                            GParamSpec *pspec);
static void     fm_list_model_set_property (GObject      *object,
                                            guint         prop_id,
                                            const GValue *value,
                                            GParamSpec   *pspec);
static int      fm_list_model_file_entry_compare_func (gconstpointer a,
                                                       gconstpointer b,
                                                       gpointer      user_data);
static void     fm_list_model_tree_model_init (GtkTreeModelIface *iface);
static void     fm_list_model_drag_dest_init (GtkTreeDragDestIface *iface);
static void     fm_list_model_sortable_init (GtkTreeSortableIface *iface);

typedef struct {
    GSequence *files;
    GHashTable *directory_reverse_map; /* map from directory to GSequenceIter's */
    GHashTable *top_reverse_map;       /* map from files in top dir to GSequenceIter's */

    int stamp;
    gboolean        has_child;
    gint            sort_id;
    gint            icon_size;
    GtkSortType     order;

    gboolean sort_directories_first;
} FMListModelPrivate;

typedef struct FileEntry FileEntry;

struct FileEntry {
    GOFFile *file;
    GHashTable *reverse_map;    /* map from files to GSequenceIter's */
    GOFDirectoryAsync *subdirectory;
    FileEntry *parent;
    GSequence *files;
    GSequenceIter *ptr;
    guint loaded : 1;
};

G_DEFINE_TYPE_WITH_CODE (FMListModel, fm_list_model, G_TYPE_OBJECT,
                         G_IMPLEMENT_INTERFACE (GTK_TYPE_TREE_MODEL, fm_list_model_tree_model_init)
                         G_IMPLEMENT_INTERFACE (GTK_TYPE_TREE_DRAG_DEST, fm_list_model_drag_dest_init)
                         G_IMPLEMENT_INTERFACE (GTK_TYPE_TREE_SORTABLE, fm_list_model_sortable_init)
                         G_ADD_PRIVATE (FMListModel))

static void
file_entry_free (FileEntry *file_entry)
{
    g_clear_pointer (&file_entry->reverse_map, g_hash_table_unref);
    g_clear_object (&file_entry->subdirectory);
    g_clear_pointer (&file_entry->files, g_sequence_free);
    g_free (file_entry);
}

static GtkTreeModelFlags
fm_list_model_get_flags (GtkTreeModel *tree_model)
{
    return (GTK_TREE_MODEL_LIST_ONLY | GTK_TREE_MODEL_ITERS_PERSIST);
}

static int
fm_list_model_get_n_columns (GtkTreeModel *tree_model)
{
    return FM_LIST_MODEL_NUM_COLUMNS;
}

static GType
fm_list_model_get_column_type (GtkTreeModel *tree_model, int index)
{
    switch (index) {
    case FM_LIST_MODEL_FILE_COLUMN:
        return GOF_TYPE_FILE;
    case FM_LIST_MODEL_PIXBUF:
        return GDK_TYPE_PIXBUF;
    default:
        if (index < FM_LIST_MODEL_NUM_COLUMNS) {
            return G_TYPE_STRING;
        } else {
            return G_TYPE_INVALID;
        }
    }
}

static void
fm_list_model_ptr_to_iter (FMListModel *model, GSequenceIter *ptr, GtkTreeIter *iter)
{
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);

    g_assert (FM_IS_LIST_MODEL (model));
    g_assert (!g_sequence_iter_is_end (ptr));

    if (iter != NULL) {
        iter->stamp = priv->stamp;
        iter->user_data = ptr;
    } else {
    }
}

static gboolean
fm_list_model_get_iter (GtkTreeModel *tree_model, GtkTreeIter *iter, GtkTreePath *path)
{
    FMListModel *model = (FMListModel *) tree_model;
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);
    GSequence *files;
    GSequenceIter *ptr = NULL;
    FileEntry *file_entry;
    int i, d;

    g_assert (FM_IS_LIST_MODEL (tree_model));

    files = priv->files;
    for (d = 0; d < gtk_tree_path_get_depth (path); d++) {
        i = gtk_tree_path_get_indices (path)[d];

        if (files == NULL || i >= g_sequence_get_length (files)) {
            return FALSE;
        }

        ptr = g_sequence_get_iter_at_pos (files, i);
        file_entry = g_sequence_get (ptr);
        files = file_entry->files;
    }

    fm_list_model_ptr_to_iter (model, ptr, iter);

    return TRUE;
}

static GtkTreePath *
fm_list_model_get_path (GtkTreeModel *tree_model, GtkTreeIter *iter)
{
    FMListModel *model = (FMListModel *) tree_model;
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);
    GtkTreePath *path;
    GSequenceIter *ptr;
    FileEntry *file_entry;

    g_assert (FM_IS_LIST_MODEL (model));
    g_return_val_if_fail (iter->stamp == priv->stamp, NULL);

    if (g_sequence_iter_is_end (iter->user_data)) {
        /* is this right? */
        return NULL;
    }

    path = gtk_tree_path_new ();
    ptr = iter->user_data;
    while (ptr != NULL) {
        gtk_tree_path_prepend_index (path, g_sequence_iter_get_position (ptr));
        file_entry = g_sequence_get (ptr);
        if (file_entry->parent != NULL) {
            ptr = file_entry->parent->ptr;
        } else {
            ptr = NULL;
        }
    }

    return path;
}

static void
fm_list_model_get_value (GtkTreeModel *tree_model, GtkTreeIter *iter, int column, GValue *value)
{
    FMListModel *model = (FMListModel *)tree_model;
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);
    FileEntry *file_entry;
    GOFFile *file;

    g_assert (FM_IS_LIST_MODEL (model));
    g_assert (priv->stamp == iter->stamp);
    g_return_if_fail (!g_sequence_iter_is_end (iter->user_data));

    file_entry = g_sequence_get (iter->user_data);
    file = file_entry->file;

    switch (column) {
    case FM_LIST_MODEL_FILE_COLUMN:
        g_value_init (value, GOF_TYPE_FILE);
        if (file != NULL && GOF_IS_FILE(file))
            g_value_set_object (value, file);
        break;

    case FM_LIST_MODEL_COLOR:
        g_value_init (value, G_TYPE_STRING);
        if (file != NULL && file->color >= 0 && file->color < sizeof(GOF_PREFERENCES_TAGS_COLORS)/sizeof(gchar*))
            g_value_set_string(value, GOF_PREFERENCES_TAGS_COLORS[file->color]);
        break;

    case FM_LIST_MODEL_FILENAME:
        g_value_init (value, G_TYPE_STRING);
        if (file != NULL)
            g_value_set_string(value, gof_file_get_display_name (file));
        break;

    case FM_LIST_MODEL_SIZE:
        g_value_init (value, G_TYPE_STRING);
        if (file != NULL)
            g_value_set_string(value, file->format_size);
        break;

    case FM_LIST_MODEL_TYPE:
        g_value_init (value, G_TYPE_STRING);
        if (file != NULL)
            g_value_set_string(value, file->formated_type);
        break;

    case FM_LIST_MODEL_MODIFIED:
        g_value_init (value, G_TYPE_STRING);
        if (file != NULL)
            g_value_set_string(value, file->formated_modified);
        break;

    case FM_LIST_MODEL_PIXBUF:
        g_value_init (value, GDK_TYPE_PIXBUF);
        if (file != NULL) {
            gof_file_update_icon (file, priv->icon_size, file->pix_scale);
            if (file->pix != NULL)
                g_value_set_object(value, file->pix);
        }
        break;

    }
}

static gboolean
fm_list_model_iter_next (GtkTreeModel *tree_model, GtkTreeIter *iter)
{
    FMListModel *model = (FMListModel *)tree_model;
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);

    g_assert (FM_IS_LIST_MODEL (model));
    g_return_val_if_fail (priv->stamp == iter->stamp, FALSE);

    iter->user_data = g_sequence_iter_next (iter->user_data);

    return !g_sequence_iter_is_end (iter->user_data);
}

static gboolean
fm_list_model_iter_children (GtkTreeModel *tree_model, GtkTreeIter *iter, GtkTreeIter *parent)
{
    FMListModel *model = (FMListModel *)tree_model;
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);
    GSequence *files;
    FileEntry *file_entry;

    g_assert (FM_IS_LIST_MODEL (model));

    if (parent == NULL) {
        files = priv->files;
    } else {
        file_entry = g_sequence_get (parent->user_data);
        files = file_entry->files;
    }

    if (files == NULL || g_sequence_get_length (files) == 0) {
        return FALSE;
    }

    iter->stamp = priv->stamp;
    iter->user_data = g_sequence_get_begin_iter (files);

    return TRUE;
}

static gboolean
fm_list_model_iter_has_child (GtkTreeModel *tree_model, GtkTreeIter *iter)
{
    FMListModel *model = (FMListModel *)tree_model;
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);
    FileEntry *file_entry;

    g_assert (FM_IS_LIST_MODEL (model));

    if (!priv->has_child)
        return FALSE;

    if (iter == NULL) {
        return !fm_list_model_is_empty (FM_LIST_MODEL (tree_model));
    }

    file_entry = g_sequence_get (iter->user_data);
    return (file_entry->files != NULL && g_sequence_get_length (file_entry->files) > 0);
}

static int
fm_list_model_iter_n_children (GtkTreeModel *tree_model, GtkTreeIter *iter)
{
    FMListModel *model = (FMListModel *)tree_model;
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);
    GSequence *files;
    FileEntry *file_entry;

    g_assert (FM_IS_LIST_MODEL (model));

    if (iter == NULL) {
        files = priv->files;
    } else {
        file_entry = g_sequence_get (iter->user_data);
        files = file_entry->files;
    }

    return g_sequence_get_length (files);
}

static gboolean
fm_list_model_iter_nth_child (GtkTreeModel *tree_model, GtkTreeIter *iter, GtkTreeIter *parent, int n)
{
    FMListModel *model = (FMListModel *)tree_model;
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);
    GSequenceIter *child;
    GSequence *files;
    FileEntry *file_entry;

    g_assert (FM_IS_LIST_MODEL (model));

    if (parent != NULL) {
        file_entry = g_sequence_get (parent->user_data);
        files = file_entry->files;
    } else {
        files = priv->files;
    }

    child = g_sequence_get_iter_at_pos (files, n);

    if (g_sequence_iter_is_end (child)) {
        return FALSE;
    }

    iter->stamp = priv->stamp;
    iter->user_data = child;

    return TRUE;
}

static gboolean
fm_list_model_iter_parent (GtkTreeModel *tree_model, GtkTreeIter *iter, GtkTreeIter *child)
{
    FMListModel *model = (FMListModel *)tree_model;
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);
    FileEntry *file_entry;

    g_assert (FM_IS_LIST_MODEL (model));

    file_entry = g_sequence_get (child->user_data);

    if (file_entry->parent == NULL) {
        return FALSE;
    }

    iter->stamp = priv->stamp;
    iter->user_data = file_entry->parent->ptr;

    return TRUE;
}

static GSequenceIter *
lookup_file (FMListModel *model, GOFFile *file, GOFDirectoryAsync *directory)
{
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);
    FileEntry *file_entry;
    GSequenceIter *ptr, *parent_ptr;

    g_assert (FM_IS_LIST_MODEL (model));
    g_assert (file != NULL);

    parent_ptr = NULL;
    if (directory) {
        parent_ptr = g_hash_table_lookup (priv->directory_reverse_map,
                                          directory);
    }

    if (parent_ptr) {
        file_entry = g_sequence_get (parent_ptr);
        g_assert (file_entry != NULL);
        ptr = g_hash_table_lookup (file_entry->reverse_map, file);
    } else {
        ptr = g_hash_table_lookup (priv->top_reverse_map, file);
    }

    if (ptr) {
        g_assert (((FileEntry *)g_sequence_get (ptr))->file == file);
    }

    return ptr;
}

struct GetIters {
    FMListModel *model;
    GOFFile *file;
    GList *iters;
};

static void
dir_to_iters (struct GetIters *data,
              GHashTable *reverse_map)
{
    GSequenceIter *ptr;

    ptr = g_hash_table_lookup (reverse_map, data->file);
    if (ptr) {
        GtkTreeIter *iter;
        iter = g_new0 (GtkTreeIter, 1);
        fm_list_model_ptr_to_iter (data->model, ptr, iter);
        data->iters = g_list_prepend (data->iters, iter);
    }
}

static void
file_to_iter_cb (gpointer  key,
                 gpointer  value,
                 gpointer  user_data)
{
    struct GetIters *data;
    FileEntry *dir_file_entry;

    data = user_data;
    dir_file_entry = g_sequence_get ((GSequenceIter *)value);
    dir_to_iters (data, dir_file_entry->reverse_map);
}

GList *
fm_list_model_get_all_iters_for_file (FMListModel *model, GOFFile *file)
{
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);
    struct GetIters data;

    g_return_val_if_fail (FM_IS_LIST_MODEL (model), NULL);

    data.file = file;
    data.model = model;
    data.iters = NULL;

    dir_to_iters (&data, priv->top_reverse_map);
    g_hash_table_foreach (priv->directory_reverse_map,
                          file_to_iter_cb, &data);

    return g_list_reverse (data.iters);
}

gboolean
fm_list_model_get_first_iter_for_file (FMListModel          *model,
                                       GOFFile              *file,
                                       GtkTreeIter          *iter)
{
    GList *list;
    gboolean res = FALSE;

    g_return_val_if_fail (FM_IS_LIST_MODEL (model), FALSE);

    list = fm_list_model_get_all_iters_for_file (model, file);
    if (list != NULL) {
        res = TRUE;
        *iter = *(GtkTreeIter *)list->data;
    }
    g_list_free_full (list, g_free);

    return res;
}

gboolean
fm_list_model_get_tree_iter_from_file (FMListModel *model, GOFFile *file,
                                       GOFDirectoryAsync *directory,
                                       GtkTreeIter *iter)
{
    GSequenceIter *ptr;

    g_return_val_if_fail (FM_IS_LIST_MODEL (model), FALSE);

    ptr = lookup_file (model, file, directory);
    if (!ptr) {
        return FALSE;
    }

    fm_list_model_ptr_to_iter (model, ptr, iter);

    return TRUE;
}

static int
fm_list_model_file_entry_compare_func (gconstpointer a,
                                       gconstpointer b,
                                       gpointer      user_data)
{
    FMListModel *model = (FMListModel *) user_data;
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);
    FileEntry *file_entry1 = (FileEntry *) a;
    FileEntry *file_entry2 = (FileEntry *) b;

    g_assert (FM_IS_LIST_MODEL (model));

    if (file_entry1->file != NULL && file_entry2->file != NULL) {

        return gof_file_compare_for_sort (file_entry1->file, file_entry2->file,
                                          priv->sort_id,
                                          priv->sort_directories_first,  /* Get value from GOF.Preferences */
                                          (priv->order == GTK_SORT_DESCENDING));

    } else if (file_entry1->file == NULL) {
        /* Dummy rows representing expanded empty directories have null files */
        return -1;
    } else {
        return 1;
    }
}

static void
fm_list_model_sort_file_entries (FMListModel *model, GSequence *files, GtkTreePath *path)
{
    GSequenceIter **old_order;
    GtkTreeIter iter;
    int *new_order;
    int length;
    int i;
    FileEntry *file_entry;
    gboolean has_iter;

    g_assert (FM_IS_LIST_MODEL (model));

    length = g_sequence_get_length (files);

    if (length <= 1) {
        return;
    }

    /* generate old order of GSequenceIter's */
    old_order = g_new (GSequenceIter *, length);
    for (i = 0; i < length; ++i) {
        GSequenceIter *ptr = g_sequence_get_iter_at_pos (files, i);

        file_entry = g_sequence_get (ptr);
        if (file_entry->files != NULL) {
            gtk_tree_path_append_index (path, i);
            fm_list_model_sort_file_entries (model, file_entry->files, path);
            gtk_tree_path_up (path);
        }

        old_order[i] = ptr;
    }

    /* sort */
    g_sequence_sort (files, fm_list_model_file_entry_compare_func, model);

    /* generate new order */
    new_order = g_new (int, length);
    /* Note: new_order[newpos] = oldpos */
    for (i = 0; i < length; ++i) {
        new_order[g_sequence_iter_get_position (old_order[i])] = i;
    }

    /* Let the world know about our new order */
    g_assert (new_order != NULL);

    has_iter = FALSE;
    if (gtk_tree_path_get_depth (path) != 0) {
        gboolean get_iter_result;
        has_iter = TRUE;
        get_iter_result = gtk_tree_model_get_iter (GTK_TREE_MODEL (model), &iter, path);
        g_assert (get_iter_result);
    }

    gtk_tree_model_rows_reordered (GTK_TREE_MODEL (model),
                                   path, has_iter ? &iter : NULL, new_order);

    g_free (old_order);
    g_free (new_order);
}

static void
fm_list_model_sort (FMListModel *model)
{
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);
    GtkTreePath *path;

    g_assert (FM_IS_LIST_MODEL (model));

    path = gtk_tree_path_new ();

    fm_list_model_sort_file_entries (model, priv->files, path);

    gtk_tree_path_free (path);
}

static gboolean
fm_list_model_get_sort_column_id (GtkTreeSortable *sortable,
                                  gint            *sort_column_id,
                                  GtkSortType     *order)
{
    FMListModel *model = (FMListModel *) sortable;
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);
    int id;

    g_assert (FM_IS_LIST_MODEL (model));

    id = priv->sort_id;

    if (id == -1) {
        return FALSE;
    }

    if (sort_column_id != NULL) {
        *sort_column_id = id;
    }

    if (order != NULL) {
        *order = priv->order;
    }

    return TRUE;
}

static void
fm_list_model_set_sort_column_id (GtkTreeSortable *sortable, gint sort_column_id, GtkSortType order)
{
    FMListModel *model = (FMListModel *) sortable;
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);

    g_assert (FM_IS_LIST_MODEL (model));

    priv->sort_id = sort_column_id;

    priv->order = order;

    fm_list_model_sort (model);
    gtk_tree_sortable_sort_column_changed (sortable);
}

static gboolean
fm_list_model_has_default_sort_func (GtkTreeSortable *sortable)
{
    return FALSE;
}

static void
add_dummy_row (FMListModel *model, FileEntry *parent_entry)
{
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);
    FileEntry *dummy_file_entry;
    GtkTreeIter iter;
    GtkTreePath *path;

    g_assert (FM_IS_LIST_MODEL (model));

    dummy_file_entry = g_new0 (FileEntry, 1);
    dummy_file_entry->parent = parent_entry;
    dummy_file_entry->ptr = g_sequence_insert_sorted (parent_entry->files, dummy_file_entry,
                                                      fm_list_model_file_entry_compare_func, model);
    iter.stamp = priv->stamp;
    iter.user_data = dummy_file_entry->ptr;

    path = gtk_tree_model_get_path (GTK_TREE_MODEL (model), &iter);
    gtk_tree_model_row_inserted (GTK_TREE_MODEL (model), path, &iter);
    gtk_tree_path_free (path);
}

gboolean
fm_list_model_add_file (FMListModel *model, GOFFile *file,
                        GOFDirectoryAsync *directory)
{
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);
    GtkTreeIter iter;
    GtkTreePath *path;
    FileEntry *file_entry;
    GSequenceIter *ptr, *parent_ptr;
    GSequence *files;
    gboolean replaced_dummy;
    GHashTable *parent_hash;

    g_return_val_if_fail (FM_IS_LIST_MODEL (model), FALSE);
    g_return_val_if_fail (file != NULL, FALSE);

    parent_ptr = g_hash_table_lookup (priv->directory_reverse_map,
                                      directory);
    if (parent_ptr) {
        file_entry = g_sequence_get (parent_ptr);
        ptr = g_hash_table_lookup (file_entry->reverse_map, file);
    } else {
        file_entry = NULL;
        ptr = g_hash_table_lookup (priv->top_reverse_map, file);
    }

    if (ptr != NULL) {
        return FALSE;
    }

    file_entry = g_new0 (FileEntry, 1);
    file_entry->file = file; /* Does not increase reference count */
    file_entry->parent = NULL;
    file_entry->subdirectory = NULL;
    file_entry->files = NULL;

    files = priv->files;
    parent_hash = priv->top_reverse_map;
    replaced_dummy = FALSE;

    if (parent_ptr != NULL) {
        file_entry->parent = g_sequence_get (parent_ptr);
        /* At this point we set loaded. Either we saw
         * "done" and ignored it waiting for this, or we do this
         * earlier, but then we replace the dummy row anyway,
         * so it doesn't matter */
        file_entry->parent->loaded = 1;
        parent_hash = file_entry->parent->reverse_map;
        files = file_entry->parent->files;
        if (g_sequence_get_length (files) == 1) { /* maybe the dummy row */
            GSequenceIter *dummy_ptr = g_sequence_get_iter_at_pos (files, 0);
            FileEntry *dummy_entry = g_sequence_get (dummy_ptr);
            if (dummy_entry->file == NULL) { /* it is the dummy row  - replace it */
                g_sequence_remove (dummy_ptr);
                replaced_dummy = TRUE;
            }
        }
    }
    file_entry->ptr = g_sequence_insert_sorted (files, file_entry,
                                                fm_list_model_file_entry_compare_func, model);

    g_hash_table_insert (parent_hash, file, file_entry->ptr);

    iter.stamp = priv->stamp;
    iter.user_data = file_entry->ptr;

    path = gtk_tree_model_get_path (GTK_TREE_MODEL (model), &iter);
    if (replaced_dummy) {
        gtk_tree_model_row_changed (GTK_TREE_MODEL (model), path, &iter);
    } else {
        gtk_tree_model_row_inserted (GTK_TREE_MODEL (model), path, &iter);
    }

    if (gof_file_is_folder (file)) {
        file_entry->files = g_sequence_new ((GDestroyNotify)file_entry_free);
        add_dummy_row (model, file_entry);
        gtk_tree_model_row_has_child_toggled (GTK_TREE_MODEL (model),
                                              path, &iter);
    }
    gtk_tree_path_free (path);
    return TRUE;
}

void
fm_list_model_file_changed (FMListModel *model, GOFFile *file,
                            GOFDirectoryAsync *directory)
{
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);
    FileEntry *parent_file_entry;
    GtkTreeIter iter;
    GtkTreePath *path, *parent_path;
    GSequenceIter *ptr;
    int pos_before, pos_after, length, i, old;
    int *new_order;
    gboolean has_iter;
    GSequence *files;

    g_return_if_fail (FM_IS_LIST_MODEL (model));

    ptr = lookup_file (model, file, directory);
    if (!ptr) {
        return;
    }


    pos_before = g_sequence_iter_get_position (ptr);

    g_sequence_sort_changed (ptr, fm_list_model_file_entry_compare_func, model);

    pos_after = g_sequence_iter_get_position (ptr);

    if (pos_before != pos_after) {
        /* The file moved, we need to send rows_reordered */

        parent_file_entry = ((FileEntry *)g_sequence_get (ptr))->parent;

        if (parent_file_entry == NULL) {
            has_iter = FALSE;
            parent_path = gtk_tree_path_new ();
            files = priv->files;
        } else {
            has_iter = TRUE;
            fm_list_model_ptr_to_iter (model, parent_file_entry->ptr, &iter);
            parent_path = gtk_tree_model_get_path (GTK_TREE_MODEL (model), &iter);
            files = parent_file_entry->files;
        }

        length = g_sequence_get_length (files);
        new_order = g_new (int, length);
        /* Note: new_order[newpos] = oldpos */
        for (i = 0, old = 0; i < length; ++i) {
            if (i == pos_after) {
                new_order[i] = pos_before;
            } else {
                if (old == pos_before)
                    old++;
                new_order[i] = old++;
            }
        }

        gtk_tree_model_rows_reordered (GTK_TREE_MODEL (model),
                                       parent_path, has_iter ? &iter : NULL, new_order);

        gtk_tree_path_free (parent_path);
        g_free (new_order);
    }

    fm_list_model_ptr_to_iter (model, ptr, &iter);
    path = gtk_tree_model_get_path (GTK_TREE_MODEL (model), &iter);
    gtk_tree_model_row_changed (GTK_TREE_MODEL (model), path, &iter);
    gtk_tree_path_free (path);
}

gboolean
fm_list_model_is_empty (FMListModel *model)
{
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);

    g_return_val_if_fail (FM_IS_LIST_MODEL (model), TRUE);

    return (g_sequence_get_length (priv->files) == 0);
}

guint
fm_list_model_get_length (FMListModel *model)
{
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);

    g_return_val_if_fail (FM_IS_LIST_MODEL (model), 0);

    return g_sequence_get_length (priv->files);
}

static void
fm_list_model_remove (FMListModel *model, GtkTreeIter *iter)
{
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);
    GSequenceIter *ptr, *child_ptr;
    FileEntry *file_entry, *child_file_entry, *parent_file_entry;
    GtkTreePath *path;
    GtkTreeIter parent_iter;

    g_assert (FM_IS_LIST_MODEL (model));
    g_return_if_fail (iter->stamp == priv->stamp);

    ptr = iter->user_data;
    file_entry = g_sequence_get (ptr);
    if (file_entry->files != NULL) {
        while (g_sequence_get_length (file_entry->files) > 0) {
            child_ptr = g_sequence_get_begin_iter (file_entry->files);
            child_file_entry = g_sequence_get (child_ptr);
            if (child_file_entry->file != NULL) {
                fm_list_model_remove_file (model,
                                           child_file_entry->file,
                                           file_entry->subdirectory);
            } else {
                path = gtk_tree_model_get_path (GTK_TREE_MODEL (model), iter);
                gtk_tree_path_append_index (path, 0);
                g_sequence_remove (child_ptr);
                gtk_tree_model_row_deleted (GTK_TREE_MODEL (model), path);
                gtk_tree_path_free (path);
            }

            /* the parent iter didn't actually change */
            iter->stamp = priv->stamp;
        }

    }

    if (file_entry->file != NULL) { /* Don't try to remove dummy row */
        if (file_entry->parent != NULL) {
            g_hash_table_remove (file_entry->parent->reverse_map, file_entry->file);
        } else {
            g_hash_table_remove (priv->top_reverse_map, file_entry->file);
        }
    }

    parent_file_entry = file_entry->parent;
    if (parent_file_entry && g_sequence_get_length (parent_file_entry->files) == 1 &&
        file_entry->file != NULL) {
        /* this is the last non-dummy child, add a dummy node */
        /* We need to do this before removing the last file to avoid
         * collapsing the row.
         */
        add_dummy_row (model, parent_file_entry);
    }
    /* We don't need to unref file here - we did not add a ref */

    if (file_entry->subdirectory != NULL) {
        g_signal_emit (model,
                       list_model_signals[SUBDIRECTORY_UNLOADED], 0,
                       file_entry->subdirectory);
        g_hash_table_remove (priv->directory_reverse_map,
                             file_entry->subdirectory);
    }

    path = gtk_tree_model_get_path (GTK_TREE_MODEL (model), iter);

    g_sequence_remove (ptr);
    gtk_tree_model_row_deleted (GTK_TREE_MODEL (model), path);

    gtk_tree_path_free (path);
}

gboolean
fm_list_model_remove_file (FMListModel *model, GOFFile *file,
                           GOFDirectoryAsync *directory)
{
    GtkTreeIter iter;

    g_return_val_if_fail (FM_IS_LIST_MODEL (model), FALSE);

    if (fm_list_model_get_tree_iter_from_file (model, file, directory, &iter)) {
        fm_list_model_remove (model, &iter);
        return TRUE;
    } else {
        return FALSE;
    }
}

static void
fm_list_model_clear_directory (FMListModel *model, GSequence *files)
{
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);
    GtkTreeIter iter;
    FileEntry *file_entry;

    g_return_if_fail (FM_IS_LIST_MODEL (model));

    while (g_sequence_get_length (files) > 0) {
        iter.user_data = g_sequence_get_begin_iter (files);

        file_entry = g_sequence_get (iter.user_data);
        if (file_entry->files != NULL) {
            fm_list_model_clear_directory (model, file_entry->files);
        }

        iter.stamp = priv->stamp;
        fm_list_model_remove (model, &iter);
    }
}

void
fm_list_model_clear (FMListModel *model)
{
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);

    g_return_if_fail (FM_IS_LIST_MODEL (model));

    fm_list_model_clear_directory (model, priv->files);
}

GOFFile *
fm_list_model_file_for_path (FMListModel *model, GtkTreePath *path)
{
    GOFFile *file = NULL;
    GtkTreeIter iter;

    g_return_val_if_fail (FM_IS_LIST_MODEL (model), NULL);

    if (gtk_tree_model_get_iter (GTK_TREE_MODEL (model), &iter, path)) {
        gtk_tree_model_get (GTK_TREE_MODEL (model),
                            &iter,
                            FM_LIST_MODEL_FILE_COLUMN, &file,
                            -1);
    }

    return file;
}

GOFFile *
fm_list_model_file_for_iter (FMListModel *model, GtkTreeIter *iter)
{
    GOFFile *file = NULL;

    g_return_val_if_fail (FM_IS_LIST_MODEL (model), NULL);

    gtk_tree_model_get (GTK_TREE_MODEL (model), iter,
                        FM_LIST_MODEL_FILE_COLUMN, &file, -1);
    return file;
}

gboolean
fm_list_model_get_directory_file (FMListModel *model, GtkTreePath *path, GOFDirectoryAsync **directory, GOFFile **file)
{
    GtkTreeIter iter;
    FileEntry *file_entry;

    *directory = NULL;
    *file = NULL;

    g_return_val_if_fail (FM_IS_LIST_MODEL (model), NULL);

    if (!gtk_tree_model_get_iter (GTK_TREE_MODEL (model), &iter, path)) {;
        return FALSE;
    }

    file_entry = g_sequence_get (iter.user_data);
    *directory = file_entry->subdirectory;
    *file = file_entry->file;

    return TRUE;
}

gboolean
fm_list_model_load_subdirectory (FMListModel *model, GtkTreePath *path, GOFDirectoryAsync **directory)
{
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);
    GtkTreeIter iter;
    FileEntry *file_entry;

    g_return_val_if_fail (FM_IS_LIST_MODEL (model), FALSE);

    if (!gtk_tree_model_get_iter (GTK_TREE_MODEL (model), &iter, path)) {
        return FALSE;
    }

    file_entry = g_sequence_get (iter.user_data);
    if (file_entry->file == NULL ||
        file_entry->subdirectory != NULL) {
        return FALSE;
    }

    file_entry->subdirectory = gof_directory_async_from_file (file_entry->file);

    g_hash_table_insert (priv->directory_reverse_map,
                         file_entry->subdirectory, file_entry->ptr);
    file_entry->reverse_map = g_hash_table_new (g_direct_hash, g_direct_equal);

    *directory = file_entry->subdirectory; /* AbstractDirectoryView will maintain another reference on this */
    return TRUE;
}

/* removes all children of the subfolder and unloads the subdirectory */
void
fm_list_model_unload_subdirectory (FMListModel *model, GtkTreeIter *iter)
{
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);
    GSequenceIter *child_ptr;
    FileEntry *file_entry, *child_file_entry;
    GtkTreeIter child_iter;

    g_return_if_fail (FM_IS_LIST_MODEL (model));

    file_entry = g_sequence_get (iter->user_data);
    if (file_entry->file == NULL ||
        file_entry->subdirectory == NULL) {
        return;
    }

    gof_directory_async_cancel (file_entry->subdirectory);
    g_hash_table_remove (priv->directory_reverse_map,
                         file_entry->subdirectory);
    file_entry->loaded = 0;

    /* Remove all children */
    while (g_sequence_get_length (file_entry->files) > 0) {
        child_ptr = g_sequence_get_begin_iter (file_entry->files);
        child_file_entry = g_sequence_get (child_ptr);
        if (child_file_entry->file == NULL) {
            /* Don't delete the dummy node */
            break;
        } else {
            fm_list_model_ptr_to_iter (model, child_ptr, &child_iter);
            fm_list_model_remove (model, &child_iter);
        }
    }

    /* Emit unload signal */
    g_signal_emit (model,
                   list_model_signals[SUBDIRECTORY_UNLOADED], 0,
                   file_entry->subdirectory);

    g_object_unref (file_entry->subdirectory); /* AbstractDirectoryView will also release its reference */
    file_entry->subdirectory = NULL;
    g_assert (g_hash_table_size (file_entry->reverse_map) == 0);
    g_hash_table_destroy (file_entry->reverse_map);
    file_entry->reverse_map = NULL;
}

void
fm_list_model_set_should_sort_directories_first (FMListModel *model, gboolean sort_directories_first)
{
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);

    g_return_if_fail (FM_IS_LIST_MODEL (model));

    if (priv->sort_directories_first == sort_directories_first) {
        return;
    }

    priv->sort_directories_first = sort_directories_first;
    fm_list_model_sort (model);
}

static gboolean
fm_list_model_drag_data_received (GtkTreeDragDest  *dest,
                                  GtkTreePath      *path,
                                  GtkSelectionData *data)
{
    return FALSE;
}

static gboolean
fm_list_model_row_drop_possible (GtkTreeDragDest  *dest,
                                 GtkTreePath      *path,
                                 GtkSelectionData *data)
{
    return FALSE;
}


static void
fm_list_model_dispose (GObject *object)
{
    FMListModel *model = FM_LIST_MODEL (object);
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);

    g_clear_pointer (&priv->files, g_sequence_free);
    g_clear_pointer (&priv->top_reverse_map, g_hash_table_unref);
    g_clear_pointer (&priv->directory_reverse_map, g_hash_table_unref);

    G_OBJECT_CLASS (fm_list_model_parent_class)->dispose (object);
}

static void
fm_list_model_init (FMListModel *model)
{
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);

    priv->files = g_sequence_new ((GDestroyNotify)file_entry_free);
    priv->top_reverse_map = g_hash_table_new (g_direct_hash, g_direct_equal);
    priv->directory_reverse_map = g_hash_table_new (g_direct_hash, g_direct_equal);
    priv->stamp = g_random_int ();
    priv->sort_id = FM_LIST_MODEL_FILENAME;
    priv->order = GTK_SORT_ASCENDING;
    priv->sort_directories_first = TRUE;
}

static void
fm_list_model_class_init (FMListModelClass *klass)
{
    GObjectClass *object_class = (GObjectClass *)klass;

    attribute_name_q = g_quark_from_static_string ("name");
    attribute_modification_date_q = g_quark_from_static_string ("modification_date");
    attribute_date_modified_q = g_quark_from_static_string ("date_modified");

    object_class->dispose = fm_list_model_dispose;
    object_class->get_property = fm_list_model_get_property;
    object_class->set_property = fm_list_model_set_property;

    g_object_class_install_property (object_class,
                                     PROP_HAS_CHILD,
                                     g_param_spec_boolean ("has-child",
                                                           "has-child",
                                                           "Whether the model list has child(s) and the treeview can expand subfolders",
                                                           FALSE,
                                                           G_PARAM_READWRITE));

    g_object_class_install_property (object_class,
                                     PROP_SIZE,
                                     g_param_spec_int ("size", "size", "icon size",
                                                        16,  256,
                                                        32,
                                                        G_PARAM_READWRITE));


    list_model_signals[SUBDIRECTORY_UNLOADED] =
        g_signal_new ("subdirectory_unloaded",
                      FM_TYPE_LIST_MODEL,
                      G_SIGNAL_RUN_FIRST,
                      G_STRUCT_OFFSET (FMListModelClass, subdirectory_unloaded),
                      NULL, NULL,
                      g_cclosure_marshal_VOID__OBJECT,
                      G_TYPE_NONE, 1,
                      GOF_DIRECTORY_TYPE_ASYNC);
}

static void
fm_list_model_tree_model_init (GtkTreeModelIface *iface)
{
    iface->get_flags = fm_list_model_get_flags;
    iface->get_n_columns = fm_list_model_get_n_columns;
    iface->get_column_type = fm_list_model_get_column_type;
    iface->get_iter = fm_list_model_get_iter;
    iface->get_path = fm_list_model_get_path;
    iface->get_value = fm_list_model_get_value;
    iface->iter_next = fm_list_model_iter_next;
    iface->iter_children = fm_list_model_iter_children;
    iface->iter_has_child = fm_list_model_iter_has_child;
    iface->iter_n_children = fm_list_model_iter_n_children;
    iface->iter_nth_child = fm_list_model_iter_nth_child;
    iface->iter_parent = fm_list_model_iter_parent;
}

static void
fm_list_model_drag_dest_init (GtkTreeDragDestIface *iface)
{
    iface->drag_data_received = fm_list_model_drag_data_received;
    iface->row_drop_possible = fm_list_model_row_drop_possible;
}

static void
fm_list_model_sortable_init (GtkTreeSortableIface *iface)
{
    iface->get_sort_column_id = fm_list_model_get_sort_column_id;
    iface->set_sort_column_id = fm_list_model_set_sort_column_id;
    iface->has_default_sort_func = fm_list_model_has_default_sort_func;
}

static void
fm_list_model_set_has_child (FMListModel *model, gboolean has_child)
{
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);

    g_return_if_fail (FM_IS_LIST_MODEL (model));

    priv->has_child = has_child;
}

static void
fm_list_model_set_icon_size (FMListModel *model, gint size)
{
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);

    g_return_if_fail (FM_IS_LIST_MODEL (model));

    priv->icon_size = size;
}

static void
fm_list_model_get_property (GObject    *object,
                            guint       prop_id,
                            GValue     *value,
                            GParamSpec *pspec)
{
    FMListModel *model = FM_LIST_MODEL (object);
    FMListModelPrivate *priv = fm_list_model_get_instance_private (model);

    switch (prop_id)
    {
    case PROP_HAS_CHILD:
        g_value_set_boolean (value, priv->has_child);
        break;

    case PROP_SIZE:
        g_value_set_int (value, priv->icon_size);
        break;

    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
        break;
    }
}

static void
fm_list_model_set_property (GObject      *object,
                            guint         prop_id,
                            const GValue *value,
                            GParamSpec   *pspec)
{
    FMListModel *model = FM_LIST_MODEL (object);

    switch (prop_id)
    {
    case PROP_HAS_CHILD:
        fm_list_model_set_has_child (model, g_value_get_boolean (value));
        break;

    case PROP_SIZE:
        fm_list_model_set_icon_size (model, g_value_get_int (value));
        break;

    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
        break;
    }
}

const gchar *
fm_list_model_column_id_to_string (FMListModelColumnID id)
{
    switch (id) {
    case FM_LIST_MODEL_FILENAME:
        return "name";
    case FM_LIST_MODEL_SIZE:
        return "size";
    case FM_LIST_MODEL_TYPE:
        return "type";
    case FM_LIST_MODEL_MODIFIED:
        return "modified";
    case FM_LIST_MODEL_PIXBUF:
        return "pixbuf";
    }

    g_return_val_if_reached ("name");
}

FMListModelColumnID
fm_list_model_column_id_from_string (const gchar *colstr)
{
    if (g_strcmp0 (colstr, "name") == 0) {
        return FM_LIST_MODEL_FILENAME;
    } else if (g_strcmp0 (colstr, "size") == 0) {
        return FM_LIST_MODEL_SIZE;
    } else if (g_strcmp0 (colstr, "type") == 0) {
        return FM_LIST_MODEL_TYPE;
    } else if (g_strcmp0 (colstr, "modified") == 0) {
        return FM_LIST_MODEL_MODIFIED;
    }

    g_return_val_if_reached (FM_LIST_MODEL_FILENAME);
}
