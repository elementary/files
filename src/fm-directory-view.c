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
#include "marlin-file-operations.h"
//#include "fm-list-view.h"
#include "eel-gtk-macros.h"
#include "marlin-marshal.h"
#include "fm-columns-view.h"
#include "marlin-dnd.h"
#include "marlin-file-utilities.h"
#include "marlin-vala.h"
#include "eel-ui.h"
#include "eel-gio-extensions.h"
#include "eel-gtk-extensions.h"

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
    gboolean active;

    /* loading indicates whether this view has begun loading a directory.
     * This flag should need not be set inside subclasses. FMDirectoryView automatically
     * sets 'loading' to TRUE before it begins loading a directory's contents and to FALSE
     * after it finishes loading the directory and its view.
     */
    gboolean loading;

    /* flag to indicate that no file updates should be dispatched to subclasses.
     * This is a workaround for bug #87701 that prevents the list view from
     * losing focus when the underlying GtkTreeView is updated.
     */
    //gboolean show_hidden_files;

    GtkActionGroup *dir_action_group;
    guint dir_merge_id;

    /*gchar* undo_action_description;
      gchar* undo_action_label;
      gchar* redo_action_description;
      gchar* redo_action_label;*/

    /* right-click drag/popup support */
    GList           *drag_file_list;
    gint            drag_scroll_timer_id;
    gint            drag_timer_id;
    gint            drag_x;
    gint            drag_y;

    /* drop site support */
    guint           drop_data_ready : 1; /* whether the drop data was received already */
    guint           drop_highlight : 1;
    guint           drop_occurred : 1;   /* whether the data was dropped */
    GList           *drop_file_list;     /* the list of URIs that are contained in the drop data */

    GdkDragContext  *drag_context;

    gboolean        selection_was_removed;

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
//static void     fm_directory_view_merge_menus   (FMDirectoryView      *view);
//static void     fm_directory_view_unmerge_menus (FMDirectoryView      *view);
static void     real_merge_menus (FMDirectoryView *view);
static void     real_unmerge_menus (FMDirectoryView *view);
static void     fm_directory_view_grab_focus (GtkWidget *widget);

static gboolean fm_directory_view_button_press_event (GtkWidget         *widget,
                                                      GdkEventButton    *event,
                                                      FMDirectoryView   *view);
static gboolean fm_directory_view_drag_drop (GtkWidget          *widget,
                                             GdkDragContext     *context,
                                             gint                x,
                                             gint                y,
                                             guint               timestamp,
                                             FMDirectoryView    *view);
static void     fm_directory_view_drag_data_received (GtkWidget          *widget,
                                                      GdkDragContext     *context,
                                                      gint                x,
                                                      gint                y,
                                                      GtkSelectionData   *selection_data,
                                                      guint               info,
                                                      guint               timestamp,
                                                      FMDirectoryView *view);
static void     fm_directory_view_drag_leave (GtkWidget          *widget,
                                              GdkDragContext     *context,
                                              guint               timestamp,
                                              FMDirectoryView *view);
static gboolean fm_directory_view_drag_motion (GtkWidget          *widget,
                                               GdkDragContext     *context,
                                               gint                x,
                                               gint                y,
                                               guint               timestamp,
                                               FMDirectoryView *view);
static void     fm_directory_view_drag_begin (GtkWidget           *widget,
                                              GdkDragContext      *context,
                                              FMDirectoryView     *view);
static void     fm_directory_view_drag_data_get (GtkWidget          *widget,
                                                 GdkDragContext     *context,
                                                 GtkSelectionData   *selection_data,
                                                 guint               info,
                                                 guint               timestamp,
                                                 FMDirectoryView    *view);
static void     fm_directory_view_drag_data_delete (GtkWidget       *widget,
                                                    GdkDragContext  *context,
                                                    FMDirectoryView *view);
static void     fm_directory_view_drag_end (GtkWidget       *widget,
                                            GdkDragContext  *context,
                                            FMDirectoryView *view);

static void     update_menus_selection (FMDirectoryView *view);

EEL_CLASS_BOILERPLATE (FMDirectoryView, fm_directory_view, GTK_TYPE_SCROLLED_WINDOW)

    /*EEL_IMPLEMENT_MUST_OVERRIDE_SIGNAL (fm_directory_view, add_file)
      EEL_IMPLEMENT_MUST_OVERRIDE_SIGNAL (fm_directory_view, bump_zoom_level)
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

/* Identifiers for DnD target types */
enum
{
    TARGET_TEXT_URI_LIST,
    TARGET_XDND_DIRECT_SAVE0,
    TARGET_NETSCAPE_URL,
};

/* Target types for dragging from the view */
static const GtkTargetEntry drag_targets[] =
{
    { "text/uri-list", 0, TARGET_TEXT_URI_LIST, },
};

/* Target types for dropping to the view */
static const GtkTargetEntry drop_targets[] =
{
    { "text/uri-list", 0, TARGET_TEXT_URI_LIST, },
    { "XdndDirectSave0", 0, TARGET_XDND_DIRECT_SAVE0, },
    { "_NETSCAPE_URL", 0, TARGET_NETSCAPE_URL, },
};


#if 0
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
static void *
load_file_from_file_hash_cb (gpointer key, gpointer value, gpointer user_data)
{
    FMDirectoryView *view = FM_DIRECTORY_VIEW (user_data);

    g_signal_emit (view, signals[ADD_FILE], 0, g_object_ref (value), view->details->slot->directory);
}
#endif

void
fm_directory_view_load_file_hash (GOFDirectoryAsync *dir, FMDirectoryView *view)
{
    /* TODO this should be threaded */
    //g_hash_table_foreach (dir->file_hash, (GHFunc) load_file_from_file_hash_cb, view);
    GHashTableIter iter;
    GFile *location;
    GOFFile *file;

    g_hash_table_iter_init (&iter, dir->file_hash);
    while (g_hash_table_iter_next (&iter, (gpointer) &location, (gpointer) &file)) {
        g_signal_emit (view, signals[ADD_FILE], 0, file, dir);
    }
}

#if 0
static gboolean
file_load_icon (GOFFile *file)
{
    /* TODO manage differents sizes depending on the view */
    printf ("%s\n", G_STRFUNC);
    gof_file_update_icon (file, 16);
    return FALSE;
}
#endif
//TODO

static void
file_loaded_callback (GOFDirectoryAsync *directory, GOFFile *file, FMDirectoryView *view)
{
    printf ("%s %s\n", G_STRFUNC, g_file_get_uri(file->location));
    gof_file_update_icon (file, 16);
    g_signal_emit (view, signals[ADD_FILE], 0, file, directory); 
    //g_idle_add ((GSourceFunc) file_load_icon, file);
}

static void
file_added_callback (GOFDirectoryAsync *directory, GOFFile *file, FMDirectoryView *view)
{
    printf ("%s %s\n", G_STRFUNC, g_file_get_uri(file->location));
    gof_file_update_icon (file, 16);
    g_signal_emit (view, signals[ADD_FILE], 0, file, directory);
    //g_idle_add ((GSourceFunc) file_load_icon, file);
}

static void
file_deleted_callback (GOFDirectoryAsync *directory, GOFFile *file, FMDirectoryView *view)
{
    printf ("%s %s\n", G_STRFUNC, g_file_get_uri(file->location));
    g_signal_emit (view, signals[REMOVE_FILE], 0, file, directory);
}

static void
directory_done_loading_callback (GOFDirectoryAsync *directory, FMDirectoryView *view)
{
    /* add the file_hash files for view which have been created during the directory loading */
    if (view->details->loading) {
        printf(">> %s load the cached files\n", G_STRFUNC);
        fm_directory_view_load_file_hash (directory, view);
    }
    view->details->loading = FALSE;
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

    if (!(directory->loading && directory->loaded))
        g_signal_connect (directory, "file_loaded", G_CALLBACK (file_loaded_callback), view);
    g_signal_connect (directory, "file_added", G_CALLBACK (file_added_callback), view);

    load_dir_async (directory);
    if (!directory->loading && directory->loaded)
        fm_directory_view_load_file_hash (directory, view);

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
                                          G_CALLBACK (file_loaded_callback),
                                          view);
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
    //
    if (!setup_autos) {
        setup_autos = TRUE;
        /*eel_preferences_add_auto_boolean (NAUTILUS_PREFERENCES_CONFIRM_TRASH,
          &confirm_trash_auto_value);
          eel_preferences_add_auto_boolean (NAUTILUS_PREFERENCES_ENABLE_DELETE,
          &show_delete_command_auto_value);*/
    }

    view->model = g_object_new (FM_TYPE_LIST_MODEL, NULL);

    view->details = g_new0 (FMDirectoryViewDetails, 1);
    view->details->drag_scroll_timer_id = -1;
    view->details->drag_timer_id = -1;
    
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

static GObject*
fm_directory_view_constructor (GType                  type,
                               guint                  n_construct_properties,
                               GObjectConstructParam *construct_properties)
{
    FMDirectoryView     *view;
    //ThunarZoomLevel     zoom_level;
    //ThunarColumn        sort_column;
    //GtkSortType         sort_order;
    GtkWidget           *widget;
    GObject             *object;

    /* let the GObject constructor create the instance */
    object = G_OBJECT_CLASS (parent_class)->constructor (type,
                                                         n_construct_properties,
                                                         construct_properties);

    /* cast to view for convenience */
    view = FM_DIRECTORY_VIEW (object);

    /* setup the default zoom-level, determined from the "last-<widget>-zoom-level" preference */
    /*g_object_get (G_OBJECT (view->preferences), THUNAR_view_GET_CLASS (standard_view)->zoom_level_property_name, &zoom_level, NULL);
      thunar_widget_set_zoom_level (THUNAR_VIEW (view), zoom_level);*/

    /* save the "zoom-level" as "last-<widget>-zoom-level" whenever the user changes the zoom level */
    //exo_binding_new (object, "zoom-level", G_OBJECT (view->preferences), THUNAR_view_GET_CLASS (standard_view)->zoom_level_property_name);

    /* determine the real widget widget (treeview or iconview) */
    widget = gtk_bin_get_child (GTK_BIN (object));

    /* apply our list model to the real widget (the child of the scrolled window),
     * we therefore assume that all real widgets have the "model" property.
     */
    //g_object_set (G_OBJECT (widget), "model", view->model, NULL);

    /* apply the single-click settings to the widget */
    /*exo_binding_new (G_OBJECT (view->preferences), "misc-single-click", G_OBJECT (view), "single-click");
      exo_binding_new (G_OBJECT (view->preferences), "misc-single-click-timeout", G_OBJECT (view), "single-click-timeout");*/

    /* apply the default sort column and sort order */
    /*g_object_get (G_OBJECT (view->preferences), "last-sort-column", &sort_column, "last-sort-order", &sort_order, NULL);
      gtk_tree_sortable_set_sort_column_id (GTK_TREE_SORTABLE (view->model), sort_column, sort_order);*/

    /* stay informed about changes to the sort column/order */
    //g_signal_connect (G_OBJECT (view->model), "sort-column-changed", G_CALLBACK (thunar_view_sort_column_changed), standard_view);

    /* setup support to navigate using a horizontal mouse wheel and the back and forward buttons */
    /*g_signal_connect (G_OBJECT (widget), "scroll-event", G_CALLBACK (thunar_view_scroll_event), object);*/
    g_signal_connect (G_OBJECT (widget), "button-press-event", G_CALLBACK (fm_directory_view_button_press_event), object);

    /* need to catch certain keys for the internal widget widget */
    //g_signal_connect (G_OBJECT (widget), "key-press-event", G_CALLBACK (thunar_view_key_press_event), object);

    /* setup the real widget as drop site */
    gtk_drag_dest_set (widget, 0, drop_targets, G_N_ELEMENTS (drop_targets), GDK_ACTION_ASK | GDK_ACTION_COPY | GDK_ACTION_LINK | GDK_ACTION_MOVE);
    g_signal_connect (G_OBJECT (widget), "drag-drop", G_CALLBACK (fm_directory_view_drag_drop), object);
    g_signal_connect (G_OBJECT (widget), "drag-data-received", G_CALLBACK (fm_directory_view_drag_data_received), object);
    g_signal_connect (G_OBJECT (widget), "drag-leave", G_CALLBACK (fm_directory_view_drag_leave), object);
    g_signal_connect (G_OBJECT (widget), "drag-motion", G_CALLBACK (fm_directory_view_drag_motion), object);

    /* setup the real widget as drag source */
    gtk_drag_source_set (widget, GDK_BUTTON1_MASK, drag_targets, G_N_ELEMENTS (drag_targets), GDK_ACTION_COPY | GDK_ACTION_MOVE | GDK_ACTION_LINK);
    g_signal_connect (G_OBJECT (widget), "drag-begin", G_CALLBACK (fm_directory_view_drag_begin), object);
    g_signal_connect (G_OBJECT (widget), "drag-data-get", G_CALLBACK (fm_directory_view_drag_data_get), object);
    g_signal_connect (G_OBJECT (widget), "drag-data-delete", G_CALLBACK (fm_directory_view_drag_data_delete), object);
    g_signal_connect (G_OBJECT (widget), "drag-end", G_CALLBACK (fm_directory_view_drag_end), object);

    /* done, we have a working object */
    return object;
}


static void
fm_directory_view_destroy (GtkWidget *object)
{
    FMDirectoryView *view;
    //GList *node, *next;

    view = FM_DIRECTORY_VIEW (object);
    log_printf (LOG_LEVEL_UNDEFINED, "$$ %s\n", G_STRFUNC);

    //disconnect_model_handlers (view);

    fm_directory_view_unmerge_menus (view);

    /* We don't own the window, so no unref */
    view->details->window = NULL;

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
    log_printf (LOG_LEVEL_UNDEFINED, "$$ %s\n", G_STRFUNC);

    GOFWindowSlot *slot = view->details->slot;

    //printf ("%s %s\n", G_STRFUNC, g_file_get_uri(slot->directory->location));
    /* disconnect all listeners */
    g_signal_handlers_disconnect_by_func (slot->directory, file_loaded_callback, view);
    g_signal_handlers_disconnect_by_func (slot->directory, file_added_callback, view);
    //g_signal_handlers_disconnect_by_func (slot->directory, "file_changed", G_CALLBACK (file_changed_callback), directory_view);
    g_signal_handlers_disconnect_by_func (slot->directory, file_deleted_callback, view);
    g_signal_handlers_disconnect_by_func (slot->directory, directory_done_loading_callback, view);
    g_object_unref (slot);

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

    /*if (slot != NULL)
        g_object_unref (slot);*/
   
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
fm_directory_view_column_add_preview (FMDirectoryView *dview, GOFFile *file)
{
    MarlinViewContextView *contextview = marlin_view_context_view_new (MARLIN_VIEW_WINDOW (dview->details->window), FALSE);
    marlin_view_context_view_update (contextview, file);
    /* resize context view to match the default columns size 180+2 border px */
    gtk_widget_set_size_request (GTK_WIDGET (contextview), 182, -1);
    gof_window_columns_add_preview(dview->details->slot, GTK_WIDGET (contextview));
}

#if 0
void
fm_directory_view_set_active_slot (FMDirectoryView *dview)
{
    /* TODO check and remove this dead function */

    GOFWindowSlot *slot = dview->details->slot;
    //marlin_window_set_active_slot (MARLIN_WINDOW (slot->window), slot);
    /*marlin_view_window_set_active_slot (MARLIN_VIEW_WINDOW (slot->window), slot);
      g_signal_emit_by_name (slot->window, "column-path-changed", slot->location);*/

    log_printf (LOG_LEVEL_UNDEFINED, "!!!!!!!!!!! %s\n", G_STRFUNC);
}
#endif

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

void
fm_directory_view_activate_single_file (FMDirectoryView *view, GOFFile *file, GdkScreen *screen)
{
    log_printf (LOG_LEVEL_UNDEFINED, "%s\n", G_STRFUNC);
    if (file->is_directory) {
        fm_directory_view_load_location (view, file->location);
    } else {
        //gof_gnome_open_single_file (file, screen); 
        gof_file_open_single (file, screen); 
    }
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
            log_printf (LOG_LEVEL_UNDEFINED, "TODO zoom in");
            return TRUE;

        case GDK_SCROLL_DOWN:
            /* Zoom Out */
            //fm_directory_view_bump_zoom_level (directory_view, -1);
            log_printf (LOG_LEVEL_UNDEFINED, "TODO zoom out");
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

static gboolean
fm_directory_view_button_press_event (GtkWidget         *widget,
                                      GdkEventButton    *event,
                                      FMDirectoryView   *view)
{
    GtkActionGroup *main_actions;
    GtkAction *action = NULL;

    main_actions = MARLIN_VIEW_WINDOW (view->details->window)->main_actions;
    if (G_LIKELY (event->type == GDK_BUTTON_PRESS))
    {
        /* Extra mouse button action: button8 = "Back" button9 = "Forward" */
        if (G_UNLIKELY (event->button == 8))
            action = gtk_action_group_get_action (main_actions, "Back");
        else if (G_UNLIKELY (event->button == 9))
            action = gtk_action_group_get_action (main_actions, "Forward");

        if (G_UNLIKELY (action != NULL))
        {
            gtk_action_activate (action);
            return TRUE;
        }
    }

    return FALSE;
}

static gboolean
fm_directory_view_drag_scroll_timer (gpointer user_data)
{
    FMDirectoryView   *view = FM_DIRECTORY_VIEW (user_data);
    GtkAdjustment     *adjustment;
    gfloat            value;
    gint              offset;
    gint              y, x;
    gint              w, h;

    GDK_THREADS_ENTER ();

    /* verify that we are realized */
    if (G_LIKELY (gtk_widget_get_realized (GTK_WIDGET (view))))
    {
        /* determine pointer location and window geometry */
        GtkWidget *widget = gtk_bin_get_child (GTK_BIN (view));
        GdkDevice *pointer = gdk_drag_context_get_device (view->details->drag_context);
        GdkWindow *window = gtk_widget_get_window (widget);

        gdk_window_get_device_position ( window, pointer, &x, &y, NULL);
        gdk_window_get_geometry (window, NULL, NULL, &w, &h);

        /* check if we are near the edge (vertical) */
        offset = y - (2 * 20);
        if (G_UNLIKELY (offset > 0))
            offset = MAX (y - (h - 2 * 20), 0);

        /* change the vertical adjustment appropriately */
        if (G_UNLIKELY (offset != 0))
        {
            /* determine the vertical adjustment */
            adjustment = gtk_scrolled_window_get_vadjustment (GTK_SCROLLED_WINDOW (view));

            /* determine the new value */
            value = CLAMP (gtk_adjustment_get_value (adjustment) + 2 * offset, gtk_adjustment_get_lower (adjustment), gtk_adjustment_get_upper (adjustment) - gtk_adjustment_get_page_size (adjustment));

            /* apply the new value */
            gtk_adjustment_set_value (adjustment, value);
        }

        /* check if we are near the edge (horizontal) */
        offset = x - (2 * 20);
        if (G_UNLIKELY (offset > 0))
            offset = MAX (x - (w - 2 * 20), 0);

        /* change the horizontal adjustment appropriately */
        if (G_UNLIKELY (offset != 0))
        {
            /* determine the vertical adjustment */
            adjustment = gtk_scrolled_window_get_hadjustment (GTK_SCROLLED_WINDOW (view));

            /* determine the new value */
            value = CLAMP (gtk_adjustment_get_value (adjustment) + 2 * offset, gtk_adjustment_get_lower (adjustment), gtk_adjustment_get_upper (adjustment) - gtk_adjustment_get_page_size (adjustment));

            /* apply the new value */
            gtk_adjustment_set_value (adjustment, value);
        }
    }
    GDK_THREADS_LEAVE ();

    return TRUE;
}

static void
fm_directory_view_drag_scroll_timer_destroy (gpointer user_data)
{
    FM_DIRECTORY_VIEW (user_data)->details->drag_scroll_timer_id = -1;
}



static GOFFile*
fm_directory_view_get_drop_file (FMDirectoryView *view,
                                 gint                x,
                                 gint                y,
                                 GtkTreePath       **path_return)
{
    GtkTreePath *path = NULL;
    //GtkTreeIter iter;
    GOFFile *file = NULL;

    /* determine the path for the given coordinates */
    path = (*FM_DIRECTORY_VIEW_GET_CLASS (view)->get_path_at_pos) (view, x, y);

    if (G_LIKELY (path != NULL))
    {
        printf ("%s path %s\n", G_STRFUNC, gtk_tree_path_to_string (path));
        /* determine the file for the path */
        file = fm_list_model_file_for_path (view->model, path);
        printf ("%s %s\n", G_STRFUNC, g_file_get_uri (file->location));

        /* we can only drop to directories and executable files */
        if (!file->is_directory && !gof_file_is_executable (file))
        {
            /* drop to the folder instead */
            g_object_unref (G_OBJECT (file));
            gtk_tree_path_free (path);
            path = NULL;
        }
    }

    /* if we don't have a path yet, we'll drop to the folder instead */
    if (G_UNLIKELY (path == NULL))
    {
        /* determine the current directory */
        //file = thunar_navigator_get_current_directory (THUNAR_NAVIGATOR (view));
        //FIXME after the GOFFile reshape
        file = gof_file_get (view->details->slot->location);
        if (G_LIKELY (file != NULL))
            g_object_ref (G_OBJECT (file));
    }

    /* return the path (if any) */
    if (G_LIKELY (path_return != NULL))
        *path_return = path;
    else if (G_LIKELY (path != NULL))
        gtk_tree_path_free (path);

    return file;
}

static GdkDragAction
fm_directory_view_get_dest_actions (FMDirectoryView     *view,
                                    GdkDragContext      *context,
                                    gint                x,
                                    gint                y,
                                    guint               timestamp,
                                    GOFFile             **file_return)
{
    GdkDragAction actions = 0;
    GdkDragAction action = 0;
    GtkTreePath  *path;
    GOFFile   *file;

    /* determine the file and path for the given coordinates */
    file = fm_directory_view_get_drop_file (view, x, y, &path);
    printf ("%s %s\n", G_STRFUNC, g_file_get_uri (file->location));

    /* check if we can drop there */
    if (G_LIKELY (file != NULL))
    {
        /* determine the possible drop actions for the file (and the suggested action if any) */
        actions = gof_file_accepts_drop (file, view->details->drop_file_list, context, &action);
        if (G_LIKELY (actions != 0))
        {
            /* tell the caller about the file (if it's interested) */
            if (G_UNLIKELY (file_return != NULL))
                *file_return = g_object_ref (G_OBJECT (file));
        }
    }

    /* reset path if we cannot drop */
    if (G_UNLIKELY (action == 0 && path != NULL))
    {
        gtk_tree_path_free (path);
        path = NULL;
    }

    /* setup the drop-file for the icon renderer, so the user
     * gets good visual feedback for the drop target.
     */
    //g_object_set (G_OBJECT (view->icon_renderer), "drop-file", (action != 0) ? file : NULL, NULL);

    /* do the view highlighting */
    if (view->details->drop_highlight != (path == NULL && action != 0))
    {
        view->details->drop_highlight = (path == NULL && action != 0);
        gtk_widget_queue_draw (GTK_WIDGET (view));
    }

    /* do the item highlighting */
    (*FM_DIRECTORY_VIEW_GET_CLASS (view)->highlight_path) (view, path);

    /* tell Gdk whether we can drop here */
    gdk_drag_status (context, action, timestamp);

    /* clean up */
    if (G_LIKELY (file != NULL))
        g_object_unref (G_OBJECT (file));
    if (G_LIKELY (path != NULL))
        gtk_tree_path_free (path);

    return actions;
}

static gboolean
fm_directory_view_drag_drop (GtkWidget          *widget,
                             GdkDragContext     *context,
                             gint                x,
                             gint                y,
                             guint               timestamp,
                             FMDirectoryView    *view)
{
    GOFFile     *file = NULL;
    GdkAtom     target;
    guchar      *prop_text;
    GFile       *path;
    gchar       *uri = NULL;
    gint        prop_len;

    printf ("%s\n", G_STRFUNC);
    target = gtk_drag_dest_find_target (widget, context, NULL);
    if (G_UNLIKELY (target == GDK_NONE))
    {
        /* we cannot handle the drag data */
        return FALSE;
    }
    else if (G_UNLIKELY (target == gdk_atom_intern_static_string ("XdndDirectSave0")))
    {
        printf ("%s XdndDirectSave0\n", G_STRFUNC);
#if 0
        /* determine the file for the drop position */
        file = fm_directory_view_get_drop_file (view, x, y, NULL);
        if (G_LIKELY (file != NULL))
        {
            /* determine the file name from the DnD source window */
            if (gdk_property_get (context->source_window, gdk_atom_intern_static_string ("XdndDirectSave0"),
                                  gdk_atom_intern_static_string ("text/plain"), 0, 1024, FALSE, NULL, NULL,
                                  &prop_len, &prop_text) && prop_text != NULL)
            {
                /* zero-terminate the string */
                prop_text = g_realloc (prop_text, prop_len + 1);
                prop_text[prop_len] = '\0';

                /* verify that the file name provided by the source is valid */
                if (G_LIKELY (*prop_text != '\0' && strchr ((const gchar *) prop_text, G_DIR_SEPARATOR) == NULL))
                {
                    /* allocate the relative path for the target */
                    path = g_file_resolve_relative_path (thunar_file_get_file (file), 
                                                         (const gchar *)prop_text);

                    /* determine the new URI */
                    uri = g_file_get_uri (path);

                    /* setup the property */
                    gdk_property_change (GDK_DRAWABLE (context->source_window),
                                         gdk_atom_intern_static_string ("XdndDirectSave0"),
                                         gdk_atom_intern_static_string ("text/plain"), 8,
                                         GDK_PROP_MODE_REPLACE, (const guchar *) uri,
                                         strlen (uri));

                    /* cleanup */
                    g_object_unref (path);
                    g_free (uri);
                }
                else
                {
                    /* tell the user that the file name provided by the X Direct Save source is invalid */
                    thunar_dialogs_show_error (GTK_WIDGET (view), NULL, _("Invalid filename provided by XDS drag site"));
                }

                /* cleanup */
                g_free (prop_text);
            }

            /* release the file reference */
            g_object_unref (G_OBJECT (file));
        }
#endif
        /* if uri == NULL, we didn't set the property */
        if (G_UNLIKELY (uri == NULL))
            return FALSE;
    }

    /* set state so the drag-data-received knows that
     * this is really a drop this time.
     */
    view->details->drop_occurred = TRUE;

    /* request the drag data from the source (initiates
     * saving in case of XdndDirectSave).
     */
    gtk_drag_get_data (widget, context, target, timestamp);

    /* we'll call gtk_drag_finish() later */
    return TRUE;
}

static void
fm_directory_view_drag_data_received (GtkWidget          *widget,
                                      GdkDragContext     *context,
                                      gint                x,
                                      gint                y,
                                      GtkSelectionData   *selection_data,
                                      guint               info,
                                      guint               timestamp,
                                      FMDirectoryView *view)
{
    GdkDragAction actions;
    GdkDragAction action;
    //ThunarFolder *folder;
    GOFFile     *file = NULL;
    GtkWidget   *toplevel;
    gboolean    succeed = FALSE;
    GError      *error = NULL;
    gchar       *working_directory;
    gchar       *argv[11];
    gchar       **bits;
    gint        pid;
    gint        n = 0;

    printf ("%s\n", G_STRFUNC);
    /* check if we don't already know the drop data */
    if (G_LIKELY (!view->details->drop_data_ready))
    {
        /* extract the URI list from the selection data (if valid) */
        if (info == TARGET_TEXT_URI_LIST && gtk_selection_data_get_format (selection_data) == 8 && gtk_selection_data_get_length (selection_data) > 0)
            view->details->drop_file_list = eel_g_file_list_new_from_string ((gchar *) gtk_selection_data_get_data (selection_data));

        /* reset the state */
        view->details->drop_data_ready = TRUE;
    }

    /* check if the data was dropped */
    if (G_UNLIKELY (view->details->drop_occurred))
    {
        /* reset the state */
        view->details->drop_occurred = FALSE;

        /* check if we're doing XdndDirectSave */
        if (G_UNLIKELY (info == TARGET_XDND_DIRECT_SAVE0))
        {
            printf ("%s TARGET_XDND_DIRECT_SAVE0\n", G_STRFUNC);
            /* we don't handle XdndDirectSave stage (3), result "F" yet */
            if (G_UNLIKELY (gtk_selection_data_get_format (selection_data) == 8 && gtk_selection_data_get_length (selection_data) == 1 && gtk_selection_data_get_data (selection_data)[0] == 'F'))
            {
                /* indicate that we don't provide "F" fallback */
                gdk_property_change (gdk_drag_context_get_source_window (context),
                                     gdk_atom_intern_static_string ("XdndDirectSave0"),
                                     gdk_atom_intern_static_string ("text/plain"), 8,
                                     GDK_PROP_MODE_REPLACE, (const guchar *) "", 0);
            }
            else if (G_LIKELY (gtk_selection_data_get_format (selection_data) == 8 && gtk_selection_data_get_length (selection_data) == 1 && gtk_selection_data_get_data (selection_data)[0] == 'S'))
            {
                /* XDS was successfull, so determine the file for the drop position */
                file = fm_directory_view_get_drop_file (view, x, y, NULL);
                if (G_LIKELY (file != NULL))
                {
                    /* verify that we have a directory here */
                    if (file->is_directory)
                    {
                        //TODO
                        /* reload the folder corresponding to the file */
                        /*folder = thunar_folder_get_for_file (file);
                          thunar_folder_reload (folder);
                          g_object_unref (G_OBJECT (folder));*/
                    }

                    /* cleanup */
                    g_object_unref (G_OBJECT (file));
                }
            }

            /* in either case, we succeed! */
            succeed = TRUE;
        }
        else if (G_UNLIKELY (info == TARGET_NETSCAPE_URL))
        {
            /* check if the format is valid and we have any data */
            if (G_LIKELY (gtk_selection_data_get_format (selection_data) == 8 && gtk_selection_data_get_length (selection_data) > 0))
            {
                /* _NETSCAPE_URL looks like this: "$URL\n$TITLE" */
                bits = g_strsplit ((const gchar *) gtk_selection_data_get_data (selection_data), "\n", -1);
                if (G_LIKELY (g_strv_length (bits) == 2))
                {
                    /* determine the file for the drop position */
                    file = fm_directory_view_get_drop_file (view, x, y, NULL);
                    if (G_LIKELY (file != NULL))
                    {
                        /* determine the absolute path to the target directory */
                        //working_directory = g_file_get_uri (thunar_file_get_file (file));
                        working_directory = g_file_get_uri (file->location);
                        printf ("%s TARGET_NETSCAPE_URL %s\n", G_STRFUNC, working_directory);

                        g_free (working_directory);
                        //TODO
#if 0
                        /* prepare the basic part of the command */
                        argv[n++] = "exo-desktop-item-edit";
                        argv[n++] = "--type=Link";
                        argv[n++] = "--url";
                        argv[n++] = bits[0];
                        argv[n++] = "--name";
                        argv[n++] = bits[1];

                        /* determine the toplevel window */
                        toplevel = gtk_widget_get_toplevel (widget);
                        if (toplevel != NULL && GTK_WIDGET_TOPLEVEL (toplevel))
                        {
#if defined(GDK_WINDOWING_X11)
                            /* on X11, we can supply the parent window id here */
                            argv[n++] = "--xid";
                            argv[n++] = g_newa (gchar, 32);
                            g_snprintf (argv[n - 1], 32, "%ld", (glong) GDK_WINDOW_XID (toplevel->window));
#endif
                        }

                        /* terminate the parameter list */
                        argv[n++] = "--create-new";
                        argv[n++] = working_directory;
                        argv[n++] = NULL;

                        /* try to run exo-desktop-item-edit */
                        succeed = gdk_spawn_on_screen (gtk_widget_get_screen (widget), working_directory, argv, NULL,
                                                       G_SPAWN_DO_NOT_REAP_CHILD | G_SPAWN_SEARCH_PATH,
                                                       NULL, NULL, &pid, &error);
                        if (G_UNLIKELY (!succeed))
                        {
                            /* display an error dialog to the user */
                            thunar_dialogs_show_error (view, error, _("Failed to create a link for the URL \"%s\""), bits[0]);
                            g_free (working_directory);
                            g_error_free (error);
                        }
                        else
                        {
                            /* reload the directory when the command terminates */
                            g_child_watch_add_full (G_PRIORITY_LOW, pid, tsv_reload_directory, working_directory, g_free);
                        }
#endif

                        /* cleanup */
                        g_object_unref (G_OBJECT (file));
                    }
                }

                /* cleanup */
                g_strfreev (bits);
            }
        }
        else if (G_LIKELY (info == TARGET_TEXT_URI_LIST))
        {
            /* determine the drop position */
            actions = fm_directory_view_get_dest_actions (view, context, x, y, timestamp, &file);
            if (G_LIKELY ((actions & (GDK_ACTION_COPY | GDK_ACTION_MOVE | GDK_ACTION_LINK)) != 0))
            {
                /* ask the user what to do with the drop data */
                //TODO
                //action = (context->action == GDK_ACTION_ASK)
                printf ("%s TARGET_TEXT_URI_LIST\n", G_STRFUNC);
                //if (gdk_drag_context_get_suggested_action (context) == GDK_ACTION_ASK)
                printf ("%s selected action %d\n", G_STRFUNC, gdk_drag_context_get_selected_action (context));
                action = (gdk_drag_context_get_selected_action (context) == GDK_ACTION_ASK)
                    ? marlin_drag_drop_action_ask (widget, actions)
                    : gdk_drag_context_get_selected_action (context);

                /* perform the requested action */
                if (G_LIKELY (action != 0))
                {
                    printf ("%s perform action %d\n", G_STRFUNC, action);
                    succeed = marlin_dnd_perform (GTK_WIDGET (view), 
                                                  file, 
                                                  view->details->drop_file_list,
                                                  action, 
                                                  NULL);
                    //fm_directory_view_new_files_closure (view));
                }
            }

            /* release the file reference */
            if (G_LIKELY (file != NULL))
                g_object_unref (G_OBJECT (file));
        }

        /* tell the peer that we handled the drop */
        gtk_drag_finish (context, succeed, FALSE, timestamp);

        /* disable the highlighting and release the drag data */
        fm_directory_view_drag_leave (widget, context, timestamp, view);
    }
}

static void
fm_directory_view_drag_leave (GtkWidget         *widget,
                              GdkDragContext    *context,
                              guint             timestamp,
                              FMDirectoryView   *view)
{
    /* reset the drop-file for the icon renderer */
    //TODO
    //g_object_set (G_OBJECT (view->icon_renderer), "drop-file", NULL, NULL);

    printf ("%s\n", G_STRFUNC);
    /* stop any running drag autoscroll timer */
    if (G_UNLIKELY (view->details->drag_scroll_timer_id >= 0))
        g_source_remove (view->details->drag_scroll_timer_id);

    /* disable the drop highlighting around the view */
    if (G_LIKELY (view->details->drop_highlight))
    {
        view->details->drop_highlight = FALSE;
        gtk_widget_queue_draw (GTK_WIDGET (view));
    }

    /* reset the "drop data ready" status and free the URI list */
    if (G_LIKELY (view->details->drop_data_ready))
    {
        //thunar_g_file_list_free (view->details->drop_file_list);
        view->details->drop_file_list = NULL;
        view->details->drop_data_ready = FALSE;
    }

    /* disable the highlighting of the items in the view */
    //TODO
    (*FM_DIRECTORY_VIEW_GET_CLASS (view)->highlight_path) (view, NULL);
}

static gboolean
fm_directory_view_drag_motion (GtkWidget        *widget,
                               GdkDragContext   *context,
                               gint             x,
                               gint             y,
                               guint            timestamp,
                               FMDirectoryView  *view)
{
    GdkDragAction   action = 0;
    GtkTreePath     *path;
    GOFFile         *file = NULL;
    GdkAtom         target;

    printf ("%s\n", G_STRFUNC);
    /* request the drop data on-demand (if we don't have it already) */
    if (G_UNLIKELY (!view->details->drop_data_ready))
    {
        /* check if we can handle that drag data (yet?) */
        target = gtk_drag_dest_find_target (widget, context, NULL);

        if ((target == gdk_atom_intern_static_string ("XdndDirectSave0")) || (target == gdk_atom_intern_static_string ("_NETSCAPE_URL")))
        {
            /* determine the file for the given coordinates */
            file = fm_directory_view_get_drop_file (view, x, y, &path);
            printf ("%s file %s\n", G_STRFUNC, g_file_get_uri (file->location));

            /* check if we can save here */
            //TODO
            /*if (G_LIKELY (file != NULL 
              && thunar_file_is_local (file) 
              && thunar_file_is_directory (file) 
              && thunar_file_is_writable (file)))
              {
              action = gdk_drag_context_get_suggested_action (context);
              }*/
            if (G_LIKELY (file != NULL && file->is_directory 
                          && gof_file_is_writable (file))) {
                printf ("%s get_suggested_action for file = directory\n", file->name);
                action = gdk_drag_context_get_suggested_action (context);
            }

            /* reset path if we cannot drop */
            if (G_UNLIKELY (action == 0 && path != NULL))
            {
                gtk_tree_path_free (path);
                path = NULL;
            }

            /* do the view highlighting */
            if (view->details->drop_highlight != (path == NULL && action != 0))
            {
                view->details->drop_highlight = (path == NULL && action != 0);
                gtk_widget_queue_draw (GTK_WIDGET (view));
            }

            /* setup drop-file for the icon renderer to highlight the target */
            //TODO
            //g_object_set (G_OBJECT (view->icon_renderer), "drop-file", (action != 0) ? file : NULL, NULL);

            /* do the item highlighting */
            (*FM_DIRECTORY_VIEW_GET_CLASS (view)->highlight_path) (view, path);

            /* cleanup */
            if (G_LIKELY (file != NULL))
                g_object_unref (G_OBJECT (file));
            if (G_LIKELY (path != NULL))
                gtk_tree_path_free (path);
        }
        else
        {
            /* request the drag data from the source */
            if (target != GDK_NONE)
                gtk_drag_get_data (widget, context, target, timestamp);
        }

        /* tell Gdk whether we can drop here */
        gdk_drag_status (context, action, timestamp);
    }
    else
    {
        /* check whether we can drop at (x,y) */
        //TODO
        printf ("check whether we can drop at (x,y)\n");
        fm_directory_view_get_dest_actions (view, context, x, y, timestamp, NULL);
    }

    /* start the drag autoscroll timer if not already running */
    if (G_UNLIKELY (view->details->drag_scroll_timer_id < 0))
    {
        view->details->drag_context = context;
        /* schedule the drag autoscroll timer */
        view->details->drag_scroll_timer_id = g_timeout_add_full (G_PRIORITY_LOW, 50, 
                                                                  fm_directory_view_drag_scroll_timer,
                                                                  view, 
                                                                  fm_directory_view_drag_scroll_timer_destroy);
    }

    return TRUE;
}


static void
fm_directory_view_drag_begin (GtkWidget           *widget,
                              GdkDragContext      *context,
                              FMDirectoryView     *view)
{
    GOFFile   *file;
    //GdkPixbuf *icon;
    gint      size;

    printf ("%s\n", G_STRFUNC);
    /* release the drag path list (just in case the drag-end wasn't fired before) */
    gof_file_list_free (view->details->drag_file_list);

    /* query the list of selected URIs */
    view->details->drag_file_list = fm_directory_view_get_selection_for_file_transfer (view);
    if (G_LIKELY (view->details->drag_file_list != NULL))
    {
        /* determine the first selected file */
        file = view->details->drag_file_list->data;
        if (G_LIKELY (file != NULL))
        {
            /* generate an icon based on that file */
            /*g_object_get (G_OBJECT (view->icon_renderer), "size", &size, NULL);
              icon = thunar_icon_factory_load_file_icon (view->icon_factory, file, THUNAR_FILE_ICON_STATE_DEFAULT, size);*/
            //TODO get icon size depending on the view and zoom lvl
            gtk_drag_set_icon_pixbuf (context, file->pix, 0, 0);
            //g_object_unref (G_OBJECT (icon));
        }
    }
}

static void
fm_directory_view_drag_data_get (GtkWidget          *widget,
                                 GdkDragContext     *context,
                                 GtkSelectionData   *selection_data,
                                 guint               info,
                                 guint               timestamp,
                                 FMDirectoryView    *view)
{
    gchar *uri_string;
    gsize len;

    /* set the URI list for the drag selection */
    uri_string = gof_file_list_to_string (view->details->drag_file_list, &len);
    gtk_selection_data_set (selection_data, gtk_selection_data_get_target(selection_data), 8, (guchar *) uri_string, len);
    g_free (uri_string);
}

static void
fm_directory_view_drag_data_delete (GtkWidget       *widget,
                                    GdkDragContext  *context,
                                    FMDirectoryView *view)
{
    /* make sure the default handler of ExoIconwidget/GtkTreewidget is never run */
    g_signal_stop_emission_by_name (G_OBJECT (widget), "drag-data-delete");
}

static void
fm_directory_view_drag_end (GtkWidget       *widget,
                            GdkDragContext  *context,
                            FMDirectoryView *view)
{
    /* stop any running drag autoscroll timer */
    if (G_UNLIKELY (view->details->drag_scroll_timer_id >= 0))
        g_source_remove (view->details->drag_scroll_timer_id);

    /* release the list of dragged URIs */
    gof_file_list_free (view->details->drag_file_list);
    view->details->drag_file_list = NULL;
}

static gboolean
fm_directory_view_drag_timer (gpointer user_data)
{
    FMDirectoryView *view = FM_DIRECTORY_VIEW (user_data);

    /* fire up the context menu */
    GDK_THREADS_ENTER ();
    //thunar_standard_view_context_menu (standard_view, 3, gtk_get_current_event_time ());
    //fm_directory_view_context_menu (view, 3, gtk_get_current_event_time ());
    fm_directory_view_context_menu (view, 3, gtk_get_current_event ());
    printf ("fire up the context menu 3\n");
    GDK_THREADS_LEAVE ();

    return FALSE;
}

static gboolean
fm_directory_view_button_release_event (GtkWidget        *widget,
                                        GdkEventButton   *event,
                                        FMDirectoryView  *view)
{
    g_return_val_if_fail (FM_IS_DIRECTORY_VIEW (view), FALSE);
    g_return_val_if_fail (view->details->drag_timer_id >= 0, FALSE);

    /* cancel the pending drag timer */
    g_source_remove (view->details->drag_timer_id);

    /* fire up the context menu */
    //thunar_standard_view_context_menu (standard_view, 0, event->time);
    fm_directory_view_context_menu (view, 0, event);
    printf ("fire up the context menu 0\n");

    return TRUE;
}

static void
dir_action_set_visible (FMDirectoryView *view, const gchar *action_name, gboolean visible)
{
    GtkAction *action;

    action = gtk_action_group_get_action (view->details->dir_action_group, action_name);
    if (action != NULL) {
        gtk_action_set_visible (action, visible);
        /* enable/disable action too */
        gtk_action_set_sensitive (action, visible);
    }
}

static void
dir_action_set_sensitive (FMDirectoryView *view, const gchar *action_name, gboolean sensitive)
{
    GtkAction *action;

    action = gtk_action_group_get_action (view->details->dir_action_group, action_name);
    if (action != NULL)
        gtk_action_set_sensitive (action, sensitive);
}

static void
update_menus_empty_selection (FMDirectoryView *view)
{
    GtkAction *action;

    g_return_if_fail (FM_IS_DIRECTORY_VIEW (view));
   
    dir_action_set_sensitive (view, "Cut", FALSE);
    dir_action_set_sensitive (view, "Copy", FALSE);
    dir_action_set_sensitive (view, "Rename", FALSE);
    
    GOFWindowSlot *slot = view->details->slot;

    if (gof_file_is_trashed (slot->directory->file)) 
        dir_action_set_visible (view, "New Folder", FALSE);
    else 
        dir_action_set_visible (view, "New Folder", TRUE);
}

static void
update_menus_selection (FMDirectoryView *view)
{
    GList       *selection;
    GtkAction   *action;
    GOFFile     *file;

    g_return_if_fail (FM_IS_DIRECTORY_VIEW (view));
    selection = fm_directory_view_get_selection (view);
    file = GOF_FILE (selection->data);

    dir_action_set_sensitive (view, "Cut", TRUE);
    dir_action_set_sensitive (view, "Copy", TRUE);
    dir_action_set_sensitive (view, "Rename", TRUE);

    if (gof_file_is_trashed(file)) {
        dir_action_set_visible (view, "Restore From Trash", TRUE);
        dir_action_set_visible (view, "Trash", FALSE);
        dir_action_set_visible (view, "Rename", FALSE);
    } else {
        dir_action_set_visible (view, "Restore From Trash", FALSE);
        dir_action_set_visible (view, "Trash", TRUE);
    }
}

static gboolean
fm_directory_view_motion_notify_event (GtkWidget         *widget,
                                       GdkEventMotion    *event,
                                       FMDirectoryView   *view)
{
    GdkDragContext *context;
    GtkTargetList  *target_list;

    g_return_val_if_fail (FM_IS_DIRECTORY_VIEW (view), FALSE);
    g_return_val_if_fail (view->details->drag_timer_id >= 0, FALSE);

    /* check if we passed the DnD threshold */
    if (gtk_drag_check_threshold (widget, view->details->drag_x, view->details->drag_y, event->x, event->y))
    {
        /* cancel the drag timer, as we won't popup the menu anymore */
        g_source_remove (view->details->drag_timer_id);

        /* allocate the drag context (preferred action is to ask the user) */
        target_list = gtk_target_list_new (drag_targets, G_N_ELEMENTS (drag_targets));
        context = gtk_drag_begin (widget, target_list, GDK_ACTION_COPY | GDK_ACTION_MOVE | GDK_ACTION_LINK | GDK_ACTION_ASK, 3, (GdkEvent *) event);
        //TODO hum GSEALED:
        //context->suggested_action = GDK_ACTION_ASK;
        gtk_target_list_unref (target_list);

        return TRUE;
    }

    return FALSE;
}

static void
fm_directory_view_drag_timer_destroy (gpointer user_data)
{
    FMDirectoryView *view = FM_DIRECTORY_VIEW (user_data);
    GtkWidget   *view_box = gtk_bin_get_child (GTK_BIN (view));

    /* unregister the motion notify and button release event handlers (thread-safe) */
    g_signal_handlers_disconnect_by_func (view_box, fm_directory_view_button_release_event, user_data);
    g_signal_handlers_disconnect_by_func (view_box, fm_directory_view_motion_notify_event, user_data);

    /* reset the drag timer source id */
    view->details->drag_timer_id = -1;
}

/**
 * (imported from thunar: thunar_standard_view_queue_popup)
 * @standard_view : a #ThunarStandardView.
 * @event         : the right click event.
 *
 * Schedules a context menu popup in response to
 * a right-click button event. Right-click events
 * need to be handled in a special way, as the
 * user may also start a drag using the right
 * mouse button and therefore this function
 * schedules a timer, which - once expired -
 * opens the context menu. If the user moves
 * the mouse prior to expiration, a right-click
 * drag (with #GDK_ACTION_ASK) will be started
 * instead.
**/
void
fm_directory_view_queue_popup (FMDirectoryView *view, GdkEventButton *event)
{
    GtkSettings *settings;
    GtkWidget   *view_box;
    gint         delay;

    g_return_if_fail (FM_IS_DIRECTORY_VIEW (view));
    g_return_if_fail (event != NULL);

    /* check if we have already scheduled a drag timer */
    if (G_LIKELY (view->details->drag_timer_id < 0))
    {
        /* remember the new coordinates */
        view->details->drag_x = event->x;
        view->details->drag_y = event->y;

        /* figure out the real view */
        view_box = gtk_bin_get_child (GTK_BIN (view));

        /* we use the menu popup delay here, which should give us good values */
        settings = gtk_settings_get_for_screen (gtk_widget_get_screen (view_box));
        g_object_get (G_OBJECT (settings), "gtk-menu-popup-delay", &delay, NULL);

        /* schedule the timer */
        view->details->drag_timer_id = g_timeout_add_full (G_PRIORITY_LOW, delay, 
                                                           fm_directory_view_drag_timer,
                                                           view, 
                                                           fm_directory_view_drag_timer_destroy);

        /* register the motion notify and the button release events on the real view */
        g_signal_connect (G_OBJECT (view_box), "button-release-event", 
                          G_CALLBACK (fm_directory_view_button_release_event), view);
        g_signal_connect (G_OBJECT (view_box), "motion-notify-event", 
                          G_CALLBACK (fm_directory_view_motion_notify_event), view);
    }
}

void
fm_directory_view_context_menu (FMDirectoryView *view,
                                guint           button,
                                GdkEventButton   *event)
                                //int32         timestamp)
{
    GtkWidget *menu;
    GList     *selection;
    GtkUIManager *ui_manager;

    g_return_if_fail (FM_IS_DIRECTORY_VIEW (view));
    selection = fm_directory_view_get_selection (view);
    //thunar_standard_view_merge_custom_actions (standard_view, selected_items);
    /*g_list_foreach (selected_items, (GFunc) gtk_tree_path_free, NULL);
    g_list_free (selected_items);*/
   
    /* grab an additional reference on the view */
    g_object_ref (G_OBJECT (view));

    ui_manager = MARLIN_VIEW_WINDOW (view->details->window)->ui;
    /* run the menu on the view's screen (figuring out whether to use the file or the folder context menu) */
    menu = gtk_ui_manager_get_widget (ui_manager, (selection != NULL) ? "/selection" : "/background");
    //thunar_gtk_menu_run (GTK_MENU (menu), GTK_WIDGET (standard_view), NULL, NULL, button, timestamp);
    
    printf ("%s\n", G_STRFUNC);
    gtk_menu_set_screen (GTK_MENU (menu), gtk_widget_get_screen (GTK_WIDGET (view)));
	gtk_widget_show (GTK_WIDGET (menu));

    eel_pop_up_context_menu (GTK_MENU(menu),
                             EEL_DEFAULT_POPUP_MENU_DISPLACEMENT,
                             EEL_DEFAULT_POPUP_MENU_DISPLACEMENT,
                             event);


    /* release the additional reference on the view */
    g_object_unref (G_OBJECT (view));
}

static void
fm_directory_view_parent_set (GtkWidget *widget,
                              GtkWidget *old_parent)
{
    FMDirectoryView *view;
    GtkWidget *parent;
    GOFDirectoryAsync *dir;

    parent = gtk_widget_get_parent (widget);
    g_assert (parent == NULL || old_parent == NULL);

    if (GTK_WIDGET_CLASS (parent_class)->parent_set != NULL) {
        GTK_WIDGET_CLASS (parent_class)->parent_set (widget, old_parent);
    }

    printf("%s\n", G_STRFUNC);
    view = FM_DIRECTORY_VIEW (widget);
    dir = view->details->slot->directory;

    if (parent != NULL) {
        g_assert (old_parent == NULL);
        g_assert (view->details->slot);
       
        if (MARLIN_VIEW_WINDOW (view->details->window)->current_tab)
        {
            /*printf ("active_slot %s\n", g_file_get_uri(MARLIN_VIEW_WINDOW (view->details->window)->current_tab->slot->location));
              printf ("view_details slot %s\n", g_file_get_uri(view->details->slot->location));*/
            if (view->details->slot == 
                MARLIN_VIEW_WINDOW (view->details->window)->current_tab->slot) {
                fm_directory_view_merge_menus (view);
                view->details->active = TRUE;
                update_menus_empty_selection (view);
                //schedule_update_menus (view);
            }
        }

        if (!dir->loading && dir->loaded)
            fm_directory_view_load_file_hash (dir, view);

    } else {
        fm_directory_view_unmerge_menus (view);
        //remove_update_menus_timeout_callback (view);
    }
}

static void
fm_directory_view_realize (GtkWidget *widget)
{
    FMDirectoryView    *view = FM_DIRECTORY_VIEW (widget);
    //TODO or NOT TODO
    //GtkIconTheme       *icon_theme;
    GdkDisplay         *display;

    /* let the GtkWidget do its work */
    GTK_WIDGET_CLASS (parent_class)->realize (widget);

    /* query the clipboard manager for the display */
    display = gtk_widget_get_display (widget);
    view->clipboard = marlin_clipboard_manager_get_for_display (display);

    /* we need update the selection state based on the clipboard content */
    /*g_signal_connect_swapped (G_OBJECT (view->clipboard), "changed",
      G_CALLBACK (thunar_standard_view_selection_changed), view);
      thunar_standard_view_selection_changed (view);*/

    /* determine the icon factory for the screen on which we are realized */
    //icon_theme = gtk_icon_theme_get_for_screen (gtk_widget_get_screen (widget));
    //view->icon_factory = thunar_icon_factory_get_for_icon_theme (icon_theme);

    /* we need to redraw whenever the "show-thumbnails" property is toggled */
    //g_signal_connect_swapped (G_OBJECT (view->icon_factory), "notify::show-thumbnails", G_CALLBACK (gtk_widget_queue_draw), view);
}

static void
fm_directory_view_unrealize (GtkWidget *widget)
{
    FMDirectoryView    *view = FM_DIRECTORY_VIEW (widget);

    /* disconnect the clipboard changed handler */
    /*g_signal_handlers_disconnect_by_func (G_OBJECT (view->clipboard), thunar_standard_view_selection_changed, view);*/

    /* drop the reference on the icon factory */
    //g_signal_handlers_disconnect_by_func (G_OBJECT (view->icon_factory), gtk_widget_queue_draw, view);
    //g_object_unref (G_OBJECT (view->icon_factory));
    //view->icon_factory = NULL;

    /* drop the reference on the clipboard manager */
    /*g_object_unref (G_OBJECT (view->clipboard));
      view->clipboard = NULL;*/

    /* let the GtkWidget do its work */
    GTK_WIDGET_CLASS (parent_class)->unrealize (widget);
}

static void
fm_directory_view_grab_focus (GtkWidget *widget)
{
    /* forward the focus grab to the real view */
    gtk_widget_grab_focus (gtk_bin_get_child (GTK_BIN (widget)));
}

static void
slot_active (GOFWindowSlot *slot, FMDirectoryView *view)
{
	g_assert (!view->details->active);
	view->details->active = TRUE;

	fm_directory_view_merge_menus (view);
	//schedule_update_menus (view);
}

static void
slot_inactive (GOFWindowSlot *slot, FMDirectoryView *view)
{
	g_assert (view->details->active ||
		  gtk_widget_get_parent (GTK_WIDGET (view)) == NULL);
	view->details->active = FALSE;

	fm_directory_view_unmerge_menus (view);
	//remove_update_menus_timeout_callback (view);
}

static void
trash_or_delete_done_cb (GHashTable *debuting_uris,
                         gboolean user_cancel,
                         FMDirectoryView *view)
{
	if (user_cancel) {
		view->details->selection_was_removed = FALSE;
	}
}

static void
trash_or_delete_files (FMDirectoryView *view,
                       const GList *files,
                       gboolean delete_if_all_already_in_trash)
{
	GList *locations;
	const GList *node;
	
	locations = NULL;
	for (node = files; node != NULL; node = node->next) {
		locations = g_list_prepend (locations,
					    g_object_ref (((GOFFile *) node->data)->location));
	}
	
	locations = g_list_reverse (locations);

	marlin_file_operations_trash_or_delete (locations,
						  GTK_WINDOW (view->details->window),
						  (MarlinDeleteCallback) trash_or_delete_done_cb,
						  view);
	g_list_free_full (locations, g_object_unref);
}

static void
trash_or_delete_selected_files (FMDirectoryView *view)
{
    GList *selection;

    /* This might be rapidly called multiple times for the same selection
	 * when using keybindings. So we remember if the current selection
	 * was already removed (but the view doesn't know about it yet).
	 */
	if (!view->details->selection_was_removed) {
		selection = fm_directory_view_get_selection_for_file_transfer (view);
		trash_or_delete_files (view, selection, TRUE);
		gof_file_list_free (selection);
		view->details->selection_was_removed = TRUE;
	}
}

static gboolean
real_trash (FMDirectoryView *view)
{
    //TODO
	/*GtkAction *action;

	action = gtk_action_group_get_action (view->details->dir_action_group,
                                          NAUTILUS_ACTION_TRASH);
	if (gtk_action_get_sensitive (action) &&
	    gtk_action_get_visible (action)) {*/
		trash_or_delete_selected_files (view);
		return TRUE;
	/*}
	return FALSE;*/
}

static void
action_trash_callback (GtkAction *action, gpointer callback_data)
{
    trash_or_delete_selected_files (FM_DIRECTORY_VIEW (callback_data));
}

static void
delete_selected_files (FMDirectoryView *view)
{
    GList *selection;
	GList *node;
	GList *locations;

	selection = fm_directory_view_get_selection_for_file_transfer (view);
	if (selection == NULL)
		return;

	locations = NULL;
	for (node = selection; node != NULL; node = node->next) {
		locations = g_list_prepend (locations,
					    g_object_ref (((GOFFile *) node->data)->location));
	}
	locations = g_list_reverse (locations);

	marlin_file_operations_delete (locations, GTK_WINDOW (view->details->window), NULL, NULL);

	g_list_free_full (locations, g_object_unref);
    gof_file_list_free (selection);
}

static void
action_delete_callback (GtkAction *action, gpointer data)
{
        delete_selected_files (FM_DIRECTORY_VIEW (data));
}

static void
action_restore_from_trash_callback (GtkAction *action, gpointer data)
{
	FMDirectoryView *view;
	GList *selection;

	view = FM_DIRECTORY_VIEW (data);

	selection = fm_directory_view_get_selection_for_file_transfer (view);
	marlin_restore_files_from_trash (selection, GTK_WINDOW (view->details->window));

	gof_file_list_free (selection);
}

static gboolean
real_delete (FMDirectoryView *view)
{
    //TODO
	/*GtkAction *action;

	action = gtk_action_group_get_action (view->details->dir_action_group,
                                          NAUTILUS_ACTION_DELETE);
	if (gtk_action_get_sensitive (action) &&
	    gtk_action_get_visible (action)) {*/
		delete_selected_files (view);
		return TRUE;
	/*}
	return FALSE;*/
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

        directory_view->details->slot = g_object_ref(slot);
        directory_view->details->window = window;
        /* store the loading state of the directory */
        directory_view->details->loading = slot->directory->loading;

        if (!(directory_view->details->loading && slot->directory->loaded))
            g_signal_connect (slot->directory, "file_loaded", G_CALLBACK (file_loaded_callback), directory_view);
        g_signal_connect (slot->directory, "file_added", G_CALLBACK (file_added_callback), directory_view);
        //TODO
        //g_signal_connect (slot->directory, "file_changed", G_CALLBACK (file_changed_callback), directory_view);
        g_signal_connect (slot->directory, "file_deleted", G_CALLBACK (file_deleted_callback), directory_view);
        g_signal_connect (slot->directory, "done_loading", G_CALLBACK (directory_done_loading_callback), directory_view);

	g_signal_connect_object (directory_view->details->slot,
				 "active", G_CALLBACK (slot_active),
				 directory_view, 0);
	g_signal_connect_object (directory_view->details->slot,
				 "inactive", G_CALLBACK (slot_inactive),
				 directory_view, 0);

          /*g_signal_connect_object (directory_view->details->window,
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

    G_OBJECT_CLASS (klass)->constructor = fm_directory_view_constructor;
    G_OBJECT_CLASS (klass)->finalize = fm_directory_view_finalize;
    G_OBJECT_CLASS (klass)->set_property = fm_directory_view_set_property;

    widget_class->destroy = fm_directory_view_destroy;
    widget_class->scroll_event = fm_directory_view_scroll_event;
    widget_class->parent_set = fm_directory_view_parent_set;

    widget_class->realize = fm_directory_view_realize;
    widget_class->unrealize = fm_directory_view_unrealize;
    widget_class->grab_focus = fm_directory_view_grab_focus;

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
                      marlin_marshal_VOID__OBJECT_OBJECT,
                      G_TYPE_NONE, 2, GOF_TYPE_FILE, GOF_TYPE_DIRECTORY_ASYNC);
    signals[REMOVE_FILE] =
        g_signal_new ("remove_file",
                      G_TYPE_FROM_CLASS (klass),
                      G_SIGNAL_RUN_LAST,
                      G_STRUCT_OFFSET (FMDirectoryViewClass, remove_file),
                      NULL, NULL,
                      marlin_marshal_VOID__OBJECT_OBJECT,
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
      klass->using_manual_layout = real_using_manual_layout;*/
    klass->merge_menus = real_merge_menus;
    klass->unmerge_menus = real_unmerge_menus;
    /* klass->update_menus = real_update_menus;
       klass->set_is_active = real_set_is_active;*/

    /* Function pointers that subclasses must override */
    //EEL_ASSIGN_MUST_OVERRIDE_SIGNAL (klass, fm_directory_view, add_file);
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

    signals[TRASH] =
        g_signal_new ("trash",
                      G_TYPE_FROM_CLASS (klass),
                      G_SIGNAL_RUN_LAST | G_SIGNAL_ACTION,
                      G_STRUCT_OFFSET (FMDirectoryViewClass, trash),
                      g_signal_accumulator_true_handled, NULL,
                      marlin_marshal_BOOLEAN__VOID,
                      G_TYPE_BOOLEAN, 0);
    signals[DELETE] =
        g_signal_new ("delete",
                      G_TYPE_FROM_CLASS (klass),
                      G_SIGNAL_RUN_LAST | G_SIGNAL_ACTION,
                      G_STRUCT_OFFSET (FMDirectoryViewClass, delete),
                      g_signal_accumulator_true_handled, NULL,
                      marlin_marshal_BOOLEAN__VOID,
                      G_TYPE_BOOLEAN, 0);

    binding_set = gtk_binding_set_by_class (klass);
    gtk_binding_entry_add_signal (binding_set, GDK_KEY_Delete, 0,
                                  "trash", 0);
    gtk_binding_entry_add_signal (binding_set, GDK_KEY_KP_Delete, 0,
                                  "trash", 0);
    gtk_binding_entry_add_signal (binding_set, GDK_KEY_KP_Delete, GDK_SHIFT_MASK,
                                  "delete", 0);

    klass->trash = real_trash;
    klass->delete = real_delete;
}

/* TODO maybe pass the entire selection in the signal */
void
fm_directory_view_notify_selection_changed (FMDirectoryView *view, GOFFile *file)
{
    GList *selection;

    view->details->selection_was_removed = FALSE;
    g_signal_emit_by_name (MARLIN_VIEW_WINDOW (view->details->window), "selection_changed", file);

    selection = fm_directory_view_get_selection (view);
    if (selection != NULL) {
        update_menus_selection (view);
    } else {
        update_menus_empty_selection (view);
    }

}


/**
 * fm_directory_view_merge_menus:
 * 
 * Add this view's menus to the window's menu bar.
 * @view: FMDirectoryView in question.
 */
void
fm_directory_view_merge_menus (FMDirectoryView *view)
{
    printf ("%s\n", G_STRFUNC);
    g_return_if_fail (FM_IS_DIRECTORY_VIEW (view));

    EEL_CALL_METHOD
        (FM_DIRECTORY_VIEW_CLASS, view,
         merge_menus, (view));
}

void
fm_directory_view_unmerge_menus (FMDirectoryView *view)
{
    g_return_if_fail (FM_IS_DIRECTORY_VIEW (view));

    EEL_CALL_METHOD
        (FM_DIRECTORY_VIEW_CLASS, view,
         unmerge_menus, (view));
}

GList *
fm_directory_view_get_selection (FMDirectoryView *view)
{
    g_return_val_if_fail (FM_IS_DIRECTORY_VIEW (view), NULL);

    return EEL_CALL_METHOD_WITH_RETURN_VALUE
        (FM_DIRECTORY_VIEW_CLASS, view,
         get_selection, (view));
}

GList *
fm_directory_view_get_selection_for_file_transfer (FMDirectoryView *view)
{
    g_return_val_if_fail (FM_IS_DIRECTORY_VIEW (view), NULL);

    return EEL_CALL_METHOD_WITH_RETURN_VALUE
        (FM_DIRECTORY_VIEW_CLASS, view,
         get_selection_for_file_transfer, (view));
}

static void
action_cut_files (GtkAction *action, FMDirectoryView *view)
{
    GList *selection;

    g_return_if_fail (GTK_IS_ACTION (action));
    g_return_if_fail (FM_IS_DIRECTORY_VIEW (view));
    g_return_if_fail (MARLIN_IS_CLIPBOARD_MANAGER (view->clipboard));

    selection = fm_directory_view_get_selection_for_file_transfer (view);
    marlin_clipboard_manager_cut_files (view->clipboard, selection);

    /*copy_or_cut_files (view, selection, FALSE);*/
    gof_file_list_free (selection);
}

static void
action_copy_files (GtkAction *action, FMDirectoryView *view)
{
    GList *selection;

    g_return_if_fail (GTK_IS_ACTION (action));
    g_return_if_fail (FM_IS_DIRECTORY_VIEW (view));
    g_return_if_fail (MARLIN_IS_CLIPBOARD_MANAGER (view->clipboard));

    selection = fm_directory_view_get_selection_for_file_transfer (view);
    marlin_clipboard_manager_copy_files (view->clipboard, selection);

    /*copy_or_cut_files (view, selection, FALSE);*/
    gof_file_list_free (selection);
}

static void
action_paste_files (GtkAction *action, FMDirectoryView *view)
{
    GFile *current_directory;

    g_return_if_fail (GTK_IS_ACTION (action));
    g_return_if_fail (FM_IS_DIRECTORY_VIEW (view));

    current_directory = view->details->slot->location;
    if (G_LIKELY (current_directory != NULL))
    {
        marlin_clipboard_manager_paste_files (view->clipboard, current_directory,
                                              GTK_WIDGET (view), NULL);
        //TODO evalutate
        //t_standard_view_new_files_closure (standard_view));
    }
}

static void
real_action_rename (FMDirectoryView *view, gboolean select_all)
{
	GOFFile *file;
	GList *selection;

	g_assert (FM_IS_DIRECTORY_VIEW (view));

	selection = fm_directory_view_get_selection (view);

    printf ("%s\n", G_STRFUNC);
	if (selection != NULL) {
		/* If there is more than one file selected, invoke a batch renamer */
		if (selection->next != NULL) {
            //TODO bulk rename tool
            printf ("TODO bulk rename tool\n");
			/*if (have_bulk_rename_tool ()) {
				invoke_external_bulk_rename_utility (view, selection);
			}*/
		} else {
			file = GOF_FILE (selection->data);
			if (!select_all) {
				/* directories don't have a file extension, so
				 * they are always pre-selected as a whole */
				select_all = file->is_directory;
			}
			EEL_CALL_METHOD (FM_DIRECTORY_VIEW_CLASS, view, start_renaming_file, (view, file, select_all));
		}
	}
}

static void
action_rename_callback (GtkAction *action, gpointer data)
{
	real_action_rename (FM_DIRECTORY_VIEW (data), FALSE);
}

static void
new_folder_done (GFile *new_folder, gpointer data)
{
    g_assert (FM_IS_DIRECTORY_VIEW (data));
 
    FMDirectoryView *view = FM_DIRECTORY_VIEW (data);
    GOFFile *file = gof_file_get (new_folder);

    //TODO
    printf ("rename file\n");
    //rename_file (view, file);
    EEL_CALL_METHOD (FM_DIRECTORY_VIEW_CLASS, view, start_renaming_file, (view, file, FALSE));
    //fm_directory_view_reveal_selection (view);

    g_object_unref (file);
}

static void
action_new_folder_callback (GtkAction *action, gpointer data)
{                
    g_assert (FM_IS_DIRECTORY_VIEW (data));
 
    FMDirectoryView *view = FM_DIRECTORY_VIEW (data);

    //data = new_folder_data_new (view);

	/*g_signal_connect_data (view,
                           "add_file",
                           G_CALLBACK (track_newly_added_locations),
                           data,
                           (GClosureNotify)NULL,
                           G_CONNECT_AFTER);*/

    /* TODO usefull for desktop
	pos = context_menu_to_file_operation_position (directory_view);*/

    printf ("%s\n", G_STRFUNC);
	marlin_file_operations_new_folder (GTK_WIDGET (view),
                                       //pos, parent_uri,
                                       NULL, view->details->slot->location,
                                       //new_folder_done, data);
                                       new_folder_done, view);

}

static void
action_properties_callback (GtkAction *action, gpointer data)
{
    //TODO
#if 0
    FMDirectoryView *view;
    GList *selection;
    GList *files;
        
    g_assert (FM_DIRECTORY_IS_VIEW (callback_data));

    view = FM_DIRECTORY_VIEW (callback_data);
    selection = nautilus_view_get_selection (view);
    if (g_list_length (selection) == 0) {
        if (view->details->directory_as_file != NULL) {
			files = g_list_append (NULL, nautilus_file_ref (view->details->directory_as_file));
			nautilus_properties_window_present (files, GTK_WIDGET (view));
			gof_file_list_free (files);
		}
	} else {
		nautilus_properties_window_present (selection, GTK_WIDGET (view));
	}
    gof_file_list_free (selection);
#endif
}


//TODO complete this list
static const GtkActionEntry directory_view_entries[] = {
    /* name, stock id */        { "Cut", GTK_STOCK_CUT,
    /* label, accelerator */      NULL, NULL,
    /* tooltip */                 N_("Prepare the selected files to be moved with a Paste command"),
            G_CALLBACK (action_cut_files) },
    /* name, stock id */        { "Copy", GTK_STOCK_COPY,
    /* label, accelerator */      NULL, NULL,
    /* tooltip */                 N_("Prepare the selected files to be copied with a Paste command"),
            G_CALLBACK (action_copy_files) },
    /* name, stock id */        { "Paste", GTK_STOCK_PASTE,
    /* label, accelerator */      NULL, NULL,
    /* tooltip */                 N_("Move or copy files previously selected by a Cut or Copy command"),
            G_CALLBACK (action_paste_files) },
    /* name, stock id */         { "Rename", NULL,
    /* label, accelerator */       N_("_Rename..."), "F2",
    /* tooltip */                  N_("Rename selected item"),
	        G_CALLBACK (action_rename_callback) },
    /* name, stock id */         { "New Folder", "folder-new",
    /* label, accelerator */       N_("Create New _Folder"), "<control><shift>N",
    /* tooltip */                  N_("Create a new empty folder inside this folder"),
	        G_CALLBACK (action_new_folder_callback) },
    /* name, stock id */         { "Trash", NULL,
    /* label, accelerator */       N_("Mo_ve to Trash"), NULL,
    /* tooltip */                  N_("Move each selected item to the Trash"),
            G_CALLBACK (action_trash_callback) },
    /* name, stock id */         { "Delete", NULL,
    /* label, accelerator */       N_("_Delete"), "<shift>Delete",
    /* tooltip */                  N_("Delete each selected item, without moving to the Trash"),
            G_CALLBACK (action_delete_callback) },
    /* name, stock id */         { "Restore From Trash", NULL,
    /* label, accelerator */       N_("_Restore"), NULL,
                                   NULL,
            G_CALLBACK (action_restore_from_trash_callback) },
    /* name, stock id */         { "Properties", GTK_STOCK_PROPERTIES,
    /* label, accelerator */       N_("_Properties"), "<alt>Return",
    /* tooltip */                  N_("View or modify the properties of each selected item"),
	        G_CALLBACK (action_properties_callback) }

};


static void
real_unmerge_menus (FMDirectoryView *view)
{
    printf("%s\n", G_STRFUNC);
    GtkUIManager *ui_manager;

    if (view->details->window == NULL) {
        return;
    }

    ui_manager = MARLIN_VIEW_WINDOW (view->details->window)->ui;

    eel_ui_unmerge_ui (ui_manager,
                       &view->details->dir_merge_id,
                       &view->details->dir_action_group);
    /*eel_ui_unmerge_ui (ui_manager,
      &view->details->extensions_menu_merge_id,
      &view->details->extensions_menu_action_group);
      eel_ui_unmerge_ui (ui_manager,
      &view->details->open_with_merge_id,
      &view->details->open_with_action_group);
      eel_ui_unmerge_ui (ui_manager,
      &view->details->scripts_merge_id,
      &view->details->scripts_action_group);
      eel_ui_unmerge_ui (ui_manager,
      &view->details->templates_merge_id,
      &view->details->templates_action_group);*/
}

static void
real_merge_menus (FMDirectoryView *view)
{
    printf("%s\n", G_STRFUNC);
    GtkActionGroup *action_group;
    GtkUIManager *ui_manager;
    GtkAction *action;
    const char *ui;
    char *tooltip;

    ui_manager = MARLIN_VIEW_WINDOW (view->details->window)->ui;

    action_group = gtk_action_group_new ("DirViewActions");
    //gtk_action_group_set_translation_domain (action_group, GETTEXT_PACKAGE);
    view->details->dir_action_group = action_group;
    gtk_action_group_add_actions (action_group, 
                                  directory_view_entries, G_N_ELEMENTS (directory_view_entries),
                                  view);

    /* Translators: %s is a directory */
    //tooltip = g_strdup_printf (_("Run or manage scripts from %s"), "~/.gnome2/nautilus-scripts");
    /* Create a script action here specially because its tooltip is dynamic */
    /*action = gtk_action_new ("Scripts", _("_Scripts"), tooltip, NULL);
      gtk_action_group_add_action (action_group, action);
      g_object_unref (action);
      g_free (tooltip);

      action = gtk_action_group_get_action (action_group, FM_ACTION_NO_TEMPLATES);
      gtk_action_set_sensitive (action, FALSE);

      g_signal_connect_object (action_group, "connect-proxy",
      G_CALLBACK (connect_proxy), G_OBJECT (view),
      G_CONNECT_SWAPPED);
      g_signal_connect_object (action_group, "pre-activate",
      G_CALLBACK (pre_activate), G_OBJECT (view),
      G_CONNECT_SWAPPED);*/

    /* Insert action group at end so clipboard action group ends up before it */
    gtk_ui_manager_insert_action_group (ui_manager, action_group, -1);
    g_object_unref (action_group); /* owned by ui manager */

    ui = eel_ui_string_get ("fm-directory-view-ui.xml");
    view->details->dir_merge_id = gtk_ui_manager_add_ui_from_string (ui_manager, ui, -1, NULL);

    //view->details->scripts_invalid = TRUE;
    //view->details->templates_invalid = TRUE;
}
