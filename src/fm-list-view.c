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
#include <glib/gi18n.h>
#include <gdk/gdk.h>
#include <gdk/gdkkeysyms.h>

#include "exo-tree-view.h"
//#include "gof-directory-async.h"
#include "marlin-cell-renderer-text-ellipsized.h"
#include "eel-glib-extensions.h"
#include "eel-gtk-extensions.h"
#include "marlin-vala.h"

/*enum
{
    PROP_0,
    PROP_ZOOM_LEVEL,
};*/

struct FMListViewDetails {
    GList       *selection;

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

static gchar *col_title[4] = { N_("Filename"), N_("Size"), N_("Type"), N_("Modified") };

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
static GList    *fm_list_view_get_selected_paths (FMDirectoryView *view);
static void     fm_list_view_select_path (FMDirectoryView *view, GtkTreePath *path);
static void     fm_list_view_set_cursor (FMDirectoryView *view, GtkTreePath *path,
                                         gboolean start_editing, gboolean select);

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
                //Remove the unloaded subdirectory from the subdirectories list.
                unload_data->view->loaded_subdirectories = g_list_remove (
                                                                unload_data->view->loaded_subdirectories,
                                                                unload_data->directory);
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
        //Add the subdirectory to the loaded subdirectories list.
        view->loaded_subdirectories = g_list_append (view->loaded_subdirectories, directory);
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

    eel_add_weak_pointer (&unload_data->view);
    g_timeout_add_seconds (COLLAPSE_TO_UNLOAD_DELAY,
                           unload_file_timeout,
                           unload_data);
}

static void
list_selection_changed_callback (GtkTreeSelection *selection, gpointer user_data)
{
    FMListView *view = FM_LIST_VIEW (user_data);

    if (view->details->selection != NULL)
        gof_file_list_free (view->details->selection);
    view->details->selection = get_selection (view);

    fm_directory_view_notify_selection_changed (FM_DIRECTORY_VIEW (view));
}

static void
fm_list_view_item_hovered (ExoTreeView *exo_tree, GtkTreePath *path, FMListView *view)
{
    fm_directory_view_notify_item_hovered (FM_DIRECTORY_VIEW (view), path);
}

static void
row_activated_callback (GtkTreeView *treeview, GtkTreeIter *iter, GtkTreePath *path, FMListView *view)
{
    g_debug ("%s\n", G_STRFUNC);
    fm_directory_view_activate_selected_items (FM_DIRECTORY_VIEW (view), MARLIN_WINDOW_OPEN_FLAG_DEFAULT);
}

static void
fm_list_view_freeze_updates (FMListView *view)
{
    /* Make filename-cells editable. */
	g_object_set (G_OBJECT (view->details->file_name_cell),
                  "editable", TRUE, NULL);
    fm_directory_view_freeze_updates (FM_DIRECTORY_VIEW (view));
}

static void
fm_list_view_unfreeze_updates (FMListView *view)
{
    /*We're done editing - make the filename-cells readonly again.*/
	g_object_set (G_OBJECT (view->details->file_name_cell),
                  "editable", FALSE, NULL);
	fm_directory_view_unfreeze_updates (FM_DIRECTORY_VIEW (view));
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
            marlin_dialogs_show_error (GTK_WIDGET (view), error, _("Failed to rename %s to %s"), g_file_info_get_name (file->info), view->details->original_name);
			/* If the rename failed (or was cancelled), kill renaming_file.
			 * We won't get a change event for the rename, so otherwise
			 * it would stay around forever.
			 */
			g_object_unref (view->details->renaming_file);
		}
	}
	
	g_object_unref (view);
}

static void
editable_focus_out_cb (GtkWidget *widget, GdkEvent *event, gpointer user_data)
{
	FMListView *view = user_data;

	view->details->editable_widget = NULL;
	fm_list_view_unfreeze_updates (view);
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
	//fm_list_view_unfreeze_updates (view);
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

    g_message ("%s\n", G_STRFUNC);
	view->details->editable_widget = NULL;

	/* Don't allow a rename with an empty string. Revert to original
	 * without notifying the user.
	 */
	if (new_text[0] == '\0') {
		fm_list_view_unfreeze_updates (view);
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
		g_free (view->details->original_name);
		view->details->original_name = g_strdup (new_text);
		gof_file_rename (file, new_text, fm_list_view_rename_callback, g_object_ref (view));
	}
	
	gof_file_unref (file);

	fm_list_view_unfreeze_updates (view);
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
	fm_list_view_freeze_updates (FM_LIST_VIEW (view));

	path = gtk_tree_model_get_path (GTK_TREE_MODEL (list_view->model), &iter);

	gtk_tree_view_scroll_to_cell (list_view->tree, NULL,
                                  list_view->details->file_name_column,
                                  TRUE, 0.0, 0.0);
	/* set cursor also triggers editing-started, where we save the editable widget */
	/*gtk_tree_view_set_cursor (list_view->tree, path,
                              list_view->details->file_name_column, TRUE);*/
    /* sound like set_cursor is not enough to trigger editing-started, we use cursor_on_cell instead */
    gtk_tree_view_set_cursor_on_cell (list_view->tree, path,
                                      list_view->details->file_name_column,
                                      (GtkCellRenderer *) list_view->details->file_name_cell,
                                      TRUE);

    if (list_view->details->editable_widget != NULL) {
        marlin_get_rename_region (list_view->details->original_name, &start_offset, &end_offset, select_all);
        gtk_editable_select_region (GTK_EDITABLE (list_view->details->editable_widget),
                                    start_offset, end_offset);
    }

	gtk_tree_path_free (path);
}

static void
fm_list_view_sync_selection (FMDirectoryView *view)
{
    fm_directory_view_notify_selection_changed (view);
}

static void
subdirectory_unloaded_callback (FMListModel *model,
                                GOFDirectoryAsync *directory,
                                gpointer callback_data)
{
    g_debug ("%s\n", G_STRFUNC);
    FMListView *view;

    g_return_if_fail (FM_IS_LIST_MODEL (model));
    g_return_if_fail (GOF_DIRECTORY_IS_ASYNC (directory));

    view = FM_LIST_VIEW(callback_data);

    fm_directory_view_remove_subdirectory (FM_DIRECTORY_VIEW (view), directory);
}

static gboolean
button_press_callback (GtkTreeView *tree_view, GdkEventButton *event, FMListView *view)
{
    GtkTreeSelection    *selection;
    GtkTreePath         *path;
    GtkTreeIter         iter;
    GtkAction           *action;
    GOFFile             *file;

    selection = gtk_tree_view_get_selection (tree_view);
    /* check if the event is for the bin window */
    if (G_UNLIKELY (event->window != gtk_tree_view_get_bin_window (tree_view)))
        return FALSE;

    /* we unselect all selected items if the user clicks on an empty
     * area of the treeview and no modifier key is active.
     */
    if ((event->state & gtk_accelerator_get_default_mod_mask ()) == 0
        && !gtk_tree_view_get_path_at_pos (tree_view, event->x, event->y, NULL, NULL, NULL, NULL))
    {
        gtk_tree_selection_unselect_all (selection);
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
                if (!gtk_tree_view_is_blank_at_pos (tree_view, event->x, event->y, NULL, NULL, NULL, NULL)	&& gtk_tree_path_get_depth (path) == 1)
                    gtk_tree_selection_select_path (selection, path);
            }

            gtk_tree_path_free (path);
        }
        /* queue the menu popup */
        fm_directory_view_queue_popup (FM_DIRECTORY_VIEW (view), event);

        return TRUE;
    }
    else if ((event->type == GDK_BUTTON_PRESS || event->type == GDK_2BUTTON_PRESS) && event->button == 2)
    {
        /* determine the path to the item that was middle-clicked */
        if (gtk_tree_view_get_path_at_pos (tree_view, event->x, event->y, &path, NULL, NULL, NULL))
        {
            /* select only the path to the item on which the user clicked */
            gtk_tree_selection_unselect_all (selection);
            gtk_tree_selection_select_path (selection, path);

            fm_directory_view_activate_selected_items (FM_DIRECTORY_VIEW (view), MARLIN_WINDOW_OPEN_FLAG_NEW_TAB);

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
    case GDK_KEY_F10:
        if (event->state & GDK_CONTROL_MASK) {
            fm_directory_view_do_popup_menu (view, (GdkEventButton *) event);
            handled = TRUE;
        }
        break;
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
        if ((event->state & GDK_SHIFT_MASK) != 0) {
            /* alternate */
            fm_directory_view_activate_selected_items (view, MARLIN_WINDOW_OPEN_FLAG_NEW_TAB);
        } else {
            fm_directory_view_preview_selected_items (view);
        }
        handled = TRUE;
        break;
    case GDK_KEY_Return:
    case GDK_KEY_KP_Enter:
        if ((event->state & GDK_SHIFT_MASK) != 0) {
            /* alternate */
            fm_directory_view_activate_selected_items (view, MARLIN_WINDOW_OPEN_FLAG_NEW_TAB);
        } else {
            fm_directory_view_activate_selected_items (view, MARLIN_WINDOW_OPEN_FLAG_DEFAULT);
        }
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
                         FMListView        *view)
{
    char *text;
    char *color;
    GdkRGBA rgba = {0.0, 0.0, 0.0, 0.0};

    GtkTreePath *path, *hover_path;

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

    g_object_set (G_OBJECT (renderer),
                  "text", text,
                  "underline", PANGO_UNDERLINE_NONE,
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
    GdkRGBA rgba = {0.0, 0.0, 0.0, 0.0};

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

static gboolean fm_list_view_draw(GtkWidget* view_, cairo_t* cr, FMListView* view)
{
    g_return_val_if_fail(FM_IS_LIST_VIEW(view), FALSE);

    GOFDirectoryAsync *dir = fm_directory_view_get_current_directory (FM_DIRECTORY_VIEW (view));

    if (gof_directory_async_is_empty (dir))
    {
        PangoLayout* layout = gtk_widget_create_pango_layout(GTK_WIDGET(view), NULL);
        gchar *str = g_strconcat("<span size='x-large'>", _("This folder is empty."), "</span>", NULL);
        pango_layout_set_markup (layout, str, -1);

        PangoRectangle extents;
        /* Get hayout height and width */
        pango_layout_get_extents(layout, NULL, &extents);
        gdouble width = pango_units_to_double(extents.width);
        gdouble height = pango_units_to_double(extents.height);
        gtk_render_layout(gtk_widget_get_style_context(GTK_WIDGET(view)), cr,
                (double)gtk_widget_get_allocated_width(GTK_WIDGET(view))/2 - width/2,
                (double)gtk_widget_get_allocated_height(GTK_WIDGET(view))/2 - height/2,
                layout);
    }

    return FALSE;
}

static void
create_and_set_up_tree_view (FMListView *view)
{
    int k;
    GtkTreeViewColumn       *col;
    GtkCellRenderer         *renderer;

    view->model = FM_DIRECTORY_VIEW (view)->model;
    g_object_set (G_OBJECT (view->model), "has-child", TRUE, NULL);

    view->tree = GTK_TREE_VIEW (exo_tree_view_new ());
    gtk_tree_view_set_model (view->tree, GTK_TREE_MODEL (view->model));

    gtk_tree_view_set_search_column (view->tree, FM_LIST_MODEL_FILENAME);
    gtk_tree_view_set_rubber_banding (view->tree, TRUE);
    gtk_tree_view_set_rules_hint (view->tree, TRUE);

    g_signal_connect (view->tree, "item-hovered", G_CALLBACK (fm_list_view_item_hovered), view);
    g_signal_connect_object (gtk_tree_view_get_selection (view->tree), "changed",
                             G_CALLBACK (list_selection_changed_callback), view, 0);

    g_signal_connect_object (view->tree, "button-press-event",
                             G_CALLBACK (button_press_callback), view, 0);
    g_signal_connect (view->tree, "draw",
                             G_CALLBACK (fm_list_view_draw), view);
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

    for(k=FM_LIST_MODEL_FILENAME; k< FM_LIST_MODEL_NUM_COLUMNS; k++) {
        if (k == FM_LIST_MODEL_FILENAME) {
            col = gtk_tree_view_column_new ();
            view->details->file_name_column = col;
            gtk_tree_view_column_set_sort_column_id  (col,k);
            gtk_tree_view_column_set_resizable (col, TRUE);
            gtk_tree_view_column_set_title (col, gettext(col_title[k-FM_LIST_MODEL_FILENAME]));
            gtk_tree_view_column_set_expand (col, TRUE);

            /* add the icon renderer */
            gtk_tree_view_column_pack_start (col, FM_DIRECTORY_VIEW (view)->icon_renderer, FALSE);
            gtk_tree_view_column_set_attributes (col, FM_DIRECTORY_VIEW (view)->icon_renderer,
                                                 "file",  FM_LIST_MODEL_FILE_COLUMN, NULL);

            renderer = marlin_cell_renderer_text_ellipsized_new ();
           	view->details->file_name_cell = (GtkCellRendererText *) renderer;
            g_signal_connect (renderer, "edited", G_CALLBACK (cell_renderer_edited), view);
			g_signal_connect (renderer, "editing-canceled", G_CALLBACK (cell_renderer_editing_canceled), view);
			g_signal_connect (renderer, "editing-started", G_CALLBACK (cell_renderer_editing_started_cb), view);

            gtk_tree_view_column_pack_start (col, renderer, TRUE);
            gtk_tree_view_column_set_cell_data_func (col, renderer,
                                                     (GtkTreeCellDataFunc) filename_cell_data_func,
                                                     view, NULL);
        } else {
            renderer = gtk_cell_renderer_text_new( );
            col = gtk_tree_view_column_new_with_attributes(gettext(col_title[k-FM_LIST_MODEL_FILENAME]), renderer, "text", k, NULL);
            if (k == FM_LIST_MODEL_SIZE || k == FM_LIST_MODEL_MODIFIED) {
                g_object_set (renderer, "xalign", 1.0);
            }
            gtk_tree_view_column_set_sort_column_id  (col,k);
            gtk_tree_view_column_set_resizable (col, TRUE);
            //gtk_tree_view_column_set_fixed_width (col, 240);
            //amtest
            gtk_tree_view_column_set_cell_data_func (col, renderer,
                                                     (GtkTreeCellDataFunc) color_row_func,
                                                     NULL, NULL);
        }

        gtk_tree_view_append_column(view->tree, col);
    }
    gtk_widget_show (GTK_WIDGET (view->tree));
    gtk_container_add (GTK_CONTAINER (view), GTK_WIDGET (view->tree));
}

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
    GList *list = NULL;

    gtk_tree_selection_selected_foreach (gtk_tree_view_get_selection (view->tree),
                                         get_selection_foreach_func, &list);

    return g_list_reverse (list);
}

static GList *
fm_list_view_get_selection (FMDirectoryView *view)
{
    return FM_LIST_VIEW (view)->details->selection;
}

static GList *
fm_list_view_get_selected_paths (FMDirectoryView *view)
{
    GtkTreeSelection *selection;

    selection = gtk_tree_view_get_selection (FM_LIST_VIEW (view)->tree);
    return gtk_tree_selection_get_selected_rows (selection, NULL);
}

static void
fm_list_view_select_path (FMDirectoryView *view, GtkTreePath *path)
{
    GtkTreeSelection *selection;

    selection = gtk_tree_view_get_selection (FM_LIST_VIEW (view)->tree);
    gtk_tree_selection_select_path (selection, path);
}

static void
fm_list_view_set_cursor (FMDirectoryView *view, GtkTreePath *path,
                         gboolean start_editing, gboolean select)
{
    FMListView *list_view = FM_LIST_VIEW (view);
    GtkTreeSelection *selection = gtk_tree_view_get_selection (list_view->tree);

    /* the treeview select the path by default */
    if (!select)
        g_signal_handlers_block_by_func (selection, list_selection_changed_callback, list_view);
    gtk_tree_view_set_cursor_on_cell (list_view->tree, path,
                                      list_view->details->file_name_column,
                                      (GtkCellRenderer *) list_view->details->file_name_cell,
                                      start_editing);

    if (!select) {
        gtk_tree_selection_unselect_path (selection, path);
        g_signal_handlers_unblock_by_func (selection, list_selection_changed_callback, list_view);
    }
}

static void
fm_list_view_select_all (FMDirectoryView *view)
{
    gtk_tree_selection_select_all (gtk_tree_view_get_selection (FM_LIST_VIEW (view)->tree));
}

static void fm_list_view_unselect_all(FMDirectoryView *view)
{
    g_return_if_fail (FM_IS_LIST_VIEW (view));
    
    GtkTreeSelection *selection;
    selection = gtk_tree_view_get_selection (FM_LIST_VIEW (view)->tree);
    if (selection)
        gtk_tree_selection_unselect_all (selection);
}

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

static gboolean
fm_list_view_get_visible_range (FMDirectoryView *view,
                                GtkTreePath     **start_path,
                                GtkTreePath     **end_path)

{
    g_return_val_if_fail (FM_IS_LIST_VIEW (view), FALSE);
    return gtk_tree_view_get_visible_range (FM_LIST_VIEW (view)->tree,
                                            start_path, end_path);
}

static void
fm_list_view_zoom_normal (FMDirectoryView *view)
{
    MarlinZoomLevel     zoom;

    zoom = g_settings_get_enum (marlin_list_view_settings, "default-zoom-level");
    g_settings_set_enum (marlin_list_view_settings, "zoom-level", zoom);
}

static void
fm_list_view_finalize (GObject *object)
{
    FMListView *view = FM_LIST_VIEW (object);

    g_debug ("%s\n", G_STRFUNC);

    //Unload all the subdirectories in the loaded subdirectories list.
    GList *l = NULL;
    for (l = view->loaded_subdirectories; l != NULL; l = l->next) {
        GOFDirectoryAsync *directory = GOF_DIRECTORY_ASYNC (l->data);
        fm_directory_view_remove_subdirectory (FM_DIRECTORY_VIEW (view), directory);
    }

    g_list_free (view->loaded_subdirectories);

    g_free (view->details->original_name);
	view->details->original_name = NULL;

    if (view->details->selection)
        gof_file_list_free (view->details->selection);

    g_free (view->details);
    G_OBJECT_CLASS (fm_list_view_parent_class)->finalize (object);
}

static void
fm_list_view_init (FMListView *view)
{
    view->details = g_new0 (FMListViewDetails, 1);
    view->details->selection = NULL;
    view->loaded_subdirectories = NULL;

    create_and_set_up_tree_view (view);

    g_settings_bind (settings, "single-click",
                     EXO_TREE_VIEW (view->tree), "single-click", 0);
    g_settings_bind (marlin_list_view_settings, "zoom-level",
                     view, "zoom-level", 0);
}

static void
fm_list_view_zoom_level_changed (FMDirectoryView *view)
{
    /* set the new "size" for the icon renderer */
    g_object_set (G_OBJECT (view->icon_renderer), "size", marlin_zoom_level_to_icon_size (view->zoom_level), "zoom-level", view->zoom_level, NULL);
    gint xpad, ypad;

    gtk_cell_renderer_get_padding (view->icon_renderer, &xpad, &ypad);
    gtk_cell_renderer_set_fixed_size (view->icon_renderer,
                                      marlin_zoom_level_to_icon_size (view->zoom_level) + 2 * xpad,
                                      marlin_zoom_level_to_icon_size (view->zoom_level) + 2 * ypad);
    gtk_tree_view_columns_autosize (FM_LIST_VIEW (view)->tree);
}

#if 0
static void
fm_list_view_get_property (GObject    *object,
                           guint       prop_id,
                           GValue     *value,
                           GParamSpec *pspec)
{
    FMListView *view = FM_LIST_VIEW (object);

    switch (prop_id)
    {

    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
        break;
    }
}

static void
fm_list_view_set_property (GObject      *object,
                           guint        prop_id,
                           const GValue *value,
                           GParamSpec   *pspec)
{
    FMListView *view = FM_LIST_VIEW (object);

    switch (prop_id)
    {

    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
        break;
    }
}
#endif

static void
fm_list_view_class_init (FMListViewClass *klass)
{
    FMDirectoryViewClass *fm_directory_view_class;
    GObjectClass *object_class = G_OBJECT_CLASS (klass);

    object_class->finalize     = fm_list_view_finalize;
    /*object_class->get_property = fm_list_view_get_property;
    object_class->set_property = fm_list_view_set_property;*/

    fm_directory_view_class = FM_DIRECTORY_VIEW_CLASS (klass);

    fm_directory_view_class->sync_selection = fm_list_view_sync_selection;
    fm_directory_view_class->get_selection = fm_list_view_get_selection;
    fm_directory_view_class->get_selection_for_file_transfer = fm_list_view_get_selection_for_file_transfer;
    fm_directory_view_class->get_selected_paths = fm_list_view_get_selected_paths;
    fm_directory_view_class->select_path = fm_list_view_select_path;
    fm_directory_view_class->select_all = fm_list_view_select_all;
    fm_directory_view_class->unselect_all = fm_list_view_unselect_all;
    fm_directory_view_class->set_cursor = fm_list_view_set_cursor;

    fm_directory_view_class->get_path_at_pos = fm_list_view_get_path_at_pos;
    fm_directory_view_class->highlight_path = fm_list_view_highlight_path;
    fm_directory_view_class->get_visible_range = fm_list_view_get_visible_range;
    fm_directory_view_class->start_renaming_file = fm_list_view_start_renaming_file;
    fm_directory_view_class->zoom_normal = fm_list_view_zoom_normal;
    fm_directory_view_class->zoom_level_changed = fm_list_view_zoom_level_changed;
}

