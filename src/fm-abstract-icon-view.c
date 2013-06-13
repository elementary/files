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

#include "fm-abstract-icon-view.h"
#include "marlin-global-preferences.h"
#include "eel-i18n.h"
#include <gdk/gdk.h>
#include <gdk/gdkkeysyms.h>

//#include "gof-directory-async.h"
#include "eel-glib-extensions.h"
#include "eel-gtk-extensions.h"
#include "eel-editable-label.h"
#include "eel-ui.h"
#include "marlin-tags.h"

enum
{
    PROP_0,
    PROP_TEXT_BESIDE_ICONS
};

struct FMAbstractIconViewDetails {
    GList               *selection;
    gboolean            text_beside_icons;

    gint                sort_type;
    gboolean            sort_reversed;

    GtkActionGroup      *icon_action_group;
    guint               icon_merge_id;

    GtkCellEditable     *editable_widget;
    GtkTreeViewColumn   *file_name_column;
    GtkCellRendererText *file_name_cell;
    char                *original_name;

    GOFFile             *renaming_file;
    gboolean            rename_done;
};

/* Wait for the rename to end when activating a file being renamed */
#define WAIT_FOR_RENAME_ON_ACTIVATE 200

//static gchar *col_title[4] = { _("Filename"), _("Size"), _("Type"), _("Modified") };

G_DEFINE_TYPE (FMAbstractIconView, fm_abstract_icon_view, FM_TYPE_DIRECTORY_VIEW);

#define parent_class fm_abstract_icon_view_parent_class

/* Declaration Prototypes */
static GList    *fm_abstract_icon_view_get_selection (FMDirectoryView *view);
static GList    *get_selection (FMAbstractIconView *view);
static GList    *fm_abstract_icon_view_get_selected_paths (FMDirectoryView *view);
static void     fm_abstract_icon_view_select_path (FMDirectoryView *view, GtkTreePath *path);
static void     fm_abstract_icon_view_set_cursor (FMDirectoryView *view, GtkTreePath *path,
                                                  gboolean start_editing, gboolean select);

//static void     fm_abstract_icon_view_clear (FMAbstractIconView *view);

/*static void
  show_selected_files (GOFFile *file)
  {
  log_printf (LOG_LEVEL_UNDEFINED, "selected: %s\n", file->name);
  }*/

static void
fm_abstract_icon_view_selection_changed (ExoIconView *iconview, gpointer user_data)
{
    FMAbstractIconView *view = FM_ABSTRACT_ICON_VIEW (user_data);

    if (view->details->selection != NULL)
        gof_file_list_free (view->details->selection);
    view->details->selection = get_selection (view);

    fm_directory_view_notify_selection_changed (FM_DIRECTORY_VIEW (view));
}

static void
fm_abstract_icon_view_item_hovered (ExoIconView *exo_icon, GtkTreePath *path, FMAbstractIconView *view)
{
    fm_directory_view_notify_item_hovered (FM_DIRECTORY_VIEW (view), path);
}

static void
fm_abstract_icon_view_item_activated (ExoIconView *exo_icon, GtkTreePath *path, FMAbstractIconView *view)
{
    //TODO make alternate
    fm_directory_view_activate_selected_items (FM_DIRECTORY_VIEW (view), MARLIN_WINDOW_OPEN_FLAG_DEFAULT); 
}

static void 
fm_abstract_icon_view_freeze_updates (FMDirectoryView *view)
{
    /* Make marlin-text-renderer cells editable. */
    g_object_set (view->name_renderer,
                  "mode", GTK_CELL_RENDERER_MODE_EDITABLE, NULL);
    fm_directory_view_freeze_updates (FM_DIRECTORY_VIEW (view));
}

static void 
fm_abstract_icon_view_unfreeze_updates (FMDirectoryView *view)
{
    /*We're done editing - make the filename-cells readonly again.*/
    g_object_set (view->name_renderer,
                  "mode", GTK_CELL_RENDERER_MODE_INERT, NULL);
    fm_directory_view_unfreeze_updates (FM_DIRECTORY_VIEW (view));
}

static void
fm_abstract_icon_view_rename_callback (GOFFile *file,
                                       GFile *result_location,
                                       GError *error,
                                       gpointer callback_data)
{
    FMAbstractIconView *view = FM_ABSTRACT_ICON_VIEW (callback_data);

    //printf ("%s\n", G_STRFUNC);
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
    FMAbstractIconView *view = user_data;

    //printf ("%s\n", G_STRFUNC);
    view->details->editable_widget = NULL;
    fm_abstract_icon_view_unfreeze_updates (FM_DIRECTORY_VIEW (view));
}

static void
cell_renderer_editing_started_cb (GtkCellRenderer *renderer,
                                  GtkCellEditable *editable,
                                  const gchar *path_str,
                                  FMAbstractIconView *icon_view)
{
    EelEditableLabel *label;

    //printf ("%s\n", G_STRFUNC);
    label = EEL_EDITABLE_LABEL (editable);
    icon_view->details->editable_widget = editable;

    /* Free a previously allocated original_name */
    g_free (icon_view->details->original_name);

    icon_view->details->original_name = g_strdup (eel_editable_label_get_text (label));

    /*g_signal_connect (label, "focus-out-event",
      G_CALLBACK (editable_focus_out_cb), icon_view);*/
    /*g_signal_connect (entry, "populate-popup", 
      G_CALLBACK (editable_populate_popup), text_renderer);*/

    //TODO
    /*nautilus_clipboard_set_up_editable
      (GTK_EDITABLE (entry),
      nautilus_view_get_ui_manager (NAUTILUS_VIEW (icon_view)),
      FALSE);*/
}

//#if 0
static void
cell_renderer_editing_canceled (GtkCellRenderer *cell,
                                FMAbstractIconView      *view)
{
    //printf ("%s\n", G_STRFUNC);
    view->details->editable_widget = NULL;
    //fm_abstract_icon_view_unfreeze_updates (FM_DIRECTORY_VIEW (view));
}
//#endif

static void
cell_renderer_edited (GtkCellRenderer   *cell,
                      const char        *path_str,
                      const char        *new_text,
                      FMAbstractIconView        *view)
{
    GtkTreePath *path;
    GOFFile *file;
    GtkTreeIter iter;

    //printf ("%s\n", G_STRFUNC);
    view->details->editable_widget = NULL;

    /* Don't allow a rename with an empty string. Revert to original 
     * without notifying the user.
     */
    if (new_text[0] == '\0') {
        fm_abstract_icon_view_unfreeze_updates (FM_DIRECTORY_VIEW (view));
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
        gof_file_rename (file, new_text, fm_abstract_icon_view_rename_callback, g_object_ref (view));

        g_free (view->details->original_name);
        view->details->original_name = g_strdup (new_text);
    }

    gof_file_unref (file);

    fm_abstract_icon_view_unfreeze_updates (FM_DIRECTORY_VIEW (view));
}

static void
fm_abstract_icon_view_sort_changed (FMAbstractIconView *view)
{
    GtkTreePath *path = NULL;
    /* store first selected item to reveal it after model sort */
    GList *selected_files = exo_icon_view_get_selected_items (view->icons);
    if (selected_files != NULL) 
        path = selected_files->data;

    gtk_tree_sortable_set_sort_column_id (GTK_TREE_SORTABLE (view->model), view->details->sort_type, (view->details->sort_reversed) ? GTK_SORT_DESCENDING : GTK_SORT_ASCENDING );

    /* reveal first selected item */
    if (path != NULL)
        exo_icon_view_scroll_to_path (view->icons, path, FALSE, 0.0, 0.0);
}

static void
action_sort_radio_callback (GtkAction *action, GtkRadioAction *current, FMAbstractIconView *view)
{
    view->details->sort_type = gtk_radio_action_get_current_value (current);

    fm_abstract_icon_view_sort_changed (view);
}

static void
action_reversed_order_callback (GtkAction *action, FMAbstractIconView *view)
{
    gboolean active = gtk_toggle_action_get_active (GTK_TOGGLE_ACTION (action));
    if (view->details->sort_reversed == active)
        return;

    view->details->sort_reversed = active;

    fm_abstract_icon_view_sort_changed (view);
}

static const GtkActionEntry icon_view_entries[] = {
    /* name, stock id, label */  { "Arrange Items", NULL, N_("Arran_ge Items") }, 
};

static const GtkToggleActionEntry icon_view_toggle_entries[] = {
    /* name, stock id */      { "Reversed Order", NULL,
        /* label, accelerator */    N_("Re_versed Order"), NULL,
        /* tooltip */               N_("Display icons in the opposite order"),
        G_CALLBACK (action_reversed_order_callback),
        0 },
};

static const GtkRadioActionEntry arrange_radio_entries[] = {
    { "Sort by Name", NULL,
        N_("By _Name"), NULL,
        N_("Keep icons sorted by name in rows"),
        FM_LIST_MODEL_FILENAME },
    { "Sort by Size", NULL,
        N_("By _Size"), NULL,
        N_("Keep icons sorted by size in rows"),
        FM_LIST_MODEL_SIZE },
    { "Sort by Type", NULL,
        N_("By _Type"), NULL,
        N_("Keep icons sorted by type in rows"),
        FM_LIST_MODEL_TYPE },
    { "Sort by Modification Date", NULL,
        N_("By Modification _Date"), NULL,
        N_("Keep icons sorted by modification date in rows"),
        FM_LIST_MODEL_MODIFIED },
    /* TODO */
    /*{ "Sort by Trash Time", NULL,
      N_("By T_rash Time"), NULL,
      N_("Keep icons sorted by trash time in rows"),
      NAUTILUS_FILE_SORT_BY_TRASHED_TIME },*/
};

static void
fm_abstract_icon_view_merge_menus (FMDirectoryView *view)
{
    FMAbstractIconView *icon_view;
    GtkUIManager *ui_manager;
    GtkActionGroup *action_group;
    GtkAction *action;
    const char *ui;

    g_assert (FM_IS_ABSTRACT_ICON_VIEW (view));

    FM_DIRECTORY_VIEW_CLASS (fm_abstract_icon_view_parent_class)->merge_menus (view);

    icon_view = FM_ABSTRACT_ICON_VIEW (view);
    ui_manager = fm_directory_view_get_ui_manager (view);

    action_group = gtk_action_group_new ("IconViewActions");
    gtk_action_group_set_translation_domain (action_group, GETTEXT_PACKAGE);
    icon_view->details->icon_action_group = action_group;
    gtk_action_group_add_actions (action_group,
                                  icon_view_entries, G_N_ELEMENTS (icon_view_entries),
                                  icon_view);
    gtk_action_group_add_toggle_actions (action_group, 
                                         icon_view_toggle_entries, G_N_ELEMENTS (icon_view_toggle_entries),
                                         icon_view);
    gtk_action_group_add_radio_actions (action_group,
                                        arrange_radio_entries,
                                        G_N_ELEMENTS (arrange_radio_entries),
                                        -1,
                                        G_CALLBACK (action_sort_radio_callback),
                                        icon_view);

    gtk_ui_manager_insert_action_group (ui_manager, action_group, 0);
    g_object_unref (action_group);

    ui = eel_ui_string_get ("fm-icon-view-ui.xml");
    icon_view->details->icon_merge_id = gtk_ui_manager_add_ui_from_string (ui_manager, ui, -1, NULL);

    /* init ArrangeItems actions */
    GOFDirectoryAsync *current_dir = fm_directory_view_get_current_directory (view);
    action = gtk_action_group_get_action (action_group, "Sort by Name");
    gtk_radio_action_set_current_value (GTK_RADIO_ACTION (action),
                                        current_dir->file->sort_column_id);
    action = gtk_action_group_get_action (action_group, "Reversed Order");
    gtk_toggle_action_set_active (GTK_TOGGLE_ACTION (action),
                                  current_dir->file->sort_order);

}

static void
fm_abstract_icon_view_unmerge_menus (FMDirectoryView *view)
{
    FMAbstractIconView *icon_view;
    GtkUIManager *ui_manager;

    FM_DIRECTORY_VIEW_CLASS (fm_abstract_icon_view_parent_class)->unmerge_menus (view);

    icon_view = FM_ABSTRACT_ICON_VIEW (view);
    ui_manager = fm_directory_view_get_ui_manager (view);
    if (ui_manager != NULL) {
        eel_ui_unmerge_ui (ui_manager,
                           &icon_view->details->icon_merge_id,
                           &icon_view->details->icon_action_group);
    }
}

static void
fm_abstract_icon_view_select_all (FMDirectoryView *view)
{
    exo_icon_view_select_all (FM_ABSTRACT_ICON_VIEW (view)->icons);
}

static void
fm_abstract_icon_view_start_renaming_file (FMDirectoryView *view,
                                           GOFFile *file,
                                           gboolean select_all)
{
    FMAbstractIconView *icon_view;
    GtkTreeIter iter;
    GtkTreePath *path;
    gint start_offset, end_offset;

    icon_view = FM_ABSTRACT_ICON_VIEW (view);

    //g_message ("%s\n", G_STRFUNC);
    /* Select all if we are in renaming mode already */
    //if (icon_view->details->file_name_column && icon_view->details->editable_widget) {
    if (icon_view->details->editable_widget) {
        gtk_editable_select_region (GTK_EDITABLE (icon_view->details->editable_widget),
                                    0, -1);
        return;
    }

    if (!fm_list_model_get_first_iter_for_file (icon_view->model, file, &iter)) {
        return;
    }

    /* Freeze updates to the view to prevent losing rename focus when the icon view updates */
    fm_abstract_icon_view_freeze_updates (view);

    path = gtk_tree_model_get_path (GTK_TREE_MODEL (icon_view->model), &iter);

    //TODO
    /*gtk_tree_view_scroll_to_cell (icon_view->tree, NULL,
      icon_view->details->file_name_column,
      TRUE, 0.0, 0.0);*/
    /* set cursor also triggers editing-started, where we save the editable widget */
    /*gtk_tree_view_set_cursor (icon_view->tree, path,
      icon_view->details->file_name_column, TRUE);*/
    /* sound like set_cursor is not enought to trigger editing-started, we use cursor_on_cell instead */
    exo_icon_view_set_cursor (icon_view->icons, path,
                              view->name_renderer,
                              TRUE);
    /*gtk_tree_view_set_cursor_on_cell (icon_view->tree, path,
      icon_view->details->file_name_column,
      (GtkCellRenderer *) icon_view->details->file_name_cell,
      TRUE);*/

    if (icon_view->details->editable_widget != NULL) {
        eel_filename_get_rename_region (icon_view->details->original_name,
                                        &start_offset, &end_offset);

        gtk_editable_select_region (GTK_EDITABLE (icon_view->details->editable_widget),
                                    start_offset, end_offset);
    }

    gtk_tree_path_free (path);
}

static void
fm_abstract_icon_view_sync_selection (FMDirectoryView *view)
{
    fm_directory_view_notify_selection_changed (view);
}

static gboolean
button_press_callback (GtkTreeView *tree_view, GdkEventButton *event, FMAbstractIconView *view)
{
    GtkTreePath     *path;
    GtkTreeIter     iter;
    GtkAction       *action;
    GOFFile         *file;

    /* open the context menu on right clicks */
    if (event->type == GDK_BUTTON_PRESS && event->button == 3)
    {
        if ((path = exo_icon_view_get_path_at_pos (view->icons, event->x, event->y)) != NULL)
        {
            /* select the path on which the user clicked if not selected yet */
            if (!exo_icon_view_path_is_selected (view->icons, path))
            {
                /* we don't unselect all other items if Control is active */
                if ((event->state & GDK_CONTROL_MASK) == 0)
                    exo_icon_view_unselect_all (view->icons);
                exo_icon_view_select_path (view->icons, path);
            }
            gtk_tree_path_free (path);

            /* queue the menu popup */
            fm_directory_view_queue_popup (FM_DIRECTORY_VIEW (view), event);
        }
        else if ((event->state & gtk_accelerator_get_default_mod_mask ()) == 0)
        {
            /* user clicked on an empty area, so we unselect everything
               to make sure that the folder context menu is opened. */
            exo_icon_view_unselect_all (view->icons);

            /* open the context menu */
            fm_directory_view_context_menu (FM_DIRECTORY_VIEW (view), event);
        }

        return TRUE;
    }
    else if ((event->type == GDK_BUTTON_PRESS || event->type == GDK_2BUTTON_PRESS) && event->button == 2)
    {
        /* determine the path to the item that was middle-clicked */
        if ((path = exo_icon_view_get_path_at_pos (view->icons, event->x, event->y)) != NULL)
        {
            /* select only the path to the item on which the user clicked */
            exo_icon_view_unselect_all (view->icons);
            exo_icon_view_select_path (view->icons, path);

            fm_directory_view_activate_selected_items (FM_DIRECTORY_VIEW (view), MARLIN_WINDOW_OPEN_FLAG_NEW_TAB);

            /* cleanup */
            gtk_tree_path_free (path);
        }

        return TRUE;
    }

    return FALSE;
}

static gboolean
key_press_callback (GtkWidget *widget, GdkEventKey *event, gpointer callback_data)
{
    FMDirectoryView *view;
    //GdkEventButton button_event = { 0 };
    gboolean handled;

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
        if (!gtk_widget_has_focus (widget)) {
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

static gboolean fm_abstract_icon_view_draw(GtkWidget* view_, cairo_t* cr, FMAbstractIconView* view)
{
    g_return_val_if_fail (FM_IS_ABSTRACT_ICON_VIEW(view), FALSE);

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
        g_free (str);
    }

    return FALSE;
}

static GList *
get_selection (FMAbstractIconView *view)
{
    GList *lp, *selected_files;
    gint n_selected_files = 0;
    GtkTreePath *path;

    /* determine the new list of selected files (replacing GtkTreePath's with GOFFile's) */
    selected_files = exo_icon_view_get_selected_items (view->icons);
    for (lp = selected_files; lp != NULL; lp = lp->next, ++n_selected_files)
    {
        path = lp->data;
        /* replace it the path with the file */
        lp->data = fm_list_model_file_for_path (view->model, lp->data);

        /* release the tree path... */
        gtk_tree_path_free (path);
    }

    return selected_files;
}

static GList *
fm_abstract_icon_view_get_selection (FMDirectoryView *view)
{
    return FM_ABSTRACT_ICON_VIEW (view)->details->selection;
}

static GList *
fm_abstract_icon_view_get_selection_for_file_transfer (FMDirectoryView *view)
{
    GList *list = g_list_copy (fm_abstract_icon_view_get_selection (view));
    g_list_foreach (list, (GFunc) gof_file_ref, NULL);

    return list;
}

static GList *
fm_abstract_icon_view_get_selected_paths (FMDirectoryView *view)
{
    return exo_icon_view_get_selected_items (FM_ABSTRACT_ICON_VIEW (view)->icons);
}

static void
fm_abstract_icon_view_select_path (FMDirectoryView *view, GtkTreePath *path)
{
    exo_icon_view_select_path (FM_ABSTRACT_ICON_VIEW (view)->icons, path);
}

static void
fm_abstract_icon_view_set_cursor (FMDirectoryView *view, GtkTreePath *path,
                                  gboolean start_editing, gboolean select)
{
    FMAbstractIconView *icon_view = FM_ABSTRACT_ICON_VIEW (view);

    exo_icon_view_set_cursor (icon_view->icons, path,
                              view->name_renderer,
                              start_editing);

    /* the icon view doesn't select by default*/
    if (select) 
        exo_icon_view_select_path (icon_view->icons, path);
}

static GtkTreePath*
fm_abstract_icon_view_get_path_at_pos (FMDirectoryView *view, gint x, gint y)
{
    GtkTreePath *path;

    g_return_val_if_fail (FM_IS_ABSTRACT_ICON_VIEW (view), NULL);

    if (exo_icon_view_get_dest_item_at_pos  (FM_ABSTRACT_ICON_VIEW (view)->icons, x, y, &path, NULL))
        return path;

    return NULL;
}

static void
fm_abstract_icon_view_highlight_path (FMDirectoryView *view, GtkTreePath *path)
{
    g_return_if_fail (FM_IS_ABSTRACT_ICON_VIEW (view));

    exo_icon_view_set_drag_dest_item (FM_ABSTRACT_ICON_VIEW (view)->icons, path, EXO_ICON_VIEW_DROP_INTO);
}

static gboolean
fm_abstract_icon_view_get_visible_range (FMDirectoryView *view,
                                         GtkTreePath     **start_path,
                                         GtkTreePath     **end_path)
{
    g_return_val_if_fail (FM_IS_ABSTRACT_ICON_VIEW (view), FALSE);
    return exo_icon_view_get_visible_range (FM_ABSTRACT_ICON_VIEW (view)->icons, start_path, end_path);
}

static void
fm_abstract_icon_view_destroy (GtkWidget *object)
{
    FMAbstractIconView *icon_view = FM_ABSTRACT_ICON_VIEW (object);

    g_warning ("%s", G_STRFUNC);

    g_settings_unbind (icon_view, "zoom-level");

    GTK_WIDGET_CLASS (fm_abstract_icon_view_parent_class)->destroy (object);
}

static void
fm_abstract_icon_view_finalize (GObject *object)
{
    FMAbstractIconView *view = FM_ABSTRACT_ICON_VIEW (object);

    g_warning ("%s\n", G_STRFUNC);

    g_free (view->details->original_name);
    view->details->original_name = NULL;

    if (view->details->selection)
        gof_file_list_free (view->details->selection);

    g_free (view->details);

    G_OBJECT_CLASS (fm_abstract_icon_view_parent_class)->finalize (object); 
}

static void
fm_abstract_icon_view_init (FMAbstractIconView *view)
{
    view->details = g_new0 (FMAbstractIconViewDetails, 1);
    view->details->selection = NULL;
    view->details->sort_type = FM_LIST_MODEL_FILENAME;
    view->details->sort_reversed = GTK_SORT_ASCENDING;

    view->model = FM_DIRECTORY_VIEW (view)->model;
    g_object_set (G_OBJECT (view->model), "has-child", FALSE, NULL);

    view->icons = EXO_ICON_VIEW (exo_icon_view_new());
    exo_icon_view_set_model (view->icons, GTK_TREE_MODEL (view->model));

    exo_icon_view_set_search_column (view->icons, FM_LIST_MODEL_FILENAME);

    g_signal_connect (G_OBJECT (view->icons), "item-activated", G_CALLBACK (fm_abstract_icon_view_item_activated), view);
    g_signal_connect (G_OBJECT (view->icons), "item-hovered", G_CALLBACK (fm_abstract_icon_view_item_hovered), view);
    g_signal_connect (G_OBJECT (view->icons), "selection-changed", G_CALLBACK (fm_abstract_icon_view_selection_changed), view);


    exo_icon_view_set_selection_mode (view->icons, GTK_SELECTION_MULTIPLE);

    /*exo_icon_view_set_row_spacing (view->icons, 0);*/
    exo_icon_view_set_item_padding (view->icons, 0);
    /*exo_icon_view_set_margin (view->icons, 0);*/

    /* add the icon renderer */
    g_object_set (G_OBJECT (FM_DIRECTORY_VIEW (view)->icon_renderer),
                  "follow-state", TRUE, "ypad", 2u, "yalign", 1.0f, NULL);
    gtk_cell_layout_pack_start (GTK_CELL_LAYOUT (view->icons), FM_DIRECTORY_VIEW (view)->icon_renderer, FALSE);
    gtk_cell_layout_add_attribute (GTK_CELL_LAYOUT (view->icons), FM_DIRECTORY_VIEW (view)->icon_renderer, "file", FM_LIST_MODEL_FILE_COLUMN);

    /* add the name renderer */
    g_object_set (G_OBJECT (FM_DIRECTORY_VIEW (view)->name_renderer), 
                  "follow-state", TRUE, "wrap-mode", PANGO_WRAP_WORD_CHAR, 
                  "xalign", 0.5f, "yalign", 0.0f, NULL);
    gtk_cell_layout_pack_start (GTK_CELL_LAYOUT (view->icons), FM_DIRECTORY_VIEW (view)->name_renderer, TRUE);
    gtk_cell_layout_add_attribute (GTK_CELL_LAYOUT (view->icons), FM_DIRECTORY_VIEW (view)->name_renderer, "text", FM_LIST_MODEL_FILENAME);
    gtk_cell_layout_add_attribute (GTK_CELL_LAYOUT (view->icons), FM_DIRECTORY_VIEW (view)->name_renderer, "background", FM_LIST_MODEL_COLOR);

    g_signal_connect (FM_DIRECTORY_VIEW (view)->name_renderer, "edited", G_CALLBACK (cell_renderer_edited), view);
    g_signal_connect (FM_DIRECTORY_VIEW (view)->name_renderer, "editing-canceled", G_CALLBACK (cell_renderer_editing_canceled), view);
    g_signal_connect (FM_DIRECTORY_VIEW (view)->name_renderer, "editing-started", G_CALLBACK (cell_renderer_editing_started_cb), view);



    /* TODO */
    /* synchronize the "text-beside-icons" property with the global preference */
    /**/
    //g_object_set (G_OBJECT (view), "text-beside-icons", FALSE, NULL);

    g_settings_bind (settings, "single-click", 
                     view->icons, "single-click", 0);
    g_settings_bind (settings, "single-click", 
                     FM_DIRECTORY_VIEW (view)->name_renderer, "follow-prelit", 0); 
    g_settings_bind (settings, "single-click", 
                     FM_DIRECTORY_VIEW (view)->icon_renderer, "selection-helpers", 0);

    g_signal_connect_object (view->icons, "button-press-event",
                             G_CALLBACK (button_press_callback), view, 0);
    g_signal_connect_object (view->icons, "key_press_event",
                             G_CALLBACK (key_press_callback), view, 0);
    g_signal_connect (view->icons, "draw",
                      G_CALLBACK (fm_abstract_icon_view_draw), view);
    gtk_widget_show (GTK_WIDGET (view->icons));
    gtk_container_add (GTK_CONTAINER (view), GTK_WIDGET (view->icons));
}

#if 0
static void
fm_abstract_icon_view_get_property (GObject      *object,
                                    guint         prop_id,
                                    GValue       *value,
                                    GParamSpec   *pspec)
{
    FMAbstractIconView *view = FM_ABSTRACT_ICON_VIEW (object);

    switch (prop_id)
    {
    case PROP_ZOOM_LEVEL:
        g_value_set_enum (value, view->zoom_level);
        break;

    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
        break;
    }   
}
#endif

static void
fm_abstract_icon_view_set_property (GObject         *object,
                                    guint            prop_id,
                                    const GValue    *value,
                                    GParamSpec      *pspec)
{
    FMAbstractIconView *view = FM_ABSTRACT_ICON_VIEW (object);

    switch (prop_id)
    {
    case PROP_TEXT_BESIDE_ICONS:
        if (g_value_get_boolean (value))
        {
            view->details->text_beside_icons = TRUE;
            exo_icon_view_set_item_orientation (view->icons, GTK_ORIENTATION_HORIZONTAL);
            g_object_set (G_OBJECT (FM_DIRECTORY_VIEW (view)->icon_renderer), "yalign", 0.5f, NULL);
        }
        else
        {
            view->details->text_beside_icons = FALSE;
            exo_icon_view_set_item_orientation (view->icons, GTK_ORIENTATION_VERTICAL);
            g_object_set (G_OBJECT (FM_DIRECTORY_VIEW (view)->icon_renderer), "yalign", 1.0f, NULL);
            g_object_set (FM_DIRECTORY_VIEW (view)->name_renderer, "xalign", 0.5f, "yalign", 0.0f, NULL);
        }
        break;

    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
        break;
    }
}

static void
fm_abstract_icon_view_class_init (FMAbstractIconViewClass *klass)
{
    FMDirectoryViewClass *fm_directory_view_class;
    GObjectClass *object_class = G_OBJECT_CLASS (klass);

    object_class->finalize     = fm_abstract_icon_view_finalize;
    //object_class->get_property = fm_abstract_icon_view_get_property;
    object_class->set_property = fm_abstract_icon_view_set_property;
    GTK_WIDGET_CLASS (klass)->destroy = fm_abstract_icon_view_destroy;

    fm_directory_view_class = FM_DIRECTORY_VIEW_CLASS (klass);

    fm_directory_view_class->sync_selection = fm_abstract_icon_view_sync_selection;
    fm_directory_view_class->get_selection = fm_abstract_icon_view_get_selection;
    fm_directory_view_class->get_selection_for_file_transfer = fm_abstract_icon_view_get_selection_for_file_transfer;
    fm_directory_view_class->get_selected_paths = fm_abstract_icon_view_get_selected_paths;
    fm_directory_view_class->select_path = fm_abstract_icon_view_select_path;
    fm_directory_view_class->select_all = fm_abstract_icon_view_select_all;
    fm_directory_view_class->set_cursor = fm_abstract_icon_view_set_cursor;

    fm_directory_view_class->get_path_at_pos = fm_abstract_icon_view_get_path_at_pos;
    fm_directory_view_class->highlight_path = fm_abstract_icon_view_highlight_path;
    fm_directory_view_class->get_visible_range = fm_abstract_icon_view_get_visible_range;
    fm_directory_view_class->start_renaming_file = fm_abstract_icon_view_start_renaming_file;

    fm_directory_view_class->merge_menus = fm_abstract_icon_view_merge_menus;
    fm_directory_view_class->unmerge_menus = fm_abstract_icon_view_unmerge_menus;

    g_object_class_install_property (object_class,
                                     PROP_TEXT_BESIDE_ICONS,
                                     g_param_spec_boolean ("text-beside-icons", 
                                                           "text-beside-icons",
                                                           "text-beside-icons",
                                                           FALSE,
                                                           (G_PARAM_WRITABLE | G_PARAM_STATIC_STRINGS)));

}

