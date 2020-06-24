/*
 * Copyright (C) 2011 ammonkey <am.monkeyd@gmail.com>
 *
 * PantheonFiles is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * PantheonFiles is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "config.h"
#include <gtk/gtk.h>
#include "pantheon-files-core.h"
#include "g-util.h"
#include "plugin.h"

G_DEFINE_TYPE (PFDropbox, pf_dropbox, MARLIN_PLUGINS_TYPE_BASE);

typedef struct {
    PFDropbox   *cvs;
    gchar           *verb;
    GOFFile         *file;
} MenuCallbackData;

static void
free_menu_cb_data (gpointer data, GObject *where_the_object_was)
{
    MenuCallbackData *cb_data = (MenuCallbackData *) data;

    g_free (cb_data->verb);
    g_free (cb_data);
}

static char *db_emblems[] = {"dropbox-uptodate",    \
                             "dropbox-syncing",     \
                             "dropbox-unsyncable",  \
                             "dropbox-selsync",     \
                             "dropbox-app",         \
                             "web",                 \
                             "people",              \
                             "photos",              \
                             "star"};

static char *emblems[] = {"process-completed-symbolic",      \
                          "aptdaemon-upgrade",               \
                          "process-error-symbolic",          \
                          "aptdaemon-upgrade",               \
                          "dropbox-app",                     \
                          "applications-internet",           \
                          "avatar-default",                  \
                          "emblem-photos-symbolic",          \
                          "emblem-favorite-symbolic"};

static void pf_dropbox_finalize (MarlinPluginsBase* obj);

static gpointer _g_object_ref0 (gpointer self) {
    return self ? g_object_ref (self) : NULL;
}

/* probably my favorite function */
static gchar *
canonicalize_path(gchar *path) {
    int i, j = 0;
    gchar *toret, **cpy, **elts;

    g_assert(path != NULL);
    g_assert(path[0] == '/');

    elts = g_strsplit(path, "/", 0);
    cpy = g_new(gchar *, g_strv_length(elts)+1);
    cpy[j++] = "/";
    for (i = 0; elts[i] != NULL; i++) {
        if (strcmp(elts[i], "..") == 0) {
            j--;
        }
        else if (strcmp(elts[i], ".") != 0 && elts[i][0] != '\0') {
            cpy[j++] = elts[i];
        }
    }

    cpy[j] = NULL;
    toret = g_build_filenamev(cpy);
    g_free(cpy);
    g_strfreev(elts);

    return toret;
}

static void
reset_file(GOFFile *file) {
    debug("resetting file %p", (void *) file);
    gof_file_update_emblem (file);
}

gboolean
reset_all_files(PFDropbox *cvs) {
    /* Only run this on the main loop or you'll cause problems. */

    /* this works because you can call a function pointer with
       more arguments than it takes */
    g_hash_table_foreach(cvs->obj2filename, (GHFunc) reset_file, NULL);
    return FALSE;
}

static void
when_file_dies(PFDropbox *cvs, GOFFile *file) {
    gchar *filename;

    filename = g_hash_table_lookup(cvs->obj2filename, file);

    /* we never got a change to view this file */
    if (filename == NULL) {
        return;
    }

    /* too chatty */
    /*  debug("removing %s <-> 0x%p", filename, file); */

    g_hash_table_remove(cvs->filename2obj, filename);
    g_hash_table_remove(cvs->obj2filename, file);
}


static void
on_connect(PFDropbox *cvs) {
    reset_all_files(cvs);
}

static void
on_disconnect(PFDropbox *cvs) {
    reset_all_files(cvs);
}

static void
handle_shell_touch(GHashTable *args, PFDropbox *cvs) {
    gchar **path;

    if ((path = g_hash_table_lookup(args, "path")) != NULL &&
        path[0][0] == '/') {
        GOFFile *file;
        gchar *filename;

        filename = canonicalize_path(path[0]);

        debug("shell touch for %s", filename);

        file = g_hash_table_lookup(cvs->filename2obj, filename);

        if (file != NULL) {
            debug("gonna reset %s", filename);
            reset_file(file);
        }
        g_free(filename);
    }

    return;
}

static char *
translate_emblem (char *str)
{
    int i=0;

    for (i; i<sizeof(emblems); i++) {
        if (strcmp (str, db_emblems[i]) == 0) {
            return emblems[i];
        }
    }

    return NULL;
}

gboolean
pf_dropbox_finish_file_info_command(DropboxFileInfoCommandResponse *dficr) {
    char *str_emblem;

    if (!dficr->dfic->cancelled) {
        gchar **status = NULL;
        gboolean isdir;

        isdir = dficr->dfic->file->is_directory;

        /* if we have emblems just use them. */
        if (dficr->emblems_response != NULL &&
            (status = g_hash_table_lookup(dficr->emblems_response, "emblems")) != NULL) {
            int i;
            for ( i = 0; status[i] != NULL; i++) {
                if (status[i][0]) {
                    if ((str_emblem = translate_emblem (status[i])) != NULL) {
                        gof_file_add_emblem(dficr->dfic->file, str_emblem);
                    } else
                        g_warning ("emblem %s not found - %s", status[i], dficr->dfic->file->uri);
                }
            }
        }
        /* if the file status command went okay */
        else if ((dficr->file_status_response != NULL &&
                  (status =
                   g_hash_table_lookup(dficr->file_status_response, "status")) != NULL) &&
                 ((isdir == TRUE &&
                   dficr->folder_tag_response != NULL) || isdir == FALSE)) {
            //FIXME
            g_critical ("grrrr %s", G_STRFUNC);
            gchar **tag = NULL;

            /* set the tag emblem */
            if (isdir &&
                (tag = g_hash_table_lookup(dficr->folder_tag_response, "tag")) != NULL) {
                if (strcmp("public", tag[0]) == 0) {
                    gof_file_add_emblem(dficr->dfic->file, emblems[5]);
                }
                else if (strcmp("shared", tag[0]) == 0) {
                    gof_file_add_emblem(dficr->dfic->file, emblems[6]);
                }
                else if (strcmp("photos", tag[0]) == 0) {
                    gof_file_add_emblem(dficr->dfic->file, emblems[7]);
                }
                else if (strcmp("sandbox", tag[0]) == 0) {
                    gof_file_add_emblem(dficr->dfic->file, emblems[8]);
                }
            }

            /* set the status emblem */
            int emblem_code = 0;

            if (strcmp("up to date", status[0]) == 0) {
                emblem_code = 1;
            }
            else if (strcmp("syncing", status[0]) == 0) {
                emblem_code = 2;
            }
            else if (strcmp("unsyncable", status[0]) == 0) {
                emblem_code = 3;
            }
            else if (strcmp("selsync", status[0]) == 0) {
                emblem_code = 4;
            }
            else if (strcmp("app", status[0]) == 0) {
                emblem_code = 5;
            }

            if (emblem_code > 0) {
                gof_file_add_emblem(dficr->dfic->file, emblems[emblem_code-1]);
            }
        }
    }

    /* destroy the objects we created */
    if (dficr->file_status_response != NULL)
        g_hash_table_unref(dficr->file_status_response);
    if (dficr->folder_tag_response != NULL)
        g_hash_table_unref(dficr->folder_tag_response);
    if (dficr->emblems_response != NULL)
        g_hash_table_unref(dficr->emblems_response);

    /* unref the objects we didn't create */
    g_object_unref(dficr->dfic->file);

    /* now free the structs */
    g_free(dficr->dfic);
    g_free(dficr);

    return FALSE;
}

static void
pf_dropbox_real_directory_loaded (MarlinPluginsBase *base, void *user_data)
{

}

static void
pf_dropbox_update_file_info (MarlinPluginsBase *base, GOFFile *file)
{
    PFDropbox *cvs = PF_DROPBOX (base);

    gchar *path = NULL;

    path = g_filename_from_uri (file->uri, NULL, NULL);
    if (path == NULL)
        return;

    int cmp = 0;
    gchar *stored_filename;
    gchar *filename;

    filename = canonicalize_path(path);
    stored_filename = g_hash_table_lookup(cvs->obj2filename, file);

    /* don't worry about the dup checks, gcc is smart enough to optimize this
       GCSE ftw */
    if ((stored_filename != NULL && (cmp = strcmp(stored_filename, filename)) != 0) ||
        stored_filename == NULL) {

        if (stored_filename != NULL && cmp != 0) {
            /* this happens when the filename changes name on a file obj
               but changed_cb isn't called */
            g_object_weak_unref(G_OBJECT(file), (GWeakNotify) when_file_dies, cvs);
            g_hash_table_remove(cvs->obj2filename, file);
            g_hash_table_remove(cvs->filename2obj, stored_filename);
        }
        else if (stored_filename == NULL) {
            GOFFile *f2;

            if ((f2 = g_hash_table_lookup(cvs->filename2obj, filename)) != NULL) {
                /* if the filename exists in the filename2obj hash
                   but the file obj doesn't exist in the obj2filename hash:

                   this happens when nautilus allocates another file object
                   for a filename without first deleting the original file object

                   just remove the association to the older file object, it's obsolete
                   */
                g_object_weak_unref(G_OBJECT(f2), (GWeakNotify) when_file_dies, cvs);

                g_hash_table_remove(cvs->filename2obj, filename);
                g_hash_table_remove(cvs->obj2filename, f2);
            }
        }

        g_object_weak_ref(G_OBJECT(file), (GWeakNotify) when_file_dies, cvs);
        g_hash_table_insert(cvs->filename2obj, g_strdup(filename), file);
        g_hash_table_insert(cvs->obj2filename, file, g_strdup(filename));
        //g_signal_connect(file, "changed", G_CALLBACK(changed_cb), cvs);
    }

    g_free(filename);

    if (dropbox_client_is_connected(&(cvs->dc)) == FALSE || file == NULL)
        return;

    DropboxFileInfoCommand *dfic = g_new0(DropboxFileInfoCommand, 1);

    dfic->cancelled = FALSE;
    dfic->provider = base;
    dfic->dc.request_type = GET_FILE_INFO;
    dfic->update_complete = NULL;
    dfic->file = g_object_ref(file);

    dropbox_command_client_request(&(cvs->dc.dcc), (DropboxCommand *) dfic);

    g_free (path);
}

static char from_hex(gchar ch) {
    return g_ascii_isdigit(ch) ? ch - '0' : g_ascii_tolower(ch) - 'a' + 10;
}

// decode in --> out, but dont fill more than n chars into out
// returns len of out if thing went well, -1 if n wasn't big enough
// can be used in place (whoa!)
int GhettoURLDecode(gchar* out, gchar* in, int n) {
    char *out_initial;

    for(out_initial = out; out-out_initial < n && *in != '\0'; out++) {
        if (*in == '%') {
            *out = from_hex(in[1]) << 4 | from_hex(in[2]);
            in += 3;
        }
        else {
            *out = *in;
            in++;
        }
    }

    if (out-out_initial < n) {
        *out = '\0';
        return out-out_initial;
    }
    return -1;
}

static void
menu_item_cb(GtkWidget *item, MenuCallbackData *cb_data)
{
    PFDropbox *cvs = cb_data->cvs;
    DropboxGeneralCommand *dcac;

    dcac = g_new(DropboxGeneralCommand, 1);
    dcac->dc.request_type = GENERAL_COMMAND;

    /* build the argument list */
    dcac->command_args = g_hash_table_new_full((GHashFunc) g_str_hash,
                                               (GEqualFunc) g_str_equal,
                                               (GDestroyNotify) g_free,
                                               (GDestroyNotify) g_strfreev);
    gchar **arglist;

    arglist = g_new0(gchar *, 2);
    arglist[0] = g_filename_from_uri(cb_data->file->uri, NULL, NULL);
    arglist[1] = NULL;
    g_hash_table_insert(dcac->command_args, g_strdup("paths"), arglist);

    arglist = g_new(gchar *, 2);
    arglist[0] = g_strdup(cb_data->verb);
    arglist[1] = NULL;
    g_hash_table_insert(dcac->command_args, g_strdup("verb"), arglist);

    dcac->command_name = g_strdup("icon_overlay_context_action");
    dcac->handler = NULL;
    dcac->handler_ud = NULL;

    dropbox_command_client_request(&(cvs->dc.dcc), (DropboxCommand *) dcac);
}

static void
pf_dropbox_parse_menu(gchar             **options,
                          GtkWidget         *menu,
                          MarlinPluginsBase *base,
                          GOFFile           *file)
{
    PFDropbox *cvs = PF_DROPBOX (base);
    MenuCallbackData *cb_data;
    int i;

    for ( i = 0; options[i] != NULL; i++) {
        gchar **option_info = g_strsplit(options[i], "~", 3);
        /* if this is a valid string */
        if (option_info[0] == NULL || option_info[1] == NULL ||
            option_info[2] == NULL || option_info[3] != NULL) {
            g_strfreev(option_info);
            continue;
        }

        gchar* item_name = option_info[0];
        gchar* item_inner = option_info[1];
        gchar* verb = option_info[2];

        GhettoURLDecode(item_name, item_name, strlen(item_name));
        GhettoURLDecode(verb, verb, strlen(verb));
        GhettoURLDecode(item_inner, item_inner, strlen(item_inner));

        g_debug ("menu %s", item_name);
        g_debug ("verb %s", verb);
        g_debug ("item_inner %s", item_inner);

        cb_data = g_new0 (MenuCallbackData, 1);
        cb_data->cvs = cvs;
        cb_data->verb = g_strdup (verb);
        cb_data->file = file;

        g_object_weak_ref (G_OBJECT (menu), (GWeakNotify) free_menu_cb_data, cb_data);

        /* Deprecated ? */
        // If the inner section has a menu in it then we create a submenu.  The verb will be ignored.
        // Otherwise add the verb to our map and add the menu item to the list.
        if (strchr(item_inner, '~') != NULL) {
            g_critical ("Dropbox %s contain inner section - TODO implement this", G_STRFUNC);
#if 0
            GString *new_action_string = g_string_new(old_action_string->str);
            gchar **suboptions = g_strsplit(item_inner, "|", -1);
            NautilusMenuItem *item;
            NautilusMenu *submenu = nautilus_menu_new();

            g_string_append(new_action_string, item_name);
            g_string_append(new_action_string, "::");

            nautilus_dropbox_parse_menu(suboptions, submenu, base, files);

            item = nautilus_menu_item_new(new_action_string->str,
                                          item_name, "", NULL);
            nautilus_menu_item_set_submenu(item, submenu);
            nautilus_menu_append_item(menu, item);

            g_strfreev(suboptions);
            g_object_unref(item);
            g_object_unref(submenu);
            g_string_free(new_action_string, TRUE);
#endif
        } else {
            gboolean grayed_out = FALSE;

            if (item_name[0] == '!') {
                item_name++;
                grayed_out = TRUE;
            }

            GtkWidget *menu_item = gtk_menu_item_new_with_label (item_name);
            if (grayed_out)
                g_object_set (menu_item, "sensitive", FALSE, NULL);
            gtk_widget_show (menu_item);

            g_signal_connect (menu_item, "activate",
                              G_CALLBACK (menu_item_cb), cb_data);
            gtk_menu_shell_append (GTK_MENU_SHELL (menu), menu_item);
        }
        g_strfreev(option_info);
    }
}

static void
get_file_items_callback(GHashTable *response, gpointer ud)
{
    GAsyncQueue *reply_queue = ud;

    /* queue_push doesn't accept NULL as a value so we create an empty hash table
     * if we got no response. */
    g_async_queue_push(reply_queue, response ? g_hash_table_ref(response) :
                       g_hash_table_new((GHashFunc) g_str_hash, (GEqualFunc) g_str_equal));
    g_async_queue_unref(reply_queue);
}

static void
pf_dropbox_context_menu (MarlinPluginsBase *base, GtkWidget *menu, GList *files)
{
    PFDropbox *cvs = PF_DROPBOX (base);
    GOFFile *file;
    gchar *filename_un, *filename;
    int file_count;

    if (dropbox_client_is_connected(&(cvs->dc)) == FALSE) {
        g_debug ("Context menu - dropbox not connected");
        return;
    }

    cvs->selection = files;
    if ((file_count = g_list_length (cvs->selection)) != 1) {
        return;
    }

    /*
     * 1. Convert files to filenames.
     */
    file = GOF_FILE (g_list_nth_data (cvs->selection, 0));
    filename_un = g_filename_from_uri (file->uri, NULL, NULL);
    filename = filename_un ? g_filename_to_utf8(filename_un, -1, NULL, NULL, NULL) : NULL;

    g_free(filename_un);
    if (filename == NULL)
        return;

    gchar **paths = g_new0(gchar *, file_count + 1);
    paths[0] = filename;

    GAsyncQueue *reply_queue = g_async_queue_new_full((GDestroyNotify)g_hash_table_unref);

    /*
     * 2. Create a DropboxGeneralCommand to call "icon_overlay_context_options"
     */

    DropboxGeneralCommand *dgc = g_new0(DropboxGeneralCommand, 1);
    dgc->dc.request_type = GENERAL_COMMAND;
    dgc->command_name = g_strdup("icon_overlay_context_options");
    dgc->command_args = g_hash_table_new_full((GHashFunc) g_str_hash,
                                              (GEqualFunc) g_str_equal,
                                              (GDestroyNotify) g_free,
                                              (GDestroyNotify) g_strfreev);
    g_hash_table_insert(dgc->command_args, g_strdup("paths"), paths);
    //FIXME
    dgc->handler = get_file_items_callback;
    dgc->handler_ud = g_async_queue_ref(reply_queue);

    /*
     * 3. Queue it up for the helper thread to run it.
     */
    dropbox_command_client_request(&(cvs->dc.dcc), (DropboxCommand *) dgc);

    guint64 gtv;

    /*
     * 4. We have to block until it's done because nautilus expects a reply.  But we will
     * only block for 50 ms for a reply.
     */

    gtv = g_get_real_time();
    gtv  = gtv + 50000;  //Add 50 ms

    GHashTable *context_options_response = g_async_queue_timeout_pop(reply_queue, gtv);
    g_async_queue_unref(reply_queue);

    if (!context_options_response) {
        g_debug ("no response from dropbox");
        return;
    }

    /*
     * 5. Parse the reply.
     */

    char **options = g_hash_table_lookup(context_options_response, "options");
    GList *toret = NULL;

    if (options && *options && **options)  {
        GtkWidget *submenu, *root_item, *separator;

        root_item = gtk_menu_item_new_with_label (_("Dropbox"));
        submenu = gtk_menu_new ();
        gtk_widget_show (root_item);
        gtk_menu_item_set_submenu ((GtkMenuItem *) root_item,submenu);

        separator = gtk_separator_menu_item_new ();
        gtk_widget_show (separator);
        gtk_menu_shell_append ((GtkMenuShell*) menu, separator);

        gtk_menu_shell_append ((GtkMenuShell*) menu, root_item);
        gee_list_insert (marlin_plugin_manager_get_menuitem_references (plugins), 0, root_item);

        pf_dropbox_parse_menu(options, submenu, base, file);
    }

    g_hash_table_unref(context_options_response);



}

static void
pf_dropbox_class_init (PFDropboxClass *klass) {
    MarlinPluginsBaseClass *object_class = MARLIN_PLUGINS_BASE_CLASS (klass);

    object_class->finalize = pf_dropbox_finalize;
    object_class->directory_loaded = pf_dropbox_real_directory_loaded;
    object_class->update_file_info = pf_dropbox_update_file_info;
    object_class->context_menu = pf_dropbox_context_menu;
}


static void
pf_dropbox_init (PFDropbox *cvs) {
    cvs->filename2obj = g_hash_table_new_full((GHashFunc) g_str_hash,
                                              (GEqualFunc) g_str_equal,
                                              (GDestroyNotify) g_free,
                                              (GDestroyNotify) NULL);
    cvs->obj2filename = g_hash_table_new_full((GHashFunc) g_direct_hash,
                                              (GEqualFunc) g_direct_equal,
                                              (GDestroyNotify) NULL,
                                              (GDestroyNotify) g_free);

    /* setup the connection obj*/
    dropbox_client_setup(&(cvs->dc));

    /* our hooks */
    /* tricky name: shell_touch signal is used for real time events too (like transfert done event) */
    pf_dropbox_hooks_add(&(cvs->dc.hookserv), "shell_touch",
                             (DropboxUpdateHook) handle_shell_touch, cvs);

    /* add connection handlers */
    dropbox_client_add_on_connect_hook(&(cvs->dc),
                                       (DropboxClientConnectHook) on_connect,
                                       cvs);
    dropbox_client_add_on_disconnect_hook(&(cvs->dc),
                                          (DropboxClientConnectHook) on_disconnect,
                                          cvs);

    /* now start the connection */
    debug("about to start client connection");
    dropbox_client_start(&(cvs->dc));
}


static void
pf_dropbox_finalize (MarlinPluginsBase* obj) {
    PFDropbox * self = PF_DROPBOX (obj);

    MARLIN_PLUGINS_BASE_CLASS (pf_dropbox_parent_class)->finalize (obj);
}

PFDropbox* pf_dropbox_new () {
    PFDropbox *u1;

    u1 = (PFDropbox*) marlin_plugins_base_construct (PF_TYPE_DROPBOX);

    return u1;
}

MarlinPluginsBase* module_init()
{
    PFDropbox* u1 = pf_dropbox_new ();

    return MARLIN_PLUGINS_BASE (u1);
}


