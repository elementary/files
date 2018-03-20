/*-
 * Copyright (c) 2005-2007 Benedikt Meurer <benny@xfce.org>
 * Copyright (c) 2009 Jannis Pohlmann <jannis@xfce.org>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, Inc.,; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */


#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <glib.h>
#include <gio/gio.h>

#include "marlin-exec.h"
#include "eel-gio-extensions.h"


/* parse GFile location using path if locale uri if native */
static void
string_append_quoted_location (GString *string, GFile *file)
{
    gchar *quoted;
    gchar *location;

    location = eel_g_file_get_location (file);
    quoted = g_shell_quote (location);
    g_string_append (string, quoted);
    g_free (quoted);
    g_free (location);
}

static void
te_string_append_quoted (GString     *string,
                         const gchar *unquoted)
{
    gchar *quoted;

    quoted = g_shell_quote (unquoted);
    g_string_append (string, quoted);
    g_free (quoted);
}

static gboolean
te_string_append_quoted_file (GString *string,
                              GFile   *file)
{
    gboolean success = FALSE;
    gchar   *path;

    /* append the absolute, local, quoted path to the string */
    path = g_file_get_path (file);
    if (G_LIKELY (path != NULL))
    {
        te_string_append_quoted (string, path);
        success = TRUE;
        g_free (path);
    }

    return success;
}

static void
te_string_append_quoted_uri (GString *string,
                             GFile   *file)
{
    gchar *uri;

    /* append the quoted URI for the path */
    uri = g_file_get_uri (file);
    te_string_append_quoted (string, uri);
    g_free (uri);
}


/**
 * marlin_exec_parse: imported from thunar
 * @exec      : the value of the <literal>Exec</literal> field.
 * @file_list : the list of #GFile<!---->s.
 * @icon      : value of the <literal>Icon</literal> field or %NULL.
 * @name      : translated value for the <literal>Name</literal> field or %NULL.
 * @path      : full path to the desktop file or %NULL.
 *
 * Substitutes <literal>Exec</literal> parameter variables according
 * to the <ulink href="http://freedesktop.org/wiki/Standards_2fdesktop_2dentry_2dspec"
 * type="http">Desktop Entry Specification</ulink> and returns the
 * parsed argument vector (in @argv) and the number of items placed
 * into @argv (in @argc).
 *
 * The @icon, @name and @path fields are optional and may be %NULL
 * if you don't know their values. The @icon parameter should be
 * the value of the <literal>Icon</literal> field from the desktop
 * file, the @name parameter should be the translated <literal>Name</literal>
 * value, while the @path parameter should refer to the full path
 * to the desktop file, whose <literal>Exec</literal> field is
 * being parsed here.
 *
 * Return value: gchar * parsed command line.
**/
gchar *
marlin_exec_parse (const gchar *exec,
                   GList       *file_list,
                   const gchar *icon,
                   const gchar *name,
                   const gchar *uri)
{
    const gchar *p;
    GString     *command_line = g_string_new (NULL);
    gchar       *cmd;
    GList       *lp;

    for (p = exec; *p != '\0'; ++p)
    {
        if (p[0] == '%' && p[1] != '\0')
        {
            switch (*++p)
            {
            case 'f':
                /* append the absolute local path of the first path object */
                if (file_list != NULL && !te_string_append_quoted_file (command_line, file_list->data))
                    goto done;
                break;

            case 'F':
                for (lp = file_list; lp != NULL; lp = lp->next)
                {
                    if (G_LIKELY (lp != file_list))
                        g_string_append_c (command_line, ' ');
                    if (!te_string_append_quoted_file (command_line, lp->data))
                        goto done;
                }
                break;

            case 'u':
                if (G_LIKELY (file_list != NULL))
                    te_string_append_quoted_uri (command_line, file_list->data);
                break;

            case 'U':
                for (lp = file_list; lp != NULL; lp = lp->next)
                {
                    if (G_LIKELY (lp != file_list))
                        g_string_append_c (command_line, ' ');
                    te_string_append_quoted_uri (command_line, lp->data);
                }
                break;

            case 'i':
                if (G_LIKELY (icon != NULL))
                {
                    g_string_append (command_line, "--icon ");
                    te_string_append_quoted (command_line, icon);
                }
                break;

            case 'c':
                if (G_LIKELY (name != NULL))
                    te_string_append_quoted (command_line, name);
                break;

            case 'k':
                if (G_LIKELY (uri != NULL))
                    te_string_append_quoted (command_line, uri);
                break;

            case '%':
                g_string_append_c (command_line, '%');
                break;
            }
        }
        else
        {
            g_string_append_c (command_line, *p);
        }
    }

done:
    cmd = command_line->str;
    g_string_free (command_line, FALSE);
    return cmd;
}

gchar *
marlin_exec_auto_parse (gchar *exec, GList *file_list)
{
    GList *lp;
    gchar *cmd;
    GString *command_line = g_string_new (NULL);

    g_string_append (command_line, exec);
    if (file_list != NULL)
        g_string_append_c (command_line, ' ');
    for (lp = file_list; lp != NULL; lp = lp->next)
    {
        if (G_LIKELY (lp != file_list))
            g_string_append_c (command_line, ' ');
        string_append_quoted_location (command_line, lp->data);
    }

    cmd = command_line->str;
    g_string_free (command_line, FALSE);
    return cmd;
}
