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
#include "fm-directory-view.h"
#include "marlin-global-preferences.h"
#include <glib/gi18n.h>
#include <gdk/gdk.h>
#include <gdk/gdkkeysyms.h>
#include "exo-tree-view.h"
#include "marlin-cell-renderer-text-ellipsized.h"
#include "eel-glib-extensions.h"
#include "eel-gtk-extensions.h"
#include "marlin-vala.h"

struct FMColumnsViewDetails {
    GList       *selection;

    GtkCellEditable     *editable_widget;
    GtkTreeViewColumn   *file_name_column;
    GtkCellRendererText *file_name_cell;
    char                *original_name;

    GOFFile     *renaming_file;
    gboolean    rename_done;
    gboolean    awaiting_double_click;
    guint       double_click_timeout_id;
    GOFFile     *selected_folder;
    MarlinWindowColumns *mwcols;
};

/* Wait for the rename to end when activating a file being renamed */
#define WAIT_FOR_RENAME_ON_ACTIVATE 200

G_DEFINE_TYPE (FMColumnsView, fm_columns_view, FM_TYPE_DIRECTORY_VIEW);

#define parent_class fm_columns_view_parent_class

/* Declaration Prototypes */
static GList    *fm_columns_view_get_selection (FMDirectoryView *view);
static GList    *get_selection (FMColumnsView *view);
static GList    *fm_columns_view_get_selected_paths (FMDirectoryView *view);
static void     fm_columns_view_select_path (FMDirectoryView *view, GtkTreePath *path);
static void     fm_columns_view_set_cursor (FMDirectoryView *view, GtkTreePath *path,
                                         gboolean start_editing, gboolean select);

static void
list_selection_changed_callback (GtkTreeSelection *selection, gpointer user_data)
{
    FMColumnsView *view = FM_COLUMNS_VIEW (user_data);

    if (view->details->selection != NULL)
        gof_file_list_free (view->details->selection);

    view->details->selection = get_selection (view);

    /* setup the current active slot */
    fm_directory_view_set_active_slot (FM_DIRECTORY_VIEW (view));
    fm_directory_view_notify_selection_changed (FM_DIRECTORY_VIEW (view));
}

static void
fm_columns_view_item_hovered (ExoTreeView *exo_tree, GtkTreePath *path, FMColumnsView *view)
{
    fm_directory_view_notify_item_hovered (FM_DIRECTORY_VIEW (view), path);
}

static void
row_activated_callback (GtkTreeView *treeview, GtkTreeIter *iter, GtkTreePath *path, FMColumnsView *view)
{
    fm_directory_view_activate_selected_items (FM_DIRECTORY_VIEW (view), MARLIN_WINDOW_OPEN_FLAG_DEFAULT);
}

static void
fm_columns_view_freeze_updates (FMColumnsView *view)
{
    /* Make filename-cells editable. */
    g_object_set (G_OBJECT (view->details->file_name_cell),
                  "editable", TRUE, NULL);
    fm_directory_view_freeze_updates (FM_DIRECTORY_VIEW (view));
}

static void
fm_columns_view_unfreeze_updates (FMColumnsView *view)
{
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

    if (view->details->renaming_file) {
        view->details->rename_done = TRUE;

        if (error != NULL) {
            marlin_dialogs_show_error (GTK_WIDGET (view),
                                       error,
                                       _("Failed to rename %s to %s"),
                                       g_file_info_get_name (file->info),
                                       view->details->original_name);
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
    FMColumnsView *view = user_data;

    view->details->editable_widget = NULL;
    fm_columns_view_unfreeze_updates (view);
}

static void
cell_renderer_editing_started_cb (GtkCellRenderer *renderer,
                                  GtkCellEditable *editable,
                                  const gchar *path_str,
                                  FMColumnsView *columns_view)
{
    GtkEntry *entry;

    entry = GTK_ENTRY (editable);
    columns_view->details->editable_widget = editable;

    /* Free a previously allocated original_name */
    g_free (columns_view->details->original_name);

    columns_view->details->original_name = g_strdup (gtk_entry_get_text (entry));

    g_signal_connect (entry, "focus-out-event",
                      G_CALLBACK (editable_focus_out_cb), columns_view);
}

static void
cell_renderer_editing_canceled (GtkCellRendererText *cell,
                                FMColumnsView          *view)
{
    view->details->editable_widget = NULL;
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
        g_free (view->details->original_name);
        view->details->original_name = g_strdup (new_text);
        gof_file_rename (file, new_text, fm_columns_view_rename_callback, g_object_ref (view));
    }

    gof_file_unref (file);

    fm_columns_view_unfreeze_updates (view);
}

static void
fm_columns_view_start_renaming_file (FMDirectoryView *view,
                                  GOFFile *file,
                                  gboolean select_all)
{
    FMColumnsView *columns_view;
    GtkTreeIter iter;
    GtkTreePath *path;
    gint start_offset, end_offset;

    columns_view = FM_COLUMNS_VIEW (view);

    /* Select all if we are in renaming mode already */
    if (columns_view->details->file_name_column && columns_view->details->editable_widget) {
        gtk_editable_select_region (GTK_EDITABLE (columns_view->details->editable_widget),
                                    0, -1);
        return;
    }

    if (!fm_list_model_get_first_iter_for_file (columns_view->model, file, &iter)) {
        return;
    }

    /* Freeze updates to the view to prevent losing rename focus when the tree view updates */
    fm_columns_view_freeze_updates (FM_COLUMNS_VIEW (view));

    path = gtk_tree_model_get_path (GTK_TREE_MODEL (columns_view->model), &iter);

    gtk_tree_view_scroll_to_cell (columns_view->tree, NULL,
                                  columns_view->details->file_name_column,
                                  TRUE, 0.0, 0.0);

    /* sound like set_cursor is not enough to trigger editing-started, we use cursor_on_cell instead */
    gtk_tree_view_set_cursor_on_cell (columns_view->tree, path,
                                      columns_view->details->file_name_column,
                                      (GtkCellRenderer *) columns_view->details->file_name_cell,
                                      TRUE);

    if (columns_view->details->editable_widget != NULL) {
        marlin_get_rename_region (columns_view->details->original_name, &start_offset, &end_offset, select_all);
        gtk_editable_select_region (GTK_EDITABLE (columns_view->details->editable_widget),
                                    start_offset, end_offset);
    }

    gtk_tree_path_free (path);
}

static void
fm_columns_view_sync_selection (FMDirectoryView *view)
{
    fm_directory_view_notify_selection_changed (view);
}

static void
fm_columns_cancel_await_double_click (FMColumnsView *view)
{
    if (view->details->awaiting_double_click) {
        g_source_remove (view->details->double_click_timeout_id);
        view->details->double_click_timeout_id = 0;
        view->details->awaiting_double_click = FALSE;
        view->details->mwcols->updates_frozen = FALSE;
    }
}

static void
fm_columns_not_double_click (FMColumnsView *view)
{
    g_return_val_if_fail (view != NULL && FM_IS_COLUMNS_VIEW (view), FALSE);
    g_return_val_if_fail (view->details->double_click_timeout_id != 0, FALSE);

    view->details->awaiting_double_click = FALSE;
    view->details->mwcols->updates_frozen = FALSE;
    if (!fm_directory_view_is_drag_pending (view))
        fm_directory_view_activate_selected_items (FM_DIRECTORY_VIEW (view), MARLIN_WINDOW_OPEN_FLAG_DEFAULT);

    return FALSE;
}

static gboolean
button_press_callback (GtkTreeView *tree_view, GdkEventButton *event, FMColumnsView *view)
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

    if (view->details->mwcols == NULL)
        view->details->mwcols = fm_directory_view_get_marlin_window_columns (FM_DIRECTORY_VIEW (view));

    /* Ignore event if another slot is waiting for a double click */
    if (view->details->mwcols->updates_frozen && !view->details->awaiting_double_click)
        return TRUE;

    gboolean on_path = gtk_tree_view_get_path_at_pos (tree_view, event->x, event->y, &path, NULL, NULL, NULL);
    gboolean on_blank = gtk_tree_view_is_blank_at_pos (tree_view, event->x, event->y, NULL, NULL, NULL, NULL);
    gboolean no_mods = (event->state & gtk_accelerator_get_default_mod_mask ()) == 0;
    gboolean finished = FALSE;

    /* we unselect all selected items if the user clicks on an empty
     * area of the treeview and no modifier key is active.
     */
    if (no_mods && !on_path)
        gtk_tree_selection_unselect_all (selection);

    if (event->button == 1 && g_settings_get_boolean (settings, "single-click")) {
        /* Handle single left-click (and start of double click) in single click mode */
        if (event->type == GDK_BUTTON_PRESS && no_mods) {
            /* Ignore second GDK_BUTTON_PRESS event of double-click */
            if (view->details->awaiting_double_click)
                finished = TRUE;
            else if (on_path && !on_blank) {
                /*Determine where user clicked - this will be the sole selection */
                gtk_tree_selection_unselect_all (selection);
                /* select the path on which the user clicked */
                gtk_tree_selection_select_path (selection, path);
                gtk_tree_path_free (path);
                /* If single folder selected ... */
                GList *file_list = NULL;
                file_list = fm_directory_view_get_selection (view);
                GOFFile *file = GOF_FILE (file_list->data);
                view->details->selected_folder = NULL;
                if (gof_file_is_folder (file)) {
                    /*  ... store clicked folder and start double-click timeout */
                    view->details->selected_folder = file;
                    view->details->awaiting_double_click = TRUE;
                    view->details->mwcols->updates_frozen = TRUE;
                    /* use short timeout to maintain responsiveness */
                    view->details->double_click_timeout_id = g_timeout_add (100,
                                                                            (GSourceFunc)fm_columns_not_double_click,
                                                                            view);
                }
                /* pass on event to activate the row and slot clicked on */
                finished = FALSE;
            }
        } else if (event->type == GDK_2BUTTON_PRESS) {
            /* In single click mode, double-clicking a folder will open it as root in a new view */
            fm_columns_cancel_await_double_click (view);
            if (view->details->selected_folder != NULL) {
                fm_directory_view_load_root_location (view, view->details->selected_folder->location);
                finished = TRUE;
            }
        }
    }
    /* Ensure any timeout is cancelled  and unfreeze update
     * if a button other than the left button is pressed */
    fm_columns_cancel_await_double_click (view);

    /* open the context menu on right clicks */
    if (event->type == GDK_BUTTON_PRESS && event->button == 3) {
        fm_directory_view_set_active_slot (FM_DIRECTORY_VIEW (view));
        if (on_path) {
            /* select the path on which the user clicked if not selected yet */
            if (!gtk_tree_selection_path_is_selected (selection, path)) {
                /* we don't unselect all other items if Control is active */
                if ((event->state & GDK_CONTROL_MASK) == 0)
                    gtk_tree_selection_unselect_all (selection);

                if (!on_blank)
                    gtk_tree_selection_select_path (selection, path);
            }
            /* queue the menu popup */
            fm_directory_view_queue_popup (FM_DIRECTORY_VIEW (view), event);
        } else {
            /* context menu popup */
            fm_directory_view_context_menu (FM_DIRECTORY_VIEW (view), event);
        }
        finished = TRUE;
    }
    else if ((event->type == GDK_BUTTON_PRESS || event->type == GDK_2BUTTON_PRESS) && event->button == 2) {
        /* determine the path to the item that was middle-clicked */
        if (on_path) {
            /* select only the path to the item on which the user clicked */
            gtk_tree_selection_unselect_all (selection);
            gtk_tree_selection_select_path (selection, path);

            fm_directory_view_activate_selected_items (FM_DIRECTORY_VIEW (view), MARLIN_WINDOW_OPEN_FLAG_NEW_TAB);
            finished = TRUE;
        }
    }
    return finished;
}

static gboolean button_release_callback (GtkTreeView *tree_view, GdkEventButton *event, FMColumnsView *view)
{
    if (g_settings_get_boolean (settings, "single-click")
        && view->details->awaiting_double_click)
            return TRUE;

    return FALSE;
}

static gboolean
key_press_callback (GtkWidget *widget, GdkEventKey *event, gpointer callback_data)
{
    FMDirectoryView *view;
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
                         FMColumnsView     *view)
{
    g_return_if_fail (GTK_IS_TREE_VIEW_COLUMN (column));
    g_return_if_fail (GTK_IS_CELL_RENDERER (renderer));
    g_return_if_fail (GTK_IS_TREE_MODEL (model));
    g_return_if_fail (FM_IS_COLUMNS_VIEW (view));

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
    }

    g_object_set (G_OBJECT (renderer),
                  "text", text,
                  "underline", PANGO_UNDERLINE_NONE,
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
    }

    g_object_set(renderer, "cell-background-rgba", &rgba, NULL);
    g_free (color);
}

static gboolean
fm_columns_view_draw (GtkWidget* view_, cairo_t* cr, FMColumnsView* view)
{
    g_return_val_if_fail (FM_IS_COLUMNS_VIEW (view), FALSE);

    GOFDirectoryAsync *dir = fm_directory_view_get_current_directory (FM_DIRECTORY_VIEW (view));

    if (gof_directory_async_is_empty (dir))
    {
        PangoLayout* layout = gtk_widget_create_pango_layout (GTK_WIDGET(view), NULL);
        gchar *str = g_strconcat ("<span size='x-large'>", _("This folder is empty."), "</span>", NULL);
        pango_layout_set_markup (layout, str, -1);

        PangoRectangle extents;
        /* Get layout height and width */
        pango_layout_get_extents (layout, NULL, &extents);
        gdouble width = pango_units_to_double(extents.width);
        gdouble height = pango_units_to_double (extents.height);
        gtk_render_layout (gtk_widget_get_style_context (GTK_WIDGET(view)), cr,
                  (double) gtk_widget_get_allocated_width (GTK_WIDGET (view)) / 2 - width / 2,
                  (double) gtk_widget_get_allocated_height (GTK_WIDGET(view)) / 2 - height / 2,
                  layout);
    }

    return FALSE;
}

static void
create_and_set_up_tree_view (FMColumnsView *view)
{
    GtkTreeViewColumn       *col;
    GtkCellRenderer         *renderer;

    view->model = FM_DIRECTORY_VIEW (view)->model;
    g_object_set (G_OBJECT (view->model), "has-child", FALSE, NULL);

    view->tree = GTK_TREE_VIEW (exo_tree_view_new ());
    gtk_tree_view_set_model (view->tree, GTK_TREE_MODEL (view->model));
    gtk_tree_view_set_headers_visible (view->tree, FALSE);
    gtk_tree_view_set_search_column (view->tree, FM_LIST_MODEL_FILENAME);
    gtk_tree_view_set_rules_hint (view->tree, TRUE);

    /* Enable rubber banding in order to stop drag starting on empty space */
    gtk_tree_view_set_rubber_banding (view->tree, TRUE);

    gtk_tree_selection_set_mode (gtk_tree_view_get_selection (view->tree), GTK_SELECTION_MULTIPLE);

    g_signal_connect (view->tree, "item-hovered",
                             G_CALLBACK (fm_columns_view_item_hovered), view);

    g_signal_connect_object (gtk_tree_view_get_selection (view->tree), "changed",
                             G_CALLBACK (list_selection_changed_callback), view, 0);

    g_signal_connect_object (view->tree, "button-press-event",
                             G_CALLBACK (button_press_callback), view, 0);
    g_signal_connect_object (view->tree, "button-release-event",
                             G_CALLBACK (button_release_callback), view, 0);

    g_signal_connect (view->tree, "draw",
                             G_CALLBACK (fm_columns_view_draw), view);

    g_signal_connect_object (view->tree, "key_press_event",
                             G_CALLBACK (key_press_callback), view, 0);

    g_signal_connect_object (view->tree, "row-activated",
                             G_CALLBACK (row_activated_callback), view, 0);

    col = gtk_tree_view_column_new ();
    view->details->file_name_column = col;
    gtk_tree_view_column_set_sort_column_id  (col, FM_LIST_MODEL_FILENAME);
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

    if (file != NULL)
        (* list) = g_list_prepend ((* list), file);
}

static GList *
get_selection (FMColumnsView *view)
{
    GList *list = NULL;
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
    FMColumnsView *columns_view = FM_COLUMNS_VIEW (view);
    GtkTreeSelection *selection = gtk_tree_view_get_selection (columns_view->tree);

    /* the treeview select the path by default */
    if (!select)
        g_signal_handlers_block_by_func (selection, list_selection_changed_callback, columns_view);
    gtk_tree_view_set_cursor_on_cell (columns_view->tree, path,
                                      columns_view->details->file_name_column,
                                      (GtkCellRenderer *) columns_view->details->file_name_cell,
                                      start_editing);

    if (!select) {
        gtk_tree_selection_unselect_path (selection, path);
        g_signal_handlers_unblock_by_func (selection, list_selection_changed_callback, columns_view);
    }
}

static void
fm_columns_view_select_all (FMDirectoryView *view)
{
    gtk_tree_selection_select_all (gtk_tree_view_get_selection (FM_COLUMNS_VIEW (view)->tree));
}

static void fm_columns_view_unselect_all(FMDirectoryView *view)
{
    gtk_tree_selection_unselect_all (gtk_tree_view_get_selection (FM_COLUMNS_VIEW (view)->tree));
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

    g_debug ("%s\n", G_STRFUNC);

    /* Unload all the subdirectories in the loaded subdirectories list. */
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

    if (view->details->selected_folder)
        g_object_unref (view->details->selected_folder);

    g_free (view->details);

    fm_columns_cancel_await_double_click (view);

    G_OBJECT_CLASS (fm_columns_view_parent_class)->finalize (object);
}

static void
fm_columns_view_init (FMColumnsView *view)
{
    view->details = g_new0 (FMColumnsViewDetails, 1);
    view->details->selection = NULL;
    view->loaded_subdirectories = NULL;
    view->details->double_click_timeout_id = 0;
    view->details->awaiting_double_click = FALSE;
    view->details->selected_folder = NULL;

    create_and_set_up_tree_view (view);

    g_settings_bind (settings, "single-click",
                     EXO_TREE_VIEW (view->tree), "single-click", 0);
    g_settings_bind (marlin_column_view_settings, "zoom-level",
                     view, "zoom-level", 0);
}

static void
fm_columns_view_zoom_level_changed (FMDirectoryView *view)
{
    /* Ignore if view not valid */
    if (FM_IS_COLUMNS_VIEW (view) && GTK_IS_TREE_VIEW (FM_COLUMNS_VIEW (view)->tree)) {
        /* set the new "size" for the icon renderer */
        g_object_set (G_OBJECT (view->icon_renderer), "size", marlin_zoom_level_to_icon_size (view->zoom_level), "zoom-level", view->zoom_level, NULL);
        gint xpad, ypad;

        gtk_cell_renderer_get_padding (view->icon_renderer, &xpad, &ypad);
        gtk_cell_renderer_set_fixed_size (view->icon_renderer,
                                          marlin_zoom_level_to_icon_size (view->zoom_level) + 2 * xpad,
                                          marlin_zoom_level_to_icon_size (view->zoom_level) + 2 * ypad);

        gtk_tree_view_columns_autosize (FM_COLUMNS_VIEW (view)->tree);
    }
}


static void
fm_columns_view_class_init (FMColumnsViewClass *klass)
{
    FMDirectoryViewClass *fm_directory_view_class;
    GObjectClass *object_class = G_OBJECT_CLASS (klass);

    object_class->finalize     = fm_columns_view_finalize;
    fm_directory_view_class = FM_DIRECTORY_VIEW_CLASS (klass);

    fm_directory_view_class->sync_selection = fm_columns_view_sync_selection;
    fm_directory_view_class->get_selection = fm_columns_view_get_selection;
    fm_directory_view_class->get_selection_for_file_transfer = fm_columns_view_get_selection_for_file_transfer;
    fm_directory_view_class->get_selected_paths = fm_columns_view_get_selected_paths;
    fm_directory_view_class->select_path = fm_columns_view_select_path;
    fm_directory_view_class->select_all = fm_columns_view_select_all;
    fm_directory_view_class->unselect_all = fm_columns_view_unselect_all;
    fm_directory_view_class->set_cursor = fm_columns_view_set_cursor;

    fm_directory_view_class->get_path_at_pos = fm_columns_view_get_path_at_pos;
    fm_directory_view_class->highlight_path = fm_columns_view_highlight_path;
    fm_directory_view_class->get_visible_range = fm_columns_view_get_visible_range;
    fm_directory_view_class->start_renaming_file = fm_columns_view_start_renaming_file;
    fm_directory_view_class->zoom_normal = fm_columns_view_zoom_normal;
    fm_directory_view_class->zoom_level_changed = fm_columns_view_zoom_level_changed;
}

