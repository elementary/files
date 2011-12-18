/*-
 * Copyright (c) 2002,2004  Anders Carlsson <andersca@gnu.org>
 * Copyright (c) 2004-2006  os-cillation e.K.
 * Copyright (c) 2008       Jannis Pohlmann <jannis@xfce.org>,
 *                          Benedikt Meurer <benny@xfce.org>
 * Copyright (c) 2011       ammonkey <am.monkeyd@gmail.com>
 *
 * Originaly Written by Anders Carlsson for gtk+: gtkiconview
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#ifndef __EXO_ICON_VIEW_H__
#define __EXO_ICON_VIEW_H__

/*#include <gtk/gtkcontainer.h>
#include <gtk/gtktreemodel.h>
#include <gtk/gtkcellrenderer.h>
#include <gtk/gtkcellarea.h>
#include <gtk/gtkselection.h>
#include <gtk/gtktooltip.h>*/

#include <gtk/gtk.h>
#include <gdk/gdk.h>

G_BEGIN_DECLS

#define EXO_TYPE_ICON_VIEW            (exo_icon_view_get_type ())
#define EXO_ICON_VIEW(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), EXO_TYPE_ICON_VIEW, ExoIconView))
#define EXO_ICON_VIEW_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass), EXO_TYPE_ICON_VIEW, ExoIconViewClass))
#define EXO_IS_ICON_VIEW(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), EXO_TYPE_ICON_VIEW))
#define EXO_IS_ICON_VIEW_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), EXO_TYPE_ICON_VIEW))
#define EXO_ICON_VIEW_GET_CLASS(obj)  (G_TYPE_INSTANCE_GET_CLASS ((obj), EXO_TYPE_ICON_VIEW, ExoIconViewClass))

typedef struct _ExoIconView           ExoIconView;
typedef struct _ExoIconViewClass      ExoIconViewClass;
typedef struct _ExoIconViewPrivate    ExoIconViewPrivate;

GType exo_icon_view_layout_mode_get_type (void) G_GNUC_CONST;
#define EXO_TYPE_ICON_VIEW_LAYOUT_MODE (exo_icon_view_layout_mode_get_type())

/**
 * ExoIconViewForeachFunc:
 * @icon_view: a #ExoIconView
 * @path: The #GtkTreePath of a selected row
 * @data: user data
 *
 * A function used by exo_icon_view_selected_foreach() to map all
 * selected rows.  It will be called on every selected row in the view.
 */
typedef void (* ExoIconViewForeachFunc)     (ExoIconView      *icon_view,
                                             GtkTreePath      *path,
                                             gpointer          data);

typedef void (* ExoIconViewSearchPositionFunc) (ExoIconView  *icon_view,
                                                GtkWidget    *search_dialog,
                                                gpointer      user_data);

/**
 * ExoIconViewSearchEqualFunc:
 * @model: the #GtkTreeModel being searched
 * @column: the search column set by exo_icon_view_set_search_column()
 * @key: the key string to compare with
 * @iter: a #GtkTreeIter pointing the row of @model that should be compared
 *  with @key.
 * @search_data: (closure): user data from exo_icon_view_set_search_equal_func()
 *
 * A function used for checking whether a row in @model matches
 * a search key string entered by the user. Note the return value
 * is reversed from what you would normally expect, though it
 * has some similarity to strcmp() returning 0 for equal strings.
 *
 * Returns: %FALSE if the row matches, %TRUE otherwise.
 */
typedef gboolean (*ExoIconViewSearchEqualFunc) (GtkTreeModel    *model,
                                                gint            column,
                                                const gchar     *key,
                                                GtkTreeIter     *iter,
                                                gpointer        search_data);


/**
 * ExoIconViewDropPosition:
 * @EXO_ICON_VIEW_NO_DROP: no drop possible
 * @EXO_ICON_VIEW_DROP_INTO: dropped item replaces the item
 * @EXO_ICON_VIEW_DROP_LEFT: droppped item is inserted to the left
 * @EXO_ICON_VIEW_DROP_RIGHT: dropped item is inserted to the right
 * @EXO_ICON_VIEW_DROP_ABOVE: dropped item is inserted above
 * @EXO_ICON_VIEW_DROP_BELOW: dropped item is inserted below
 *
 * An enum for determining where a dropped item goes.
 */
typedef enum
{
    EXO_ICON_VIEW_NO_DROP,
    EXO_ICON_VIEW_DROP_INTO,
    EXO_ICON_VIEW_DROP_LEFT,
    EXO_ICON_VIEW_DROP_RIGHT,
    EXO_ICON_VIEW_DROP_ABOVE,
    EXO_ICON_VIEW_DROP_BELOW
} ExoIconViewDropPosition;

/**
 * ExoIconViewLayoutMode:
 * @EXO_ICON_VIEW_LAYOUT_ROWS : layout items in rows.
 * @EXO_ICON_VIEW_LAYOUT_COLS : layout items in columns.
 *
 * Specifies the layouting mode of an #ExoIconView. @EXO_ICON_VIEW_LAYOUT_ROWS
 * is the default, which lays out items vertically in rows from top to bottom.
 * @EXO_ICON_VIEW_LAYOUT_COLS lays out items horizontally in columns from left
 * to right.
 **/
typedef enum
{
    EXO_ICON_VIEW_LAYOUT_ROWS,
    EXO_ICON_VIEW_LAYOUT_COLS
} ExoIconViewLayoutMode;

struct _ExoIconView
{
    GtkContainer parent;

    /*< private >*/
    ExoIconViewPrivate *priv;
};

struct _ExoIconViewClass
{
    GtkContainerClass parent_class;

    void    (* item_activated)         (ExoIconView      *icon_view,
                                        GtkTreePath      *path);
    void    (* selection_changed)      (ExoIconView      *icon_view);

    /* Key binding signals */
    void    (* select_all)             (ExoIconView      *icon_view);
    void    (* unselect_all)           (ExoIconView      *icon_view);
    void    (* select_cursor_item)     (ExoIconView      *icon_view);
    void    (* toggle_cursor_item)     (ExoIconView      *icon_view);
    gboolean (* move_cursor)           (ExoIconView      *icon_view,
                                        GtkMovementStep   step,
                                        gint              count);
    gboolean (* activate_cursor_item)  (ExoIconView      *icon_view);

    /* Padding for future expansion */
    void (*_exo_reserved1) (void);
    void (*_exo_reserved2) (void);
    void (*_exo_reserved3) (void);
    void (*_exo_reserved4) (void);
};

GType          exo_icon_view_get_type          (void) G_GNUC_CONST;
GtkWidget *    exo_icon_view_new               (void);
GtkWidget *    exo_icon_view_new_with_area     (GtkCellArea    *area);
GtkWidget *    exo_icon_view_new_with_model    (GtkTreeModel   *model);

void           exo_icon_view_set_model         (ExoIconView    *icon_view,
                                                GtkTreeModel   *model);
GtkTreeModel * exo_icon_view_get_model         (ExoIconView    *icon_view);
void           exo_icon_view_set_text_column   (ExoIconView    *icon_view,
                                                gint            column);
gint           exo_icon_view_get_text_column   (ExoIconView    *icon_view);
void           exo_icon_view_set_markup_column (ExoIconView    *icon_view,
                                                gint            column);
gint           exo_icon_view_get_markup_column (ExoIconView    *icon_view);
void           exo_icon_view_set_pixbuf_column (ExoIconView    *icon_view,
                                                gint            column);
gint           exo_icon_view_get_pixbuf_column (ExoIconView    *icon_view);

void           exo_icon_view_set_item_orientation (ExoIconView    *icon_view,
                                                   GtkOrientation  orientation);
GtkOrientation exo_icon_view_get_item_orientation (ExoIconView    *icon_view);
void           exo_icon_view_set_columns       (ExoIconView    *icon_view,
                                                gint            columns);
gint           exo_icon_view_get_columns       (ExoIconView    *icon_view);
void           exo_icon_view_set_item_width    (ExoIconView    *icon_view,
                                                gint            item_width);
gint           exo_icon_view_get_item_width    (ExoIconView    *icon_view);
void           exo_icon_view_set_spacing       (ExoIconView    *icon_view, 
                                                gint            spacing);
gint           exo_icon_view_get_spacing       (ExoIconView    *icon_view);
void           exo_icon_view_set_row_spacing   (ExoIconView    *icon_view, 
                                                gint            row_spacing);
gint           exo_icon_view_get_row_spacing   (ExoIconView    *icon_view);
void           exo_icon_view_set_column_spacing (ExoIconView    *icon_view, 
                                                 gint            column_spacing);
gint           exo_icon_view_get_column_spacing (ExoIconView    *icon_view);
void           exo_icon_view_set_margin        (ExoIconView    *icon_view, 
                                                gint            margin);
gint           exo_icon_view_get_margin        (ExoIconView    *icon_view);
void           exo_icon_view_set_item_padding  (ExoIconView    *icon_view, 
                                                gint            item_padding);
gint           exo_icon_view_get_item_padding  (ExoIconView    *icon_view);

GtkTreePath *  exo_icon_view_get_path_at_pos   (ExoIconView     *icon_view,
                                                gint             x,
                                                gint             y);
gboolean       exo_icon_view_get_item_at_pos   (ExoIconView     *icon_view,
                                                gint              x,
                                                gint              y,
                                                GtkTreePath     **path,
                                                GtkCellRenderer **cell);
gboolean       exo_icon_view_get_visible_range (ExoIconView      *icon_view,
                                                GtkTreePath     **start_path,
                                                GtkTreePath     **end_path);

void           exo_icon_view_selected_foreach   (ExoIconView            *icon_view,
                                                 ExoIconViewForeachFunc  func,
                                                 gpointer                data);
void           exo_icon_view_set_selection_mode (ExoIconView            *icon_view,
                                                 GtkSelectionMode        mode);
GtkSelectionMode exo_icon_view_get_selection_mode (ExoIconView            *icon_view);
ExoIconViewLayoutMode exo_icon_view_get_layout_mode     (const ExoIconView        *icon_view);
void                  exo_icon_view_set_layout_mode     (ExoIconView              *icon_view,
                                                         ExoIconViewLayoutMode     layout_mode);

gboolean         exo_icon_view_get_single_click (ExoIconView *icon_view);
void             exo_icon_view_set_single_click (ExoIconView *icon_view,
                                                 gboolean     single_click);
guint            exo_icon_view_get_single_click_timeout (ExoIconView *icon_view);
void             exo_icon_view_set_single_click_timeout (ExoIconView *icon_view,
                                                         guint  single_click_timeout);
void             exo_icon_view_select_path        (ExoIconView            *icon_view,
                                                   GtkTreePath            *path);
void             exo_icon_view_unselect_path      (ExoIconView            *icon_view,
                                                   GtkTreePath            *path);
gboolean         exo_icon_view_path_is_selected   (ExoIconView            *icon_view,
                                                   GtkTreePath            *path);
gint             exo_icon_view_get_item_row       (ExoIconView            *icon_view,
                                                   GtkTreePath            *path);
gint             exo_icon_view_get_item_column    (ExoIconView            *icon_view,
                                                   GtkTreePath            *path);
GList           *exo_icon_view_get_selected_items (ExoIconView            *icon_view);
void             exo_icon_view_select_all         (ExoIconView            *icon_view);
void             exo_icon_view_unselect_all       (ExoIconView            *icon_view);
void             exo_icon_view_item_activated     (ExoIconView            *icon_view,
                                                   GtkTreePath            *path);
void             exo_icon_view_set_cursor         (ExoIconView            *icon_view,
                                                   GtkTreePath            *path,
                                                   GtkCellRenderer        *cell,
                                                   gboolean                start_editing);
gboolean         exo_icon_view_get_cursor         (ExoIconView            *icon_view,
                                                   GtkTreePath           **path,
                                                   GtkCellRenderer       **cell);
void             exo_icon_view_scroll_to_path     (ExoIconView            *icon_view,
                                                   GtkTreePath            *path,
                                                   gboolean                use_align,
                                                   gfloat                  row_align,
                                                   gfloat                  col_align);

/* Drag-and-Drop support */
void                   exo_icon_view_enable_model_drag_source (ExoIconView              *icon_view,
                                                               GdkModifierType           start_button_mask,
                                                               const GtkTargetEntry     *targets,
                                                               gint                      n_targets,
                                                               GdkDragAction             actions);
void                   exo_icon_view_enable_model_drag_dest   (ExoIconView              *icon_view,
                                                               const GtkTargetEntry     *targets,
                                                               gint                      n_targets,
                                                               GdkDragAction             actions);
void                   exo_icon_view_unset_model_drag_source  (ExoIconView              *icon_view);
void                   exo_icon_view_unset_model_drag_dest    (ExoIconView              *icon_view);
void                   exo_icon_view_set_reorderable          (ExoIconView              *icon_view,
                                                               gboolean                  reorderable);
gboolean               exo_icon_view_get_reorderable          (ExoIconView              *icon_view);


/* These are useful to implement your own custom stuff. */
void                   exo_icon_view_set_drag_dest_item       (ExoIconView              *icon_view,
                                                               GtkTreePath              *path,
                                                               ExoIconViewDropPosition   pos);
void                   exo_icon_view_get_drag_dest_item       (ExoIconView              *icon_view,
                                                               GtkTreePath             **path,
                                                               ExoIconViewDropPosition  *pos);
gboolean               exo_icon_view_get_dest_item_at_pos     (ExoIconView              *icon_view,
                                                               gint                      drag_x,
                                                               gint                      drag_y,
                                                               GtkTreePath             **path,
                                                               ExoIconViewDropPosition  *pos);
cairo_surface_t       *exo_icon_view_create_drag_icon         (ExoIconView              *icon_view,
                                                               GtkTreePath              *path);

void    exo_icon_view_convert_widget_to_bin_window_coords     (ExoIconView *icon_view,
                                                               gint         wx,
                                                               gint         wy,
                                                               gint        *bx,
                                                               gint        *by);


void    exo_icon_view_set_tooltip_item                        (ExoIconView     *icon_view,
                                                               GtkTooltip      *tooltip,
                                                               GtkTreePath     *path);
void    exo_icon_view_set_tooltip_cell                        (ExoIconView     *icon_view,
                                                               GtkTooltip      *tooltip,
                                                               GtkTreePath     *path,
                                                               GtkCellRenderer *cell);
gboolean exo_icon_view_get_tooltip_context                    (ExoIconView       *icon_view,
                                                               gint              *x,
                                                               gint              *y,
                                                               gboolean           keyboard_tip,
                                                               GtkTreeModel     **model,
                                                               GtkTreePath      **path,
                                                               GtkTreeIter       *iter);
void    exo_icon_view_set_tooltip_column                     (ExoIconView       *icon_view,
                                                               gint               column);
gint    exo_icon_view_get_tooltip_column                     (ExoIconView       *icon_view);

void    exo_icon_view_invalidate_sizes                       (ExoIconView       *icon_view);

/* Interactive search */
void        exo_icon_view_set_enable_search     (ExoIconView    *icon_view,
                                                 gboolean       enable_search);
gboolean    exo_icon_view_get_enable_search     (ExoIconView    *icon_view);
gint        exo_icon_view_get_search_column     (ExoIconView    *icon_view);
void        exo_icon_view_set_search_column     (ExoIconView    *icon_view,
                                                 gint           column);
ExoIconViewSearchEqualFunc exo_icon_view_get_search_equal_func (ExoIconView     *icon_view);
void        exo_icon_view_set_search_equal_func (ExoIconView                    *icon_view,
                                                 ExoIconViewSearchEqualFunc     search_equal_func,
                                                 gpointer                       search_user_data,
                                                 GDestroyNotify                 search_destroy);

GtkEntry    *exo_icon_view_get_search_entry     (ExoIconView    *icon_view);
void        exo_icon_view_set_search_entry      (ExoIconView    *icon_view,
                                                 GtkEntry       *entry);
ExoIconViewSearchPositionFunc exo_icon_view_get_search_position_func (ExoIconView   *icon_view);
void        exo_icon_view_set_search_position_func (ExoIconView                     *icon_view,
                                                    ExoIconViewSearchPositionFunc   func,
                                                    gpointer                        data,
                                                    GDestroyNotify                  destroy);


G_END_DECLS

#endif /* __EXO_ICON_VIEW_H__ */
