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
#include "eel-gtk-extensions.h"
#include "marlin-tags.h"

struct FMListViewDetails {
    GList       *selection;
    GtkTreePath *new_selection_path;   /* Path of the new selection after removing a file */

    GtkCellEditable     *editable_widget;
    GtkTreeViewColumn   *file_name_column;
    GtkCellRendererText *file_name_cell;
    char                *original_name;

    GOFFile     *renaming_file;
    gboolean    rename_done;
};

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

struct SelectionForeachData {
    GList *list;
    GtkTreeSelection *selection;
};

/* Declaration Prototypes */
static GList    *fm_list_view_get_selection (FMDirectoryView *view);
static GList    *get_selection (FMListView *view);
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

    /*GList *paths = gtk_tree_selection_get_selected_rows (selection, NULL);
    if (paths!=NULL && gtk_tree_model_get_iter (GTK_TREE_MODEL(view->model), &iter, paths->data))   
    {
        gtk_tree_model_get (GTK_TREE_MODEL (view->model), &iter,
                            FM_LIST_MODEL_FILE_COLUMN, &file,
                            -1);
        //if (file != NULL) 
    }*/
    if (view->details->selection != NULL)
        gof_file_list_free (view->details->selection);
    view->details->selection = get_selection(view);

    if (view->details->selection != NULL) 
        file = view->details->selection->data;
    
    fm_directory_view_notify_selection_changed (FM_DIRECTORY_VIEW (view), file);

    //fm_directory_view_notify_selection_changed (FM_DIRECTORY_VIEW (view), file);
    /*g_list_foreach (paths, (GFunc) gtk_tree_path_free, NULL);
    g_list_free (paths);*/
}

#if 0
static void
activate_selected_items (FMListView *view)
{
    GList *file_list;
    GdkScreen *screen;
    GOFFile *file;

    file_list = fm_list_view_get_selection (FM_DIRECTORY_VIEW (view));

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

    screen = eel_gtk_widget_get_screen (GTK_WIDGET (view));
    guint nb_elem = g_list_length (file_list);
    if (nb_elem == 1)
        fm_directory_view_activate_single_file(FM_DIRECTORY_VIEW (view), file_list->data, screen);
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
                    gof_file_open_single (file, screen);
                }
            }
    }

    //gof_file_list_free (file_list);
}
#endif

static void
row_activated_callback (GtkTreeView *treeview, GtkTreeIter *iter, GtkTreePath *path, FMListView *view)
{
    log_printf (LOG_LEVEL_UNDEFINED, "%s\n", G_STRFUNC);
    fm_directory_view_activate_selected_items (FM_DIRECTORY_VIEW (view));
}

static void
fm_list_view_colorize_selected_items (FMDirectoryView *view, int ncolor)
{
    GList *file_list;
    GOFFile *file;
    char *uri;

    file_list = fm_list_view_get_selection (view);
    /*guint array_length = MIN (g_list_length (file_list)*sizeof(char), 30);
      char **array = malloc(array_length + 1);
      char **l = array;*/
    for (; file_list != NULL; file_list=file_list->next)
    {
        file = file_list->data;
        //log_printf (LOG_LEVEL_UNDEFINED, "colorize %s %d\n", file->name, ncolor);
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
fm_list_view_rename_callback (GOFFile *file,
                              GFile *result_location,
                              GError *error,
                              gpointer callback_data)
{
	FMListView *view = FM_LIST_VIEW (callback_data);

    printf ("%s\n", G_STRFUNC);
	if (view->details->renaming_file) {
		view->details->rename_done = TRUE;
		
		if (error != NULL) {
			/* If the rename failed (or was cancelled), kill renaming_file.
			 * We won't get a change event for the rename, so otherwise
			 * it would stay around forever.
			 */
			gof_file_unref (view->details->renaming_file);
			view->details->renaming_file = NULL;
		}
	}
	
	g_object_unref (view);
}

static void
editable_focus_out_cb (GtkWidget *widget, GdkEvent *event, gpointer user_data)
{
	FMListView *view = user_data;

    //TODO
	//nautilus_view_unfreeze_updates (NAUTILUS_VIEW (view));
	view->details->editable_widget = NULL;
}

static void
cell_renderer_editing_started_cb (GtkCellRenderer *renderer,
                                  GtkCellEditable *editable,
                                  const gchar *path_str,
                                  FMListView *list_view)
{
	GtkEntry *entry;

	entry = GTK_ENTRY (editable);
	list_view->details->editable_widget = editable;

	/* Free a previously allocated original_name */
	g_free (list_view->details->original_name);

	list_view->details->original_name = g_strdup (gtk_entry_get_text (entry));

	g_signal_connect (entry, "focus-out-event",
                      G_CALLBACK (editable_focus_out_cb), list_view);

    //TODO
	/*nautilus_clipboard_set_up_editable
		(GTK_EDITABLE (entry),
		 nautilus_view_get_ui_manager (NAUTILUS_VIEW (list_view)),
		 FALSE);*/
}

static void
cell_renderer_editing_canceled (GtkCellRendererText *cell,
                                FMListView          *view)
{
	view->details->editable_widget = NULL;

    //TODO
	//nautilus_view_unfreeze_updates (NAUTILUS_VIEW (view));
}

static void
cell_renderer_edited (GtkCellRendererText *cell,
                      const char          *path_str,
                      const char          *new_text,
                      FMListView          *view)
{
	GtkTreePath *path;
	GOFFile *file;
	GtkTreeIter iter;

    printf ("%s\n", G_STRFUNC);
	view->details->editable_widget = NULL;

	/* Don't allow a rename with an empty string. Revert to original 
	 * without notifying the user.
	 */
	if (new_text[0] == '\0') {
		g_object_set (G_OBJECT (view->details->file_name_cell),
                      "editable", FALSE, NULL);
		//nautilus_view_unfreeze_updates (FM_DIRECTORY_VIEW (view));
		return;
	}
	
	path = gtk_tree_path_new_from_string (path_str);

	gtk_tree_model_get_iter (GTK_TREE_MODEL (view->model), &iter, path);

	gtk_tree_path_free (path);
	
	gtk_tree_model_get (GTK_TREE_MODEL (view->model), &iter,
                        FM_LIST_MODEL_FILE_COLUMN, &file, -1);

	/* Only rename if name actually changed */
	if (strcmp (new_text, view->details->original_name) != 0) {
		view->details->renaming_file = gof_file_ref (file);
		view->details->rename_done = FALSE;
		gof_file_rename (file, new_text, fm_list_view_rename_callback, g_object_ref (view));

		g_free (view->details->original_name);
		view->details->original_name = g_strdup (new_text);
	}
	
	gof_file_unref (file);

	/*We're done editing - make the filename-cells readonly again.*/
	g_object_set (G_OBJECT (view->details->file_name_cell),
                  "editable", FALSE, NULL);

    //TODO
	//nautilus_view_unfreeze_updates (NAUTILUS_VIEW (view));
}

static void
fm_list_view_start_renaming_file (FMDirectoryView *view,
                                  GOFFile *file,
                                  gboolean select_all)
{
	FMListView *list_view;
	GtkTreeIter iter;
	GtkTreePath *path;
	gint start_offset, end_offset;

	list_view = FM_LIST_VIEW (view);
	
	/* Select all if we are in renaming mode already */
	if (list_view->details->file_name_column && list_view->details->editable_widget) {
		gtk_editable_select_region (GTK_EDITABLE (list_view->details->editable_widget),
                                    0, -1);
		return;
	}

	if (!fm_list_model_get_first_iter_for_file (list_view->model, file, &iter)) {
		return;
	}

	/* Freeze updates to the view to prevent losing rename focus when the tree view updates */
    //TODO
	//nautilus_view_freeze_updates (NAUTILUS_VIEW (view));

	path = gtk_tree_model_get_path (GTK_TREE_MODEL (list_view->model), &iter);

	/* Make filename-cells editable. */
	g_object_set (G_OBJECT (list_view->details->file_name_cell),
                  "editable", TRUE, NULL);

	gtk_tree_view_scroll_to_cell (list_view->tree, NULL,
                                  list_view->details->file_name_column,
                                  TRUE, 0.0, 0.0);
	/* set cursor also triggers editing-started, where we save the editable widget */
	/*gtk_tree_view_set_cursor (list_view->tree, path,
                              list_view->details->file_name_column, TRUE);*/
    /* sound like set_cursor is not enought to trigger editing-started, we use cursor_on_cell instead */
    gtk_tree_view_set_cursor_on_cell (list_view->tree, path,
                                      list_view->details->file_name_column,
                                      (GtkCellRenderer *) list_view->details->file_name_cell,
                                      TRUE);

	if (list_view->details->editable_widget != NULL) {
		eel_filename_get_rename_region (list_view->details->original_name,
                                        &start_offset, &end_offset);

		gtk_editable_select_region (GTK_EDITABLE (list_view->details->editable_widget),
                                    start_offset, end_offset);
	}

	gtk_tree_path_free (path);
}

static void
fm_list_view_sync_selection (FMDirectoryView *view)
{
    FMListView *list_view = FM_LIST_VIEW (view);
    GOFFile *file;

    if (list_view->details->selection != NULL) 
        file = list_view->details->selection->data;

    fm_directory_view_notify_selection_changed (view, file);
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

/*static void
  do_popup_menu (GtkWidget *widget, FMListView *view, GdkEventButton *event)
  {
  if (tree_view_has_selection (GTK_TREE_VIEW (widget))) {
//fm_directory_view_pop_up_selection_context_menu (FM_DIRECTORY_VIEW (view), event);
printf ("popup_selection_menu\n");
} else {
//fm_directory_view_pop_up_background_context_menu (FM_DIRECTORY_VIEW (view), event);
printf ("popup_background_menu\n");
}
}*/

static gboolean
button_press_callback (GtkTreeView *tree_view, GdkEventButton *event, FMListView *view)
{
    GtkTreeSelection    *selection;
    GtkTreePath         *path;
    GtkTreeIter         iter;
    GtkAction           *action;
    GOFFile             *file;

    /* check if the event is for the bin window */
    if (G_UNLIKELY (event->window != gtk_tree_view_get_bin_window (tree_view)))
        return FALSE;

    /* we unselect all selected items if the user clicks on an empty
     * area of the treeview and no modifier key is active.
     */
    if ((event->state & gtk_accelerator_get_default_mod_mask ()) == 0
        && !gtk_tree_view_get_path_at_pos (tree_view, event->x, event->y, NULL, NULL, NULL, NULL))
    {
        selection = gtk_tree_view_get_selection (tree_view);
        gtk_tree_selection_unselect_all (selection);
    }

    /* open the context menu on right clicks */
    if (event->type == GDK_BUTTON_PRESS && event->button == 3)
    {
        selection = gtk_tree_view_get_selection (tree_view);
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
            fm_directory_view_queue_popup (FM_DIRECTORY_VIEW (view), event);
        }
        else
        {
            /* open the context menu */
            fm_directory_view_context_menu (view, event->button, event);
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
            if (G_LIKELY (event->type == GDK_2BUTTON_PRESS || exo_tree_view_get_single_click (EXO_TREE_VIEW (tree_view))))
            {
                file = fm_list_model_file_for_path (view->model, path);
                fm_directory_view_activate_single_file (FM_DIRECTORY_VIEW (view), file, eel_gtk_widget_get_screen (GTK_WIDGET (view)), TRUE);
                g_object_unref (file);
            }

            /* cleanup */
            gtk_tree_path_free (path);
        }

        return TRUE;
    }

    return FALSE;
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
        fm_directory_view_activate_selected_items (view);
        //}
        handled = TRUE;
        break;
    case GDK_KEY_Return:
    case GDK_KEY_KP_Enter:
        /*if ((event->state & GDK_SHIFT_MASK) != 0) {
          activate_selected_items_alternate (FM_LIST_VIEW (view), NULL, TRUE);
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
        gdk_rgba_parse (&rgba, color);
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
        gdk_rgba_parse (&rgba, color);
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
    //view->model = g_object_new (FM_TYPE_LIST_MODEL, "has-child", TRUE, NULL);
    view->model = FM_DIRECTORY_VIEW (view)->model;
    g_object_set (G_OBJECT (view->model), "has-child", TRUE, NULL);
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

    g_signal_connect_object (view->tree, "button-press-event",
                             G_CALLBACK (button_press_callback), view, 0);
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
            col = gtk_tree_view_column_new ();
            view->details->file_name_column = col;
            gtk_tree_view_column_set_sort_column_id  (col,k);
            gtk_tree_view_column_set_resizable (col, TRUE);
            gtk_tree_view_column_set_title (col, col_title[k-3]);
            gtk_tree_view_column_set_expand (col, TRUE);
#if 0
            renderer = gtk_cell_renderer_pixbuf_new (); 
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
           	view->details->file_name_cell = (GtkCellRendererText *) renderer;
            g_signal_connect (renderer, "edited", G_CALLBACK (cell_renderer_edited), view);
			g_signal_connect (renderer, "editing-canceled", G_CALLBACK (cell_renderer_editing_canceled), view);
			g_signal_connect (renderer, "editing-started", G_CALLBACK (cell_renderer_editing_started_cb), view);

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

static void
fm_list_view_remove_file (FMDirectoryView *view, GOFFile *file, GOFDirectoryAsync *directory)
{
    printf ("%s %s\n", G_STRFUNC, g_file_get_uri(file->location));
    GtkTreePath *path;
    GtkTreePath *file_path;
    GtkTreeIter iter;
    GtkTreeIter temp_iter;
    GtkTreeRowReference* row_reference;
    FMListView *list_view;
    GtkTreeModel* tree_model; 
    GtkTreeSelection *selection;

    path = NULL;
    row_reference = NULL;
    list_view = FM_LIST_VIEW (view);
    tree_model = GTK_TREE_MODEL(list_view->model);

    if (fm_list_model_get_tree_iter_from_file (list_view->model, file, directory, &iter))
    {
        selection = gtk_tree_view_get_selection (list_view->tree);
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

        fm_list_model_remove_file (list_view->model, file, directory);

        if (gtk_tree_row_reference_valid (row_reference)) {
            if (list_view->details->new_selection_path) {
                gtk_tree_path_free (list_view->details->new_selection_path);
            }
            list_view->details->new_selection_path = gtk_tree_row_reference_get_path (row_reference);
        }

        if (row_reference) {
            gtk_tree_row_reference_free (row_reference);
        }
    }   
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
get_selection (FMListView *view)
{
    GList *list;

    list = NULL;

    gtk_tree_selection_selected_foreach (gtk_tree_view_get_selection (view->tree),
                                         get_selection_foreach_func, &list);

    return g_list_reverse (list);
}

static GList *
fm_list_view_get_selection (FMDirectoryView *view)
{
    return FM_LIST_VIEW (view)->details->selection;
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
fm_list_view_get_selection_for_file_transfer_foreach_func (GtkTreeModel *model, GtkTreePath *path, GtkTreeIter *iter, gpointer data)
{
    GOFFile *file;
    struct SelectionForeachData *selection_data;
    GtkTreeIter parent, child;

    selection_data = data;

    gtk_tree_model_get (model, iter,
                        FM_LIST_MODEL_FILE_COLUMN, &file,
                        -1);

    if (file != NULL) {
        /* If the parent folder is also selected, don't include this file in the
         * file operation, since that would copy it to the toplevel target instead
         * of keeping it as a child of the copied folder
         */
        child = *iter;
        while (gtk_tree_model_iter_parent (model, &parent, &child)) {
            if (gtk_tree_selection_iter_is_selected (selection_data->selection,
                                                     &parent)) {
                return;
            }
            child = parent;
        }

        gof_file_ref (file);
        selection_data->list = g_list_prepend (selection_data->list, file);
    }
}


static GList *
fm_list_view_get_selection_for_file_transfer (FMDirectoryView *view)
{
    struct SelectionForeachData selection_data;

    selection_data.list = NULL;
    selection_data.selection = gtk_tree_view_get_selection (FM_LIST_VIEW (view)->tree);

    gtk_tree_selection_selected_foreach (selection_data.selection,
                                         fm_list_view_get_selection_for_file_transfer_foreach_func, &selection_data);

    return g_list_reverse (selection_data.list);
}

static GtkTreePath*
fm_list_view_get_path_at_pos (FMDirectoryView *view, gint x, gint y)
{
    GtkTreePath *path;

    g_return_val_if_fail (FM_IS_LIST_VIEW (view), NULL);

    if (gtk_tree_view_get_dest_row_at_pos (FM_LIST_VIEW (view)->tree, x, y, &path, NULL))
        return path;

    return NULL;
}

static void
fm_list_view_highlight_path (FMDirectoryView *view, GtkTreePath *path)
{
    g_return_if_fail (FM_IS_LIST_VIEW (view));
    //gtk_tree_view_set_drag_dest_row (GTK_TREE_VIEW (GTK_BIN (standard_view)->child), path, GTK_TREE_VIEW_DROP_INTO_OR_AFTER);
    gtk_tree_view_set_drag_dest_row (FM_LIST_VIEW (view)->tree, path, GTK_TREE_VIEW_DROP_INTO_OR_AFTER);
}

#if 0
static void
fm_list_view_zoom_level_changed (FMListView *view)
{
    GList *cols, *l;

    cols =  gtk_tree_view_get_columns (view->tree);
    for(l=cols; l != NULL; l=l->next) {
        /* just queue a resize on this column */
        if (gtk_tree_view_column_get_visible (l->data))
            gtk_tree_view_column_queue_resize (l->data);
    }
}
#endif

static void
fm_list_view_finalize (GObject *object)
{
    FMListView *view = FM_LIST_VIEW (object);

    log_printf (LOG_LEVEL_UNDEFINED, "$$ %s\n", G_STRFUNC);

    g_free (view->details->original_name);
	view->details->original_name = NULL;

    if (view->details->new_selection_path)
        gtk_tree_path_free (view->details->new_selection_path);
    if (view->details->selection)
        gof_file_list_free (view->details->selection);

    g_object_unref (view->model);
    g_free (view->details);
    G_OBJECT_CLASS (fm_list_view_parent_class)->finalize (object); 
}

static void
fm_list_view_init (FMListView *view)
{
    view->details = g_new0 (FMListViewDetails, 1);
    view->details->selection = NULL;

    create_and_set_up_tree_view (view);

    g_settings_bind (settings, "single-click", 
                     EXO_TREE_VIEW (view->tree), "single-click", 0);
    g_settings_bind (settings, "single-click-timeout", 
                     EXO_TREE_VIEW (view->tree), "single-click-timeout", 0);

    /* set the new "size" for the icon renderer */
    g_object_set (G_OBJECT (FM_DIRECTORY_VIEW (view)->icon_renderer), "size", 16, NULL);
    //TODO clean up this "hack"
    gtk_cell_renderer_set_fixed_size (FM_DIRECTORY_VIEW (view)->icon_renderer, 18, 18);

    //fm_list_view_zoom_level_changed (view);
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
    fm_directory_view_class->remove_file = fm_list_view_remove_file;
    fm_directory_view_class->colorize_selection = fm_list_view_colorize_selected_items;        
    fm_directory_view_class->sync_selection = fm_list_view_sync_selection;
    fm_directory_view_class->get_selection = fm_list_view_get_selection;
    fm_directory_view_class->get_selection_for_file_transfer = fm_list_view_get_selection_for_file_transfer;

    fm_directory_view_class->get_path_at_pos = fm_list_view_get_path_at_pos;
    fm_directory_view_class->highlight_path = fm_list_view_highlight_path;
    fm_directory_view_class->start_renaming_file = fm_list_view_start_renaming_file;



    //eel_g_settings_add_auto_boolean (settings, "single-click", &single_click);
    //g_type_class_add_private (object_class, sizeof (GOFDirectoryAsyncPrivate));
}

