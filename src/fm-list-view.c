/*
 * Copyright (C) 2010 ammonkey
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

#include "fm-list-view.h"
#include "fm-list-model.h"
#include "fm-directory-view.h"
#include "marlin-global-preferences.h"
#include "eel-i18n.h"
#include <gdk/gdk.h>
#include <gdk/gdkkeysyms.h>

#include "exo-tree-view.h"
//#include "gof-directory-async.h"
#include "nautilus-cell-renderer-text-ellipsized.h"
#include "eel-glib-extensions.h"
#include "marlin-tags.h"

/*
   struct FMListViewDetails {
   GtkTreeView     *tree;
   FMListModel     *model;
   };*/

/* We wait two seconds after row is collapsed to unload the subdirectory */
#define COLLAPSE_TO_UNLOAD_DELAY 2 

/* Wait for the rename to end when activating a file being renamed */
#define WAIT_FOR_RENAME_ON_ACTIVATE 200

static gchar *col_title[4] = { _("Filename"), _("Size"), _("Type"), _("Modified") };

//G_DEFINE_TYPE (FMListView, fm_list_view, G_TYPE_OBJECT)
/*#define GOF_DIRECTORY_ASYNC_GET_PRIVATE(obj) \
  (G_TYPE_INSTANCE_GET_PRIVATE(obj, GOF_TYPE_DIRECTORY_ASYNC, GOFDirectoryAsyncPrivate))*/

G_DEFINE_TYPE (FMListView, fm_list_view, FM_TYPE_DIRECTORY_VIEW);

#define parent_class fm_list_view_parent_class

struct UnloadDelayData {
    GOFFile *file;
    GOFDirectoryAsync *directory;
    FMListView *view;
};

/* Declaration Prototypes */
static GList    *fm_list_view_get_selection (FMListView *view);
//static void     fm_list_view_clear (FMListView *view);

#if 0
static gboolean
unload_file_timeout (gpointer data)
{
    struct UnloadDelayData *unload_data = data;
    FMListView *view = unload_data->view;
    GtkTreeIter *iter = &(unload_data->iter);
    GtkTreePath *path;

    path = gtk_tree_model_get_path (GTK_TREE_MODEL (view->model), iter);
    if (!gtk_tree_view_row_expanded (view->tree, path)) {
        log_printf (LOG_LEVEL_UNDEFINED, "unloadn");
        fm_list_model_unload_subdirectory (view->model, iter);
    }
    if (path != NULL)
        gtk_tree_path_free (path);
    g_free (unload_data);
    return FALSE;
}
#endif

static gboolean
unload_file_timeout (gpointer data)
{
    struct UnloadDelayData *unload_data = data;
    GtkTreeIter iter;
    FMListModel *model;
    GtkTreePath *path;

    if (unload_data->view != NULL) {
        model = unload_data->view->model;
        if (fm_list_model_get_tree_iter_from_file (model,
                                                   unload_data->file,
                                                   unload_data->directory,
                                                   &iter)) {
            path = gtk_tree_model_get_path (GTK_TREE_MODEL (model), &iter);
            if (!gtk_tree_view_row_expanded (unload_data->view->tree,
                                             path)) {
                fm_list_model_unload_subdirectory (model, &iter);
            }
            gtk_tree_path_free (path);
        }
    }
    eel_remove_weak_pointer (&unload_data->view);

    g_free (unload_data);
    return FALSE;
}

static void
row_expanded_callback (GtkTreeView *treeview, GtkTreeIter *iter, GtkTreePath *path, gpointer callback_data)
{
    FMListView *view;
    GOFDirectoryAsync *directory;

    view = FM_LIST_VIEW (callback_data);

    if (fm_list_model_load_subdirectory (view->model, path, &directory)) {
        fm_directory_view_add_subdirectory (FM_DIRECTORY_VIEW (view), directory);
    }
}

static void
row_collapsed_callback (GtkTreeView *treeview, GtkTreeIter *iter, GtkTreePath *path, gpointer callback_data)
{
    FMListView *view;
    struct UnloadDelayData *unload_data;

    view = FM_LIST_VIEW (callback_data);
    unload_data = g_new (struct UnloadDelayData, 1);
    unload_data->view = view;

    fm_list_model_get_directory_file (view->model, path, &unload_data->directory, &unload_data->file);

    //log_printf (LOG_LEVEL_UNDEFINED, "collapsed %s %s\n", unload_data->file->name, gof_directory_get_uri(unload_data->directory));

    eel_add_weak_pointer (&unload_data->view);
    g_timeout_add_seconds (COLLAPSE_TO_UNLOAD_DELAY,
                           unload_file_timeout,
                           unload_data);

    //fm_list_model_unload_subdirectory (view->model, iter);
}

/*static void
  show_selected_files (GOFFile *file)
  {
  log_printf (LOG_LEVEL_UNDEFINED, "selected: %s\n", file->name);
  }*/

static void
list_selection_changed_callback (GtkTreeSelection *selection, gpointer user_data)
{
    GtkTreeIter iter;
    GOFFile *file = NULL;
    FMListView *view = FM_LIST_VIEW (user_data);

    GList *paths = gtk_tree_selection_get_selected_rows (selection, NULL);
    if (paths!=NULL && gtk_tree_model_get_iter (GTK_TREE_MODEL(view->model), &iter, paths->data))   
    {
        gtk_tree_model_get (GTK_TREE_MODEL (view->model), &iter,
                            FM_LIST_MODEL_FILE_COLUMN, &file,
                            -1);
        //if (file != NULL) 
    }
    fm_directory_view_notify_selection_changed (FM_DIRECTORY_VIEW (view), file);

    g_list_foreach (paths, (GFunc) gtk_tree_path_free, NULL);
    g_list_free (paths);
}

static void
gof_gnome_open_single_file (GOFFile *file, GdkScreen *screen)
{
    char *uri, *quoted_uri, *cmd;

    if (g_file_is_native (file->location))
    {
        uri = g_filename_from_uri(g_file_get_uri(file->location), NULL, NULL);
        quoted_uri = g_shell_quote(uri);
        cmd = g_strconcat("gnome-open ", quoted_uri, NULL);
        g_free(quoted_uri);

        //printf("command %s\n", uri);
        gdk_spawn_command_line_on_screen (screen, cmd, NULL);
        g_free (uri);
        g_free (cmd);
    }
    else
    {
        log_printf (LOG_LEVEL_UNDEFINED, "non native\n");

        /* FIXME: work with all apps supporting gio 
           don't work with archives: opening a zip from trash with
           file-roller - happens too with nautilus */
        uri = g_file_get_uri(file->location);
        cmd = g_strconcat("gnome-open ", uri, NULL);
        printf("command %s\n", cmd);
        gdk_spawn_command_line_on_screen (screen, cmd, NULL);
        g_free (uri);
        g_free (cmd);
    }
}

static void
fm_directory_activate_single_file (GOFFile *file, FMListView *view, GdkScreen *screen)
{
    //GOFDirectoryAsync *dir;

    printf("%s\n", G_STRFUNC);
    if (file->is_directory) {
        //view->location = file->location;
        /*
           fm_list_view_clear(view);
           dir = gof_directory_async_new(view->location);*/
        /*fm_list_view_clear(view);
          gof_window_slot_change_location(view->slot, file->location);*/
        fm_directory_view_load_location (FM_DIRECTORY_VIEW (view), file->location);
    } else {
        gof_gnome_open_single_file (file, screen); 
    }

}

static void
activate_selected_items (FMListView *view)
{
    GList *file_list;
    GdkScreen *screen;
    GOFFile *file;

    file_list = fm_list_view_get_selection (view);

#if 0	
    if (view->details->renaming_file) {
        /* We're currently renaming a file, wait until the rename is
           finished, or the activation uri will be wrong */
        if (view->details->renaming_file_activate_timeout == 0) {
            view->details->renaming_file_activate_timeout =
                g_timeout_add (WAIT_FOR_RENAME_ON_ACTIVATE, (GSourceFunc) activate_selected_items, view);
        }
        return;
    }

    if (view->details->renaming_file_activate_timeout != 0) {
        g_source_remove (view->details->renaming_file_activate_timeout);
        view->details->renaming_file_activate_timeout = 0;
    }
#endif	
    /*fm_directory_view_activate_files (FM_DIRECTORY_VIEW (view),
      file_list,
      NAUTILUS_WINDOW_OPEN_ACCORDING_TO_MODE,
      0,
      TRUE);*/

    /* TODO add mountable etc */

    screen = gdk_screen_get_default();
    guint nb_elem = g_list_length (file_list);
    if (nb_elem == 1)
        fm_directory_activate_single_file(file_list->data, view, screen);
    else
    {
        /* ignore opening more than 10 elements at a time */
        if (nb_elem < 10)
            for (; file_list != NULL; file_list=file_list->next)
            {
                file = file_list->data;
                if (file->is_directory) {
                    /* TODO open dirs in new tabs */
                    log_printf (LOG_LEVEL_UNDEFINED, "open dir - new tab? %s\n", file->name);
                } else {
                    gof_gnome_open_single_file (file, screen);
                }
            }
    }

    gof_file_list_free (file_list);
}

static void
row_activated_callback (GtkTreeView *treeview, GtkTreeIter *iter, GtkTreePath *path, FMListView *view)
{
    log_printf (LOG_LEVEL_UNDEFINED, "%s\n", G_STRFUNC);
    activate_selected_items (view);
}

static void
fm_list_view_colorize_selected_items (FMDirectoryView *view, int ncolor)
{
    FMListView *list_view = FM_LIST_VIEW (view);
    GList *file_list;
    GOFFile *file;
    char *uri;

    file_list = fm_list_view_get_selection (list_view);
    /*guint array_length = MIN (g_list_length (file_list)*sizeof(char), 30);
      char **array = malloc(array_length + 1);
      char **l = array;*/
    for (; file_list != NULL; file_list=file_list->next)
    {
        file = file_list->data;
        //printf("colorize %s %d\n", file->name, ncolor);
        file->color = tags_colors[ncolor];
        uri = g_file_get_uri(file->location);
        //*array = uri;
        marlin_view_tags_set_color (tags, uri, ncolor, NULL, NULL);
        g_free (uri);
    }
    /**array = NULL;
      marlin_view_tags_uris_set_color (tags, l, array_length, ncolor, NULL);*/
    /*for (; *l != NULL; l=l++)
      log_printf (LOG_LEVEL_UNDEFINED, "array uri: %s\n", *l);*/
    //g_strfreev(l);
}

static void
fm_list_view_sync_selection (FMDirectoryView *view)
{
    FMListView *list_view = FM_LIST_VIEW (view);

    list_selection_changed_callback (gtk_tree_view_get_selection (list_view->tree), view);
}

static void
subdirectory_unloaded_callback (FMListModel *model,
                                GOFDirectoryAsync *directory,
                                gpointer callback_data)
{
    log_printf (LOG_LEVEL_UNDEFINED, "%s\n", G_STRFUNC);
    FMListView *view;

    g_return_if_fail (FM_IS_LIST_MODEL (model));
    g_return_if_fail (GOF_IS_DIRECTORY_ASYNC (directory));

    view = FM_LIST_VIEW(callback_data);

    /*g_signal_handlers_disconnect_by_func (directory,
      G_CALLBACK (subdirectory_done_loading_callback),
      view);*/
    fm_directory_view_remove_subdirectory (FM_DIRECTORY_VIEW (view), directory);
}

static gboolean
key_press_callback (GtkWidget *widget, GdkEventKey *event, gpointer callback_data)
{
    FMListView *view;
    //GdkEventButton button_event = { 0 };
    gboolean handled;
    GtkTreeView *tree_view;
    GtkTreePath *path;

    tree_view = GTK_TREE_VIEW (widget);

    view = FM_LIST_VIEW (callback_data);
    handled = FALSE;

    switch (event->keyval) {
        /*case GDK_F10:
          if (event->state & GDK_CONTROL_MASK) {
          fm_directory_view_pop_up_background_context_menu (view, &button_event);
          handled = TRUE;
          }
          break;*/
    case GDK_KEY_Right:
        gtk_tree_view_get_cursor (tree_view, &path, NULL);
        if (path) {
            gtk_tree_view_expand_row (tree_view, path, FALSE);
            gtk_tree_path_free (path);
        }
        handled = TRUE;
        break;
    case GDK_KEY_Left:
        gtk_tree_view_get_cursor (tree_view, &path, NULL);
        if (path) {
            gtk_tree_view_collapse_row (tree_view, path);
            gtk_tree_path_free (path);
        }
        handled = TRUE;
        break;
    case GDK_KEY_space:
        if (event->state & GDK_CONTROL_MASK) {
            handled = FALSE;
            break;
        }
        if (!gtk_widget_has_focus (GTK_WIDGET (tree_view))) {
            handled = FALSE;
            break;
        }
        /*if ((event->state & GDK_SHIFT_MASK) != 0) {
          activate_selected_items_alternate (FM_LIST_VIEW (view), NULL, TRUE);
          } else {*/
        activate_selected_items (FM_LIST_VIEW (view));
        //}
        handled = TRUE;
        break;
    case GDK_KEY_Return:
    case GDK_KEY_KP_Enter:
        /*if ((event->state & GDK_SHIFT_MASK) != 0) {
          activate_selected_items_alternate (FM_LIST_VIEW (view), NULL, TRUE);
          } else {*/
        activate_selected_items (view);
        //}
        handled = TRUE;
        break;

    default:
        handled = FALSE;
    }

    return handled;
}

static void
filename_cell_data_func (GtkTreeViewColumn *column,
                         GtkCellRenderer   *renderer,
                         GtkTreeModel      *model,
                         GtkTreeIter       *iter,
                         gpointer          *data)
{
    char *text;
    char *color;
    GdkRGBA rgba;

    //GtkTreePath *path;
    PangoUnderline underline;

    gtk_tree_model_get (model, iter,
                        FM_LIST_MODEL_FILENAME, &text,
                        -1);

    gtk_tree_model_get (model, iter,
                        FM_LIST_MODEL_COLOR, &color,
                        -1);
    if (color != NULL) {
        gdk_rgba_parse (color, &rgba);
        //rgba.alpha = 0.85;
    }

    /*if (color) {
      GList *lrenderers = gtk_cell_layout_get_cells (GTK_CELL_LAYOUT(column));
      GList *l;
      for (l=lrenderers; l != NULL; l=l->next)
      g_object_set(l->data, "cell-background", color, NULL);
      g_list_free (lrenderers);
      }
      g_free (color);*/

    /*if (click_policy_auto_value == NAUTILUS_CLICK_POLICY_SINGLE) {
      path = gtk_tree_model_get_path (model, iter);

      if (view->details->hover_path == NULL ||
      gtk_tree_path_compare (path, view->details->hover_path)) {
      underline = PANGO_UNDERLINE_NONE;
      } else {
      underline = PANGO_UNDERLINE_SINGLE;
      }

      gtk_tree_path_free (path);
      } else {*/
    underline = PANGO_UNDERLINE_NONE;
    //underline = PANGO_UNDERLINE_SINGLE;
    //}

    g_object_set (G_OBJECT (renderer),
                  "text", text,
                  "underline", underline,
                  //"cell-background", color,
                  "cell-background-rgba", &rgba,
                  NULL);
    g_free (text);
}

static void
color_row_func (GtkTreeViewColumn *column,
                GtkCellRenderer   *renderer,
                GtkTreeModel      *model,
                GtkTreeIter       *iter,
                gpointer          *data)
{
    char *color;
    GdkRGBA rgba;

    gtk_tree_model_get (model, iter,
                        FM_LIST_MODEL_COLOR, &color,
                        -1);
    if (color != NULL) {
        gdk_rgba_parse (color, &rgba);
        //rgba.alpha = 0.85;
    }

    //g_object_set(renderer, "cell-background", color, NULL);
    g_object_set(renderer, "cell-background-rgba", &rgba, NULL);
    g_free (color);
}

static void
create_and_set_up_tree_view (FMListView *view)
{
    int k;
    GtkTreeViewColumn       *col;
    GtkCellRenderer         *renderer;
    //GtkTreeSortable         *sortable;
    //GtkBindingSet *binding_set;

    //view->details->m_store = gtk_list_store_new  (GOF_DIR_COLS_MAX, GDK_TYPE_PIXBUF, G_TYPE_STRING, G_TYPE_STRING);
    view->model = g_object_new (FM_TYPE_LIST_MODEL, "has-child", TRUE, NULL);
    //view->details->customlist = custom_list_new();

    //#if 0
    //sortable = GTK_TREE_SORTABLE(view->model);
    //sortable = GTK_TREE_SORTABLE(view->details->m_store);
    /*gtk_tree_sortable_set_sort_func(sortable, GOF_DIR_COL_FILENAME, sort_iter_compare_func,
      GINT_TO_POINTER(GOF_DIR_COL_FILENAME), NULL);
      gtk_tree_sortable_set_sort_func(sortable, GOF_DIR_COL_SIZE, sort_iter_compare_func,
      GINT_TO_POINTER(GOF_DIR_COL_SIZE), NULL);*/
    /* set initial sort order */
    //gtk_tree_sortable_set_sort_column_id(sortable, GOF_DIR_COL_FILENAME, GTK_SORT_ASCENDING);
    //#endif
    //view->tree = gtk_tree_view_new_with_model (GTK_TREE_MODEL (view->details->m_store));
    //view->tree = gtk_tree_view_new_with_model (GTK_TREE_MODEL (view->details->customlist));
    //view->tree = GTK_TREE_VIEW (gtk_tree_view_new_with_model (GTK_TREE_MODEL (view->model)));
    view->tree = GTK_TREE_VIEW (exo_tree_view_new ());
    gtk_tree_view_set_model (view->tree, GTK_TREE_MODEL (view->model));

    /*exo_tree_view_set_single_click (EXO_TREE_VIEW (view->tree), TRUE);
      exo_tree_view_set_single_click_timeout (EXO_TREE_VIEW (view->tree), 350);*/

    //view->tree = gtk_tree_view_new();
    //gtk_tree_view_set_rules_hint(GTK_TREE_VIEW (view->tree), TRUE);
    //gtk_tree_view_set_fixed_height_mode (GTK_TREE_VIEW (view->tree), TRUE);
    //gtk_tree_view_set_enable_search (GTK_TREE_VIEW (view->tree), FALSE);
    gtk_tree_view_set_search_column (view->tree, FM_LIST_MODEL_FILENAME);
    gtk_tree_view_set_rubber_banding (view->tree, TRUE);

    /*gtk_tree_sortable_set_sort_column_id(GTK_TREE_SORTABLE(view->details->m_store), 
      GOF_DIR_COL_FILENAME, GTK_SORT_ASCENDING);*/

    /*binding_set = gtk_binding_set_by_class (GTK_WIDGET_GET_CLASS (view->details->tree_view));
      gtk_binding_entry_remove (binding_set, GDK_BackSpace, 0);*/

    g_signal_connect_object (gtk_tree_view_get_selection (view->tree), "changed",
                             G_CALLBACK (list_selection_changed_callback), view, 0);

    /*g_signal_connect_object (view->tree, "button-press-event",
      G_CALLBACK (button_press_callback), view, 0);*/
    g_signal_connect_object (view->tree, "key_press_event",
                             G_CALLBACK (key_press_callback), view, 0);
    g_signal_connect_object (view->tree, "row_expanded",
                             G_CALLBACK (row_expanded_callback), view, 0);
    g_signal_connect_object (view->tree, "row_collapsed",
                             G_CALLBACK (row_collapsed_callback), view, 0);
    g_signal_connect_object (view->tree, "row-activated",
                             G_CALLBACK (row_activated_callback), view, 0);

    gtk_tree_selection_set_mode (gtk_tree_view_get_selection (view->tree), GTK_SELECTION_MULTIPLE);

    g_signal_connect_object (view->model, "subdirectory_unloaded",
                             G_CALLBACK (subdirectory_unloaded_callback), view, 0);

    //for(k=0; k< GOF_DIR_COLS_MAX; k++) {
    for(k=3; k< FM_LIST_MODEL_NUM_COLUMNS; k++) {
        /*if(k == FM_LIST_MODEL_ICON) {
          renderer = gtk_cell_renderer_pixbuf_new( ); 
          col = gtk_tree_view_column_new_with_attributes (NULL, renderer, "pixbuf", k, NULL);
        //gtk_tree_view_column_set_fixed_width (col, 22);
        //gtk_tree_view_column_set_expand (col, TRUE);
        }*/ 
        if (k == FM_LIST_MODEL_FILENAME) {
            //cell = nautilus_cell_renderer_pixbuf_emblem_new ();
            renderer = gtk_cell_renderer_pixbuf_new( ); 
            col = gtk_tree_view_column_new ();
            gtk_tree_view_column_set_sort_column_id  (col,k);
            gtk_tree_view_column_set_resizable (col, TRUE);
            gtk_tree_view_column_set_title (col, col_title[k-3]);
            gtk_tree_view_column_set_expand (col, TRUE);
            gtk_tree_view_column_pack_start (col, renderer, FALSE);
            gtk_tree_view_column_set_attributes (col,
                                                 renderer,
                                                 "pixbuf", FM_LIST_MODEL_ICON,
                                                 //"pixbuf_emblem", FM_LIST_MODEL_SMALLEST_EMBLEM_COLUMN,
                                                 NULL);

            renderer = nautilus_cell_renderer_text_ellipsized_new ();
            renderer = gtk_cell_renderer_text_new( );
            gtk_tree_view_column_pack_start (col, renderer, TRUE);
            gtk_tree_view_column_set_cell_data_func (col, renderer,
                                                     (GtkTreeCellDataFunc) filename_cell_data_func,
                                                     NULL, NULL);
        } else {
            renderer = gtk_cell_renderer_text_new( );
            col = gtk_tree_view_column_new_with_attributes(col_title[k-3], renderer, "text", k, NULL);
            gtk_tree_view_column_set_sort_column_id  (col,k);
            gtk_tree_view_column_set_resizable (col, TRUE);
            //gtk_tree_view_column_set_fixed_width (col, 240);
            //amtest
            gtk_tree_view_column_set_cell_data_func (col, renderer,
                                                     (GtkTreeCellDataFunc) color_row_func,
                                                     NULL, NULL);
        }
        //g_object_set(renderer, "cell-background", "red", NULL);
        /*GList *lrenderers = gtk_cell_layout_get_cells (GTK_CELL_LAYOUT(col));
          GList *l;
          for (l=lrenderers; l != NULL; l=l->next)
          g_object_set(l->data, "cell-background", "red", NULL);*/


        //gtk_tree_view_column_set_sizing (col, GTK_TREE_VIEW_COLUMN_FIXED);
        gtk_tree_view_append_column(view->tree, col);
    }
    gtk_widget_show (GTK_WIDGET (view->tree));
    //g_signal_connect (dir, "done-loading", G_CALLBACK (done_loading), NULL);
    gtk_container_add (GTK_CONTAINER (view), GTK_WIDGET (view->tree));
}

static void
fm_list_view_add_file (FMDirectoryView *view, GOFFile *file, GOFDirectoryAsync *directory)
{
    FMListModel *model;

    model = FM_LIST_VIEW (view)->model;
    fm_list_model_add_file (model, file, directory);
}

/*
   static void
   fm_list_view_clear (FMListView *view)
   {
   if (view->model != NULL) {
//stop_cell_editing (view);
fm_list_model_clear (view->model);
}
}*/

static void
fm_list_view_get_selection_foreach_func (GtkTreeModel *model, GtkTreePath *path, GtkTreeIter *iter, gpointer data)
{
    GList **list;
    GOFFile *file;

    list = data;

    gtk_tree_model_get (model, iter,
                        FM_LIST_MODEL_FILE_COLUMN, &file,
                        -1);

    if (file != NULL) {
        (* list) = g_list_prepend ((* list), file);
    }
}

static GList *
fm_list_view_get_selection (FMListView *view)
{
    GList *list;

    list = NULL;

    gtk_tree_selection_selected_foreach (gtk_tree_view_get_selection (view->tree),
                                         fm_list_view_get_selection_foreach_func, &list);

    return g_list_reverse (list);
}

/*static void
  fm_list_view_set_selection (FMListView *list_view, GList *selection)
  {
  GtkTreeSelection *tree_selection;
  GList *node;
  GList *iters, *l;
  GOFFile *file;

  tree_selection = gtk_tree_view_get_selection (list_view->tree);

//g_signal_handlers_block_by_func (tree_selection, list_selection_changed_callback, view);

gtk_tree_selection_unselect_all (tree_selection);
for (node = selection; node != NULL; node = node->next) {
file = node->data;
iters = fm_list_model_get_all_iters_for_file (list_view->model, file);

for (l = iters; l != NULL; l = l->next) {
gtk_tree_selection_select_iter (tree_selection,
(GtkTreeIter *)l->data);
}
//eel_g_list_free_deep (iters);
}

//g_signal_handlers_unblock_by_func (tree_selection, list_selection_changed_callback, view);
//fm_directory_view_notify_selection_changed (view);
}

static void
fm_list_view_select_all (FMListView *view)
{
gtk_tree_selection_select_all (gtk_tree_view_get_selection (view->tree));
}*/

static void
fm_list_view_finalize (GObject *object)
{
    FMListView *view = FM_LIST_VIEW (object);

    log_printf (LOG_LEVEL_UNDEFINED, "$$ %s\n", G_STRFUNC);

    g_object_unref (view->model);
    //g_free (view->details);
    G_OBJECT_CLASS (fm_list_view_parent_class)->finalize (object); 
}

static void
fm_list_view_init (FMListView *view)
{
    //view->details = g_new0 (FMListViewDetails, 1);
    create_and_set_up_tree_view (view);

    g_settings_bind (settings, "single-click", 
                     EXO_TREE_VIEW (view->tree), "single-click", 0);
    g_settings_bind (settings, "single-click-timeout", 
                     EXO_TREE_VIEW (view->tree), "single-click-timeout", 0);
}

static void
fm_list_view_class_init (FMListViewClass *klass)
{
    FMDirectoryViewClass *fm_directory_view_class;
    GObjectClass *object_class = G_OBJECT_CLASS (klass);
    //GParamSpec   *pspec;

    object_class->finalize     = fm_list_view_finalize;
    /*object_class->get_property = _get_property;
      object_class->set_property = _set_property;*/

    fm_directory_view_class = FM_DIRECTORY_VIEW_CLASS (klass);

    fm_directory_view_class->add_file = fm_list_view_add_file;
    fm_directory_view_class->colorize_selection = fm_list_view_colorize_selected_items;        
    fm_directory_view_class->sync_selection = fm_list_view_sync_selection;
    //eel_g_settings_add_auto_boolean (settings, "single-click", &single_click);
    //g_type_class_add_private (object_class, sizeof (GOFDirectoryAsyncPrivate));
}


/*
   GtkTreeView*
   fm_list_view_get_tree_view (FMListView *list_view)
   {
   return list_view->tree_view;
   }
   */
