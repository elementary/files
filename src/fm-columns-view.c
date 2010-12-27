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

#include "fm-columns-view.h"
#include "fm-list-model.h"
#include "eel-i18n.h"
#include <gdk/gdk.h>
#include <gdk/gdkkeysyms.h>

//#include "gof-directory-async.h"
#include "nautilus-cell-renderer-text-ellipsized.h"
#include "marlin-global-preferences.h"
#include "marlin-tags.h"
//#include "marlin-vala.h"

/*
   struct FMColumnsViewDetails {
   GtkTreeView     *tree;
   FMListModel     *model;
   };*/

/* Wait for the rename to end when activating a file being renamed */
#define WAIT_FOR_RENAME_ON_ACTIVATE 200

//static gchar *col_title = _("Filename");

//G_DEFINE_TYPE (FMColumnsView, fm_columns_view, G_TYPE_OBJECT)
/*#define GOF_DIRECTORY_ASYNC_GET_PRIVATE(obj) \
  (G_TYPE_INSTANCE_GET_PRIVATE(obj, GOF_TYPE_DIRECTORY_ASYNC, GOFDirectoryAsyncPrivate))*/

G_DEFINE_TYPE (FMColumnsView, fm_columns_view, FM_TYPE_DIRECTORY_VIEW);

#define parent_class fm_columns_view_parent_class


struct UnloadDelayData {
    FMColumnsView *view;
    GOFFile *file;
    GOFDirectoryAsync *directory;
};

/* Declaration Prototypes */
static GList    *fm_columns_view_get_selection (FMColumnsView *view);
//static void     fm_columns_view_clear (FMColumnsView *view);

#if 0
static void
row_expanded_callback (GtkTreeView *treeview, GtkTreeIter *iter, GtkTreePath *path, gpointer callback_data)
{
    FMColumnsView *view;
    GOFDirectoryAsync *directory;

    view = FM_COLUMNS_VIEW (callback_data);

    if (fm_list_model_load_subdirectory (view->model, path, &directory)) {
        fm_directory_view_add_subdirectory (FM_DIRECTORY_VIEW (view), directory);
    }
}

static void
row_collapsed_callback (GtkTreeView *treeview, GtkTreeIter *iter, GtkTreePath *path, gpointer callback_data)
{
    FMColumnsView *view;
    struct UnloadDelayData *unload_data;

    view = FM_COLUMNS_VIEW (callback_data);
    unload_data = g_new (struct UnloadDelayData, 1);
    unload_data->view = view;

    fm_list_model_get_directory_file (view->model, path, &unload_data->directory, &unload_data->file);

    //log_printf (LOG_LEVEL_UNDEFINED, "collapsed %s %s\n", unload_data->file->name, gof_directory_get_uri(unload_data->directory));
    g_timeout_add_seconds (COLLAPSE_TO_UNLOAD_DELAY,
                           unload_file_timeout,
                           unload_data);

    //fm_list_model_unload_subdirectory (view->model, iter);
}
#endif

static void
show_selected_files (GOFFile *file)
{
    log_printf (LOG_LEVEL_UNDEFINED, "selected: %s\n", file->name);
}

static void
list_selection_changed_callback (GtkTreeSelection *selection, gpointer user_data)
{
    FMColumnsView *view = FM_COLUMNS_VIEW (user_data);
    GOFFile *file;
    GList *file_list;

    file_list = fm_columns_view_get_selection (view);
    if (file_list == NULL)
        return;
    file = file_list->data;
    //show_selected_files (file);

    /* setup the current active slot */
    fm_directory_view_set_active_slot (FM_DIRECTORY_VIEW (view));
    if (file->is_directory)
        fm_directory_view_column_add_location (FM_DIRECTORY_VIEW (view), file->location);
    else
        fm_directory_view_column_add_preview (FM_DIRECTORY_VIEW (view), file);
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

        //log_printf (LOG_LEVEL_UNDEFINED, "command %s\n", uri);
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
        log_printf (LOG_LEVEL_UNDEFINED, "command %s\n", cmd);
        gdk_spawn_command_line_on_screen (screen, cmd, NULL);
        g_free (uri);
        g_free (cmd);
    }
}

static void
fm_directory_activate_single_file (GOFFile *file, FMColumnsView *view, GdkScreen *screen)
{
    //GOFDirectoryAsync *dir;

    log_printf (LOG_LEVEL_UNDEFINED, "%s\n", G_STRFUNC);
    if (file->is_directory) {
        //view->location = file->location;
        /*
           fm_columns_view_clear(view);
           dir = gof_directory_async_new(view->location);*/
        /*fm_columns_view_clear(view);
          gof_window_slot_change_location(view->slot, file->location);*/
        fm_directory_view_load_location (FM_DIRECTORY_VIEW (view), file->location);
    } else {
        gof_gnome_open_single_file (file, screen); 
    }

}

static void
activate_selected_items (FMColumnsView *view)
{
    GList *file_list;
    GdkScreen *screen;
    GOFFile *file;

    file_list = fm_columns_view_get_selection (view);

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
    if (g_list_length (file_list) == 1)
        fm_directory_activate_single_file(file_list->data, view, screen);
    else
    {
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
row_activated_callback (GtkTreeView *treeview, GtkTreeIter *iter, GtkTreePath *path, FMColumnsView *view)
{
    log_printf (LOG_LEVEL_UNDEFINED, "%s\n", G_STRFUNC);
    activate_selected_items (view);
}

static void
fm_columns_view_colorize_selected_items (FMDirectoryView *view, int ncolor)
{
    FMColumnsView *cview = FM_COLUMNS_VIEW (view);
    GList *file_list;
    GOFFile *file;
    char *uri;

    file_list = fm_columns_view_get_selection (cview);
    for (; file_list != NULL; file_list=file_list->next)
    {
        file = file_list->data;
        //log_printf (LOG_LEVEL_UNDEFINED, "colorize %s %d\n", file->name, ncolor);
        file->color = tags_colors[ncolor];
        uri = g_file_get_uri(file->location);
        marlin_view_tags_set_color (tags, uri, ncolor, NULL, NULL);
        g_free (uri);
    }
}

static gboolean
key_press_callback (GtkWidget *widget, GdkEventKey *event, gpointer callback_data)
{
    FMColumnsView *view;
    //GdkEventButton button_event = { 0 };
    gboolean handled;
    GtkTreeView *tree_view;
    GtkTreePath *path;

    tree_view = GTK_TREE_VIEW (widget);

    view = FM_COLUMNS_VIEW (callback_data);
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
            //gtk_tree_view_expand_row (tree_view, path, FALSE);
            gtk_tree_path_free (path);
        }
        handled = TRUE;
        break;
    case GDK_KEY_Left:
        gtk_tree_view_get_cursor (tree_view, &path, NULL);
        if (path) {
            //gtk_tree_view_collapse_row (tree_view, path);
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
          activate_selected_items_alternate (FM_COLUMNS_VIEW (view), NULL, TRUE);
          } else {*/
        activate_selected_items (FM_COLUMNS_VIEW (view));
        //}
        handled = TRUE;
        break;
    case GDK_KEY_Return:
    case GDK_KEY_KP_Enter:
        /*if ((event->state & GDK_SHIFT_MASK) != 0) {
          activate_selected_items_alternate (FM_COLUMNS_VIEW (view), NULL, TRUE);
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
    //GtkTreePath *path;
    PangoUnderline underline;

    gtk_tree_model_get (model, iter,
                        FM_LIST_MODEL_FILENAME, &text,
                        -1);

    gtk_tree_model_get (model, iter,
                        FM_LIST_MODEL_COLOR, &color,
                        -1);

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
                  "cell-background", color,
                  "ellipsize", PANGO_ELLIPSIZE_MIDDLE,
                  NULL);
    g_free (text);
}

static void
create_and_set_up_tree_view (FMColumnsView *view)
{
    //int k;
    GtkTreeViewColumn       *col;
    GtkCellRenderer         *renderer;
    //GtkTreeSortable         *sortable;
    //GtkBindingSet *binding_set;

    //view->details->m_store = gtk_list_store_new  (GOF_DIR_COLS_MAX, GDK_TYPE_PIXBUF, G_TYPE_STRING, G_TYPE_STRING);
    view->model = g_object_new (FM_TYPE_LIST_MODEL, NULL);
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
    view->tree = g_object_new (GTK_TYPE_TREE_VIEW, "model", GTK_TREE_MODEL (view->model),
                               "headers-visible", FALSE, NULL);
    //view->tree = gtk_tree_view_new();
    //gtk_tree_view_set_rules_hint(GTK_TREE_VIEW (view->tree), TRUE);
    //gtk_tree_view_set_fixed_height_mode (GTK_TREE_VIEW (view->tree), TRUE);
    //gtk_tree_view_set_enable_search (GTK_TREE_VIEW (view->tree), FALSE);
    gtk_tree_view_set_search_column (view->tree, FM_LIST_MODEL_FILENAME);
    //gtk_tree_view_set_reorderable (view->tree, FALSE);

    /*gtk_tree_sortable_set_sort_column_id(GTK_TREE_SORTABLE(view->details->m_store), 
      GOF_DIR_COL_FILENAME, GTK_SORT_ASCENDING);*/

    /*binding_set = gtk_binding_set_by_class (GTK_WIDGET_GET_CLASS (view->details->tree_view));
      gtk_binding_entry_remove (binding_set, GDK_BackSpace, 0);*/

    g_signal_connect_object (gtk_tree_view_get_selection (view->tree), "changed",
                             G_CALLBACK (list_selection_changed_callback), view, 0);

    g_signal_connect_object (view->tree, "key_press_event",
                             G_CALLBACK (key_press_callback), view, 0);
    /*g_signal_connect_object (view->tree, "row_expanded",
      G_CALLBACK (row_expanded_callback), view, 0);
      g_signal_connect_object (view->tree, "row_collapsed",
      G_CALLBACK (row_collapsed_callback), view,
      0);*/
    g_signal_connect_object (view->tree, "row-activated",
                             G_CALLBACK (row_activated_callback), view, 0);

    gtk_tree_selection_set_mode (gtk_tree_view_get_selection (view->tree), GTK_SELECTION_SINGLE);

    //cell = nautilus_cell_renderer_pixbuf_emblem_new ();
    renderer = gtk_cell_renderer_pixbuf_new( ); 
    col = gtk_tree_view_column_new ();
    gtk_tree_view_column_set_sort_column_id  (col, FM_LIST_MODEL_FILENAME);
    //gtk_tree_view_column_set_resizable (col, TRUE);
    //gtk_tree_view_column_set_title (col, col_title);
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

    //gtk_tree_view_column_set_sizing (col, GTK_TREE_VIEW_COLUMN_FIXED);
    gtk_tree_view_append_column(view->tree, col);

    gtk_widget_show (GTK_WIDGET (view->tree));
    gtk_container_add (GTK_CONTAINER (view), GTK_WIDGET (view->tree));
    /*GtkWidget *mbox = gtk_hbox_new (FALSE, 0);
      gtk_widget_show (mbox);
      gtk_box_pack_start (GTK_BOX (mbox), GTK_WIDGET (view->tree), FALSE, FALSE, 0);
    //gtk_box_pack_start (GTK_BOX (mbox), GTK_WIDGET (view->tree), TRUE, FALSE, 0);
    gtk_container_add (GTK_CONTAINER (view), mbox);*/

    //gtk_widget_grab_focus (GTK_WIDGET (view->tree));
    //g_signal_connect (dir, "done-loading", G_CALLBACK (done_loading), NULL);


    //GtkWidget *hpane = gtk_hpaned_new();
    /*GtkWidget *hbox = gtk_hbox_new(FALSE, 0);
      gtk_widget_show (hbox);
      gtk_scrolled_window_add_with_viewport(GTK_SCROLLED_WINDOW (view), hbox);*/
    /*gtk_scrolled_window_set_policy (GTK_SCROLLED_WINDOW (view),
      GTK_POLICY_AUTOMATIC,
      GTK_POLICY_NEVER);*/
    //gtk_box_pack_start (GTK_BOX (hbox), GTK_WIDGET (view->tree), FALSE, FALSE, 0);
    //gtk_container_add (GTK_CONTAINER (hbox), GTK_WIDGET (view->tree));
    //gtk_container_add (GTK_CONTAINER (view), hbox);
}

static void
fm_columns_view_add_file (FMDirectoryView *view, GOFFile *file, GOFDirectoryAsync *directory)
{
    FMListModel *model;

    model = FM_COLUMNS_VIEW (view)->model;
    fm_list_model_add_file (model, file, directory);
}

/*static void
  fm_columns_view_clear (FMColumnsView *view)
  {
  if (view->model != NULL) {
//stop_cell_editing (view);
fm_list_model_clear (view->model);
}
}*/

static void
fm_columns_view_get_selection_foreach_func (GtkTreeModel *model, GtkTreePath *path, GtkTreeIter *iter, gpointer data)
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
fm_columns_view_get_selection (FMColumnsView *view)
{
    GList *list;

    list = NULL;

    gtk_tree_selection_selected_foreach (gtk_tree_view_get_selection (view->tree),
                                         fm_columns_view_get_selection_foreach_func, &list);

    return g_list_reverse (list);
}

/*static void
  fm_columns_view_set_selection (FMColumnsView *list_view, GList *selection)
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
fm_columns_view_select_all (FMColumnsView *view)
{
gtk_tree_selection_select_all (gtk_tree_view_get_selection (view->tree));
}*/


static void
fm_columns_view_finalize (GObject *object)
{
    FMColumnsView *view = FM_COLUMNS_VIEW (object);

    log_printf (LOG_LEVEL_UNDEFINED, "%s\n", G_STRFUNC);

    g_object_unref (view->model);
    //g_free (view->details);
    G_OBJECT_CLASS (fm_columns_view_parent_class)->finalize (object); 
}

static void
fm_columns_view_init (FMColumnsView *view)
{
    //view->details = g_new0 (FMColumnsViewDetails, 1);
    create_and_set_up_tree_view (view);

    //fm_columns_view_click_policy_changed (FM_DIRECTORY_VIEW (view));
}

static void
fm_columns_view_class_init (FMColumnsViewClass *klass)
{
    FMDirectoryViewClass *fm_directory_view_class;
    GObjectClass *object_class = G_OBJECT_CLASS (klass);
    //GParamSpec   *pspec;

    object_class->finalize     = fm_columns_view_finalize;
    /*object_class->get_property = _get_property;
      object_class->set_property = _set_property;*/

    fm_directory_view_class = FM_DIRECTORY_VIEW_CLASS (klass);

    fm_directory_view_class->add_file = fm_columns_view_add_file;
    fm_directory_view_class->colorize_selection = fm_columns_view_colorize_selected_items;
    fm_directory_view_class->get_selection_for_file_transfer = fm_columns_view_get_selection;

    //g_type_class_add_private (object_class, sizeof (GOFDirectoryAsyncPrivate));
}


/*
   GtkTreeView*
   fm_columns_view_get_tree_view (FMColumnsView *list_view)
   {
   return list_view->tree_view;
   }
   */
