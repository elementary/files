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
#include "eel-gtk-extensions.h"
#include "marlin-tags.h"
//#include "marlin-vala.h"

struct FMColumnsViewDetails {
    GList       *selection;
    GtkTreePath *new_selection_path;   /* Path of the new selection after removing a file */

    gint pressed_button;
};

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
static GList    *get_selection (FMColumnsView *view);
static GList    *fm_columns_view_get_selection (FMDirectoryView *view);
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

    if (view->details->selection != NULL)
        gof_file_list_free (view->details->selection);
    view->details->selection = get_selection (view);
    if (view->details->selection == NULL)
        return;
    file = view->details->selection->data;
    //show_selected_files (file);

    /* setup the current active slot */
    //fm_directory_view_set_active_slot (FM_DIRECTORY_VIEW (view));
    if (file->is_directory)
        fm_directory_view_column_add_location (FM_DIRECTORY_VIEW (view), file->location);
    else
        fm_directory_view_column_add_preview (FM_DIRECTORY_VIEW (view), file);
}

static void
row_activated_callback (GtkTreeView *treeview, GtkTreeIter *iter, GtkTreePath *path, FMColumnsView *view)
{
    log_printf (LOG_LEVEL_UNDEFINED, "%s\n", G_STRFUNC);
    fm_directory_view_activate_selected_items (FM_DIRECTORY_VIEW (view));
}

static void
fm_columns_view_colorize_selected_items (FMDirectoryView *view, int ncolor)
{
    GList *file_list;
    GOFFile *file;
    char *uri;

    file_list = fm_columns_view_get_selection (view);
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
button_press_callback (GtkTreeView *tree_view, GdkEventButton *event, FMColumnsView *view)
{
    GtkTreeSelection    *selection;
    GtkTreePath         *path;
    GtkTreeIter         iter;
    GtkAction           *action;

    /* check if the event is for the bin window */
    if (G_UNLIKELY (event->window != gtk_tree_view_get_bin_window (tree_view)))
        return FALSE;

    view->details->pressed_button = -1;
    /* we unselect all selected items if the user clicks on an empty
     * area of the treeview and no modifier key is active.
     */
    if ((event->state & gtk_accelerator_get_default_mod_mask ()) == 0
        && !gtk_tree_view_get_path_at_pos (tree_view, event->x, event->y, NULL, NULL, NULL, NULL))
    {
        selection = gtk_tree_view_get_selection (tree_view);
        gtk_tree_selection_unselect_all (selection);
    }

    selection = gtk_tree_view_get_selection (tree_view);
    if (event->type == GDK_BUTTON_PRESS && event->button == 1) {
        /* save last pressed button */
        if (view->details->pressed_button < 0)
            view->details->pressed_button = event->button;

        /* disconnect the selection changed signal to operate only on release button event */
         g_signal_handlers_block_by_func (selection, list_selection_changed_callback, view);
    }

    /* open the context menu on right clicks */
    if (event->type == GDK_BUTTON_PRESS && event->button == 3)
    {
        if (gtk_tree_view_get_path_at_pos (tree_view, event->x, event->y, &path, NULL, NULL, NULL))
        {
            /* select the path on which the user clicked if not selected yet */
            if (!gtk_tree_selection_path_is_selected (selection, path))
            {
                /* we don't unselect all other items if Control is active */
                if ((event->state & GDK_CONTROL_MASK) == 0)
                    gtk_tree_selection_unselect_all (selection);
                gtk_tree_selection_select_path (selection, path);
            }
            gtk_tree_path_free (path);

            /* queue the menu popup */
            printf ("thunar_standard_view_queue_popup (THUNAR_STANDARD_VIEW (view), event)\n");
            fm_directory_view_queue_popup (FM_DIRECTORY_VIEW (view), event);
        }
        else
        {
            /* open the context menu */
            //thunar_standard_view_context_menu (THUNAR_STANDARD_VIEW (view), event->button, event->time);
            printf ("thunar_standard_view_context_menu (THUNAR_STANDARD_VIEW (view), event->button, event->time)\n");
        }

        return TRUE;
    }
    else if ((event->type == GDK_BUTTON_PRESS || event->type == GDK_2BUTTON_PRESS) && event->button == 2)
    {
        /* determine the path to the item that was middle-clicked */
        if (gtk_tree_view_get_path_at_pos (tree_view, event->x, event->y, &path, NULL, NULL, NULL))
        {
            /* select only the path to the item on which the user clicked */
            selection = gtk_tree_view_get_selection (tree_view);
            gtk_tree_selection_unselect_all (selection);
            gtk_tree_selection_select_path (selection, path);

            /* if the event was a double-click or we are in single-click mode, then
             * we'll open the file or folder (folder's are opened in new windows)
             */
            //amtest
#if 0
            if (G_LIKELY (event->type == GDK_2BUTTON_PRESS || exo_tree_view_get_single_click (EXO_TREE_VIEW (tree_view))))
            {
                printf ("activate selected ??\n");
#if 0
                /* determine the file for the path */
                gtk_tree_model_get_iter (GTK_TREE_MODEL (view->model), &iter, path);
                file = thunar_list_model_get_file (view->model, &iter);
                if (G_LIKELY (file != NULL))
                {
                    /* determine the action to perform depending on the type of the file */
                    /*action = thunar_gtk_ui_manager_get_action_by_name (THUNAR_STANDARD_VIEW (view)->ui_manager,
                      thunar_file_is_directory (file) ? "open-in-new-window" : "open");*/
                    printf ("open or open-in-new-window\n");

                    /* emit the action */
                    /*if (G_LIKELY (action != NULL))
                      gtk_action_activate (action);*/

                    /* release the file reference */
                    g_object_unref (G_OBJECT (file));
                }
#endif
            }
#endif
            /* cleanup */
            gtk_tree_path_free (path);
        }

        return TRUE;
    }

    return FALSE;
}

static gboolean
button_release_callback (GtkTreeView *tree_view, GdkEventButton *event, FMColumnsView *view)
{
    GtkTreeSelection    *selection;
    GtkTreePath         *path;

    if (view->details->pressed_button == event->button) 
    {
        selection = gtk_tree_view_get_selection (tree_view);
        list_selection_changed_callback (selection, view);
        g_signal_handlers_unblock_by_func (selection, list_selection_changed_callback, view);

        /* reset the pressed_button state */
        view->details->pressed_button = -1;
    }

    return TRUE;
}

/*static gboolean
  popup_menu_callback (GtkWidget *widget, gpointer callback_data)
  {
  FMListView *view;

  view = FM_LIST_VIEW (callback_data);

  do_popup_menu (widget, view, NULL);

  return TRUE;
  }*/

static gboolean
key_press_callback (GtkWidget *widget, GdkEventKey *event, gpointer callback_data)
{
    FMDirectoryView *view;
    //GdkEventButton button_event = { 0 };
    gboolean handled;
    GtkTreeView *tree_view;
    GtkTreePath *path;

    tree_view = GTK_TREE_VIEW (widget);

    view = FM_DIRECTORY_VIEW (callback_data);
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
            gtk_tree_path_free (path);
        }
        handled = TRUE;
        break;
    case GDK_KEY_Left:
        gtk_tree_view_get_cursor (tree_view, &path, NULL);
        if (path) {
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
        fm_directory_view_activate_selected_items (view);
        //}
        handled = TRUE;
        break;
    case GDK_KEY_Return:
    case GDK_KEY_KP_Enter:
        /*if ((event->state & GDK_SHIFT_MASK) != 0) {
          activate_selected_items_alternate (FM_COLUMNS_VIEW (view), NULL, TRUE);
          } else {*/
        fm_directory_view_activate_selected_items (view);
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

    view->model = FM_DIRECTORY_VIEW (view)->model;
    g_object_set (G_OBJECT (view->model), "has-child", FALSE, NULL);

    view->tree = g_object_new (GTK_TYPE_TREE_VIEW, "model", GTK_TREE_MODEL (view->model),
                               "headers-visible", FALSE, NULL);
    //gtk_tree_view_set_rules_hint(GTK_TREE_VIEW (view->tree), TRUE);
    //gtk_tree_view_set_fixed_height_mode (GTK_TREE_VIEW (view->tree), TRUE);
    //gtk_tree_view_set_enable_search (GTK_TREE_VIEW (view->tree), FALSE);
    gtk_tree_view_set_search_column (view->tree, FM_LIST_MODEL_FILENAME);
    //gtk_tree_view_set_reorderable (view->tree, FALSE);

    /*binding_set = gtk_binding_set_by_class (GTK_WIDGET_GET_CLASS (view->details->tree_view));
      gtk_binding_entry_remove (binding_set, GDK_BackSpace, 0);*/

    g_signal_connect_object (gtk_tree_view_get_selection (view->tree), "changed",
                             G_CALLBACK (list_selection_changed_callback), view, 0);

    g_signal_connect_object (view->tree, "button-press-event",
                             G_CALLBACK (button_press_callback), view, 0);
    g_signal_connect_object (view->tree, "button-release-event",
                             G_CALLBACK (button_release_callback), view, 0);
    g_signal_connect_object (view->tree, "key_press_event",
                             G_CALLBACK (key_press_callback), view, 0);
    g_signal_connect_object (view->tree, "row-activated",
                             G_CALLBACK (row_activated_callback), view, 0);

    gtk_tree_selection_set_mode (gtk_tree_view_get_selection (view->tree), GTK_SELECTION_SINGLE);

    col = gtk_tree_view_column_new ();
    gtk_tree_view_column_set_sort_column_id  (col, FM_LIST_MODEL_FILENAME);
    //gtk_tree_view_column_set_resizable (col, TRUE);
    //gtk_tree_view_column_set_title (col, col_title);
    gtk_tree_view_column_set_expand (col, TRUE);

#if 0
    renderer = gtk_cell_renderer_pixbuf_new( ); 
    gtk_tree_view_column_pack_start (col, renderer, FALSE);
    gtk_tree_view_column_set_attributes (col,
                                         renderer,
                                         "pixbuf", FM_LIST_MODEL_ICON,
                                         //"pixbuf_emblem", FM_LIST_MODEL_SMALLEST_EMBLEM_COLUMN,
                                         NULL);
#endif
    /* add the icon renderer */
    gtk_tree_view_column_pack_start (col, FM_DIRECTORY_VIEW (view)->icon_renderer, FALSE);
    gtk_tree_view_column_set_attributes (col, FM_DIRECTORY_VIEW (view)->icon_renderer,
                                         "file",  FM_LIST_MODEL_FILE_COLUMN, NULL);

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
}

static void
fm_columns_view_add_file (FMDirectoryView *view, GOFFile *file, GOFDirectoryAsync *directory)
{
    FMListModel *model;

    model = FM_COLUMNS_VIEW (view)->model;
    fm_list_model_add_file (model, file, directory);
}

static void
fm_columns_view_remove_file (FMDirectoryView *view, GOFFile *file, GOFDirectoryAsync *directory)
{
    printf ("%s %s\n", G_STRFUNC, g_file_get_uri(file->location));
    GtkTreePath *path;
    GtkTreePath *file_path;
    GtkTreeIter iter;
    GtkTreeIter temp_iter;
    GtkTreeRowReference* row_reference;
    FMColumnsView *col_view;
    GtkTreeModel* tree_model; 
    GtkTreeSelection *selection;

    path = NULL;
    row_reference = NULL;
    col_view = FM_COLUMNS_VIEW (view);
    tree_model = GTK_TREE_MODEL(col_view->model);

    if (fm_list_model_get_tree_iter_from_file (col_view->model, file, directory, &iter))
    {
        selection = gtk_tree_view_get_selection (col_view->tree);
        file_path = gtk_tree_model_get_path (tree_model, &iter);

        if (gtk_tree_selection_path_is_selected (selection, file_path)) {
            /* get reference for next element in the list view. If the element to be deleted is the 
             * last one, get reference to previous element. If there is only one element in view
             * no need to select anything.
             */
            temp_iter = iter;

            if (gtk_tree_model_iter_next (tree_model, &iter)) {
                path = gtk_tree_model_get_path (tree_model, &iter);
                row_reference = gtk_tree_row_reference_new (tree_model, path);
            } else {
                path = gtk_tree_model_get_path (tree_model, &temp_iter);
                if (gtk_tree_path_prev (path)) {
                    row_reference = gtk_tree_row_reference_new (tree_model, path);
                }
            }
            gtk_tree_path_free (path);
        }

        gtk_tree_path_free (file_path);

        fm_list_model_remove_file (col_view->model, file, directory);

        if (gtk_tree_row_reference_valid (row_reference)) {
            if (col_view->details->new_selection_path) {
                gtk_tree_path_free (col_view->details->new_selection_path);
            }
            col_view->details->new_selection_path = gtk_tree_row_reference_get_path (row_reference);
        }

        if (row_reference) {
            gtk_tree_row_reference_free (row_reference);
        }
    }   
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
get_selection_foreach_func (GtkTreeModel *model, GtkTreePath *path, GtkTreeIter *iter, gpointer data)
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
get_selection (FMColumnsView *view)
{
    GList *list;

    list = NULL;

    gtk_tree_selection_selected_foreach (gtk_tree_view_get_selection (view->tree),
                                         get_selection_foreach_func, &list);

    return g_list_reverse (list);
}

static GList *
fm_columns_view_get_selection (FMDirectoryView *view)
{
    return FM_COLUMNS_VIEW (view)->details->selection;
}

static GList *
fm_columns_view_get_selection_for_file_transfer (FMDirectoryView *view)
{
    GList *list = g_list_copy (fm_columns_view_get_selection (view));
    g_list_foreach (list, (GFunc) gof_file_ref, NULL);

    return list;
}

static GtkTreePath*
fm_columns_view_get_path_at_pos (FMDirectoryView *view, gint x, gint y)
{
    GtkTreePath *path;

    g_return_val_if_fail (FM_IS_COLUMNS_VIEW (view), NULL);

    if (gtk_tree_view_get_dest_row_at_pos (FM_COLUMNS_VIEW (view)->tree, x, y, &path, NULL))
        return path;

    return NULL;
}

static void
fm_columns_view_highlight_path (FMDirectoryView *view, GtkTreePath *path)
{
    g_return_if_fail (FM_IS_COLUMNS_VIEW (view));
    //gtk_tree_view_set_drag_dest_row (GTK_TREE_VIEW (GTK_BIN (standard_view)->child), path, GTK_TREE_VIEW_DROP_INTO_OR_AFTER);
    gtk_tree_view_set_drag_dest_row (FM_COLUMNS_VIEW (view)->tree, path, GTK_TREE_VIEW_DROP_INTO_OR_AFTER);
}

static void
fm_columns_view_finalize (GObject *object)
{
    FMColumnsView *view = FM_COLUMNS_VIEW (object);

    log_printf (LOG_LEVEL_UNDEFINED, "%s\n", G_STRFUNC);

    if (view->details->new_selection_path) 
        gtk_tree_path_free (view->details->new_selection_path);
    if (view->details->selection)
        gof_file_list_free (view->details->selection);

    g_object_unref (view->model);
    g_free (view->details);
    G_OBJECT_CLASS (fm_columns_view_parent_class)->finalize (object); 
}

static void
fm_columns_view_init (FMColumnsView *view)
{
    view->details = g_new0 (FMColumnsViewDetails, 1);
    view->details->pressed_button = -1;

    create_and_set_up_tree_view (view);

    //fm_columns_view_click_policy_changed (FM_DIRECTORY_VIEW (view));
    
    /* set the new "size" for the icon renderer */
    g_object_set (G_OBJECT (FM_DIRECTORY_VIEW (view)->icon_renderer), "size", 16, NULL);
    //TODO clean up this "hack"
    gtk_cell_renderer_set_fixed_size (FM_DIRECTORY_VIEW (view)->icon_renderer, 18, 18);
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
    fm_directory_view_class->remove_file = fm_columns_view_remove_file;
    fm_directory_view_class->colorize_selection = fm_columns_view_colorize_selected_items;
    fm_directory_view_class->get_selection = fm_columns_view_get_selection; 
    fm_directory_view_class->get_selection_for_file_transfer = fm_columns_view_get_selection_for_file_transfer; 

    fm_directory_view_class->get_path_at_pos = fm_columns_view_get_path_at_pos;
    fm_directory_view_class->highlight_path = fm_columns_view_highlight_path;

    //g_type_class_add_private (object_class, sizeof (GOFDirectoryAsyncPrivate));
}

