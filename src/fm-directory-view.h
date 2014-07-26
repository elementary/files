/* fm-directory-view.h
 *
 * Copyright (C) 1999, 2000  Free Software Foundaton
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
 * Authors: Ettore Perazzoli
 * 	    Darin Adler <darin@bentspoon.com>
 * 	    John Sullivan <sullivan@eazel.com>
 *          Pavel Cisler <pavel@eazel.com>
 */

#ifndef FM_DIRECTORY_VIEW_H
#define FM_DIRECTORY_VIEW_H

#include <gtk/gtk.h>
#include <gio/gio.h>
#include "gof-file.h"
//#include "marlin-window-columns.h"
//#include "gof-window-slot.h"
//#include "marlin-vala.h"
#include "marlin-clipboard-manager.h"
#include "fm-list-model.h"
//#include "fm-columns-view.h"
//#include "fm-list-view.h"
//#include "fm-icon-view.h"
#include "marlin-view-window.h"
#include "marlincore.h"
#include "marlin-enum-types.h"

#define FM_TYPE_DIRECTORY_VIEW (fm_directory_view_get_type ())
#define FM_DIRECTORY_VIEW(obj) (G_TYPE_CHECK_INSTANCE_CAST ((obj), FM_TYPE_DIRECTORY_VIEW, FMDirectoryView))
#define FM_DIRECTORY_VIEW_CLASS(klass) (G_TYPE_CHECK_CLASS_CAST ((klass), FM_TYPE_DIRECTORY_VIEW, FMDirectoryViewClass))
#define FM_IS_DIRECTORY_VIEW(obj) (G_TYPE_CHECK_INSTANCE_TYPE ((obj), FM_TYPE_DIRECTORY_VIEW))
#define FM_IS_DIRECTORY_VIEW_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), FM_TYPE_DIRECTORY_VIEW))
#define FM_DIRECTORY_VIEW_GET_CLASS(obj) (G_TYPE_INSTANCE_GET_CLASS ((obj), FM_TYPE_DIRECTORY_VIEW, FMDirectoryViewClass))

typedef struct _FMDirectoryView FMDirectoryView;
typedef struct _FMDirectoryViewClass FMDirectoryViewClass;
typedef struct _FMDirectoryViewPrivate FMDirectoryViewPrivate;

#define MAX_TEMPLATES 32

typedef struct FMDirectoryViewDetails FMDirectoryViewDetails;

struct _FMDirectoryView {
	GtkScrolledWindow parent_instance;
	FMDirectoryViewPrivate * priv;
	MarlinZoomLevel zoom_level;
	MarlinClipboardManager* clipboard;
	FMListModel* model;
	GtkCellRenderer* icon_renderer;
	GtkCellRenderer* name_renderer;
	MarlinViewSlot* slot;
};

struct _FMDirectoryViewClass {
	GtkScrolledWindowClass parent_class;
	void (*zoom_normal) (FMDirectoryView* self);
	void (*zoom_level_changed) (FMDirectoryView* self);
	GList* (*get_selection) (FMDirectoryView* self);
	GList* (*get_selection_for_file_transfer) (FMDirectoryView* self);
	GList* (*get_selected_paths) (FMDirectoryView* self);
	void (*highlight_path) (FMDirectoryView* self, GtkTreePath* path);
	GtkTreePath* (*get_path_at_pos) (FMDirectoryView* self, gint x, gint y);
	void (*select_all) (FMDirectoryView* self);
	void (*unselect_all) (FMDirectoryView* self);
	void (*select_path) (FMDirectoryView* self, GtkTreePath* path);
	void (*set_cursor) (FMDirectoryView* self, GtkTreePath* path, gboolean start_editing, gboolean select);
	gboolean (*get_visible_range) (FMDirectoryView* self, GtkTreePath** start_path, GtkTreePath** end_path);
	void (*start_renaming_file) (FMDirectoryView* self, GOFFile* file, gboolean preselect_whole_name);
	void (*unmerge_menus) (FMDirectoryView* self);
	void (*merge_menus) (FMDirectoryView* self);
	void (*sync_selection) (FMDirectoryView* self);
};

typedef enum  {
	FM_DIRECTORY_VIEW_TARGET_TYPE_STRING,
	FM_DIRECTORY_VIEW_TARGET_TYPE_TEXT_URI_LIST,
	FM_DIRECTORY_VIEW_TARGET_TYPE_XDND_DIRECT_SAVE0,
	FM_DIRECTORY_VIEW_TARGET_TYPE_NETSCAPE_URL
} FMDirectoryViewTargetType;

/* GObject support */
GType   fm_directory_view_get_type (void);
GType fm_directory_view_target_type_get_type (void) G_GNUC_CONST;
FMDirectoryView* fm_directory_view_construct (GType object_type, MarlinViewSlot* _slot);
void fm_directory_view_zoom_in (FMDirectoryView* self);
void fm_directory_view_zoom_out (FMDirectoryView* self);
void fm_directory_view_set_active_slot (FMDirectoryView* self);
void fm_directory_view_column_add_location (FMDirectoryView* self, GFile* location);
void fm_directory_view_load_location (FMDirectoryView* self, GFile* location);
void fm_directory_view_load_root_location (FMDirectoryView* self, GFile* location);
void fm_directory_view_add_subdirectory (FMDirectoryView* self, GOFDirectoryAsync* dir);
void fm_directory_view_remove_subdirectory (FMDirectoryView* self, GOFDirectoryAsync* dir);
void fm_directory_view_activate_selected_items (FMDirectoryView* self, MarlinOpenFlag flag);
void fm_directory_view_preview_selected_items (FMDirectoryView* self);
void fm_directory_view_after_restore_selection (FMDirectoryView* self, GtkTreePath* path);
void fm_directory_view_select_first_for_empty_selection (FMDirectoryView* self);
void fm_directory_view_select_gof_file (FMDirectoryView* self, GOFFile* file);
void fm_directory_view_add_gof_file_to_selection (FMDirectoryView* self, GOFFile* file);
void fm_directory_view_select_glib_files (FMDirectoryView* self, GList* location_list);
void fm_directory_view_trash_or_delete_selected_files (FMDirectoryView* self);
void fm_directory_view_after_trash_or_delete (FMDirectoryView* self, GHashTable* debuting_files, gboolean user_cancel, void* data);
gboolean fm_directory_view_scroll_event (FMDirectoryView* self, GdkEventScroll* event);
void fm_directory_view_notify_selection_changed (FMDirectoryView* self);
void fm_directory_view_set_updates_frozen (FMDirectoryView* self, gboolean freeze);
gboolean fm_directory_view_get_updates_frozen (FMDirectoryView* self);
gboolean fm_directory_view_is_drag_pending (FMDirectoryView* self);
gboolean fm_directory_view_is_selection_only_folders (FMDirectoryView* self, GList* list);
void fm_directory_view_grab_focus (FMDirectoryView* self);
GAppInfo* fm_directory_view_get_default_app (FMDirectoryView* self);
GList* fm_directory_view_get_open_with_apps (FMDirectoryView* self);
void fm_directory_view_zoom_normal (FMDirectoryView* self);
void fm_directory_view_zoom_level_changed (FMDirectoryView* self);
GList* fm_directory_view_get_selection (FMDirectoryView* self);
GList* fm_directory_view_get_selection_for_file_transfer (FMDirectoryView* self);
GList* fm_directory_view_get_selected_paths (FMDirectoryView* self);
void fm_directory_view_highlight_path (FMDirectoryView* self, GtkTreePath* path);
GtkTreePath* fm_directory_view_get_path_at_pos (FMDirectoryView* self, gint x, gint y);
void fm_directory_view_select_all (FMDirectoryView* self);
void fm_directory_view_unselect_all (FMDirectoryView* self);
void fm_directory_view_select_path (FMDirectoryView* self, GtkTreePath* path);
void fm_directory_view_set_cursor (FMDirectoryView* self, GtkTreePath* path, gboolean start_editing, gboolean select);
gboolean fm_directory_view_get_visible_range (FMDirectoryView* self, GtkTreePath** start_path, GtkTreePath** end_path);
void fm_directory_view_start_renaming_file (FMDirectoryView* self, GOFFile* file, gboolean preselect_whole_name);
void fm_directory_view_unmerge_menus (FMDirectoryView* self);
void fm_directory_view_merge_menus (FMDirectoryView* self);
void fm_directory_view_sync_selection (FMDirectoryView* self);
MarlinViewWindow* fm_directory_view_get_window (FMDirectoryView* self);


#endif /* FM_DIRECTORY_VIEW_H */
