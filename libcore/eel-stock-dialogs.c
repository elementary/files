/* eel-stock-dialogs.c: Various standard dialogs for Eel.
 *
 * Copyright (C) 2000 Eazel, Inc.
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
 *
 * Authors: Darin Adler <darin@eazel.com>
 */

#include "eel-stock-dialogs.h"

#include <glib/gi18n-lib.h>

void
eel_gtk_message_dialog_set_details_label (GtkMessageDialog *dialog,
                                          const gchar *details_text)
{
    GtkWidget *content_area, *expander, *label;

    content_area = gtk_message_dialog_get_message_area (dialog);
    expander = gtk_expander_new_with_mnemonic (_("Show more _details"));
    gtk_expander_set_spacing (GTK_EXPANDER (expander), 6);

    label = gtk_label_new (details_text);
    gtk_label_set_line_wrap (GTK_LABEL (label), TRUE);
    gtk_label_set_selectable (GTK_LABEL (label), TRUE);
    gtk_misc_set_alignment (GTK_MISC (label), 0.0, 0.5);

    gtk_container_add (GTK_CONTAINER (expander), label);
    gtk_box_pack_start (GTK_BOX (content_area), expander, FALSE, FALSE, 0);

    gtk_widget_show (label);
    gtk_widget_show (expander);
}

static GtkDialog *
show_message_dialog (const char *primary_text,
                     const char *secondary_text,
                     GtkMessageType type,
                     GtkButtonsType buttons_type,
                     const char *details_text,
                     GtkWindow *parent)
{
    GtkWidget *dialog;
    dialog = gtk_message_dialog_new (parent, 0, type, buttons_type, NULL);
    gtk_window_set_deletable (GTK_WINDOW (dialog), FALSE);
    g_object_set (dialog, "text", primary_text, "secondary-text", secondary_text, NULL);

    if (details_text != NULL) {
        eel_gtk_message_dialog_set_details_label (GTK_MESSAGE_DIALOG (dialog),
                                                  details_text);
    }
    gtk_widget_show (dialog);

    g_signal_connect (GTK_DIALOG (dialog), "response",
                      G_CALLBACK (gtk_widget_destroy), NULL);

    return (GTK_DIALOG (dialog));
}

static GtkDialog *
show_ok_dialog (const char *primary_text,
                const char *secondary_text,
                GtkMessageType type,
                GtkWindow *parent)
{
    GtkDialog *dialog;
    dialog = show_message_dialog (primary_text, secondary_text, type,
                                  GTK_BUTTONS_OK, NULL, parent);
    gtk_dialog_set_default_response (GTK_DIALOG (dialog), GTK_RESPONSE_OK);

    return dialog;
}

GtkDialog *
eel_show_warning_dialog (const char *primary_text,
                         const char *secondary_text,
                         GtkWindow *parent)
{
    return show_ok_dialog (primary_text,
                           secondary_text,
                           GTK_MESSAGE_WARNING, parent);
}

//TODO merge with marlin_dialogs_show_error
GtkDialog *
eel_show_error_dialog (const char *primary_text,
                       const char *secondary_text,
                       GtkWindow *parent)
{
    return show_ok_dialog (primary_text,
                           secondary_text,
                           GTK_MESSAGE_ERROR, parent);
}

/**
 * marlin_util_parse_parent: (imported from thunar)
 * @parent        : a #GtkWidget, a #GdkScreen or %NULL.
 * @window_return : return location for the toplevel #GtkWindow or
 *                  %NULL.
 *
 * Determines the screen for the @parent and returns that #GdkScreen.
 * If @window_return is not %NULL, the pointer to the #GtkWindow is
 * placed into it, or %NULL if the window could not be determined.
 *
 * Return value: the #GdkScreen for the @parent.
**/
static GdkScreen*
marlin_util_parse_parent (gpointer parent, GtkWindow **window_return)
{
    GdkScreen *screen;
    GtkWidget *window = NULL;

    g_return_val_if_fail (parent == NULL || GDK_IS_SCREEN (parent) || GTK_IS_WIDGET (parent), NULL);

    /* determine the proper parent */
    if (parent == NULL)
    {
        /* just use the default screen then */
        screen = gdk_screen_get_default ();
    }
    else if (GDK_IS_SCREEN (parent))
    {
        /* yep, that's a screen */
        screen = GDK_SCREEN (parent);
    }
    else
    {
        /* parent is a widget, so let's determine the toplevel window */
        window = gtk_widget_get_toplevel (GTK_WIDGET (parent));
        if (gtk_widget_is_toplevel (window))
        {
            /* make sure the toplevel window is shown */
            gtk_widget_show_now (window);
        }
        else
        {
            /* no toplevel, not usable then */
            window = NULL;
        }

        /* determine the screen for the widget */
        screen = gtk_widget_get_screen (GTK_WIDGET (parent));
    }

    /* check if we should return the window */
    if (G_LIKELY (window_return != NULL))
        *window_return = (GtkWindow *) window;

    return screen;
}


/**
 * marlin_dialogs_show_error: (imported from thunar)
 * @parent : a #GtkWidget on which the error dialog should be shown, or a #GdkScreen
 *           if no #GtkWidget is known. May also be %NULL, in which case the default
 *           #GdkScreen will be used.
 * @error  : a #GError, which gives a more precise description of the problem or %NULL.
 * @format : the printf()-style format for the primary problem description.
 * @...    : argument list for the @format.
 *
 * Displays an error dialog on @widget using the @format as primary message and optionally
 * displaying @error as secondary error text.
 *
 * If @widget is not %NULL and @widget is part of a #GtkWindow, the function makes sure
 * that the toplevel window is visible prior to displaying the error dialog.
**/
void
marlin_dialogs_show_error (gpointer      parent,
                           const GError *error,
                           const gchar  *format,
                           ...)
{
    GtkWidget *dialog;
    GtkWindow *window;
    GdkScreen *screen;
    va_list    args;
    gchar     *primary_text;

    g_return_if_fail (parent == NULL || GDK_IS_SCREEN (parent) || GTK_IS_WIDGET (parent));

    /* parse the parent pointer */
    screen = marlin_util_parse_parent (parent, &window);

    /* determine the primary error text */
    va_start (args, format);
    primary_text = g_strdup_vprintf (format, args);
    va_end (args);

    /* allocate the error dialog */
    dialog = gtk_message_dialog_new (window,
                                     GTK_DIALOG_DESTROY_WITH_PARENT
                                     | GTK_DIALOG_MODAL,
                                     GTK_MESSAGE_ERROR,
                                     GTK_BUTTONS_CLOSE,
                                     "%s.", primary_text);
    gtk_window_set_deletable (GTK_WINDOW (dialog), FALSE);

    /* move the dialog to the appropriate screen */
    if (G_UNLIKELY (window == NULL && screen != NULL))
        gtk_window_set_screen (GTK_WINDOW (dialog), screen);

    /* set secondary text if an error is provided */
    if (G_LIKELY (error != NULL))
        gtk_message_dialog_format_secondary_text (GTK_MESSAGE_DIALOG (dialog), "%s.", error->message);

    /* display the dialog */
    gtk_dialog_run (GTK_DIALOG (dialog));

    /* cleanup */
    gtk_widget_destroy (dialog);
    g_free (primary_text);
}

