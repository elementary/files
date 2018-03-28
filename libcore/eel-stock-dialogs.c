/* eel-stock-dialogs.c: Various standard dialogs for Eel.
 *
 * Copyright (C) 2000 Eazel, Inc.
 *
 * The Gnome Library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License as
 * published by the Free Software Foundation, Inc.,; either version 2 of the
 * License, or (at your option) any later version.
 *
 * The Gnome Library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with the Gnome Library; see the file COPYING.LIB.  If not,
 * write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
 * Boston, MA 02110-1335 USA.
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

GtkDialog *
eel_show_error_dialog (const char *primary_text,
                       const char *secondary_text,
                       GtkWindow *parent)
{
    return show_ok_dialog (primary_text,
                           secondary_text,
                           GTK_MESSAGE_ERROR, parent);
}

