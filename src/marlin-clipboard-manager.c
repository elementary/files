/* $Id$ */
/*-
 * Imported from thunar
 * Copyright (c) 2005-2006 Benedikt Meurer <benny@xfce.org>
 * Copyright (c) 2009 Jannis Pohlmann <jannis@xfce.org>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2 of the License, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program; if not, write to the Free Software Foundation, Inc., 59 Temple
 * Place, Suite 330, Boston, MA  02111-1307  USA
 */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#ifdef HAVE_MEMORY_H
#include <memory.h>
#endif
#ifdef HAVE_STRING_H
#include <string.h>
#endif

#include "marlin-clipboard-manager.h"
#include <glib.h>
#include <glib/gi18n.h>
#include "eel-stock-dialogs.h"

/*#include <thunar/thunar-application.h>
#include <thunar/thunar-clipboard-manager.h>
#include <thunar/thunar-dialogs.h>
#include <thunar/thunar-gobject-extensions.h>
#include <thunar/thunar-private.h>*/


enum
{
    PROP_0,
    PROP_CAN_PASTE,
};

enum
{
    CHANGED,
    LAST_SIGNAL,
};

enum
{
    TARGET_GNOME_COPIED_FILES,
    TARGET_UTF8_STRING,
};



static void marlin_clipboard_manager_finalize           (GObject                     *object);
static void marlin_clipboard_manager_get_property       (GObject                     *object,
                                                         guint                        prop_id,
                                                         GValue                      *value,
                                                         GParamSpec                  *pspec);
static void marlin_clipboard_manager_file_destroyed     (GOFFile                  *file,
                                                         MarlinClipboardManager      *manager);
static void marlin_clipboard_manager_owner_changed      (GtkClipboard                *clipboard,
                                                         GdkEventOwnerChange         *event,
                                                         MarlinClipboardManager      *manager);
static void marlin_clipboard_manager_contents_received  (GtkClipboard                *clipboard,
                                                         GtkSelectionData            *selection_data,
                                                         gpointer                     user_data);
static void marlin_clipboard_manager_targets_received   (GtkClipboard                *clipboard,
                                                         GtkSelectionData            *selection_data,
                                                         gpointer                     user_data);
static void marlin_clipboard_manager_get_callback       (GtkClipboard                *clipboard,
                                                         GtkSelectionData            *selection_data,
                                                         guint                        info,
                                                         gpointer                     user_data);
static void marlin_clipboard_manager_clear_callback     (GtkClipboard                *clipboard,
                                                         gpointer                     user_data);
static void marlin_clipboard_manager_transfer_files     (MarlinClipboardManager      *manager,
                                                         gboolean                     copy,
                                                         GList                       *files);



struct _MarlinClipboardManagerClass
{
    GObjectClass __parent__;

    void (*changed) (MarlinClipboardManager *manager);
};

struct _MarlinClipboardManager
{
    GObject __parent__;

    GtkClipboard *clipboard;
    gboolean      can_paste;
    GdkAtom       x_special_gnome_copied_files;

    gboolean      files_cutted;
    GList        *files;
};

typedef struct
{
    MarlinClipboardManager *manager;
    GFile                  *target_file;
    GtkWidget              *widget;
    GCallback               *new_files_closure;
} MarlinClipboardPasteRequest;



static const GtkTargetEntry clipboard_targets[] =
{
    { "x-special/gnome-copied-files", 0, TARGET_GNOME_COPIED_FILES },
    { "UTF8_STRING", 0, TARGET_UTF8_STRING }
};

static GQuark marlin_clipboard_manager_quark = 0;
static guint  manager_signals[LAST_SIGNAL];



G_DEFINE_TYPE (MarlinClipboardManager, marlin_clipboard_manager, G_TYPE_OBJECT)



static void
marlin_clipboard_manager_class_init (MarlinClipboardManagerClass *klass)
{
    GObjectClass *gobject_class;

    gobject_class = G_OBJECT_CLASS (klass);
    gobject_class->finalize = marlin_clipboard_manager_finalize;
    gobject_class->get_property = marlin_clipboard_manager_get_property;

    /**
     * MarlinClipboardManager:can-paste:
     *
     * This property tells whether the current clipboard content of
     * this #MarlinClipboardManager can be pasted into a folder
     * displayed by a #MarlinView.
    **/
    g_object_class_install_property (gobject_class,
                                     PROP_CAN_PASTE,
                                     g_param_spec_boolean ("can-paste", "can-paste", "can-paste",
                                                           FALSE,
                                                           G_PARAM_READABLE));
    //amtest
    // EXO_PARAM_READABLE));

    /**
     * MarlinClipboardManager::changed:
     * @manager : a #MarlinClipboardManager.
     *
     * This signal is emitted whenever the contents of the
     * clipboard associated with @manager changes.
    **/
    manager_signals[CHANGED] =
        g_signal_new ("changed",
                      G_TYPE_FROM_CLASS (klass),
                      G_SIGNAL_RUN_FIRST,
                      G_STRUCT_OFFSET (MarlinClipboardManagerClass, changed),
                      NULL, NULL,
                      g_cclosure_marshal_VOID__VOID,
                      G_TYPE_NONE, 0);
}



static void
marlin_clipboard_manager_init (MarlinClipboardManager *manager)
{
    manager->x_special_gnome_copied_files = gdk_atom_intern_static_string ("x-special/gnome-copied-files");
}



static void
marlin_clipboard_manager_finalize (GObject *object)
{
    MarlinClipboardManager *manager = MARLIN_CLIPBOARD_MANAGER (object);
    GList                  *lp;

    /* release any pending files */
    for (lp = manager->files; lp != NULL; lp = lp->next)
    {
        g_signal_handlers_disconnect_by_func (G_OBJECT (lp->data), marlin_clipboard_manager_file_destroyed, manager);
        g_object_unref (G_OBJECT (lp->data));
    }
    g_list_free (manager->files);

    /* disconnect from the clipboard */
    g_signal_handlers_disconnect_by_func (G_OBJECT (manager->clipboard), marlin_clipboard_manager_owner_changed, manager);
    g_object_set_qdata (G_OBJECT (manager->clipboard), marlin_clipboard_manager_quark, NULL);
    g_object_unref (G_OBJECT (manager->clipboard));

    (*G_OBJECT_CLASS (marlin_clipboard_manager_parent_class)->finalize) (object);
}



static void
marlin_clipboard_manager_get_property (GObject    *object,
                                       guint       prop_id,
                                       GValue     *value,
                                       GParamSpec *pspec)
{
    MarlinClipboardManager *manager = MARLIN_CLIPBOARD_MANAGER (object);

    switch (prop_id)
    {
    case PROP_CAN_PASTE:
        g_value_set_boolean (value, marlin_clipboard_manager_get_can_paste (manager));
        break;

    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
        break;
    }
}



static void
marlin_clipboard_manager_file_destroyed (GOFFile             *file,
                                         MarlinClipboardManager *manager)
{
    g_return_if_fail (MARLIN_IS_CLIPBOARD_MANAGER (manager));
    g_return_if_fail (g_list_find (manager->files, file) != NULL);

    /* remove the file from our list */
    manager->files = g_list_remove (manager->files, file);

    /* disconnect from the file */
    g_signal_handlers_disconnect_by_func (G_OBJECT (file), marlin_clipboard_manager_file_destroyed, manager);
    g_object_unref (G_OBJECT (file));
}



static void
marlin_clipboard_manager_owner_changed (GtkClipboard           *clipboard,
                                        GdkEventOwnerChange    *event,
                                        MarlinClipboardManager *manager)
{
    g_return_if_fail (GTK_IS_CLIPBOARD (clipboard));
    g_return_if_fail (MARLIN_IS_CLIPBOARD_MANAGER (manager));
    g_return_if_fail (manager->clipboard == clipboard);

    /* need to take a reference on the manager, because the clipboards
     * "targets received callback" mechanism is not cancellable.
     */
    g_object_ref (G_OBJECT (manager));

    /* request the list of supported targets from the new owner */
    gtk_clipboard_request_contents (clipboard, gdk_atom_intern_static_string ("TARGETS"),
                                    marlin_clipboard_manager_targets_received, manager);
}

static GList *
convert_lines_to_gfile_list (char **lines)
{
    int i;
    GList *result;

    if (lines[0] == NULL) {
        return NULL;
    }

    result = NULL;
    for (i=0; lines[i] != NULL; i++) {
        //printf ("lines %d: %s\n", i, lines[i]);
        //result = g_list_prepend (result, g_strdup (lines[i]));
        result = g_list_prepend (result, g_file_new_for_uri (lines[i]));
    }
    return g_list_reverse (result);
}

static void
marlin_clipboard_manager_contents_received (GtkClipboard     *clipboard,
                                            GtkSelectionData *selection_data,
                                            gpointer          user_data)
{
    g_debug ("%s\n", G_STRFUNC);
    MarlinClipboardPasteRequest *request = user_data;
    MarlinClipboardManager      *manager = MARLIN_CLIPBOARD_MANAGER (request->manager);
    gboolean                     path_copy = TRUE;
    GList                       *file_list = NULL;
    char                        **lines;
    gchar                       *data;

    /* check whether the retrieval worked */
    if (G_LIKELY (gtk_selection_data_get_length (selection_data) > 0))
    {
        /* be sure the selection data is zero-terminated */
        data = (gchar *) gtk_selection_data_get_data (selection_data);
        data[gtk_selection_data_get_length (selection_data)] = '\0';

        /* check whether to copy or move */
        if (g_ascii_strncasecmp (data, "copy", 4) == 0)
        {
            path_copy = TRUE;
            data += 5;
        }
        else if (g_ascii_strncasecmp (data, "cut", 3) == 0)
        {
            path_copy = FALSE;
            data += 4;
        }

        /* get uris list from selection_data */
        lines = g_strsplit (data, "\n", 0);
        file_list = convert_lines_to_gfile_list (lines);
        g_strfreev (lines);
    }

    /* perform the action if possible */
    if (G_LIKELY (file_list != NULL))
    {
        //application = marlin_application_get ();
        //TODO
        if (G_LIKELY (path_copy))
        {
            //marlin_application_copy_into (application, request->widget, file_list, request->target_file, request->new_files_closure);
            g_debug ("marlin_application_copy_into\n");
            /*marlin_file_operations_copy (file_list, NULL, request->target_file,
              NULL, NULL, NULL);*/
            marlin_file_operations_copy_move (file_list, NULL, request->target_file,
                                              GDK_ACTION_COPY, NULL, request->new_files_closure, request->widget);

        } else {
            g_debug ("marlin_application_move_into\n");
            //marlin_application_move_into (application, request->widget, file_list, request->target_file, request->new_files_closure);
            marlin_file_operations_copy_move (file_list, NULL, request->target_file,
                                              GDK_ACTION_MOVE, NULL, request->new_files_closure, request->widget);
        }
        //g_object_unref (G_OBJECT (application));
        g_list_free_full (file_list, g_object_unref);

        /* clear the clipboard if it contained "cutted data"
         * (gtk_clipboard_clear takes care of not clearing
         * the selection if we don't own it)
         */
        if (G_UNLIKELY (!path_copy))
            gtk_clipboard_clear (manager->clipboard);

        /* check the contents of the clipboard again if either the Xserver or
         * our GTK+ version doesn't support the XFixes extension */
        if (!gdk_display_supports_selection_notification (gtk_clipboard_get_display (manager->clipboard)))
        {
            marlin_clipboard_manager_owner_changed (manager->clipboard, NULL, manager);
        }
    }
    else
    {
        /* tell the user that we cannot paste */
        marlin_dialogs_show_error (request->widget, NULL, _("There is nothing on the clipboard to paste"));
    }

    /* free the request */
    if (G_LIKELY (request->widget != NULL))
        g_object_remove_weak_pointer (G_OBJECT (request->widget), (gpointer) &request->widget);

    g_object_unref (G_OBJECT (request->manager));
    g_object_unref (request->target_file);
    g_slice_free (MarlinClipboardPasteRequest, request);
}



static void
marlin_clipboard_manager_targets_received (GtkClipboard     *clipboard,
                                           GtkSelectionData *selection_data,
                                           gpointer          user_data)
{
    MarlinClipboardManager *manager = MARLIN_CLIPBOARD_MANAGER (user_data);
    GdkAtom                *targets;
    gint                    n_targets;
    gint                    n;

    g_return_if_fail (GTK_IS_CLIPBOARD (clipboard));
    g_return_if_fail (MARLIN_IS_CLIPBOARD_MANAGER (manager));
    g_return_if_fail (manager->clipboard == clipboard);

    /* reset the "can-paste" state */
    manager->can_paste = FALSE;

    /* check the list of targets provided by the owner */
    if (gtk_selection_data_get_targets (selection_data, &targets, &n_targets))
    {
        for (n = 0; n < n_targets; ++n)
            if (targets[n] == manager->x_special_gnome_copied_files)
            {
                manager->can_paste = TRUE;
                break;
            }

        g_free (targets);
    }

    /* notify listeners that we have a new clipboard state */
    g_signal_emit (manager, manager_signals[CHANGED], 0);
    g_object_notify (G_OBJECT (manager), "can-paste");

    /* drop the reference taken for the callback */
    g_object_unref (manager);
}

static char *
marlin_clipboard_file_list_to_string (MarlinClipboardManager *manager,
                                      gboolean format_for_text,
                                      gsize *len)
{
    GString *uris;
    char *uri, *tmp;
    GFile *f;
    guint i;
    GList *l;

    if (format_for_text) {
        uris = g_string_new (NULL);
    } else {
        uris = g_string_new (manager->files_cutted ? "cut" : "copy");
    }

    for (i = 0, l = manager->files; l != NULL; l = l->next, i++) {
        uri = g_file_get_uri(GOF_FILE(l->data)->location);

        if (format_for_text) {
            f = g_file_new_for_uri (uri);
            tmp = g_file_get_parse_name (f);
            g_object_unref (f);

            if (tmp != NULL) {
                g_string_append (uris, tmp);
                g_free (tmp);
            } else {
                g_string_append (uris, uri);
            }

            /* skip newline for last element */
            if (i + 1 < g_list_length (manager->files)) {
                g_string_append_c (uris, '\n');
            }
        } else {
            g_string_append_c (uris, '\n');
            g_string_append (uris, uri);
        }

        g_free (uri);
    }

    *len = uris->len;
    return g_string_free (uris, FALSE);
}

static void
marlin_clipboard_manager_get_callback (GtkClipboard     *clipboard,
                                       GtkSelectionData *selection_data,
                                       guint             target_info,
                                       gpointer          user_data)
{
    MarlinClipboardManager *manager = MARLIN_CLIPBOARD_MANAGER (user_data);
    char *str;
    gsize len;

    g_return_if_fail (GTK_IS_CLIPBOARD (clipboard));
    g_return_if_fail (MARLIN_IS_CLIPBOARD_MANAGER (manager));
    g_return_if_fail (manager->clipboard == clipboard);

    switch (target_info)
    {
    case TARGET_GNOME_COPIED_FILES:
        str = marlin_clipboard_file_list_to_string (manager, FALSE, &len);
        gtk_selection_data_set (selection_data, gtk_selection_data_get_target (selection_data), 8, (guchar *) str, len);
        g_free (str);
        break;

    case TARGET_UTF8_STRING:
        str = marlin_clipboard_file_list_to_string (manager, TRUE, &len);
        gtk_selection_data_set_text (selection_data, str, len);
        //gtk_selection_data_set (selection_data, gtk_selection_data_get_target (selection_data), 8, (guchar *) string_list, strlen (string_list));
        g_free (str);
        break;

    default:
        g_assert_not_reached ();
    }
}



static void
marlin_clipboard_manager_clear_callback (GtkClipboard *clipboard,
                                         gpointer      user_data)
{
    MarlinClipboardManager *manager = MARLIN_CLIPBOARD_MANAGER (user_data);
    GList                  *lp;

    g_return_if_fail (GTK_IS_CLIPBOARD (clipboard));
    g_return_if_fail (MARLIN_IS_CLIPBOARD_MANAGER (manager));
    g_return_if_fail (manager->clipboard == clipboard);

    /* release the pending files */
    for (lp = manager->files; lp != NULL; lp = lp->next)
    {
        g_signal_handlers_disconnect_by_func (G_OBJECT (lp->data), marlin_clipboard_manager_file_destroyed, manager);
        g_object_unref (G_OBJECT (lp->data));
    }
    g_list_free (manager->files);
    manager->files = NULL;
}



static void
marlin_clipboard_manager_transfer_files (MarlinClipboardManager *manager,
                                         gboolean                copy,
                                         GList                  *files)
{
    GOFFile *file;
    GList      *lp;

    /* release any pending files */
    for (lp = manager->files; lp != NULL; lp = lp->next)
    {
        g_signal_handlers_disconnect_by_func (G_OBJECT (lp->data), marlin_clipboard_manager_file_destroyed, manager);
        g_object_unref (G_OBJECT (lp->data));
    }
    g_list_free (manager->files);

    /* remember the transfer operation */
    manager->files_cutted = !copy;

    /* setup the new file list */
    for (lp = files, manager->files = NULL; lp != NULL; lp = lp->next)
    {
        file = g_object_ref (G_OBJECT (lp->data));
        manager->files = g_list_prepend (manager->files, file);
        g_signal_connect (G_OBJECT (file), "destroy", G_CALLBACK (marlin_clipboard_manager_file_destroyed), manager);
    }

    /* acquire the CLIPBOARD ownership */
    gtk_clipboard_set_with_owner (manager->clipboard, clipboard_targets,
                                  G_N_ELEMENTS (clipboard_targets),
                                  marlin_clipboard_manager_get_callback,
                                  marlin_clipboard_manager_clear_callback,
                                  G_OBJECT (manager));

    /* Need to fake a "owner-change" event here if the Xserver doesn't support clipboard notification */
    if (!gdk_display_supports_selection_notification (gtk_clipboard_get_display (manager->clipboard)))
        marlin_clipboard_manager_owner_changed (manager->clipboard, NULL, manager);
}



/**
 * marlin_clipboard_manager_new_get_for_display:
 * @display : a #GdkDisplay.
 *
 * Determines the #MarlinClipboardManager that is used to manage
 * the clipboard on the given @display.
 *
 * The caller is responsible for freeing the returned object
 * using g_object_unref() when it's no longer needed.
 *
 * Return value: the #MarlinClipboardManager for @display.
**/
MarlinClipboardManager*
marlin_clipboard_manager_new_get_for_display (GdkDisplay *display)
{
    MarlinClipboardManager *manager;
    GtkClipboard           *clipboard;

    g_return_val_if_fail (GDK_IS_DISPLAY (display), NULL);

    /* generate the quark on-demand */
    if (G_UNLIKELY (marlin_clipboard_manager_quark == 0))
        marlin_clipboard_manager_quark = g_quark_from_static_string ("marlin-clipboard-manager");

    /* figure out the clipboard for the given display */
    clipboard = gtk_clipboard_get_for_display (display, GDK_SELECTION_CLIPBOARD);

    /* check if a clipboard manager exists */
    manager = g_object_get_qdata (G_OBJECT (clipboard), marlin_clipboard_manager_quark);
    if (G_LIKELY (manager != NULL))
    {
        g_object_ref (G_OBJECT (manager));
        return manager;
    }

    /* allocate a new manager */
    manager = g_object_new (MARLIN_TYPE_CLIPBOARD_MANAGER, NULL);
    manager->clipboard = g_object_ref (G_OBJECT (clipboard));
    g_object_set_qdata (G_OBJECT (clipboard), marlin_clipboard_manager_quark, manager);

    /* listen for the "owner-change" signal on the clipboard */
    g_signal_connect (G_OBJECT (manager->clipboard), "owner-change",
                      G_CALLBACK (marlin_clipboard_manager_owner_changed), manager);

    return manager;
}



/**
 * marlin_clipboard_manager_get_can_paste:
 * @manager : a #MarlinClipboardManager.
 *
 * Tells whether the contents of the clipboard represented
 * by @manager can be pasted into a folder.
 *
 * Return value: %TRUE if the contents of the clipboard
 *               represented by @manager can be pasted
 *               into a folder.
**/
gboolean
marlin_clipboard_manager_get_can_paste (MarlinClipboardManager *manager)
{
    g_return_val_if_fail (MARLIN_IS_CLIPBOARD_MANAGER (manager), FALSE);
    return manager->can_paste;
}



/**
 * marlin_clipboard_manager_has_cutted_file:
 * @manager : a #MarlinClipboardManager.
 * @file    : a #GOFFile.
 *
 * Checks whether @file was cutted to the given @manager earlier.
 *
 * Return value: %TRUE if @file is on the cutted list of @manager.
**/
gboolean
marlin_clipboard_manager_has_cutted_file (MarlinClipboardManager *manager,
                                          const GOFFile       *file)
{
    g_return_val_if_fail (MARLIN_IS_CLIPBOARD_MANAGER (manager), FALSE);
    g_return_val_if_fail (GOF_IS_FILE (file), FALSE);

    return (manager->files_cutted && g_list_find (manager->files, file) != NULL);
}

gboolean
marlin_clipboard_manager_has_file (MarlinClipboardManager *manager,
                                          const GOFFile       *file)
{
    g_return_val_if_fail (MARLIN_IS_CLIPBOARD_MANAGER (manager), FALSE);
    g_return_val_if_fail (GOF_IS_FILE (file), FALSE);

    return (g_list_find (manager->files, file) != NULL);
}

guint
marlin_clipboard_manager_count_files (MarlinClipboardManager *manager)
{
    g_return_val_if_fail (MARLIN_IS_CLIPBOARD_MANAGER (manager), 0);

    return g_list_length (manager->files);
}

/**
 * marlin_clipboard_manager_copy_files:
 * @manager : a #MarlinClipboardManager.
 * @files   : a list of #GOFFile<!---->s.
 *
 * Sets the clipboard represented by @manager to
 * contain the @files and marks them to be copied
 * when the user pastes from the clipboard.
**/
void
marlin_clipboard_manager_copy_files (MarlinClipboardManager *manager,
                                     GList                  *files)
{
    g_return_if_fail (MARLIN_IS_CLIPBOARD_MANAGER (manager));
    marlin_clipboard_manager_transfer_files (manager, TRUE, files);
}



/**
 * marlin_clipboard_manager_cut_files:
 * @manager : a #MarlinClipboardManager.
 * @files   : a list of #GOFFile<!---->s.
 *
 * Sets the clipboard represented by @manager to
 * contain the @files and marks them to be moved
 * when the user pastes from the clipboard.
**/
void
marlin_clipboard_manager_cut_files (MarlinClipboardManager *manager,
                                    GList                  *files)
{
    g_return_if_fail (MARLIN_IS_CLIPBOARD_MANAGER (manager));
    marlin_clipboard_manager_transfer_files (manager, FALSE, files);
}



/**
 * marlin_clipboard_manager_paste_files:
 * @manager           : a #MarlinClipboardManager.
 * @target_file       : the #GFile of the folder to which the contents on the clipboard
 *                      should be pasted.
 * @widget            : a #GtkWidget, on which to perform the paste or %NULL if no widget is
 *                      known.
 * @new_files_closure : a #GClosure to connect to the job's "new-files" signal,
 *                      which will be emitted when the job finishes with the
 *                      list of #GFile<!---->s created by the job, or
 *                      %NULL if you're not interested in the signal.
 *
 * Pastes the contents from the clipboard associated with @manager to the directory
 * referenced by @target_file.
**/
void
marlin_clipboard_manager_paste_files (MarlinClipboardManager *manager,
                                      GFile                  *target_file,
                                      GtkWidget              *widget,
                                      MarlinCopyCallback     *new_files_closure)
{
    MarlinClipboardPasteRequest *request;
    g_return_if_fail (MARLIN_IS_CLIPBOARD_MANAGER (manager));
    g_return_if_fail (widget == NULL || GTK_IS_WIDGET (widget));

    /* prepare the paste request */
    request = g_slice_new0 (MarlinClipboardPasteRequest);
    request->manager = g_object_ref (G_OBJECT (manager));
    request->target_file = g_object_ref (target_file);
    request->widget = widget;

    /* take a reference on the closure (if any) */
    if (G_LIKELY (new_files_closure != NULL))
    {
        request->new_files_closure = new_files_closure;
    }

    /* get notified when the widget is destroyed prior to
     * completing the clipboard contents retrieval
     */
    if (G_LIKELY (request->widget != NULL))
        g_object_add_weak_pointer (G_OBJECT (request->widget), (gpointer) &request->widget);

    /* schedule the request */
    gtk_clipboard_request_contents (manager->clipboard, manager->x_special_gnome_copied_files,
                                    marlin_clipboard_manager_contents_received, request);
}

