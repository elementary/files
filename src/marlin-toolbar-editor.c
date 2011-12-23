/*
 * Copyright (C) 2009 Enrico Tröger <enrico(dot)troeger(at)uvena(dot)de>
 * Copyright (C) 2010 ammonkey
 *
 * Marlin is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * Marlin is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; see the file COPYING.  If not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Code originaly coming from the toolbar editor of Midori adpated to rhythmbox
 * by ammonkey
 *
 * Authors: Enrico Tröger <enrico(dot)troeger(at)uvena(dot)de>
 *          ammonkey <am.monkeyd@gmail.com>
 *
 */

#include <config.h>

#include <glib/gi18n.h>

#include "marlin-toolbar-editor.h"
#include "marlin-global-preferences.h"

typedef struct
{
    GtkWidget *dialog;

    GtkTreeView *tree_available;
    GtkTreeView *tree_used;

    GtkListStore *store_available;
    GtkListStore *store_used;

    GtkTreePath *last_drag_path;
    GtkTreeViewDropPosition last_drag_pos;

    GtkWidget *drag_source;

    MarlinViewWindow *mvw;
} TBEditorWidget;

enum
{
    TB_EDITOR_COL_ACTION,
    TB_EDITOR_COL_LABEL,
    TB_EDITOR_COL_ICON,
    TB_EDITOR_COLS_MAX
};

#define CONF_UI_TOOLBAR_ITEMS "toolbar-items"

static const GtkTargetEntry tb_editor_dnd_targets[] =
{
    { "RB_TB_EDITOR_ROW", 0, 0 }
};
static const gint tb_editor_dnd_targets_len = G_N_ELEMENTS(tb_editor_dnd_targets);

/**
 * katze_strip_mnemonics:
 * @original: a string with mnemonics
 *
 * Parses the given string for mnemonics in the form
 * "B_utton" or "Button (_U)" and returns a string
 * without any mnemonics.
 *
 * Return value: a newly allocated string without mnemonics
 *
 * Since: 0.1.8
**/
static gchar*
katze_strip_mnemonics (const gchar* original)
{
    /* A copy of _gtk_toolbar_elide_underscores
       Copyright (C) 1995-1997 Peter Mattis, Spencer Kimball and Josh MacDonald
       Copied from GTK+ 2.17.1 */
    gchar *q, *result;
    const gchar *p, *end;
    gsize len;
    gboolean last_underscore;

    if (!original)
        return NULL;

    len = strlen (original);
    q = result = g_malloc (len + 1);
    last_underscore = FALSE;

    end = original + len;
    for (p = original; p < end; p++)
    {
        if (!last_underscore && *p == '_')
            last_underscore = TRUE;
        else
        {
            last_underscore = FALSE;
            if (original + 2 <= p && p + 1 <= end &&
                p[-2] == '(' && p[-1] == '_' && p[0] != '_' && p[1] == ')')
            {
                q--;
                *q = '\0';
                p++;
            }
            else
                *q++ = *p;
        }
    }

    if (last_underscore)
        *q++ = '_';

    *q = '\0';

    return result;
}

/**
 * katze_object_get_string:
 * @object: a #GObject
 * @property: the name of the property to get
 *
 * Retrieve the string value of the specified property.
 *
 * Return value: a newly allocated string
**/
static gchar*
katze_object_get_string (gpointer     object,
                         const gchar* property)
{
    gchar* value = NULL;

    g_return_val_if_fail (G_IS_OBJECT (object), NULL);
    /* FIXME: Check value type */

    g_object_get (object, property, &value, NULL);
    return value;
}


static void tb_editor_set_item_values(TBEditorWidget *tbw, const gchar *action_name,
                                      GtkListStore *store, GtkTreeIter *iter)
{
    gchar *icon = NULL;
    gchar *label = NULL;
    gchar *label_clean = NULL;
    GdkPixbuf *pix = NULL;
    GtkAction *action;

    action = gtk_action_group_get_action(marlin_view_window_get_actiongroup(tbw->mvw), action_name);

    if (action != NULL)
    {
        /*gtk_action_block_activate(action);
          log_printf (LOG_LEVEL_UNDEFINED, "blocked %s\n", action_name);*/
        icon = katze_object_get_string(action, "icon-name");
        if (icon == NULL)
        {
            icon = katze_object_get_string(action, "stock-id");
        }

        label = katze_object_get_string(action, "label");
        if (label != NULL)
            label_clean = katze_strip_mnemonics(label);
    }
    else
        label_clean = strdup(action_name);


    GtkIconTheme *icon_theme = gtk_icon_theme_get_default ();
    /*GtkIconInfo *icon_info = gtk_icon_theme_lookup_icon (icon_theme, icon, 16,
      GTK_ICON_LOOKUP_USE_BUILTIN | GTK_ICON_LOOKUP_GENERIC_FALLBACK | GTK_ICON_LOOKUP_FORCE_SIZE);
      gchar *test;
      test = gtk_icon_info_get_filename (icon_info);
    //log_printf (LOG_LEVEL_UNDEFINED, "action: %20s icon: %20s\n", action_name, icon);
    log_printf (LOG_LEVEL_UNDEFINED, "action: %20s icon: %20s test: %s\n", action_name, icon, test);*/


    if (icon != NULL)
    {
        //GtkIconSize status_btn_size = gtk_icon_size_from_name ("16px");
        GtkWidget *image = gtk_image_new ();
        //pix = gtk_widget_render_icon (image, icon, status_btn_size, NULL);
        pix = gtk_widget_render_icon (image, icon, GTK_ICON_SIZE_MENU, NULL);
        gtk_widget_destroy (image);

        if (pix==NULL && icon!=NULL)
            pix = gtk_icon_theme_load_icon (icon_theme, icon, 16,
                                            GTK_ICON_LOOKUP_USE_BUILTIN | GTK_ICON_LOOKUP_GENERIC_FALLBACK | GTK_ICON_LOOKUP_FORCE_SIZE, NULL);
    }

    gtk_list_store_set(store, iter,
                       TB_EDITOR_COL_ACTION, action_name,
                       TB_EDITOR_COL_LABEL, label_clean,
                       //TB_EDITOR_COL_LABEL, action_name,
                       TB_EDITOR_COL_ICON, pix,
                       -1);

    g_free(icon);
    g_free(label);
    g_free(label_clean);
}

static void tb_editor_scroll_to_iter(GtkTreeView *treeview, GtkTreeIter *iter)
{
    GtkTreePath *path = gtk_tree_model_get_path(gtk_tree_view_get_model(treeview), iter);
    gtk_tree_view_scroll_to_cell(treeview, path, NULL, TRUE, 0.5, 0.0);
    gtk_tree_path_free(path);
}

static void tb_editor_free_path(TBEditorWidget *tbw)
{
    gtk_tree_path_free(tbw->last_drag_path);
    tbw->last_drag_path = NULL;
}

static void tb_editor_btn_remove_clicked_cb(GtkWidget *button, TBEditorWidget *tbw)
{
    GtkTreeModel *model_used;
    GtkTreeSelection *selection_used;
    GtkTreeIter iter_used, iter_new;
    gchar *action_name;

    selection_used = gtk_tree_view_get_selection(tbw->tree_used);
    if (gtk_tree_selection_get_selected(selection_used, &model_used, &iter_used))
    {
        gtk_tree_model_get(model_used, &iter_used, TB_EDITOR_COL_ACTION, &action_name, -1);
        if (g_strcmp0(action_name, "Location") != 0)
        {
            if (gtk_list_store_remove(tbw->store_used, &iter_used))
                gtk_tree_selection_select_iter(selection_used, &iter_used);

            if (g_strcmp0(action_name, "Separator") != 0)
            {
                gtk_list_store_append(tbw->store_available, &iter_new);
                tb_editor_set_item_values(tbw, action_name, tbw->store_available, &iter_new);
                tb_editor_scroll_to_iter(tbw->tree_available, &iter_new);
            }
        }
        g_free(action_name);
    }
}

static void tb_editor_btn_add_clicked_cb(GtkWidget *button, TBEditorWidget *tbw)
{
    GtkTreeModel *model_available;
    GtkTreeSelection *selection_available, *selection_used;
    GtkTreeIter iter_available, iter_new, iter_selected;
    gchar *action_name;

    selection_available = gtk_tree_view_get_selection(tbw->tree_available);
    if (gtk_tree_selection_get_selected(selection_available, &model_available, &iter_available))
    {
        gtk_tree_model_get(model_available, &iter_available, TB_EDITOR_COL_ACTION, &action_name, -1);
        if (g_strcmp0(action_name, "Separator") != 0)
        {
            if (gtk_list_store_remove(tbw->store_available, &iter_available))
                gtk_tree_selection_select_iter(selection_available, &iter_available);
        }

        selection_used = gtk_tree_view_get_selection(tbw->tree_used);
        if (gtk_tree_selection_get_selected(selection_used, NULL, &iter_selected))
        {
            gtk_list_store_insert_before(tbw->store_used, &iter_new, &iter_selected);
            tb_editor_set_item_values(tbw, action_name, tbw->store_used, &iter_new);
        }
        else
        {
            gtk_list_store_append(tbw->store_used, &iter_new);
            tb_editor_set_item_values(tbw, action_name, tbw->store_used, &iter_new);
        }

        tb_editor_scroll_to_iter(tbw->tree_used, &iter_new);

        g_free(action_name);
    }
}

static gboolean tb_editor_drag_motion_cb(GtkWidget *widget, GdkDragContext *drag_context,
                                         gint x, gint y, guint ltime, TBEditorWidget *tbw)
{
    gtk_tree_path_free(tbw->last_drag_path);
    gtk_tree_view_get_drag_dest_row(GTK_TREE_VIEW(widget),
                                    &(tbw->last_drag_path), &(tbw->last_drag_pos));

    return FALSE;
}


static void tb_editor_drag_data_get_cb(GtkWidget *widget, GdkDragContext *context,
                                       GtkSelectionData *data, guint info, guint ltime,
                                       TBEditorWidget *tbw)
{
    GtkTreeIter iter;
    GtkTreeSelection *selection;
    GtkTreeModel *model;
    GdkAtom atom;
    gchar *name;

    selection = gtk_tree_view_get_selection(GTK_TREE_VIEW(widget));
    if (! gtk_tree_selection_get_selected(selection, &model, &iter))
        return;

    gtk_tree_model_get(model, &iter, TB_EDITOR_COL_ACTION, &name, -1);
    if (name == NULL || *name == '\0')
    {
        g_free(name);
        return;
    }

    atom = gdk_atom_intern(tb_editor_dnd_targets[0].target, FALSE);
    gtk_selection_data_set(data, atom, 8, (guchar*) name, strlen(name));

    g_free(name);

    tbw->drag_source = widget;
}


static void tb_editor_drag_data_rcvd_cb(GtkWidget *widget, GdkDragContext *context,
                                        gint x, gint y, GtkSelectionData *data, guint info,
                                        guint ltime, TBEditorWidget *tbw)
{
    GtkTreeView *tree = GTK_TREE_VIEW(widget);
    gboolean del = FALSE;

    if (gtk_selection_data_get_target (data) != GDK_NONE )
    {
        gboolean is_sep;
        const guchar *text = gtk_selection_data_get_data (data);

        is_sep = (g_strcmp0(text, "Separator") == 0);
        /* If the source of the action is equal to the target, we do just re-order and
        ** so need to delete the separator to get it moved, not just copied. */
        if (is_sep && widget == tbw->drag_source)
            is_sep = FALSE;

        if (tree != tbw->tree_available || ! is_sep)
        {
            GtkTreeIter iter, iter_before, *iter_before_ptr;
            GtkListStore *store = GTK_LIST_STORE(gtk_tree_view_get_model(tree));

            if (tbw->last_drag_path != NULL)
            {
                gtk_tree_model_get_iter(GTK_TREE_MODEL(store), &iter_before, tbw->last_drag_path);

                if (gtk_list_store_iter_is_valid(store, &iter_before))
                    iter_before_ptr = &iter_before;
                else
                    iter_before_ptr = NULL;

                if (tbw->last_drag_pos == GTK_TREE_VIEW_DROP_BEFORE ||
                    tbw->last_drag_pos == GTK_TREE_VIEW_DROP_INTO_OR_BEFORE)
                    gtk_list_store_insert_before(store, &iter, iter_before_ptr);
                else
                    gtk_list_store_insert_after(store, &iter, iter_before_ptr);

                tb_editor_set_item_values(tbw, text, store, &iter);
            }
            else
            {
                gtk_list_store_append(store, &iter);
                tb_editor_set_item_values(tbw, text, store, &iter);
            }

            tb_editor_scroll_to_iter(tree, &iter);
        }
        if (tree != tbw->tree_used || ! is_sep)
            del = TRUE;
    }

    tbw->drag_source = NULL; /* reset the value just to be sure */
    tb_editor_free_path(tbw);
    gtk_drag_finish(context, TRUE, del, ltime);
}

static gboolean tb_editor_foreach_used(GtkTreeModel *model, GtkTreePath *path,
                                       GtkTreeIter *iter, gpointer data)
{
    gchar *action_name;

    gtk_tree_model_get(model, iter, TB_EDITOR_COL_ACTION, &action_name, -1);

    if (action_name != NULL && *action_name != '\0')
    {
        g_string_append(data, action_name);
        g_string_append_c(data, ',');
    }

    g_free(action_name);
    return FALSE;
}

static void tb_editor_update_toolbar(TBEditorWidget *tbw)
{
    GString *str = g_string_new(NULL);
    char *tmp;
    int len;

    gtk_tree_model_foreach(GTK_TREE_MODEL(tbw->store_used), tb_editor_foreach_used, str);

    /* removing the last character ',' */
    tmp = str->str;
    len = strlen(tmp);
    tmp[len-1] = 0;

    char **used_items = g_strsplit(tmp ? tmp : "", ",", 0);
    g_settings_set_strv (settings, CONF_UI_TOOLBAR_ITEMS, (const char * const *) used_items);
    marlin_view_window_set_toolbar_items (tbw->mvw);

    g_string_free(str, TRUE);
    g_strfreev (used_items);
}

static void tb_editor_available_items_changed_cb(GtkTreeModel *model, GtkTreePath *arg1,
                                                 GtkTreeIter *arg2, TBEditorWidget *tbw)
{
    tb_editor_update_toolbar(tbw);
}


static void tb_editor_available_items_deleted_cb(GtkTreeModel *model, GtkTreePath *arg1,
                                                 TBEditorWidget *tbw)
{
    tb_editor_update_toolbar(tbw);
}

static TBEditorWidget *tb_editor_create_dialog(MarlinViewWindow *mvw)
{
    GtkWidget *dialog, *vbox, *hbox, *vbox_buttons, *button_add, *button_remove;
    GtkWidget *swin_available, *swin_used, *tree_available, *tree_used, *label;
    GtkCellRenderer *text_renderer, *icon_renderer;
    GtkTreeViewColumn *column;
    TBEditorWidget *tbw = g_new(TBEditorWidget, 1);

    dialog = gtk_dialog_new_with_buttons(_("Customize Toolbar"),
                                         GTK_WINDOW (mvw),
                                         GTK_DIALOG_DESTROY_WITH_PARENT,
                                         GTK_STOCK_CLOSE, GTK_RESPONSE_CLOSE, NULL);
    vbox = gtk_dialog_get_content_area(GTK_DIALOG(dialog));
    gtk_box_set_spacing(GTK_BOX(vbox), 6);
    gtk_widget_set_name(dialog, "GeanyDialog");
    gtk_window_set_default_size(GTK_WINDOW(dialog), -1, 400);
    gtk_dialog_set_default_response(GTK_DIALOG(dialog), GTK_RESPONSE_CLOSE);

    tbw->store_available = gtk_list_store_new(TB_EDITOR_COLS_MAX,
                                              G_TYPE_STRING, G_TYPE_STRING, GDK_TYPE_PIXBUF);
    tbw->store_used = gtk_list_store_new(TB_EDITOR_COLS_MAX,
                                         G_TYPE_STRING, G_TYPE_STRING, GDK_TYPE_PIXBUF);

    label = gtk_label_new(
                          _("Select items to be displayed on the toolbar. Items can be reordered by drag and drop."));
    gtk_misc_set_alignment(GTK_MISC(label), 0.0, 0.5);

    tree_available = gtk_tree_view_new();
    gtk_tree_view_set_model(GTK_TREE_VIEW(tree_available), GTK_TREE_MODEL(tbw->store_available));
    gtk_tree_view_set_rules_hint(GTK_TREE_VIEW(tree_available), TRUE);
    gtk_tree_sortable_set_sort_column_id(
                                         GTK_TREE_SORTABLE(tbw->store_available), TB_EDITOR_COL_LABEL, GTK_SORT_ASCENDING);

    icon_renderer = gtk_cell_renderer_pixbuf_new();
    column = gtk_tree_view_column_new_with_attributes(
                                                      NULL, icon_renderer, "pixbuf", TB_EDITOR_COL_ICON, NULL);
    gtk_tree_view_append_column(GTK_TREE_VIEW(tree_available), column);

    text_renderer = gtk_cell_renderer_text_new();
    column = gtk_tree_view_column_new_with_attributes(
                                                      _("Available Items"), text_renderer, "text", TB_EDITOR_COL_LABEL, NULL);
    gtk_tree_view_append_column(GTK_TREE_VIEW(tree_available), column);

    swin_available = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(swin_available),
                                   GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC);
    gtk_scrolled_window_set_shadow_type(GTK_SCROLLED_WINDOW(swin_available), GTK_SHADOW_ETCHED_IN);
    gtk_container_add(GTK_CONTAINER(swin_available), tree_available);

    tree_used = gtk_tree_view_new();
    gtk_tree_view_set_model(GTK_TREE_VIEW(tree_used), GTK_TREE_MODEL(tbw->store_used));
    gtk_tree_view_set_rules_hint(GTK_TREE_VIEW(tree_used), TRUE);
    gtk_tree_view_set_reorderable(GTK_TREE_VIEW(tree_used), TRUE);

    icon_renderer = gtk_cell_renderer_pixbuf_new();
    column = gtk_tree_view_column_new_with_attributes(
                                                      NULL, icon_renderer, "pixbuf", TB_EDITOR_COL_ICON, NULL);
    gtk_tree_view_append_column(GTK_TREE_VIEW(tree_used), column);

    text_renderer = gtk_cell_renderer_text_new();
    column = gtk_tree_view_column_new_with_attributes(
                                                      _("Displayed Items"), text_renderer, "text", TB_EDITOR_COL_LABEL, NULL);
    gtk_tree_view_append_column(GTK_TREE_VIEW(tree_used), column);

    swin_used = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(swin_used),
                                   GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC);
    gtk_scrolled_window_set_shadow_type(GTK_SCROLLED_WINDOW(swin_used), GTK_SHADOW_ETCHED_IN);
    gtk_container_add(GTK_CONTAINER(swin_used), tree_used);

    /* drag'n'drop */
    gtk_tree_view_enable_model_drag_source(GTK_TREE_VIEW(tree_available), GDK_BUTTON1_MASK,
                                           tb_editor_dnd_targets, tb_editor_dnd_targets_len, GDK_ACTION_MOVE);
    gtk_tree_view_enable_model_drag_dest(GTK_TREE_VIEW(tree_available),
                                         tb_editor_dnd_targets, tb_editor_dnd_targets_len, GDK_ACTION_MOVE);
    g_signal_connect(tree_available, "drag-data-get",
                     G_CALLBACK(tb_editor_drag_data_get_cb), tbw);
    g_signal_connect(tree_available, "drag-data-received",
                     G_CALLBACK(tb_editor_drag_data_rcvd_cb), tbw);
    g_signal_connect(tree_available, "drag-motion",
                     G_CALLBACK(tb_editor_drag_motion_cb), tbw);

    gtk_tree_view_enable_model_drag_source(GTK_TREE_VIEW(tree_used), GDK_BUTTON1_MASK,
                                           tb_editor_dnd_targets, tb_editor_dnd_targets_len, GDK_ACTION_MOVE);
    gtk_tree_view_enable_model_drag_dest(GTK_TREE_VIEW(tree_used),
                                         tb_editor_dnd_targets, tb_editor_dnd_targets_len, GDK_ACTION_MOVE);
    g_signal_connect(tree_used, "drag-data-get",
                     G_CALLBACK(tb_editor_drag_data_get_cb), tbw);
    g_signal_connect(tree_used, "drag-data-received",
                     G_CALLBACK(tb_editor_drag_data_rcvd_cb), tbw);
    g_signal_connect(tree_used, "drag-motion",
                     G_CALLBACK(tb_editor_drag_motion_cb), tbw);


    button_add = gtk_button_new();
    gtk_button_set_image(GTK_BUTTON(button_add),
                         gtk_image_new_from_stock(GTK_STOCK_GO_FORWARD, GTK_ICON_SIZE_BUTTON));
    button_remove = gtk_button_new();
    g_signal_connect(button_add, "clicked", G_CALLBACK(tb_editor_btn_add_clicked_cb), tbw);
    gtk_button_set_image(GTK_BUTTON(button_remove),
                         gtk_image_new_from_stock(GTK_STOCK_GO_BACK, GTK_ICON_SIZE_BUTTON));
    g_signal_connect(button_remove, "clicked", G_CALLBACK(tb_editor_btn_remove_clicked_cb), tbw);

    vbox_buttons = gtk_vbox_new(FALSE, 6);
    /* FIXME this is a little hack'ish, any better ideas? */
    gtk_box_pack_start(GTK_BOX(vbox_buttons), gtk_label_new(""), TRUE, TRUE, 0);
    gtk_box_pack_start(GTK_BOX(vbox_buttons), button_add, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(vbox_buttons), button_remove, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(vbox_buttons), gtk_label_new(""), TRUE, TRUE, 0);

    hbox = gtk_hbox_new(FALSE, 6);
    gtk_box_pack_start(GTK_BOX(hbox), swin_available, TRUE, TRUE, 0);
    gtk_box_pack_start(GTK_BOX(hbox), vbox_buttons, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(hbox), swin_used, TRUE, TRUE, 0);

    gtk_box_pack_start(GTK_BOX(vbox), label, FALSE, FALSE, 6);
    gtk_box_pack_start(GTK_BOX(vbox), hbox, TRUE, TRUE, 0);

    gtk_widget_show_all(vbox);

    g_object_unref(tbw->store_available);
    g_object_unref(tbw->store_used);

    tbw->dialog = dialog;
    tbw->tree_available = GTK_TREE_VIEW(tree_available);
    tbw->tree_used = GTK_TREE_VIEW(tree_used);

    tbw->last_drag_path = NULL;

    return tbw;
}

static char**
rb_get_toolbar_actions ()
{
    static char* actions[] = {
        "Back","Forward","Up","LocationEntry",
        "Separator","ViewSwitcher",
        NULL };

    return actions;
}

static gboolean
find_in_used_items(char **used_items, char *name)
{
    char **used_item;

    for (used_item=used_items; *used_item; used_item++)
        if (!strcmp (*used_item, name))
            return TRUE;
    return FALSE;
}

void
marlin_toolbar_editor_dialog_show (MarlinViewWindow *mvw)
{
    GtkTreeIter iter;
    GtkTreePath *path;
    TBEditorWidget *tbw;
    char **used_item;
    char **used_items;
    char **all_items;
    char **all_item;

    /* read the current active toolbar items */
    used_items = g_settings_get_strv (settings, CONF_UI_TOOLBAR_ITEMS);

    /* get all available actions */
    all_items = rb_get_toolbar_actions ();

    /* create the GUI */
    tbw = tb_editor_create_dialog(mvw);

    /* cache some pointers, this is safe enough since the dialog is run modally */
    tbw->mvw = mvw;

    /* fill the stores */
    for (all_item=all_items; *all_item; all_item++)
    {
        if (strcmp(*all_item, "Separator") == 0 ||
            !find_in_used_items(used_items, *all_item))
        {
            gtk_list_store_append(tbw->store_available, &iter);
            tb_editor_set_item_values(tbw, *all_item, tbw->store_available, &iter);
        }
    }
    for (used_item=used_items; *used_item; used_item++)
    {
        gtk_list_store_append(tbw->store_used, &iter);
        tb_editor_set_item_values(tbw, *used_item, tbw->store_used, &iter);
    }

    /* connect the changed signals after populating the store */
    g_signal_connect(tbw->store_used, "row-changed",
                     G_CALLBACK(tb_editor_available_items_changed_cb), tbw);
    g_signal_connect(tbw->store_used, "row-deleted",
                     G_CALLBACK(tb_editor_available_items_deleted_cb), tbw);

    /* run it */
    gtk_dialog_run(GTK_DIALOG(tbw->dialog));

    gtk_widget_destroy(tbw->dialog);

    g_strfreev (used_items);
    tb_editor_free_path(tbw);
    g_free(tbw);
}

