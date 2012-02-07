/*
 * Copyright (C) 2011 ammonkey <am.monkeyd@gmail.com>
 * 
 * Marlin is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * Marlin is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <gtk/gtk.h>
#include <glib/gi18n.h>
#include <gof-file.h>
#include "g-util.h"
#include "plugin.h"

//static gpointer marlin_dropbox_parent_class = NULL;

//#define MARLIN_DROPBOX_GET_PRIVATE(o) (G_TYPE_INSTANCE_GET_PRIVATE ((o), MARLIN_TYPE_DROPBOX, MarlinDropboxPrivate))

G_DEFINE_TYPE (MarlinDropbox, marlin_dropbox, MARLIN_PLUGINS_TYPE_BASE);

typedef struct {
    MarlinDropbox   *cvs;
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

static char *db_emblems[] = {"dropbox-uptodate", "dropbox-syncing", "dropbox-unsyncable", "web", "people", "photos", "star"};
static char *emblems[] = {"emblem-ubuntuone-synchronized", "emblem-ubuntuone-updating", "dropbox-unsyncable", "emblem-web", "emblem-people", "emblem-photos", "emblem-star"};
//gchar *DEFAULT_EMBLEM_PATHS[2] = { EMBLEMDIR , NULL };

static void marlin_dropbox_finalize (MarlinPluginsBase* obj);

static gpointer _g_object_ref0 (gpointer self) {
    return self ? g_object_ref (self) : NULL;
}

/*static gchar* current_path = NULL;
  static gboolean menu_added = FALSE;
  static GSettings* settings = NULL;
  static GList *menus = NULL;
  static GtkWidget *menu;*/

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
reset_all_files(MarlinDropbox *cvs) {
    /* Only run this on the main loop or you'll cause problems. */

    /* this works because you can call a function pointer with
       more arguments than it takes */
    g_hash_table_foreach(cvs->obj2filename, (GHFunc) reset_file, NULL);
    return FALSE;
}

static void
when_file_dies(MarlinDropbox *cvs, GOFFile *file) {
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

/*****/
#if 0
gboolean
add_emblem_paths(GHashTable* emblem_paths_response)
{
    /* Only run this on the main loop or you'll cause problems. */
    if (!emblem_paths_response)
        return FALSE;

    gchar **emblem_paths_list;
    int i;

    GtkIconTheme *theme = gtk_icon_theme_get_default();

    if (emblem_paths_response &&
        (emblem_paths_list = g_hash_table_lookup(emblem_paths_response, "path"))) {
        for (i = 0; emblem_paths_list[i] != NULL; i++) {
            if (emblem_paths_list[i][0])
                gtk_icon_theme_append_search_path(theme, emblem_paths_list[i]);
        }
    }
    g_hash_table_unref(emblem_paths_response);
    return FALSE;
}

gboolean
remove_emblem_paths(GHashTable* emblem_paths_response)
{
    /* Only run this on the main loop or you'll cause problems. */
    if (!emblem_paths_response)
        return FALSE;

    gchar **emblem_paths_list = g_hash_table_lookup(emblem_paths_response, "path");
    if (!emblem_paths_list)
        goto exit;

    // We need to remove the old paths.
    GtkIconTheme * icon_theme = gtk_icon_theme_get_default();
    gchar ** paths;
    gint path_count;

    gtk_icon_theme_get_search_path(icon_theme, &paths, &path_count);

    gint i, j, out = 0;
    gboolean found = FALSE;
    for (i = 0; i < path_count; i++) {
        gboolean keep = TRUE;
        for (j = 0; emblem_paths_list[j] != NULL; j++) {
            if (emblem_paths_list[j][0]) {
                if (!g_strcmp0(paths[i], emblem_paths_list[j])) {
                    found = TRUE;
                    keep = FALSE;
                    g_free(paths[i]);
                    break;
                }
            }
        }
        if (keep) {
            paths[out] = paths[i];
            out++;
        }
    }

    /* If we found one we need to reset the path to
       accomodate the changes */
    if (found) {
        paths[out] = NULL; /* Clear the last one */
        gtk_icon_theme_set_search_path(icon_theme, (const gchar **)paths, out);
    }

    g_strfreev(paths);
exit:
    g_hash_table_unref(emblem_paths_response);
    return FALSE;
}

void get_emblem_paths_cb(GHashTable *emblem_paths_response, MarlinDropbox *cvs)
{
    if (!emblem_paths_response) {
        emblem_paths_response = g_hash_table_new((GHashFunc) g_str_hash,
                                                 (GEqualFunc) g_str_equal);
        //FIXME
        //g_hash_table_insert(emblem_paths_response, "path", DEFAULT_EMBLEM_PATHS);
    } else {
        /* Increase the ref so that finish_general_command doesn't delete it. */
        g_hash_table_ref(emblem_paths_response);
    }

    g_mutex_lock(cvs->emblem_paths_mutex);
    if (cvs->emblem_paths) {
        g_idle_add((GSourceFunc) remove_emblem_paths, cvs->emblem_paths);
        cvs->emblem_paths = NULL;
    }
    cvs->emblem_paths = emblem_paths_response;
    g_mutex_unlock(cvs->emblem_paths_mutex);

    g_idle_add((GSourceFunc) add_emblem_paths, g_hash_table_ref(emblem_paths_response));
    g_idle_add((GSourceFunc) reset_all_files, cvs);
}
#endif

static void
on_connect(MarlinDropbox *cvs) {
    reset_all_files(cvs);

    g_message ("%s", G_STRFUNC);
    //amtest
    /* We don't necessarly need the original dropbox icons */
    /*dropbox_command_client_send_command(&(cvs->dc.dcc),
      (MarlinDropboxCommandResponseHandler) get_emblem_paths_cb,
      cvs, "get_emblem_paths", NULL);*/
}

static void
on_disconnect(MarlinDropbox *cvs) {
    reset_all_files(cvs);

    //FIXME
    g_message ("%s", G_STRFUNC);
    //amtest
#if 0
    g_mutex_lock(cvs->emblem_paths_mutex);
    /* This call will free the data too. */
    g_idle_add((GSourceFunc) remove_emblem_paths, cvs->emblem_paths);
    cvs->emblem_paths = NULL;
    g_mutex_unlock(cvs->emblem_paths_mutex);
#endif
}

static void
handle_shell_touch(GHashTable *args, MarlinDropbox *cvs) {
    gchar **path;

    //  debug_enter();

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
marlin_dropbox_finish_file_info_command(DropboxFileInfoCommandResponse *dficr) {

    char *str_emblem;

    //debug_enter();
    //NautilusOperationResult result = NAUTILUS_OPERATION_FAILED;

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
                    //g_message ("emblem %s", status[i]);
                    if ((str_emblem = translate_emblem (status[i])) != NULL)
                        gof_file_add_emblem(dficr->dfic->file, str_emblem);
                    else
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
                    gof_file_add_emblem(dficr->dfic->file, "emblem-web");
                }
                else if (strcmp("shared", tag[0]) == 0) {
                    gof_file_add_emblem(dficr->dfic->file, "emblem-people");
                }
                else if (strcmp("photos", tag[0]) == 0) {
                    gof_file_add_emblem(dficr->dfic->file, "emblem-photos");
                }
                else if (strcmp("sandbox", tag[0]) == 0) {
                    gof_file_add_emblem(dficr->dfic->file, "emblem-star");
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

            if (emblem_code > 0) {
                /*
                   debug("%s to %s", emblems[emblem_code-1],
                   g_filename_from_uri(dficr->dfic->file->uri,
                   NULL, NULL));
                   */
                //FIXME
                g_message ("emblem code %d", emblem_code);
                gof_file_add_emblem(dficr->dfic->file, emblems[emblem_code-1]);
            }
        }
    }

    /* complete the info request */
    //FIXME
    /*if (!dropbox_use_operation_in_progress_workaround) {
      nautilus_info_provider_update_complete_invoke(dficr->dfic->update_complete,
      dficr->dfic->provider,
      (NautilusOperationHandle*) dficr->dfic,
      result);
      }*/
    //reset_file (dficr->dfic->file);
    gof_file_icon_changed (dficr->dfic->file);

    /* destroy the objects we created */
    if (dficr->file_status_response != NULL)
        g_hash_table_unref(dficr->file_status_response);
    if (dficr->folder_tag_response != NULL)
        g_hash_table_unref(dficr->folder_tag_response);
    if (dficr->emblems_response != NULL)
        g_hash_table_unref(dficr->emblems_response);

    /* unref the objects we didn't create */
    //FIXME
    //g_closure_unref(dficr->dfic->update_complete);
    g_object_unref(dficr->dfic->file);

    /* now free the structs */
    g_free(dficr->dfic);
    g_free(dficr);

    return FALSE;
}

static void 
marlin_dropbox_real_directory_loaded (MarlinPluginsBase *base, void *user_data) 
{
    /*GOFFile *file;

    GObject *obj = ((GObject**) user_data)[2];
    file = g_object_ref ((GOFFile *) obj);
    g_message ("%s : %s", G_STRFUNC, file->uri);*/

    //unref file

}

static void 
marlin_dropbox_update_file_info (MarlinPluginsBase *base, GOFFile *file) 
{
    MarlinDropbox *cvs = MARLIN_DROPBOX (base);

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
            //g_signal_handlers_disconnect_by_func(file, G_CALLBACK(changed_cb), cvs);
        }
        //FIXME check
        /*else if (stored_filename == NULL) {
          g_critical ("grrrrrrrrr");
          }*/
        //#if 0
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
                //g_signal_handlers_disconnect_by_func(f2, G_CALLBACK(changed_cb), cvs);
                g_hash_table_remove(cvs->filename2obj, filename);
                g_hash_table_remove(cvs->obj2filename, f2);
            }
        }
        //#endif

        /* too chatty */
        /* debug("adding %s <-> 0x%p", filename, file);*/
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
    //FIXME
    //dfic->update_complete = g_closure_ref(update_complete);
    dfic->update_complete = NULL;
    dfic->file = g_object_ref(file);

    dropbox_command_client_request(&(cvs->dc.dcc), (DropboxCommand *) dfic);

    //FIXME
    //*handle = (NautilusOperationHandle *) dfic;

    /*return dropbox_use_operation_in_progress_workaround
      ? NAUTILUS_OPERATION_COMPLETE
      : NAUTILUS_OPERATION_IN_PROGRESS;*/

    g_free (path);
}

static char from_hex(gchar ch) {
    return isdigit(ch) ? ch - '0' : tolower(ch) - 'a' + 10;
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
    MarlinDropbox *cvs = cb_data->cvs;
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
marlin_dropbox_parse_menu(gchar			    **options,
                          GtkWidget		    *menu,
                          MarlinPluginsBase *base,
                          GOFFile           *file)
{
    MarlinDropbox *cvs = MARLIN_DROPBOX (base);
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

        g_message ("menu %s", item_name);
        g_message ("verb %s", verb);
        g_message ("item_inner %s", item_inner);

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
marlin_dropbox_context_menu (MarlinPluginsBase *base, GtkWidget *menu, GList *files) 
{
    MarlinDropbox *cvs = MARLIN_DROPBOX (base);
    GOFFile *file;
    gchar *filename_un, *filename;
    int file_count;

    g_message ("%s", G_STRFUNC);
    //context_menu_new (u1, menu);

    cvs->selection = files;
    if ((file_count = g_list_length (cvs->selection)) != 1)
        return;

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

    GTimeVal gtv;

    /*
     * 4. We have to block until it's done because nautilus expects a reply.  But we will
     * only block for 50 ms for a reply.
     */

    g_get_current_time(&gtv);
    g_time_val_add(&gtv, 50000);

    GHashTable *context_options_response = g_async_queue_timed_pop(reply_queue, &gtv);
    g_async_queue_unref(reply_queue);

    if (!context_options_response) 
        return;

    /*
     * 5. Parse the reply.
     */

    char **options = g_hash_table_lookup(context_options_response, "options");
    GList *toret = NULL;

    if (options && *options && **options)  {
        GtkWidget *submenu, *root_item;

        root_item = gtk_menu_item_new_with_mnemonic (_("Dropbo_x"));
        submenu = gtk_menu_new ();
        gtk_widget_show (root_item);
        gtk_menu_item_set_submenu ((GtkMenuItem *) root_item,submenu);
        gtk_menu_shell_append ((GtkMenuShell*) menu, root_item);
        plugins->menus = g_list_prepend (plugins->menus, _g_object_ref0 (root_item));

        marlin_dropbox_parse_menu(options, submenu, base, file);
    }

    g_hash_table_unref(context_options_response);



}

static void 
marlin_dropbox_class_init (MarlinDropboxClass *klass) {
    MarlinPluginsBaseClass *object_class = MARLIN_PLUGINS_BASE_CLASS (klass);
    //g_type_class_add_private (klass, sizeof (MarlinDropboxPrivate));

    object_class->finalize = marlin_dropbox_finalize;
    object_class->directory_loaded = marlin_dropbox_real_directory_loaded;
    object_class->update_file_info = marlin_dropbox_update_file_info;
    object_class->context_menu = marlin_dropbox_context_menu;
}


static void 
marlin_dropbox_init (MarlinDropbox *cvs) {
    //self->priv = MARLIN_DROPBOX_GET_PRIVATE (self);
    //self->priv = g_new0 (MarlinDropboxPrivate, 1);

    cvs->filename2obj = g_hash_table_new_full((GHashFunc) g_str_hash,
                                              (GEqualFunc) g_str_equal,
                                              (GDestroyNotify) g_free,
                                              (GDestroyNotify) NULL);
    cvs->obj2filename = g_hash_table_new_full((GHashFunc) g_direct_hash,
                                              (GEqualFunc) g_direct_equal,
                                              (GDestroyNotify) NULL,
                                              (GDestroyNotify) g_free);
    //amtest
    /*cvs->emblem_paths_mutex = g_mutex_new();
      cvs->emblem_paths = NULL;*/

    /* setup the connection obj*/
    dropbox_client_setup(&(cvs->dc));

    /* our hooks */
    /* tricky name: shell_touch signal is used for real time events too (like transfert done event) */
    marlin_dropbox_hooks_add(&(cvs->dc.hookserv), "shell_touch",
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
marlin_dropbox_finalize (MarlinPluginsBase* obj) {
    MarlinDropbox * self = MARLIN_DROPBOX (obj);

    //_g_object_unref0 (self->priv->trash_monitor);
    MARLIN_PLUGINS_BASE_CLASS (marlin_dropbox_parent_class)->finalize (obj);
}

MarlinDropbox* marlin_dropbox_new () {
    MarlinDropbox *u1;

    u1 = (MarlinDropbox*) marlin_plugins_base_construct (MARLIN_TYPE_DROPBOX);

    return u1;
}

MarlinPluginsBase* module_init()
{
    MarlinDropbox* u1 = marlin_dropbox_new ();

    return MARLIN_PLUGINS_BASE (u1);
}

