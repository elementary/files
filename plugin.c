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
#include "plugin.h"

//static gpointer marlin_dropbox_parent_class = NULL;

//#define MARLIN_DROPBOX_GET_PRIVATE(o) (G_TYPE_INSTANCE_GET_PRIVATE ((o), MARLIN_TYPE_DROPBOX, MarlinDropboxPrivate))

G_DEFINE_TYPE (MarlinDropbox, marlin_dropbox, MARLIN_PLUGINS_TYPE_BASE)

static void marlin_dropbox_finalize (MarlinPluginsBase* obj);

/*static gchar* current_path = NULL;
static gboolean menu_added = FALSE;
static GSettings* settings = NULL;
static GList *menus = NULL;
static GtkWidget *menu;*/

static void 
marlin_dropbox_real_directory_loaded (MarlinPluginsBase *base, void *user_data) 
{
    GOFFile *file;

    GObject *obj = ((GObject**) user_data)[2];
    file = g_object_ref ((GOFFile *) obj);
    g_message ("%s : %s", G_STRFUNC, file->uri);

    //unref file

}

static void 
marlin_dropbox_update_file_info (MarlinPluginsBase *base, GOFFile *file) 
{
    MarlinDropbox *u1 = MARLIN_DROPBOX (base);

    //file_watcher_add_file (u1->file_watcher, file);
}

static void 
marlin_dropbox_context_menu (MarlinPluginsBase *base, GtkWidget *menu) 
{
    MarlinDropbox *u1 = MARLIN_DROPBOX (base);

    g_message ("%s", G_STRFUNC);
    //context_menu_new (u1, menu);
}

static void marlin_dropbox_real_file (MarlinPluginsBase *base, GList *files) {
    MarlinDropbox *u1 = MARLIN_DROPBOX (base);

    u1->selection = files;

    /*GList *l;
    GOFFile *goffile;
    for (l=files; l != NULL; l=l->next) {
        goffile = (GOFFile *) l->data;
        g_message ("selection %s", goffile->uri);
    }*/
}

static void 
marlin_dropbox_class_init (MarlinDropboxClass *klass) {
    MarlinPluginsBaseClass *object_class = MARLIN_PLUGINS_BASE_CLASS (klass);
	//g_type_class_add_private (klass, sizeof (MarlinDropboxPrivate));

	object_class->finalize = marlin_dropbox_finalize;
	object_class->directory_loaded = marlin_dropbox_real_directory_loaded;
	object_class->update_file_info = marlin_dropbox_update_file_info;
	object_class->context_menu = marlin_dropbox_context_menu;
	object_class->file = marlin_dropbox_real_file;
}


static void 
marlin_dropbox_init (MarlinDropbox *u1) {
	//self->priv = MARLIN_DROPBOX_GET_PRIVATE (self);
    //self->priv = g_new0 (MarlinDropboxPrivate, 1);
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

