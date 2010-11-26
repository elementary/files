/* fm-directory-view.c
 *
 * Copyright (C) 1999, 2000  Free Software Foundation
 * Copyright (C) 2000, 2001  Eazel, Inc.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authors: Ettore Perazzoli,
 *          John Sullivan <sullivan@eazel.com>,
 *          Darin Adler <darin@bentspoon.com>,
 *          Pavel Cisler <pavel@eazel.com>,
 *          David Emory Watson <dwatson@cs.ucr.edu>
 */

#include <config.h>
#include "fm-directory-view.h"
#include <math.h>

#include <gdk/gdkkeysyms.h>
#include <gtk/gtk.h>
#include <glib/gi18n.h>
#include <glib/gstdio.h>
#include <gio/gio.h>
#include "gof-directory-async.h"
//#include "fm-list-view.h"
#include "eel-gtk-macros.h"
#include "nautilus-marshal.h"
#include "fm-columns-view.h"
#include "marlin-private.h"

enum {
    ADD_FILE,
    BEGIN_FILE_CHANGES,
    BEGIN_LOADING,
    CLEAR,
    END_FILE_CHANGES,
    FLUSH_ADDED_FILES,
    END_LOADING,
    FILE_CHANGED,
    LOAD_ERROR,
    MOVE_COPY_ITEMS,
    REMOVE_FILE,
    TRASH,
    DELETE,
    COLORIZE_SELECTION,
    SYNC_SELECTION,
    LAST_SIGNAL
};

enum 
{
    PROP_0,
    PROP_WINDOW_SLOT
};


static guint signals[LAST_SIGNAL];

//static GdkAtom copied_files_atom;

//static gboolean show_delete_command_auto_value;
//static gboolean confirm_trash_auto_value;

//static char *scripts_directory_uri;
//static int scripts_directory_uri_length;

struct FMDirectoryViewDetails
{
    GtkWidget *window;
    GOFWindowSlot *slot;
    //GOFDirectoryAsync *directory;
    //GOFFile *directory_as_file;

    /* whether we are in the active slot */
    //gboolean active;

    /* loading indicates whether this view has begun loading a directory.
     * This flag should need not be set inside subclasses. FMDirectoryView automatically
     * sets 'loading' to TRUE before it begins loading a directory's contents and to FALSE
     * after it finishes loading the directory and its view.
     */
    //gboolean loading;

    /* flag to indicate that no file updates should be dispatched to subclasses.
     * This is a workaround for bug #87701 that prevents the list view from
     * losing focus when the underlying GtkTreeView is updated.
     */
    //gboolean show_hidden_files;

    /*gchar* undo_action_description;
      gchar* undo_action_label;
      gchar* redo_action_description;
      gchar* redo_action_label;*/
};

#if 0
typedef struct {
    GOFFile *file;
    GOFDirectoryAsync *directory;
} FileAndDirectory;
#endif
/* forward declarations */

static void     fm_directory_view_class_init    (FMDirectoryViewClass *klass);
static void     fm_directory_view_init          (FMDirectoryView      *view);
/*static void     fm_directory_view_create_links_for_files       (FMDirectoryView      *view,
  GList                *files,
  GArray               *item_locations);
  static void     trash_or_delete_files                          (GtkWindow            *parent_window,
  const GList          *files,
  gboolean              delete_if_all_already_in_trash,
  FMDirectoryView      *view);*/

EEL_CLASS_BOILERPLATE (FMDirectoryView, fm_directory_view, GTK_TYPE_SCROLLED_WINDOW)

EEL_IMPLEMENT_MUST_OVERRIDE_SIGNAL (fm_directory_view, add_file)
    /*EEL_IMPLEMENT_MUST_OVERRIDE_SIGNAL (fm_directory_view, bump_zoom_level)
      EEL_IMPLEMENT_MUST_OVERRIDE_SIGNAL (fm_directory_view, can_zoom_in)
      EEL_IMPLEMENT_MUST_OVERRIDE_SIGNAL (fm_directory_view, can_zoom_out)
      EEL_IMPLEMENT_MUST_OVERRIDE_SIGNAL (fm_directory_view, clear)
      EEL_IMPLEMENT_MUST_OVERRIDE_SIGNAL (fm_directory_view, file_changed)
      EEL_IMPLEMENT_MUST_OVERRIDE_SIGNAL (fm_directory_view, get_background_widget)
      EEL_IMPLEMENT_MUST_OVERRIDE_SIGNAL (fm_directory_view, get_selection)
      EEL_IMPLEMENT_MUST_OVERRIDE_SIGNAL (fm_directory_view, get_selection_for_file_transfer)
      EEL_IMPLEMENT_MUST_OVERRIDE_SIGNAL (fm_directory_view, get_item_count)
      EEL_IMPLEMENT_MUST_OVERRIDE_SIGNAL (fm_directory_view, is_empty)
      EEL_IMPLEMENT_MUST_OVERRIDE_SIGNAL (fm_directory_view, reset_to_defaults)
      EEL_IMPLEMENT_MUST_OVERRIDE_SIGNAL (fm_directory_view, restore_default_zoom_level)
      EEL_IMPLEMENT_MUST_OVERRIDE_SIGNAL (fm_directory_view, select_all)
      EEL_IMPLEMENT_MUST_OVERRIDE_SIGNAL (fm_directory_view, set_selection)
      EEL_IMPLEMENT_MUST_OVERRIDE_SIGNAL (fm_directory_view, zoom_to_level)
      EEL_IMPLEMENT_MUST_OVERRIDE_SIGNAL (fm_directory_view, get_zoom_level)
      EEL_IMPLEMENT_MUST_OVERRIDE_SIGNAL (fm_directory_view, invert_selection)*/

    /*typedef struct {
      GAppInfo *application;
      GList *files;
      FMDirectoryView *directory_view;
      } ApplicationLaunchParameters;*/

#if 0
GtkWidget *
fm_directory_view_get_nautilus_window (FMDirectoryView  *view)
{
    g_assert (view->details->window != NULL);

    return view->details->window;
}

GOFWindowSlot *
fm_directory_view_get_nautilus_window_slot (FMDirectoryView  *view)
{
    g_assert (view->details->slot != NULL);

    return view->details->slot;
}

/* Returns the GtkWindow that this directory view occupies, or NULL
 * if at the moment this directory view is not in a GtkWindow or the
 * GtkWindow cannot be determined. Primarily used for parenting dialogs.
 */
GtkWindow *
fm_directory_view_get_containing_window (FMDirectoryView *view)
{
    GtkWidget *window;

    g_assert (FM_IS_DIRECTORY_VIEW (view));

    window = gtk_widget_get_ancestor (GTK_WIDGET (view), GTK_TYPE_WINDOW);
    if (window == NULL) {
        return NULL;
    }

    return GTK_WINDOW (window);
}
#endif

#if 0
static void
open_location (FMDirectoryView *directory_view, 
               const char *new_uri, 
               NautilusWindowOpenMode mode,
               NautilusWindowOpenFlags flags)
{
    GtkWindow *window;
    GFile *location;

    g_assert (FM_IS_DIRECTORY_VIEW (directory_view));
    g_assert (new_uri != NULL);

    window = fm_directory_view_get_containing_window (directory_view);
    nautilus_debug_log (FALSE, NAUTILUS_DEBUG_LOG_DOMAIN_USER,
                        "directory view open_location window=%p: %s", window, new_uri);
    location = g_file_new_for_uri (new_uri);
    nautilus_window_slot_info_open_location (directory_view->details->slot,
                                             location, mode, flags, NULL);
    g_object_unref (location);
}

static GtkWidget *
fm_directory_view_get_widget (NautilusView *view)
{
    return GTK_WIDGET (view);
}
#endif

static void
file_added_callback (GOFDirectoryAsync *directory, GOFFile *file, gpointer callback_data)
{
    FMDirectoryView *view = FM_DIRECTORY_VIEW (callback_data);

    g_signal_emit (view, signals[ADD_FILE], 0, file, directory); 
}

void
fm_directory_view_add_subdirectory (FMDirectoryView *view, GOFDirectoryAsync *directory)
{
    /*nautilus_directory_file_monitor_add (directory,
      &view->details->model,
      view->details->show_hidden_files,
      view->details->show_backup_files,
      attributes,
      files_added_callback, view);*/

    g_signal_connect
        (directory, "file_added",
         G_CALLBACK (file_added_callback), view);
    /* TODO */
    /*g_signal_connect
      (directory, "files_changed",
      G_CALLBACK (files_changed_callback), view);*/

    /*view->details->subdirectory_list = g_list_prepend (
      view->details->subdirectory_list, directory);*/
}

void
fm_directory_view_remove_subdirectory (FMDirectoryView *view, GOFDirectoryAsync *directory)
{
    /*g_assert (g_list_find (view->details->subdirectory_list, directory));

      view->details->subdirectory_list = g_list_remove (
      view->details->subdirectory_list, directory);*/

    g_signal_handlers_disconnect_by_func (directory,
                                          G_CALLBACK (file_added_callback),
                                          view);
    /* TODO */
    /*g_signal_handlers_disconnect_by_func (directory,
      G_CALLBACK (files_changed_callback),
      view);*/

    /*nautilus_directory_file_monitor_remove (directory, &view->details->model);*/
}


/*
   void
   fm_directory_view_init_view_iface (NautilusViewIface *iface)
   {
   iface->grab_focus = fm_directory_view_grab_focus;
   iface->update_menus = view_iface_update_menus;

   iface->get_widget = fm_directory_view_get_widget;
   iface->load_location = fm_directory_view_load_location;
   iface->stop_loading = fm_directory_view_stop_loading;

   iface->get_selection_count = fm_directory_view_get_selection_count;
   iface->get_selection = fm_directory_view_get_selection_locations;
   iface->set_selection = fm_directory_view_set_selection_locations;
   iface->set_is_active = (gpointer)fm_directory_view_set_is_active;

   iface->supports_zooming = (gpointer)fm_directory_view_supports_zooming;
   iface->bump_zoom_level = (gpointer)fm_directory_view_bump_zoom_level;
   iface->zoom_to_level = (gpointer)fm_directory_view_zoom_to_level;
   iface->restore_default_zoom_level = (gpointer)fm_directory_view_restore_default_zoom_level;
   iface->can_zoom_in = (gpointer)fm_directory_view_can_zoom_in;
   iface->can_zoom_out = (gpointer)fm_directory_view_can_zoom_out;
   iface->get_zoom_level = (gpointer)fm_directory_view_get_zoom_level;

   iface->pop_up_location_context_menu = (gpointer)fm_directory_view_pop_up_location_context_menu;
   iface->drop_proxy_received_uris = (gpointer)fm_directory_view_drop_proxy_received_uris;
   iface->drop_proxy_received_netscape_url = (gpointer)fm_directory_view_drop_proxy_received_netscape_url;
   }*/

static void
fm_directory_view_init (FMDirectoryView *view)
{
    static gboolean setup_autos = FALSE;
    //char *templates_uri;

    if (!setup_autos) {
        setup_autos = TRUE;
        /*eel_preferences_add_auto_boolean (NAUTILUS_PREFERENCES_CONFIRM_TRASH,
          &confirm_trash_auto_value);
          eel_preferences_add_auto_boolean (NAUTILUS_PREFERENCES_ENABLE_DELETE,
          &show_delete_command_auto_value);*/
    }

    view->details = g_new0 (FMDirectoryViewDetails, 1);

    gtk_scrolled_window_set_policy (GTK_SCROLLED_WINDOW (view),
                                    GTK_POLICY_AUTOMATIC,
                                    GTK_POLICY_AUTOMATIC);
    gtk_scrolled_window_set_hadjustment (GTK_SCROLLED_WINDOW (view), NULL);
    gtk_scrolled_window_set_vadjustment (GTK_SCROLLED_WINDOW (view), NULL);
    /* amtest: i am not sure i want a shadow here or only when no tabs */ 
    //gtk_scrolled_window_set_shadow_type (GTK_SCROLLED_WINDOW (view), GTK_SHADOW_IN);
    //gtk_scrolled_window_set_shadow_type (GTK_SCROLLED_WINDOW (view), GTK_SHADOW_NONE);

    /*g_signal_connect_object (nautilus_signaller_get_current (),
      "user_dirs_changed",
      G_CALLBACK (user_dirs_changed),
      view, G_CONNECT_SWAPPED);*/

    /*g_signal_connect_object (nautilus_trash_monitor_get (), "trash_state_changed",
      G_CALLBACK (fm_directory_view_trash_state_changed_callback), view, 0);*/

    /* React to clipboard changes */
    /*g_signal_connect_object (nautilus_clipboard_monitor_get (), "clipboard_changed",
      G_CALLBACK (clipboard_changed_callback), view, 0);*/

    /* Register to menu provider extension signal managing menu updates */
    /*g_signal_connect_object (nautilus_signaller_get_current (), "popup_menu_changed",
      G_CALLBACK (fm_directory_view_update_menus), view, G_CONNECT_SWAPPED);*/

    gtk_widget_show (GTK_WIDGET (view));

    /*eel_preferences_add_callback (NAUTILUS_PREFERENCES_CONFIRM_TRASH,
      schedule_update_menus_callback, view);
      eel_preferences_add_callback (NAUTILUS_PREFERENCES_ENABLE_DELETE,
      schedule_update_menus_callback, view);
      eel_preferences_add_callback (NAUTILUS_PREFERENCES_ICON_VIEW_CAPTIONS,
      text_attribute_names_changed_callback, view);
      eel_preferences_add_callback (NAUTILUS_PREFERENCES_SHOW_IMAGE_FILE_THUMBNAILS,
      image_display_policy_changed_callback, view);
      eel_preferences_add_callback (NAUTILUS_PREFERENCES_CLICK_POLICY,
      click_policy_changed_callback, view);
      eel_preferences_add_callback (NAUTILUS_PREFERENCES_SORT_DIRECTORIES_FIRST, 
      sort_directories_first_changed_callback, view);
      eel_preferences_add_callback (NAUTILUS_PREFERENCES_LOCKDOWN_COMMAND_LINE,
      lockdown_disable_command_line_changed_callback, view);*/

    /* Update undo actions stuff and connect signals from the undostack manager */
    /*view->details->undo_active = FALSE;
      view->details->redo_active = FALSE;
      view->details->undo_action_description = NULL;
      view->details->undo_action_label = NULL;
      view->details->redo_action_description = NULL;
      view->details->redo_action_label = NULL;

      NautilusUndoStackManager* manager = nautilus_undostack_manager_instance ();

      g_signal_connect_object (G_OBJECT(manager), "request-menu-update",
      G_CALLBACK(undo_redo_menu_update_callback), view, 0);

      nautilus_undostack_manager_request_menu_update (nautilus_undostack_manager_instance());*/


}

static void
fm_directory_view_destroy (GtkWidget *object)
{
    FMDirectoryView *view;
    //GList *node, *next;

    view = FM_DIRECTORY_VIEW (object);
    printf ("$$ %s\n", G_STRFUNC);

    //disconnect_model_handlers (view);

    //fm_directory_view_unmerge_menus (view);

    /* We don't own the window, so no unref */
    //view->details->window = NULL;

    /*fm_directory_view_stop (view);
      fm_directory_view_clear (view);*/

    /*remove_update_menus_timeout_callback (view);
      remove_update_status_idle_callback (view);*/

    EEL_CALL_PARENT (GTK_WIDGET_CLASS, destroy, (object));
}

static void
fm_directory_view_finalize (GObject *object)
{
    FMDirectoryView *view;

    view = FM_DIRECTORY_VIEW (object);
    printf ("$$ %s\n", G_STRFUNC);

    /*eel_preferences_remove_callback (NAUTILUS_PREFERENCES_CONFIRM_TRASH,
      schedule_update_menus_callback, view);
      eel_preferences_remove_callback (NAUTILUS_PREFERENCES_ENABLE_DELETE,
      schedule_update_menus_callback, view);
      eel_preferences_remove_callback (NAUTILUS_PREFERENCES_ICON_VIEW_CAPTIONS,
      text_attribute_names_changed_callback, view);
      eel_preferences_remove_callback (NAUTILUS_PREFERENCES_SHOW_IMAGE_FILE_THUMBNAILS,
      image_display_policy_changed_callback, view);
      eel_preferences_remove_callback (NAUTILUS_PREFERENCES_CLICK_POLICY,
      click_policy_changed_callback, view);
      eel_preferences_remove_callback (NAUTILUS_PREFERENCES_SORT_DIRECTORIES_FIRST,
      sort_directories_first_changed_callback, view);
      eel_preferences_remove_callback (NAUTILUS_PREFERENCES_LOCKDOWN_COMMAND_LINE,
      lockdown_disable_command_line_changed_callback, view);*/

    /*unschedule_pop_up_location_context_menu (view);
      if (view->details->location_popup_event != NULL) {
      gdk_event_free ((GdkEvent *) view->details->location_popup_event);
      }

      g_hash_table_destroy (view->details->non_ready_files);*/

    /*g_object_unref (view->details->slot);
      view->details->slot = NULL;*/

    g_free (view->details);

    EEL_CALL_PARENT (G_OBJECT_CLASS, finalize, (object));
}

void
fm_directory_view_column_add_location (FMDirectoryView *dview, GFile *location)
{
    //marlin_window_columns_set_active_slot(dview->details->slot);
    //marlin_window_columns_add(dview->details->slot->mwcols, location);
    gof_window_columns_add_location(dview->details->slot, location);
}

void
fm_directory_view_column_add_preview (FMDirectoryView *dview, GFile *location)
{
    gof_window_columns_add_preview(dview->details->slot, location);
}

void
fm_directory_view_set_active_slot (FMDirectoryView *dview)
{
    GOFWindowSlot *slot = dview->details->slot;
    //marlin_window_set_active_slot (MARLIN_WINDOW (slot->window), slot);
    /*marlin_view_window_set_active_slot (MARLIN_VIEW_WINDOW (slot->window), slot);
      g_signal_emit_by_name (slot->window, "column-path-changed", slot->location);*/

    printf ("!!!!!!!!!!! %s\n", G_STRFUNC);
}

void
fm_directory_view_load_location (FMDirectoryView *directory_view, GFile *location)
{
    //GOFDirectoryAsync *directory;

    /*if (eel_uri_is_search (location)) {
      directory_view->details->allow_moves = FALSE;
      } else {
      directory_view->details->allow_moves = TRUE;
      }*/

    //directory = gof_directory_async_new(location);
    /*if (FM_IS_COLUMNS_VIEW (directory_view))
      marlin_window_columns_change_location (directory_view->details->slot, location);
      else
      gof_window_slot_change_location (directory_view->details->slot, location);*/
    GOFWindowSlot *slot = directory_view->details->slot;

    g_signal_emit_by_name (slot->ctab, "path-changed", location);
}

static gboolean
fm_directory_view_handle_scroll_event (FMDirectoryView *directory_view,
                                       GdkEventScroll *event)
{
    if (event->state & GDK_CONTROL_MASK) {
        switch (event->direction) {
        case GDK_SCROLL_UP:
            /* Zoom In */
            //fm_directory_view_bump_zoom_level (directory_view, 1);
            printf ("TODO zoom in");
            return TRUE;

        case GDK_SCROLL_DOWN:
            /* Zoom Out */
            //fm_directory_view_bump_zoom_level (directory_view, -1);
            printf ("TODO zoom out");
            return TRUE;

        case GDK_SCROLL_LEFT:
        case GDK_SCROLL_RIGHT:
            break;

        default:
            g_assert_not_reached ();
        }
    }

    return FALSE;
}

/* handle Shift+Scroll, which will cause a zoom-in/out */
static gboolean
fm_directory_view_scroll_event (GtkWidget *widget,
                                GdkEventScroll *event)
{
    FMDirectoryView *directory_view;

    directory_view = FM_DIRECTORY_VIEW (widget);
    if (fm_directory_view_handle_scroll_event (directory_view, event)) {
        return TRUE;
    }

    return GTK_WIDGET_CLASS (parent_class)->scroll_event (widget, event);
}

static void
fm_directory_view_parent_set (GtkWidget *widget,
                              GtkWidget *old_parent)
{
    FMDirectoryView *view;
    GtkWidget *parent;

    view = FM_DIRECTORY_VIEW (widget);

    parent = gtk_widget_get_parent (widget);
    g_assert (parent == NULL || old_parent == NULL);

    if (GTK_WIDGET_CLASS (parent_class)->parent_set != NULL) {
        GTK_WIDGET_CLASS (parent_class)->parent_set (widget, old_parent);
    }

    if (parent != NULL) {
        g_assert (old_parent == NULL);

        /*if (view->details->slot == 
          nautilus_window_info_get_active_slot (view->details->window)) {
          view->details->active = TRUE;

          fm_directory_view_merge_menus (view);
          schedule_update_menus (view);
          }
          } else {
          fm_directory_view_unmerge_menus (view);
          remove_update_menus_timeout_callback (view);*/
    }
}

static void
fm_directory_view_set_property (GObject         *object,
                                guint            prop_id,
                                const GValue    *value,
                                GParamSpec      *pspec)
{
    FMDirectoryView *directory_view;
    GOFWindowSlot *slot;
    GtkWidget *window;

    directory_view = FM_DIRECTORY_VIEW (object);

    switch (prop_id)  {
    case PROP_WINDOW_SLOT:
        g_assert (directory_view->details->slot == NULL);

        slot = GOF_WINDOW_SLOT (g_value_get_object (value));
        window = marlin_view_view_container_get_window (MARLIN_VIEW_VIEW_CONTAINER(slot->ctab));

        directory_view->details->slot = slot;
        directory_view->details->window = window;

        g_signal_connect (slot->directory, "file_added", G_CALLBACK (file_added_callback), directory_view);

        /*g_signal_connect_object (directory_view->details->slot,
          "active", G_CALLBACK (slot_active),
          directory_view, 0);
          g_signal_connect_object (directory_view->details->slot,
          "inactive", G_CALLBACK (slot_inactive),
          directory_view, 0);

          g_signal_connect_object (directory_view->details->window,
          "hidden-files-mode-changed", G_CALLBACK (hidden_files_mode_changed),
          directory_view, 0);*/
        //fm_directory_view_init_show_hidden_files (directory_view);
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
        break;
    }
}

static void
fm_directory_view_class_init (FMDirectoryViewClass *klass)
{
    GtkWidgetClass *widget_class;
    GtkScrolledWindowClass *scrolled_window_class;
    GtkBindingSet *binding_set;

    widget_class = GTK_WIDGET_CLASS (klass);
    scrolled_window_class = GTK_SCROLLED_WINDOW_CLASS (klass);

    G_OBJECT_CLASS (klass)->finalize = fm_directory_view_finalize;
    G_OBJECT_CLASS (klass)->set_property = fm_directory_view_set_property;

    widget_class->destroy = fm_directory_view_destroy;
    widget_class->scroll_event = fm_directory_view_scroll_event;
    widget_class->parent_set = fm_directory_view_parent_set;

    /* Get rid of the strange 3-pixel gap that GtkScrolledWindow
     * uses by default. It does us no good.
     */
    scrolled_window_class->scrollbar_spacing = 0;

    signals[ADD_FILE] =
        g_signal_new ("add_file",
                      G_TYPE_FROM_CLASS (klass),
                      G_SIGNAL_RUN_LAST,
                      G_STRUCT_OFFSET (FMDirectoryViewClass, add_file),
                      NULL, NULL,
                      nautilus_marshal_VOID__OBJECT_OBJECT,
                      G_TYPE_NONE, 2, GOF_TYPE_FILE, GOF_TYPE_DIRECTORY_ASYNC);
    signals[COLORIZE_SELECTION] =
        g_signal_new ("colorize_selection",
                      G_TYPE_FROM_CLASS (klass),
                      G_SIGNAL_RUN_LAST,
                      G_STRUCT_OFFSET (FMDirectoryViewClass, colorize_selection),
                      NULL, NULL,
                      g_cclosure_marshal_VOID__INT,
                      G_TYPE_NONE, 1, G_TYPE_INT);
    signals[SYNC_SELECTION] =
        g_signal_new ("sync_selection",
                      G_TYPE_FROM_CLASS (klass),
                      G_SIGNAL_RUN_LAST,
                      G_STRUCT_OFFSET (FMDirectoryViewClass, sync_selection),
                      NULL, NULL,
                      g_cclosure_marshal_VOID__VOID,
                      G_TYPE_NONE, 0);

    /*signals[BEGIN_FILE_CHANGES] =
      g_signal_new ("begin_file_changes",
      G_TYPE_FROM_CLASS (klass),
      G_SIGNAL_RUN_LAST,
      G_STRUCT_OFFSET (FMDirectoryViewClass, begin_file_changes),
      NULL, NULL,
      g_cclosure_marshal_VOID__VOID,
      G_TYPE_NONE, 0);
      signals[BEGIN_LOADING] =
      g_signal_new ("begin_loading",
      G_TYPE_FROM_CLASS (klass),
      G_SIGNAL_RUN_LAST,
      G_STRUCT_OFFSET (FMDirectoryViewClass, begin_loading),
      NULL, NULL,
      g_cclosure_marshal_VOID__VOID,
      G_TYPE_NONE, 0);*/
    /*	signals[CLEAR] =
        g_signal_new ("clear",
        G_TYPE_FROM_CLASS (klass),
        G_SIGNAL_RUN_LAST,
        G_STRUCT_OFFSET (FMDirectoryViewClass, clear),
        NULL, NULL,
        g_cclosure_marshal_VOID__VOID,
        G_TYPE_NONE, 0);*/
    /*signals[END_FILE_CHANGES] =
      g_signal_new ("end_file_changes",
      G_TYPE_FROM_CLASS (klass),
      G_SIGNAL_RUN_LAST,
      G_STRUCT_OFFSET (FMDirectoryViewClass, end_file_changes),
      NULL, NULL,
      g_cclosure_marshal_VOID__VOID,
      G_TYPE_NONE, 0);
      signals[FLUSH_ADDED_FILES] =
      g_signal_new ("flush_added_files",
      G_TYPE_FROM_CLASS (klass),
      G_SIGNAL_RUN_LAST,
      G_STRUCT_OFFSET (FMDirectoryViewClass, flush_added_files),
      NULL, NULL,
      g_cclosure_marshal_VOID__VOID,
      G_TYPE_NONE, 0);*/
#if 0
    signals[END_LOADING] =
        g_signal_new ("end_loading",
                      G_TYPE_FROM_CLASS (klass),
                      G_SIGNAL_RUN_LAST,
                      G_STRUCT_OFFSET (FMDirectoryViewClass, end_loading),
                      NULL, NULL,
                      g_cclosure_marshal_VOID__BOOLEAN,
                      G_TYPE_NONE, 1, G_TYPE_BOOLEAN);
    signals[FILE_CHANGED] =
        g_signal_new ("file_changed",
                      G_TYPE_FROM_CLASS (klass),
                      G_SIGNAL_RUN_LAST,
                      G_STRUCT_OFFSET (FMDirectoryViewClass, file_changed),
                      NULL, NULL,
                      nautilus_marshal_VOID__OBJECT_OBJECT,
                      G_TYPE_NONE, 2, GOF_TYPE_FILE, GOF_TYPE_DIRECTORY_ASYNC);
    signals[LOAD_ERROR] =
        g_signal_new ("load_error",
                      G_TYPE_FROM_CLASS (klass),
                      G_SIGNAL_RUN_LAST,
                      G_STRUCT_OFFSET (FMDirectoryViewClass, load_error),
                      NULL, NULL,
                      g_cclosure_marshal_VOID__POINTER,
                      G_TYPE_NONE, 1, G_TYPE_POINTER);
    signals[REMOVE_FILE] =
        g_signal_new ("remove_file",
                      G_TYPE_FROM_CLASS (klass),
                      G_SIGNAL_RUN_LAST,
                      G_STRUCT_OFFSET (FMDirectoryViewClass, remove_file),
                      NULL, NULL,
                      nautilus_marshal_VOID__OBJECT_OBJECT,
                      G_TYPE_NONE, 2, GOF_TYPE_FILE, GOF_TYPE_DIRECTORY_ASYNC);
#endif
    //klass->accepts_dragged_files = real_accepts_dragged_files;
    //klass->file_limit_reached = real_file_limit_reached;
    //klass->file_still_belongs = real_file_still_belongs;
    //klass->get_emblem_names_to_exclude = real_get_emblem_names_to_exclude;
    /*klass->get_selected_icon_locations = real_get_selected_icon_locations;
      klass->is_read_only = real_is_read_only;
      klass->load_error = real_load_error;
      klass->can_rename_file = can_rename_file;
      klass->start_renaming_file = start_renaming_file;
      klass->supports_creating_files = real_supports_creating_files;
      klass->supports_properties = real_supports_properties;
      klass->supports_zooming = real_supports_zooming;
      klass->using_manual_layout = real_using_manual_layout;
      klass->merge_menus = real_merge_menus;
      klass->unmerge_menus = real_unmerge_menus;
      klass->update_menus = real_update_menus;
      klass->set_is_active = real_set_is_active;*/

    /* Function pointers that subclasses must override */
    EEL_ASSIGN_MUST_OVERRIDE_SIGNAL (klass, fm_directory_view, add_file);
    /*EEL_ASSIGN_MUST_OVERRIDE_SIGNAL (klass, fm_directory_view, bump_zoom_level);
      EEL_ASSIGN_MUST_OVERRIDE_SIGNAL (klass, fm_directory_view, can_zoom_in);
      EEL_ASSIGN_MUST_OVERRIDE_SIGNAL (klass, fm_directory_view, can_zoom_out);
      EEL_ASSIGN_MUST_OVERRIDE_SIGNAL (klass, fm_directory_view, clear);
      EEL_ASSIGN_MUST_OVERRIDE_SIGNAL (klass, fm_directory_view, file_changed);
      EEL_ASSIGN_MUST_OVERRIDE_SIGNAL (klass, fm_directory_view, get_background_widget);
      EEL_ASSIGN_MUST_OVERRIDE_SIGNAL (klass, fm_directory_view, get_selection);
      EEL_ASSIGN_MUST_OVERRIDE_SIGNAL (klass, fm_directory_view, get_selection_for_file_transfer);
      EEL_ASSIGN_MUST_OVERRIDE_SIGNAL (klass, fm_directory_view, get_item_count);
      EEL_ASSIGN_MUST_OVERRIDE_SIGNAL (klass, fm_directory_view, is_empty);
      EEL_ASSIGN_MUST_OVERRIDE_SIGNAL (klass, fm_directory_view, reset_to_defaults);
      EEL_ASSIGN_MUST_OVERRIDE_SIGNAL (klass, fm_directory_view, restore_default_zoom_level);
      EEL_ASSIGN_MUST_OVERRIDE_SIGNAL (klass, fm_directory_view, select_all);
      EEL_ASSIGN_MUST_OVERRIDE_SIGNAL (klass, fm_directory_view, set_selection);
      EEL_ASSIGN_MUST_OVERRIDE_SIGNAL (klass, fm_directory_view, invert_selection);
      EEL_ASSIGN_MUST_OVERRIDE_SIGNAL (klass, fm_directory_view, zoom_to_level);
      EEL_ASSIGN_MUST_OVERRIDE_SIGNAL (klass, fm_directory_view, get_zoom_level);*/

    //copied_files_atom = gdk_atom_intern ("x-special/gnome-copied-files", FALSE);

    g_object_class_install_property (G_OBJECT_CLASS (klass),
                                     PROP_WINDOW_SLOT,
                                     g_param_spec_object ("window-slot",
                                                          "Window Slot",
                                                          "The parent window slot reference",
                                                          GOF_TYPE_WINDOW_SLOT,
                                                          G_PARAM_WRITABLE |
                                                          G_PARAM_CONSTRUCT_ONLY));

    /*signals[TRASH] =
      g_signal_new ("trash",
      G_TYPE_FROM_CLASS (klass),
      G_SIGNAL_RUN_LAST | G_SIGNAL_ACTION,
      G_STRUCT_OFFSET (FMDirectoryViewClass, trash),
      g_signal_accumulator_true_handled, NULL,
      eel_marshal_BOOLEAN__VOID,
      G_TYPE_BOOLEAN, 0);
      signals[DELETE] =
      g_signal_new ("delete",
      G_TYPE_FROM_CLASS (klass),
      G_SIGNAL_RUN_LAST | G_SIGNAL_ACTION,
      G_STRUCT_OFFSET (FMDirectoryViewClass, delete),
      g_signal_accumulator_true_handled, NULL,
      eel_marshal_BOOLEAN__VOID,
      G_TYPE_BOOLEAN, 0);*/

    binding_set = gtk_binding_set_by_class (klass);
    gtk_binding_entry_add_signal (binding_set, GDK_KEY_Delete, 0,
                                  "trash", 0);
    gtk_binding_entry_add_signal (binding_set, GDK_KEY_KP_Delete, 0,
                                  "trash", 0);
    gtk_binding_entry_add_signal (binding_set, GDK_KEY_KP_Delete, GDK_SHIFT_MASK,
                                  "delete", 0);

    //klass->trash = real_trash;
    //klass->delete = real_delete;
}

void
fm_directory_view_notify_selection_changed (FMDirectoryView *view, GOFFile *file)
{
    g_signal_emit_by_name (MARLIN_VIEW_WINDOW (view->details->window), "selection_changed", file);
}
