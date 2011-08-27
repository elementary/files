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

#include "fm-icon-view.h"
#include "fm-list-model.h"
#include "fm-directory-view.h"
#include "marlin-global-preferences.h"
#include "eel-i18n.h"
#include <gdk/gdk.h>
#include <gdk/gdkkeysyms.h>

//#include "gof-directory-async.h"
#include "nautilus-cell-renderer-text-ellipsized.h"
#include "eel-glib-extensions.h"
#include "eel-gtk-extensions.h"
#include "eel-editable-label.h"
#include "marlin-tags.h"

enum
{
    PROP_0,
    PROP_ZOOM_LEVEL,
    PROP_TEXT_BESIDE_ICONS
};

struct FMIconViewDetails {
    GList       *selection;
    GtkTreePath *new_selection_path;   /* Path of the new selection after removing a file */

    GtkCellEditable     *editable_widget;
    GtkTreeViewColumn   *file_name_column;
    GtkCellRendererText *file_name_cell;
    char                *original_name;

    GOFFile     *renaming_file;
    gboolean    rename_done;
};

/* Wait for the rename to end when activating a file being renamed */
#define WAIT_FOR_RENAME_ON_ACTIVATE 200

//static gchar *col_title[4] = { _("Filename"), _("Size"), _("Type"), _("Modified") };

G_DEFINE_TYPE (FMIconView, fm_icon_view, FM_TYPE_DIRECTORY_VIEW);

#define parent_class fm_icon_view_parent_class

/* Declaration Prototypes */
static GList    *fm_icon_view_get_selection (FMDirectoryView *view);
static GList    *get_selection (FMIconView *view);
static GList    *fm_icon_view_get_selected_paths (FMDirectoryView *view);
static void     fm_icon_view_select_path (FMDirectoryView *view, GtkTreePath *path);
static void     fm_icon_view_set_cursor (FMDirectoryView *view, GtkTreePath *path, gboolean start_editing);

//static void     fm_icon_view_clear (FMIconView *view);
static void     fm_icon_view_zoom_level_changed (FMIconView *view);

/*static void
  show_selected_files (GOFFile *file)
  {
  log_printf (LOG_LEVEL_UNDEFINED, "selected: %s\n", file->name);
  }*/

static void
fm_icon_view_selection_changed (GtkIconView *iconview, gpointer user_data)
{
    FMIconView *view = FM_ICON_VIEW (user_data);

    if (view->details->selection != NULL)
        gof_file_list_free (view->details->selection);
    view->details->selection = get_selection (view);

    fm_directory_view_notify_selection_changed (FM_DIRECTORY_VIEW (view));
}

static void
fm_icon_view_item_activated (ExoIconView *exo_icon, GtkTreePath *path, FMIconView *view)
{
    fm_directory_view_activate_selected_items (FM_DIRECTORY_VIEW (view));    
}

static void
fm_icon_view_rename_callback (GOFFile *file,
                              GFile *result_location,
                              GError *error,
                              gpointer callback_data)
{
    FMIconView *view = FM_ICON_VIEW (callback_data);

    //printf ("%s\n", G_STRFUNC);
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
    FMIconView *view = user_data;

    //printf ("%s\n", G_STRFUNC);
    view->details->editable_widget = NULL;
    fm_directory_view_unfreeze_updates (FM_DIRECTORY_VIEW (view));
    
    /*We're done editing - make the filename-cells readonly again.*/
    g_object_set (FM_DIRECTORY_VIEW (view)->name_renderer,
                  "mode", GTK_CELL_RENDERER_MODE_INERT, NULL);

}

static void
cell_renderer_editing_started_cb (GtkCellRenderer *renderer,
                                  GtkCellEditable *editable,
                                  const gchar *path_str,
                                  FMIconView *icon_view)
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
                                FMIconView      *view)
{
    //printf ("%s\n", G_STRFUNC);
    view->details->editable_widget = NULL;

    fm_directory_view_unfreeze_updates (FM_DIRECTORY_VIEW (view));
    
    /*We're done editing - make the filename-cells readonly again.*/
    g_object_set (FM_DIRECTORY_VIEW (view)->name_renderer,
                  "mode", GTK_CELL_RENDERER_MODE_INERT, NULL);
}
//#endif

static void
cell_renderer_edited (GtkCellRenderer   *cell,
                      const char        *path_str,
                      const char        *new_text,
                      FMIconView        *view)
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
        g_object_set (FM_DIRECTORY_VIEW (view)->name_renderer,
                      "mode", GTK_CELL_RENDERER_MODE_INERT, NULL);
        fm_directory_view_unfreeze_updates (FM_DIRECTORY_VIEW (view));
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
        gof_file_rename (file, new_text, fm_icon_view_rename_callback, g_object_ref (view));

        g_free (view->details->original_name);
        view->details->original_name = g_strdup (new_text);
    }

    gof_file_unref (file);

    /*We're done editing - make the filename-cells readonly again.*/
    g_object_set (FM_DIRECTORY_VIEW (view)->name_renderer,
                  "mode", GTK_CELL_RENDERER_MODE_INERT, NULL);

    fm_directory_view_unfreeze_updates (FM_DIRECTORY_VIEW (view));
}
static void
fm_icon_view_select_all (FMDirectoryView *view)
{
    exo_icon_view_select_all (FM_ICON_VIEW (view)->icons);
}

static void
fm_icon_view_start_renaming_file (FMDirectoryView *view,
                                  GOFFile *file,
                                  gboolean select_all)
{
    FMIconView *icon_view;
    GtkTreeIter iter;
    GtkTreePath *path;
    gint start_offset, end_offset;

    icon_view = FM_ICON_VIEW (view);

    //printf ("%s\n", G_STRFUNC);
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
    fm_directory_view_freeze_updates (FM_DIRECTORY_VIEW (view));

    path = gtk_tree_model_get_path (GTK_TREE_MODEL (icon_view->model), &iter);

    /* Make marlin-text-renderer cells editable. */
    g_object_set (view->name_renderer,
                  "mode", GTK_CELL_RENDERER_MODE_EDITABLE, NULL);

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
fm_icon_view_sync_selection (FMDirectoryView *view)
{
    fm_directory_view_notify_selection_changed (view);
}


/*static void
  do_popup_menu (GtkWidget *widget, FMIconView *view, GdkEventButton *event)
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
button_press_callback (GtkTreeView *tree_view, GdkEventButton *event, FMIconView *view)
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
            fm_directory_view_context_menu (FM_DIRECTORY_VIEW (view), event->button, event);
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

            /* if the event was a double-click or we are in single-click mode, then
             * we'll open the file or folder (folder's are opened in new windows)
             */
            if (G_LIKELY (event->type == GDK_2BUTTON_PRESS ||  exo_icon_view_get_single_click (view->icons)))
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
  FMIconView *view;

  view = FM_ICON_VIEW (callback_data);

  do_popup_menu (widget, view, NULL);

  return TRUE;
  }*/

static gboolean
key_press_callback (GtkWidget *widget, GdkEventKey *event, gpointer callback_data)
{
    FMDirectoryView *view;
    //GdkEventButton button_event = { 0 };
    gboolean handled;

    view = FM_DIRECTORY_VIEW (callback_data);
    handled = FALSE;

    switch (event->keyval) {
    /*case GDK_F10:
          if (event->state & GDK_CONTROL_MASK) {
          fm_directory_view_pop_up_background_context_menu (view, &button_event);
          handled = TRUE;
          }
          break;*/
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
            //TODO
            printf ("activate alternate\n"); 
            //activate_selected_items_alternate (FM_ICON_VIEW (view), NULL, TRUE);
        } else {
            fm_directory_view_preview_selected_items (view);
        }
        handled = TRUE;
        break;
    /*case GDK_KEY_Return:
    case GDK_KEY_KP_Enter:
        if ((event->state & GDK_SHIFT_MASK) != 0) {
          activate_selected_items_alternate (FM_ICON_VIEW (view), NULL, TRUE);
          handled = TRUE;
          }
        break; */

    default:
        handled = FALSE;
    }

    return handled;
}

static gboolean fm_icon_view_draw(GtkWidget* view_, cairo_t* cr, FMIconView* view)
{
    g_return_if_fail(FM_IS_ICON_VIEW(view));
    GtkTreeIter iter;
    gboolean folder_empty = !gtk_tree_model_get_iter_first(view->model, &iter);
    if(folder_empty && !fm_directory_view_get_loading(FM_DIRECTORY_VIEW(view)))
    {
        PangoLayout* layout = gtk_widget_create_pango_layout(GTK_WIDGET(view), _("This folder is empty."));
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
fm_icon_view_add_file (FMDirectoryView *view, GOFFile *file, GOFDirectoryAsync *directory)
{
    FMListModel *model;

    model = FM_ICON_VIEW (view)->model;
    fm_list_model_add_file (model, file, directory);
}

static GList *
get_selection (FMIconView *view)
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
fm_icon_view_get_selection (FMDirectoryView *view)
{
    return FM_ICON_VIEW (view)->details->selection;
}

static GList *
fm_icon_view_get_selection_for_file_transfer (FMDirectoryView *view)
{
    GList *list = g_list_copy (fm_icon_view_get_selection (view));
    g_list_foreach (list, (GFunc) gof_file_ref, NULL);

    return list;
}

static GList *
fm_icon_view_get_selected_paths (FMDirectoryView *view)
{
    return exo_icon_view_get_selected_items (FM_ICON_VIEW (view)->icons);
}

static void
fm_icon_view_select_path (FMDirectoryView *view, GtkTreePath *path)
{
    exo_icon_view_select_path (FM_ICON_VIEW (view)->icons, path);
}

static void
fm_icon_view_set_cursor (FMDirectoryView *view, GtkTreePath *path, gboolean start_editing)
{
    FMIconView *icon_view = FM_ICON_VIEW (view);

    exo_icon_view_set_cursor (icon_view->icons, path,
                              view->name_renderer,
                              start_editing);
}

static GtkTreePath*
fm_icon_view_get_path_at_pos (FMDirectoryView *view, gint x, gint y)
{
    GtkTreePath *path;

    g_return_val_if_fail (FM_IS_ICON_VIEW (view), NULL);

    if (exo_icon_view_get_dest_item_at_pos  (FM_ICON_VIEW (view)->icons, x, y, &path, NULL))
        return path;

    return NULL;
}

static void
fm_icon_view_highlight_path (FMDirectoryView *view, GtkTreePath *path)
{
    g_return_if_fail (FM_IS_ICON_VIEW (view));

    exo_icon_view_set_drag_dest_item (FM_ICON_VIEW (view)->icons, path, EXO_ICON_VIEW_DROP_INTO);
}

static gboolean
fm_icon_view_get_visible_range (FMDirectoryView *view,
                                GtkTreePath     **start_path,
                                GtkTreePath     **end_path)
{
    g_return_val_if_fail (FM_IS_ICON_VIEW (view), FALSE);
    return exo_icon_view_get_visible_range (FM_ICON_VIEW (view)->icons, start_path, end_path);
}

static void
fm_icon_view_zoom_normal (FMDirectoryView *view)
{
    MarlinZoomLevel     zoom;
    
    zoom = g_settings_get_enum (marlin_icon_view_settings, "default-zoom-level");
    g_settings_set_enum (marlin_icon_view_settings, "zoom-level", zoom);
}

static void
fm_icon_view_destroy (GtkWidget *object)
{
    FMIconView *icon_view = FM_ICON_VIEW (object);

    g_warning ("%s", G_STRFUNC);

    g_settings_unbind (icon_view, "zoom-level");

    GTK_WIDGET_CLASS (fm_icon_view_parent_class)->destroy (object);
}

static void
fm_icon_view_finalize (GObject *object)
{
    FMIconView *view = FM_ICON_VIEW (object);

    g_warning ("%s\n", G_STRFUNC);

    g_free (view->details->original_name);
    view->details->original_name = NULL;

    if (view->details->new_selection_path)
        gtk_tree_path_free (view->details->new_selection_path);
    if (view->details->selection)
        gof_file_list_free (view->details->selection);


    g_object_unref (view->model);
    g_free (view->details);
    G_OBJECT_CLASS (fm_icon_view_parent_class)->finalize (object); 
}

static void
fm_icon_view_init (FMIconView *view)
{
    view->details = g_new0 (FMIconViewDetails, 1);
    view->details->selection = NULL;

    view->model = FM_DIRECTORY_VIEW (view)->model;
    g_object_set (G_OBJECT (view->model), "has-child", FALSE, NULL);

    view->icons = EXO_ICON_VIEW (exo_icon_view_new());
    exo_icon_view_set_model (view->icons, GTK_TREE_MODEL (view->model));

    exo_icon_view_set_search_column (view->icons, FM_LIST_MODEL_FILENAME);

    g_signal_connect (G_OBJECT (view->icons), "item-activated", G_CALLBACK (fm_icon_view_item_activated), view);
    g_signal_connect (G_OBJECT (view->icons), "selection-changed", G_CALLBACK (fm_icon_view_selection_changed), view);


    exo_icon_view_set_selection_mode (view->icons, GTK_SELECTION_MULTIPLE);
    
    /* add the icon renderer */
    g_object_set (G_OBJECT (FM_DIRECTORY_VIEW (view)->icon_renderer),
                  "follow-state", TRUE, "ypad", 3u, NULL);
    g_object_set (G_OBJECT (FM_DIRECTORY_VIEW (view)->icon_renderer),
                  "follow-state", TRUE, "yalign", 1.0f, NULL);
    gtk_cell_layout_pack_start (GTK_CELL_LAYOUT (view->icons), FM_DIRECTORY_VIEW (view)->icon_renderer, FALSE);
    gtk_cell_layout_add_attribute (GTK_CELL_LAYOUT (view->icons), FM_DIRECTORY_VIEW (view)->icon_renderer, "file", FM_LIST_MODEL_FILE_COLUMN);

    /* add the name renderer */
    g_object_set (G_OBJECT (FM_DIRECTORY_VIEW (view)->name_renderer), 
                  "follow-state", TRUE, "wrap-mode", PANGO_WRAP_WORD_CHAR, NULL);
    gtk_cell_layout_pack_start (GTK_CELL_LAYOUT (view->icons), FM_DIRECTORY_VIEW (view)->name_renderer, TRUE);
    gtk_cell_layout_add_attribute (GTK_CELL_LAYOUT (view->icons), FM_DIRECTORY_VIEW (view)->name_renderer, "text", FM_LIST_MODEL_FILENAME);
    gtk_cell_layout_add_attribute (GTK_CELL_LAYOUT (view->icons), FM_DIRECTORY_VIEW (view)->name_renderer, "background", FM_LIST_MODEL_COLOR);

    g_signal_connect (FM_DIRECTORY_VIEW (view)->name_renderer, "edited", G_CALLBACK (cell_renderer_edited), view);
    g_signal_connect (FM_DIRECTORY_VIEW (view)->name_renderer, "editing-canceled", G_CALLBACK (cell_renderer_editing_canceled), view);
    g_signal_connect (FM_DIRECTORY_VIEW (view)->name_renderer, "editing-started", G_CALLBACK (cell_renderer_editing_started_cb), view);



    /* TODO */
    /* synchronize the "text-beside-icons" property with the global preference */
    /**/
    g_object_set (G_OBJECT (view), "text-beside-icons", FALSE, NULL);

    g_settings_bind (settings, "single-click", 
                     view->icons, "single-click", 0);
    g_settings_bind (settings, "single-click-timeout", 
                     view->icons, "single-click-timeout", 0);
    g_settings_bind (settings, "single-click", 
                     FM_DIRECTORY_VIEW (view)->name_renderer, "follow-prelit", 0); 
    g_settings_bind (settings, "single-click", 
                     FM_DIRECTORY_VIEW (view)->icon_renderer, "selection-helpers", 0);
    g_settings_bind (marlin_icon_view_settings, "zoom-level", 
                     view, "zoom-level", 0);


    g_signal_connect_object (view->icons, "button-press-event",
                             G_CALLBACK (button_press_callback), view, 0);
    g_signal_connect_object (view->icons, "key_press_event",
                             G_CALLBACK (key_press_callback), view, 0);
    g_signal_connect (view->icons, "draw",
                             G_CALLBACK (fm_icon_view_draw), view);
    gtk_widget_show (GTK_WIDGET (view->icons));
    gtk_container_add (GTK_CONTAINER (view), GTK_WIDGET (view->icons));
}

static void
fm_icon_view_get_property (GObject      *object,
                           guint         prop_id,
                           GValue       *value,
                           GParamSpec   *pspec)
{
    FMIconView *view = FM_ICON_VIEW (object);

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

static void
fm_icon_view_set_property (GObject      *object,
                           guint         prop_id,
                           const GValue       *value,
                           GParamSpec   *pspec)
{
    FMIconView *view = FM_ICON_VIEW (object);

    switch (prop_id)
    {
    case PROP_TEXT_BESIDE_ICONS:
        if (G_UNLIKELY (g_value_get_boolean (value)))
        {
            exo_icon_view_set_item_orientation (view->icons, GTK_ORIENTATION_HORIZONTAL);
            //g_object_set (G_OBJECT (view->name_renderer), "wrap-width", 128, "yalign", 0.5f, NULL);
            g_object_set (FM_DIRECTORY_VIEW (view)->name_renderer, "wrap-width", 128, "xalign", 0.0f, "yalign", 0.5f, NULL);

            /* disconnect the "zoom-level" signal handler, since we're using a fixed wrap-width here */
            /*g_signal_handlers_disconnect_by_func (marlin_icon_view_settings,
                                                  fm_icon_view_zoom_level_changed, view);*/
        }
        else
        {
            exo_icon_view_set_item_orientation (view->icons, GTK_ORIENTATION_VERTICAL);
            g_object_set (FM_DIRECTORY_VIEW (view)->name_renderer, "xalign", 0.5f, "yalign", 0.0f, NULL);

            /* connect the "zoom-level" signal handler as the wrap-width is now synced with the "zoom-level" */
            /*g_signal_connect_swapped (marlin_icon_view_settings, "changed::zoom-level",
                                      G_CALLBACK (fm_icon_view_zoom_level_changed), view);
            fm_icon_view_zoom_level_changed (view);*/
        }
        break;
    case PROP_ZOOM_LEVEL:
        view->zoom_level = g_value_get_enum (value);
        fm_icon_view_zoom_level_changed (view);
        break;

    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
        break;
    }
}

static void
fm_icon_view_class_init (FMIconViewClass *klass)
{
    FMDirectoryViewClass *fm_directory_view_class;
    GObjectClass *object_class = G_OBJECT_CLASS (klass);

    object_class->finalize     = fm_icon_view_finalize;
    object_class->get_property = fm_icon_view_get_property;
    object_class->set_property = fm_icon_view_set_property;
    GTK_WIDGET_CLASS (klass)->destroy = fm_icon_view_destroy;

    fm_directory_view_class = FM_DIRECTORY_VIEW_CLASS (klass);

    fm_directory_view_class->add_file = fm_icon_view_add_file;
    fm_directory_view_class->sync_selection = fm_icon_view_sync_selection;
    fm_directory_view_class->get_selection = fm_icon_view_get_selection;
    fm_directory_view_class->get_selection_for_file_transfer = fm_icon_view_get_selection_for_file_transfer;
    fm_directory_view_class->get_selected_paths = fm_icon_view_get_selected_paths;
    fm_directory_view_class->select_path = fm_icon_view_select_path;
    fm_directory_view_class->select_all = fm_icon_view_select_all;
    fm_directory_view_class->set_cursor = fm_icon_view_set_cursor;

    fm_directory_view_class->get_path_at_pos = fm_icon_view_get_path_at_pos;
    fm_directory_view_class->highlight_path = fm_icon_view_highlight_path;
    fm_directory_view_class->get_visible_range = fm_icon_view_get_visible_range;
    fm_directory_view_class->start_renaming_file = fm_icon_view_start_renaming_file;
    fm_directory_view_class->zoom_normal = fm_icon_view_zoom_normal;

    g_object_class_install_property (object_class,
                                     PROP_TEXT_BESIDE_ICONS,
                                     g_param_spec_boolean ("text-beside-icons", 
                                                           "text-beside-icons",
                                                           "text-beside-icons",
                                                           FALSE,
                                                           (G_PARAM_WRITABLE | G_PARAM_STATIC_STRINGS)));

    g_object_class_install_property (object_class,
                                     PROP_ZOOM_LEVEL,
                                     g_param_spec_enum ("zoom-level", "zoom-level", "zoom-level",
                                                        MARLIN_TYPE_ZOOM_LEVEL,
                                                        MARLIN_ZOOM_LEVEL_NORMAL,
                                                        G_PARAM_READWRITE));
                                                        //G_PARAM_CONSTRUCT | G_PARAM_READWRITE));

}

static void fm_icon_view_zoom_level_changed (FMIconView *view)
{
    gint wrap_width;

    g_return_if_fail (FM_IS_ICON_VIEW (view));

    /* determine the "wrap-width" depending on the "zoom-level" */
    switch (view->zoom_level)
    {
    case MARLIN_ZOOM_LEVEL_SMALLEST:
        wrap_width = 48;
        break;

    case MARLIN_ZOOM_LEVEL_SMALLER:
        wrap_width = 64;
        break;

    case MARLIN_ZOOM_LEVEL_SMALL:
        wrap_width = 72;
        break;

    case MARLIN_ZOOM_LEVEL_NORMAL:
        wrap_width = 112;
        break;

    default:
        wrap_width = 128;
        break;
    }

    /* set the new "wrap-width" for the text renderer */
    g_object_set (FM_DIRECTORY_VIEW (view)->name_renderer, "wrap-width", wrap_width, "zoom-level", view->zoom_level, NULL);
    /* set the new "size" for the icon renderer */
    g_object_set (FM_DIRECTORY_VIEW (view)->icon_renderer, "size", marlin_zoom_level_to_icon_size (view->zoom_level), NULL);

    exo_icon_view_invalidate_sizes (FM_ICON_VIEW (view)->icons);
}

