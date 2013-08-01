/* marlin-dnd.c - Common Drag & drop handling code 
 *
 * Copyright (c) 2005-2006 Benedikt Meurer <benny@xfce.org>
 * Copyright (c) 2009-2011 Jannis Pohlmann <jannis@xfce.org>
 *
 * The Gnome Library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * The Gnome Library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with the Gnome Library; see the file COPYING.LIB.  If not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#include "marlin-dnd.h"

#include <glib/gi18n.h>
#include <stdio.h>
#include <string.h>
#include "eel-gtk-extensions.h"
#include "gof-file.h"

typedef struct
{
    GMainLoop *loop;
    GdkDragAction chosen;
} DropActionMenuData;

static void
menu_deactivate_callback (GtkWidget *menu,
                          gpointer   data)
{
    DropActionMenuData *damd;

    damd = data;

    if (g_main_loop_is_running (damd->loop))
        g_main_loop_quit (damd->loop);
}

static void
drop_action_activated_callback (GtkWidget  *menu_item,
                                gpointer    data)
{
    DropActionMenuData *damd;

    damd = data;

    damd->chosen = GPOINTER_TO_INT (g_object_get_data (G_OBJECT (menu_item),
                                                       "action"));

    if (g_main_loop_is_running (damd->loop))
        g_main_loop_quit (damd->loop);
}

static void
append_drop_action_menu_item (GtkWidget          *menu,
                              const char         *text,
                              GdkDragAction       action,
                              gboolean            sensitive,
                              DropActionMenuData *damd)
{
    GtkWidget *menu_item;

    menu_item = gtk_menu_item_new_with_mnemonic (text);
    gtk_widget_set_sensitive (menu_item, sensitive);
    gtk_menu_shell_append (GTK_MENU_SHELL (menu), menu_item);

    g_object_set_data (G_OBJECT (menu_item),
                       "action",
                       GINT_TO_POINTER (action));

    g_signal_connect (menu_item, "activate",
                      G_CALLBACK (drop_action_activated_callback),
                      damd);

    gtk_widget_show (menu_item);
}

/* Pops up a menu of actions to perform on dropped files */
GdkDragAction
marlin_drag_drop_action_ask (GtkWidget *widget,
                             GdkDragAction actions)
{
    GtkWidget *menu;
    GtkWidget *menu_item;
    DropActionMenuData damd;

    /* Create the menu and set the sensitivity of the items based on the
     * allowed actions.
     */
    menu = gtk_menu_new ();
    gtk_menu_set_screen (GTK_MENU (menu), gtk_widget_get_screen (widget));

    append_drop_action_menu_item (menu, _("_Move Here"),
                                  GDK_ACTION_MOVE,
                                  (actions & GDK_ACTION_MOVE) != 0,
                                  &damd);

    append_drop_action_menu_item (menu, _("_Copy Here"),
                                  GDK_ACTION_COPY,
                                  (actions & GDK_ACTION_COPY) != 0,
                                  &damd);

    append_drop_action_menu_item (menu, _("_Link Here"),
                                  GDK_ACTION_LINK,
                                  (actions & GDK_ACTION_LINK) != 0,
                                  &damd);

    append_drop_action_menu_item (menu, _("Set as _Background"),
                                  MARLIN_DND_ACTION_SET_AS_BACKGROUND,
                                  (actions & MARLIN_DND_ACTION_SET_AS_BACKGROUND) != 0,
                                  &damd);

    eel_gtk_menu_append_separator (GTK_MENU (menu));

    menu_item = gtk_menu_item_new_with_mnemonic (_("Cancel"));
    gtk_menu_shell_append (GTK_MENU_SHELL (menu), menu_item);
    gtk_widget_show (menu_item);

    damd.chosen = 0;
    damd.loop = g_main_loop_new (NULL, FALSE);

    g_signal_connect (menu, "deactivate",
                      G_CALLBACK (menu_deactivate_callback),
                      &damd);

    gtk_grab_add (menu);

    gtk_menu_popup (GTK_MENU (menu), NULL, NULL,
                    NULL, NULL, 0, GDK_CURRENT_TIME);

    g_main_loop_run (damd.loop);

    gtk_grab_remove (menu);

    g_main_loop_unref (damd.loop);

    g_object_ref_sink (menu);
    g_object_unref (menu);

    return damd.chosen;
}

/**
 * marlin_dnd_perform: (imported from thunar)
 * @widget            : the #GtkWidget on which the drop was done.
 * @file              : the #GOFFile on which the @file_list was dropped.
 * @file_list         : the list of #GFile<!---->s that was dropped.
 * @action            : the #GdkDragAction that was performed.
 * @new_files_closure : a #GClosure to connect to the job's "new-files" signal,
 *                      which will be emitted when the job finishes with the
 *                      list of #GFile<!---->s created by the job, or
 *                      %NULL if you're not interested in the signal.
 *
 * Performs the drop of @file_list on @file in @widget, as given in
 * @action and returns %TRUE if the drop was started successfully
 * (or even completed successfully), else %FALSE.
 *
 * Return value: %TRUE if the DnD operation was started
 *               successfully, else %FALSE.
**/
gboolean
marlin_dnd_perform (GtkWidget       *widget,
                    GOFFile         *file,
                    GList           *file_list,
                    GdkDragAction   action,
                    GClosure        *new_files_closure)
{
    gboolean           succeed = TRUE;
    GError            *error = NULL;

    g_return_val_if_fail (GTK_IS_WIDGET (widget), FALSE);
    g_return_val_if_fail (GOF_IS_FILE (file), FALSE);
    g_return_val_if_fail (gtk_widget_get_realized (widget), FALSE);

#if 0
    /* check if the file is a directory */
    if (file->is_directory)
    {
        switch (action)
        {
        case GDK_ACTION_COPY:
            break;

        case GDK_ACTION_MOVE:
            break;

        case GDK_ACTION_LINK:
            break;

        default:
            succeed = FALSE;
        }
    }
#endif
    if (gof_file_is_folder (file))
    {
        printf ("%s marlin_file_operation_copy_move\n", G_STRFUNC);
        marlin_file_operations_copy_move (file_list, NULL, gof_file_get_target_location (file),
                                          action, widget, NULL, NULL);
    }
    else if (gof_file_is_executable (file))
    {
        succeed = gof_file_execute (file, gtk_widget_get_screen (widget), file_list, &error);
        if (G_UNLIKELY (!succeed))
        {
            /* display an error to the user */
            marlin_dialogs_show_error (widget, error, _("Failed to execute file \"%s\""), gof_file_get_display_name (file));

            /* release the error */
            g_error_free (error);
        }
    }
    else
    {
        succeed = FALSE;
    }

    return succeed;
}


