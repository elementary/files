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

#ifndef PF_DROPBOX_H
#define PF_DROPBOX_H

#include <glib.h>
#include <glib-object.h>
#include <pantheon-files-core/pantheon-files-core.h>

#include "dropbox-command-client.h"
#include "dropbox-hooks.h"
#include "dropbox-client.h"

#define PF_TYPE_DROPBOX (pf_dropbox_get_type ())
#define PF_DROPBOX(obj) (G_TYPE_CHECK_INSTANCE_CAST ((obj), PF_TYPE_DROPBOX, PFDropbox))
#define PF_DROPBOX_CLASS(klass) (G_TYPE_CHECK_CLASS_CAST ((klass), PF_TYPE_DROPBOX, PFDropboxClass))
#define PF_IS_DROPBOX(obj) (G_TYPE_CHECK_INSTANCE_TYPE ((obj), PF_TYPE_DROPBOX))
#define PF_IS_DROPBOX_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), PF_TYPE_DROPBOX))
#define PF_DROPBOX_GET_CLASS(obj) (G_TYPE_INSTANCE_GET_CLASS ((obj), PF_TYPE_DROPBOX, PFDropboxClass))

typedef struct _PFDropbox PFDropbox;
typedef struct _PFDropboxClass PFDropboxClass;
typedef struct _PFDropboxPrivate PFDropboxPrivate;
#define _g_object_unref0(var) ((var == NULL) ? NULL : (var = (g_object_unref (var), NULL)))

struct _PFDropbox {
    MarlinPluginsBase parent_instance;

    GHashTable *filename2obj;
    GHashTable *obj2filename;
    DropboxClient dc;

    GList *selection;
};

struct _PFDropboxClass {
    MarlinPluginsBaseClass parent_class;
};

struct _PFDropboxPrivate {
};

GType pf_dropbox_get_type (void) G_GNUC_CONST;

#endif
