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

//#include "marlin-cell-renderer-text-ellipsized.h"
#include "marlin-global-preferences.h"
#include "eel-gtk-extensions.h"
#include "marlin-tags.h"

/*enum
{
    PROP_0,
    PROP_ZOOM_LEVEL,
};*/

struct FMColumnsViewDetails {
    GList       *selection;

    GtkCellEditable     *editable_widget;
    GtkTreeViewColumn   *file_name_column;
    GtkCellRendererText *file_name_cell;
    char                *original_name;

    GOFFile             *renaming_file;
    gboolean            rename_done;

    gint                pressed_button;
    gboolean            updates_frozen;
};

/* Wait for the rename to end when activating a file being renamed */
#define WAIT_FOR_RENAME_ON_ACTIVATE 200

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
static GList    *fm_columns_view_get_selected_paths (FMDirectoryView *view);
static void     fm_columns_view_select_path (FMDirectoryView *view, GtkTreePath *path);
static void     fm_columns_view_set_cursor (FMDirectoryView *view, GtkTreePath *path,
                                             gboolean start_editing, gboolean select);

static gboolean fm_columns_view_draw(GtkWidget* view_, cairo_t* cr, FMColumnsView* view)
{
    g_return_val_if_fail(FM_IS_COLUMNS_VIEW(view), FALSE);
    
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
show_selected_files (GOFFile *file)
{
    g_message ("selected: %s\n", file->name);
}

static void
list_selection_changed_callback (GtkTreeSelection *selection, gpointer user_data)
{
    FMColumnsView *view = FM_COLUMNS_VIEW (user_data);
    GOFFile *file;

    g_warning ("%s", G_STRFUNC);
    if (view->details->selection != NULL)
        gof_file_list_free (view->details->selection);
    view->details->selection = get_selection (view);
    //show_selected_files (file);

    /* don't update column if we got a drag_begin started */
    if (fm_directory_view_is_drag_pending (FM_DIRECTORY_VIEW (view)))
        return;

    /* setup the current active slot */
    fm_directory_view_set_active_slot (FM_DIRECTORY_VIEW (view));
    fm_directory_view_notify_selection_changed (FM_DIRECTORY_VIEW (view));

    if (view->details->selection == NULL)
        return;
    /* dont show preview or load directory if we got more than 1 element selected */
    if (view->details->selection->next)
        return;
    if (view->details->updates_frozen)
        return;

    file = view->details->selection->data;
    if (file->is_directory)
        fm_directory_view_column_add_location (FM_DIRECTORY_VIEW (view), file->location);
    else
        fm_directory_view_column_add_preview (FM_DIRECTORY_VIEW (view), view->details->selection);
}

static void
row_activated_callback (GtkTreeView *treeview, GtkTreeIter *iter, GtkTreePath *path, FMColumnsView *view)
{
    g_message ("%s\n", G_STRFUNC);
    fm_directory_view_activate_selected_items (FM_DIRECTORY_VIEW (view), MARLIN_WINDOW_OPEN_FLAG_NEW_TAB);
}

static void
fm_columns_view_freeze_updates (FMColumnsView *view)
{
    view->details->updates_frozen = TRUE;
	
    /* Make filename-cells editable. */
	g_object_set (G_OBJECT (view->details->file_name_cell),
                  "editable", TRUE, NULL);
	fm_directory_view_freeze_updates (FM_DIRECTORY_VIEW (view));
}

static void
fm_columns_view_unfreeze_updates (FMColumnsView *view)
{
    view->details->updates_frozen = FALSE;
	
    /*We're done editing - make the filename-cells readonly again.*/
	g_object_set (G_OBJECT (view->details->file_name_cell),
                  "editable", FALSE, NULL);
	fm_directory_view_unfreeze_updates (FM_DIRECTORY_VIEW (view));
}

static void
fm_columns_view_rename_callback (GOFFile *file,
                                 GFile *result_location,
                                 GError *error,
                                 gpointer callback_data)
{
	FMColumnsView *view = FM_COLUMNS_VIEW (callback_data);

    printf ("%s\n", G_STRFUNC);
	if (view->details->renaming_file) {
		view->details->rename_done = TRUE;
		
		if (error != NULL) {
            marlin_dialogs_show_error (GTK_WIDGET (view), error, _("Failed to rename %s to %s"), file->name, view->details->original_name);
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
	FMColumnsView *view = user_data;

	fm_columns_view_unfreeze_updates (view);
	view->details->editable_widget = NULL;
}

static void
cell_renderer_editing_started_cb (GtkCellRenderer *renderer,
                                  GtkCellEditable *editable,
                                  const gchar *path_str,
                                  FMColumnsView *col_view)
{
	GtkEntry *entry;

	entry = GTK_ENTRY (editable);
	col_view->details->editable_widget = editable;

	/* Free a previously allocated original_name */
	g_free (col_view->details->original_name);

	col_view->details->original_name = g_strdup (gtk_entry_get_text (entry));

	g_signal_connect (entry, "focus-out-event",
                      G_CALLBACK (editable_focus_out_cb), col_view);
}

static void
cell_renderer_editing_canceled (GtkCellRendererText *cell,
                                FMColumnsView          *view)
{
	view->details->editable_widget = NULL;
	fm_columns_view_unfreeze_updates (view);
}

static void
cell_renderer_edited (GtkCellRendererText *cell,
                      const char          *path_str,
                      const char          *new_text,
                      FMColumnsView          *view)
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
		fm_columns_view_unfreeze_updates (view);
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
		gof_file_rename (file, new_text, fm_columns_view_rename_callback, g_object_ref (view));

		g_free (view->details->original_name);
		view->details->original_name = g_strdup (new_text);
	}
	
	gof_file_unref (file);

	fm_columns_view_unfreeze_updates (view);
}

static void
fm_columns_view_start_renaming_file (FMDirectoryView *view,
                                     GOFFile *file,
                                     gboolean select_all)
{
	FMColumnsView *col_view;
	GtkTreeIter iter;
	GtkTreePath *path;
	gint start_offset, end_offset;

	col_view = FM_COLUMNS_VIEW (view);

    g_message ("%s", G_STRFUNC);
	/* Select all if we are in renaming mode already */
	if (col_view->details->file_name_column && col_view->details->editable_widget) {
		gtk_editable_select_region (GTK_EDITABLE (col_view->details->editable_widget),
                                    0, -1);
		return;
	}

	if (!fm_list_model_get_first_iter_for_file (col_view->model, file, &iter)) {
		return;
	}

	/* Freeze updates to the view to prevent losing rename focus when the tree view updates */
	fm_columns_view_freeze_updates (col_view);

	path = gtk_tree_model_get_path (GTK_TREE_MODEL (col_view->model), &iter);

	gtk_tree_view_scroll_to_cell (col_view->tree, NULL,
                                  col_view->details->file_name_column,
                                  TRUE, 0.0, 0.0);
	/* set cursor also triggers editing-started, where we save the editable widget */
	/*gtk_tree_view_set_cursor (col_view->tree, path,
                              col_view->details->file_name_column, TRUE);*/
    /* sound like set_cursor is not enought to trigger editing-started, we use cursor_on_cell instead */
    gtk_tree_view_set_cursor_on_cell (col_view->tree, path,
                                      col_view->details->file_name_column,
                                      (GtkCellRenderer *) col_view->details->file_name_cell,
                                      TRUE);

	if (col_view->details->editable_widget != NULL) {
		eel_filename_get_rename_region (col_view->details->original_name,
                                        &start_offset, &end_offset);

		gtk_editable_select_region (GTK_EDITABLE (col_view->details->editable_widget),
                                    start_offset, end_offset);
	}

	gtk_tree_path_free (path);
}

static void fm_columns_view_select_all(FMDirectoryView *view)
{
    gtk_tree_selection_select_all (gtk_tree_view_get_selection (FM_COLUMNS_VIEW (view)->tree));
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
        if (view->details->pressed_button < 0) {
            view->details->pressed_button = event->button;
            view->details->updates_frozen = TRUE;
        }
    }

    /* open the context menu on right clicks */
    if (event->type == GDK_BUTTON_PRESS && event->button == 3)
    {
        if (view->details->pressed_button < 0) {
            view->details->pressed_button = event->button;
            view->details->updates_frozen = TRUE;
        }
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
            printf ("menu queue_popup\n");
            fm_directory_view_set_active_slot (FM_DIRECTORY_VIEW (view));
            fm_directory_view_queue_popup (FM_DIRECTORY_VIEW (view), event);
        }
        else
        {
            /* open the context menu */
            printf ("context_menu\n");
            fm_directory_view_set_active_slot (FM_DIRECTORY_VIEW (view));
            fm_directory_view_context_menu (FM_DIRECTORY_VIEW (view), event);
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

    g_message ("%s", G_STRFUNC);
    if (view->details->pressed_button == event->button && view->details->pressed_button != -1)
    {
        view->details->updates_frozen = FALSE;
        selection = gtk_tree_view_get_selection (tree_view);
        list_selection_changed_callback (selection, view);
        
        /* reset the pressed_button state */
        view->details->pressed_button = -1;
    }
    

    return TRUE;
}

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

    underline = PANGO_UNDERLINE_NONE;

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
    GtkTreeViewColumn       *col;
    GtkCellRenderer         *renderer;

    view->model = FM_DIRECTORY_VIEW (view)->model;
    g_object_set (G_OBJECT (view->model), "has-child", FALSE, NULL);

    view->tree = g_object_new (GTK_TYPE_TREE_VIEW, "model", GTK_TREE_MODEL (view->model),
                               "headers-visible", FALSE, NULL);
    gtk_tree_view_set_search_column (view->tree, FM_LIST_MODEL_FILENAME);

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
    g_signal_connect (view->tree, "draw",
                             G_CALLBACK (fm_columns_view_draw), view);

    gtk_tree_selection_set_mode (gtk_tree_view_get_selection (view->tree), GTK_SELECTION_MULTIPLE);

    col = gtk_tree_view_column_new ();
    view->details->file_name_column = col;
    gtk_tree_view_column_set_sort_column_id  (col, FM_LIST_MODEL_FILENAME);
    gtk_tree_view_column_set_expand (col, TRUE);

    /* add the icon renderer */
    gtk_tree_view_column_pack_start (col, FM_DIRECTORY_VIEW (view)->icon_renderer, FALSE);
    gtk_tree_view_column_set_attributes (col, FM_DIRECTORY_VIEW (view)->icon_renderer,
                                         "file",  FM_LIST_MODEL_FILE_COLUMN, NULL);

    //renderer = marlin_cell_renderer_text_ellipsized_new ();
    renderer = gtk_cell_renderer_text_new( );
    view->details->file_name_cell = (GtkCellRendererText *) renderer;
    g_signal_connect (renderer, "edited", G_CALLBACK (cell_renderer_edited), view);
    g_signal_connect (renderer, "editing-canceled", G_CALLBACK (cell_renderer_editing_canceled), view);
    g_signal_connect (renderer, "editing-started", G_CALLBACK (cell_renderer_editing_started_cb), view);

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

static GList *
fm_columns_view_get_selected_paths (FMDirectoryView *view)
{
    GtkTreeSelection *selection;

    selection = gtk_tree_view_get_selection (FM_COLUMNS_VIEW (view)->tree);
    return gtk_tree_selection_get_selected_rows (selection, NULL);
}

static void
fm_columns_view_select_path (FMDirectoryView *view, GtkTreePath *path)
{
    GtkTreeSelection *selection;

    selection = gtk_tree_view_get_selection (FM_COLUMNS_VIEW (view)->tree);
    gtk_tree_selection_select_path (selection, path);
}

static void
fm_columns_view_set_cursor (FMDirectoryView *view, GtkTreePath *path, 
                            gboolean start_editing, gboolean select)
{
    FMColumnsView *cols_view = FM_COLUMNS_VIEW (view);
    GtkTreeSelection *selection = gtk_tree_view_get_selection (cols_view->tree);

    /* the treeview select the path by default. */
    if (!select)
        g_signal_handlers_block_by_func (selection, list_selection_changed_callback, view);
    gtk_tree_view_set_cursor_on_cell (cols_view->tree, path, 
                                      cols_view->details->file_name_column,
                                      (GtkCellRenderer *) cols_view->details->file_name_cell,
                                      start_editing);

    if (!select) {
        GtkTreeSelection *selection = gtk_tree_view_get_selection (cols_view->tree);
        gtk_tree_selection_unselect_path (selection, path);
        g_signal_handlers_unblock_by_func (selection, list_selection_changed_callback, view);
    }
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

static gboolean
fm_columns_view_get_visible_range (FMDirectoryView *view, 
                                   GtkTreePath     **start_path,
                                   GtkTreePath     **end_path)

{
    g_return_if_fail (FM_IS_COLUMNS_VIEW (view));
    return gtk_tree_view_get_visible_range (FM_COLUMNS_VIEW (view)->tree,
                                            start_path, end_path);
}

static void
fm_columns_view_zoom_normal (FMDirectoryView *view)
{
    MarlinZoomLevel     zoom;
    
    zoom = g_settings_get_enum (marlin_column_view_settings, "default-zoom-level");
    g_settings_set_enum (marlin_column_view_settings, "zoom-level", zoom);
}


static void
fm_columns_view_finalize (GObject *object)
{
    FMColumnsView *view = FM_COLUMNS_VIEW (object);

    g_warning ("%s\n", G_STRFUNC);

    if (view->details->selection)
        gof_file_list_free (view->details->selection);

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
    
    g_settings_bind (marlin_column_view_settings, "zoom-level", 
                     view, "zoom-level", 0);
}

static void
fm_columns_view_zoom_level_changed (FMDirectoryView *view)
{
    /* set the new "size" for the icon renderer */
    g_object_set (G_OBJECT (view->icon_renderer), "size", marlin_zoom_level_to_icon_size (view->zoom_level), NULL);
    gint xpad, ypad;

    gtk_cell_renderer_get_padding (view->icon_renderer, &xpad, &ypad);
    gtk_cell_renderer_set_fixed_size (view->icon_renderer, 
                                      marlin_zoom_level_to_icon_size (view->zoom_level) + 2 * xpad,
                                      marlin_zoom_level_to_icon_size (view->zoom_level) + 2 * ypad);
    gtk_tree_view_columns_autosize (FM_COLUMNS_VIEW (view)->tree);
}

#if 0
static void
fm_columns_view_get_property (GObject    *object,
                              guint       prop_id,
                              GValue     *value,
                              GParamSpec *pspec)
{
    FMColumnsView *view = FM_COLUMNS_VIEW (object);

    switch (prop_id)
    {

    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
        break;
    }   
}

static void
fm_columns_view_set_property (GObject       *object,
                              guint         prop_id,
                              const GValue  *value,
                              GParamSpec    *pspec)
{
    FMColumnsView *view = FM_COLUMNS_VIEW (object);

    switch (prop_id)
    {

    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
        break;
    }   
}
#endif

static void
fm_columns_view_class_init (FMColumnsViewClass *klass)
{
    FMDirectoryViewClass *fm_directory_view_class;
    GObjectClass *object_class = G_OBJECT_CLASS (klass);

    object_class->finalize     = fm_columns_view_finalize;
    /*object_class->get_property = fm_columns_view_get_property;
    object_class->set_property = fm_columns_view_set_property;*/

    fm_directory_view_class = FM_DIRECTORY_VIEW_CLASS (klass);

    fm_directory_view_class->get_selection = fm_columns_view_get_selection; 
    fm_directory_view_class->get_selection_for_file_transfer = fm_columns_view_get_selection_for_file_transfer;
    fm_directory_view_class->get_selected_paths = fm_columns_view_get_selected_paths;
    fm_directory_view_class->select_path = fm_columns_view_select_path;
    fm_directory_view_class->select_all = fm_columns_view_select_all;
    fm_directory_view_class->set_cursor = fm_columns_view_set_cursor;

    fm_directory_view_class->get_path_at_pos = fm_columns_view_get_path_at_pos;
    fm_directory_view_class->highlight_path = fm_columns_view_highlight_path;
    fm_directory_view_class->get_visible_range = fm_columns_view_get_visible_range;
    fm_directory_view_class->start_renaming_file = fm_columns_view_start_renaming_file;
    fm_directory_view_class->zoom_normal = fm_columns_view_zoom_normal;
    fm_directory_view_class->zoom_level_changed = fm_columns_view_zoom_level_changed;
}

