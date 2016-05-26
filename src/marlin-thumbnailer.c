/*-
 * Copyright (c) 2009-2011 Jannis Pohlmann <jannis@xfce.org>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
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

#include <config.h>

#ifdef HAVE_DBUS
#include <dbus/dbus.h>
#include <dbus/dbus-glib.h>

#include "marlin-thumbnailer-proxy.h"
#endif

/*#include <thunar/thunar-marshal.h>
#include <thunar/thunar-private.h>
#include <thunar/thunar-thumbnailer.h>*/
#include "marlin-thumbnailer.h"



/**
 * WARNING: The source code in this file may do harm to animals. Dead kittens
 * are to be expected.
 *
 *
 * MarlinThumbnailer is a class for requesting thumbnails from org.xfce.tumbler.*
 * D-Bus services. This header contains an in-depth description of its design to make
 * it easier to understand why things are the way they are.
 *
 * Please note that all D-Bus calls are performed asynchronously.
 *
 *
 * When a request call is sent out, an internal request ID is created and
 * associated with the corresponding DBusGProxyCall via the request_call_mapping hash
 * table.
 *
 * The D-Bus reply handler then checks if there was an delivery error or
 * not. If the request method was sent successfully, the handle returned by the
 * D-Bus thumbnailer is associated bidirectionally with the internal request ID via
 * the request_handle_mapping and handle_request_mappings. In both cases, the
 * association of the internal request ID with the DBusGProxyCall is removed from
 * request_call_mapping.
 *
 * These hash tables play a major role in the Finished, Error and Ready
 * signal handlers.
 *
 *
 * Ready / Error
 * =============
 *
 * The Ready and Error signal handlers work exactly like Started except that
 * the Ready idle function sets the thumb state of the corresponding
 * GOFFile objects to _READY and the Error signal sets the state to _NONE.
 *
 *
 * Finished
 * ========
 *
 * The Finished signal handler looks up the internal request ID based on
 * the D-Bus thumbnailer handle. It then drops all corresponding information
 * from handle_request_mapping and request_handle_mapping.
 */



#ifdef HAVE_DBUS
typedef enum
{
    MARLIN_THUMBNAILER_IDLE_ERROR,
    MARLIN_THUMBNAILER_IDLE_READY,
    MARLIN_THUMBNAILER_IDLE_STARTED,
} MarlinThumbnailerIdleType;



typedef struct _MarlinThumbnailerCall MarlinThumbnailerCall;
typedef struct _MarlinThumbnailerIdle MarlinThumbnailerIdle;
typedef struct _MarlinThumbnailerItem MarlinThumbnailerItem;
#endif



static void                   marlin_thumbnailer_finalize               (GObject               *object);
#ifdef HAVE_DBUS
static void                   marlin_thumbnailer_init_thumbnailer_proxy (MarlinThumbnailer     *thumbnailer,
                                                                         DBusGConnection       *connection);
static gboolean               marlin_thumbnailer_file_is_supported      (MarlinThumbnailer     *thumbnailer,
                                                                         GOFFile            *file);
static void                   marlin_thumbnailer_thumbnailer_finished   (DBusGProxy            *proxy,
                                                                         guint                  handle,
                                                                         MarlinThumbnailer     *thumbnailer);
static void                   marlin_thumbnailer_thumbnailer_error      (DBusGProxy            *proxy,
                                                                         guint                  handle,
                                                                         const gchar          **uris,
                                                                         gint                   code,
                                                                         const gchar           *message,
                                                                         MarlinThumbnailer     *thumbnailer);
static void                   marlin_thumbnailer_thumbnailer_ready      (DBusGProxy            *proxy,
                                                                         guint32                handle,
                                                                         const gchar          **uris,
                                                                         MarlinThumbnailer     *thumbnailer);
static guint                  marlin_thumbnailer_queue_async            (MarlinThumbnailer     *thumbnailer,
                                                                         gchar                **uris,
                                                                         const gchar          **mime_hints,
                                                                         gboolean large);
static gboolean               marlin_thumbnailer_error_idle             (gpointer               user_data);
static gboolean               marlin_thumbnailer_ready_idle             (gpointer               user_data);
static void                   marlin_thumbnailer_call_free              (MarlinThumbnailerCall *call);
static void                   marlin_thumbnailer_idle_free              (gpointer               data);
#endif



struct _MarlinThumbnailerClass
{
    GObjectClass __parent__;
};

struct _MarlinThumbnailer
{
    GObject __parent__;

#ifdef HAVE_DBUS
    /* proxies to communicate with D-Bus services */
    DBusGProxy *thumbnailer_proxy;

    /* hash table to map D-Bus service handles to MarlinThumbnailer requests */
    GHashTable *handle_request_mapping;

    /* hash table to map MarlinThumbnailer requests to D-Bus service handles */
    GHashTable *request_handle_mapping;

    /* hash table to map MarlinThumbnailer requests to DBusGProxyCalls */
    GHashTable *request_call_mapping;

    GMutex     lock;

    /* cached arrays of URI schemes and MIME types for which thumbnails
     * can be generated */
    gchar     **supported_schemes;
    gchar     **supported_types;

    /* last MarlinThumbnailer request ID */
    guint       last_request;

    /* IDs of idle functions */
    GList      *idles;
#endif
};

#ifdef HAVE_DBUS
struct _MarlinThumbnailerCall
{
    MarlinThumbnailer *thumbnailer;
    gpointer           request;
};

struct _MarlinThumbnailerIdle
{
    MarlinThumbnailerIdleType type;
    MarlinThumbnailer        *thumbnailer;
    guint                     id;

    union
    {
        char                  **uris;
        gpointer                request;
    }                         data;
};

struct _MarlinThumbnailerItem
{
    GFile *file;
    gchar *mime_hint;
};
#endif


static MarlinThumbnailer    *mthumbnailer;


G_DEFINE_TYPE (MarlinThumbnailer, marlin_thumbnailer, G_TYPE_OBJECT);


static void
marlin_thumbnailer_class_init (MarlinThumbnailerClass *klass)
{
    GObjectClass *gobject_class;

    gobject_class = G_OBJECT_CLASS (klass);
    gobject_class->finalize = marlin_thumbnailer_finalize;
}



static void
marlin_thumbnailer_init (MarlinThumbnailer *thumbnailer)
{
#ifdef HAVE_DBUS
    DBusGConnection *connection;

    g_mutex_init (&thumbnailer->lock);
    thumbnailer->supported_schemes = NULL;
    thumbnailer->supported_types = NULL;
    thumbnailer->last_request = 0;
    thumbnailer->idles = NULL;

    /* try to connect to D-Bus */
    connection = dbus_g_bus_get (DBUS_BUS_SESSION, NULL);

    /* initialize the proxies */
    marlin_thumbnailer_init_thumbnailer_proxy (thumbnailer, connection);

    /* check if we have a thumbnailer proxy */
    if (thumbnailer->thumbnailer_proxy != NULL)
    {
        /* we do, set up the hash tables */
        thumbnailer->request_handle_mapping =
            g_hash_table_new_full (g_direct_hash, g_direct_equal, NULL, NULL);
        thumbnailer->handle_request_mapping =
            g_hash_table_new_full (g_direct_hash, g_direct_equal, NULL, NULL);
        thumbnailer->request_call_mapping =
            g_hash_table_new_full (g_direct_hash, g_direct_equal, NULL, NULL);
    }

    /* release the D-Bus connection if we have one */
    if (connection != NULL)
        dbus_g_connection_unref (connection);
#endif
}



static void
marlin_thumbnailer_finalize (GObject *object)
{
#ifdef HAVE_DBUS
    MarlinThumbnailerIdle *idle;
    MarlinThumbnailer     *thumbnailer = MARLIN_THUMBNAILER (object);
    GList                 *list;
    GList                 *lp;

    /* acquire the thumbnailer lock */
    g_mutex_lock (&thumbnailer->lock);

    /* abort all pending idle functions */
    for (lp = thumbnailer->idles; lp != NULL; lp = lp->next)
    {
        idle = lp->data;
        g_source_remove (idle->id);
    }

    /* free the idle list */
    g_list_free (thumbnailer->idles);

    if (thumbnailer->thumbnailer_proxy != NULL)
    {
        /* cancel all pending D-Bus calls */
        list = g_hash_table_get_values (thumbnailer->request_call_mapping);
        for (lp = list; lp != NULL; lp = lp->next)
            dbus_g_proxy_cancel_call (thumbnailer->thumbnailer_proxy, lp->data);
        g_list_free (list);

        g_hash_table_unref (thumbnailer->request_call_mapping);

#if 0
        /* dequeue all pending requests */
        list = g_hash_table_get_keys (thumbnailer->handle_request_mapping);
        for (lp = list; lp != NULL; lp = lp->next)
            marlin_thumbnailer_dequeue_internal (thumbnailer, GPOINTER_TO_UINT (lp->data));
        g_list_free (list);
#endif

        g_hash_table_unref (thumbnailer->handle_request_mapping);
        g_hash_table_unref (thumbnailer->request_handle_mapping);

        /* disconnect from the thumbnailer proxy */
        g_signal_handlers_disconnect_matched (thumbnailer->thumbnailer_proxy,
                                              G_SIGNAL_MATCH_DATA, 0, 0,
                                              NULL, NULL, thumbnailer);

        /* release the thumbnailer proxy */
        g_object_unref (thumbnailer->thumbnailer_proxy);
    }

    /* free the cached URI schemes and MIME types array */
    g_strfreev (thumbnailer->supported_schemes);
    g_strfreev (thumbnailer->supported_types);

    /* release the thumbnailer lock */
    g_mutex_unlock (&thumbnailer->lock);

    /* release the mutex */
    g_mutex_clear (&thumbnailer->lock);
#endif

    (*G_OBJECT_CLASS (marlin_thumbnailer_parent_class)->finalize) (object);
}



#ifdef HAVE_DBUS
static void
marlin_thumbnailer_init_thumbnailer_proxy (MarlinThumbnailer *thumbnailer,
                                           DBusGConnection   *connection)
{
    /* we can't have a proxy without a D-Bus connection */
    if (connection == NULL)
    {
        thumbnailer->thumbnailer_proxy = NULL;
        return;
    }

    /* create the thumbnailer proxy */
    thumbnailer->thumbnailer_proxy =
        dbus_g_proxy_new_for_name (connection,
                                   "org.freedesktop.thumbnails.Thumbnailer1",
                                   "/org/freedesktop/thumbnails/Thumbnailer1",
                                   "org.freedesktop.thumbnails.Thumbnailer1");

    /* TODO this should actually be VOID:UINT,BOXED,INT,STRING */
    dbus_g_object_register_marshaller (g_cclosure_marshal_generic,
                                       G_TYPE_NONE,
                                       G_TYPE_UINT,
                                       G_TYPE_STRV,
                                       G_TYPE_UINT,
                                       G_TYPE_STRING,
                                       G_TYPE_INVALID);

    dbus_g_object_register_marshaller ((GClosureMarshal) g_cclosure_marshal_generic,
                                       G_TYPE_NONE,
                                       G_TYPE_UINT,
                                       G_TYPE_STRV,
                                       G_TYPE_INVALID);

    dbus_g_proxy_add_signal (thumbnailer->thumbnailer_proxy, "Error",
                             G_TYPE_UINT, G_TYPE_STRV, G_TYPE_UINT, G_TYPE_STRING,
                             G_TYPE_INVALID);
    dbus_g_proxy_add_signal (thumbnailer->thumbnailer_proxy, "Finished",
                             G_TYPE_UINT, G_TYPE_INVALID);
    dbus_g_proxy_add_signal (thumbnailer->thumbnailer_proxy, "Ready",
                             G_TYPE_UINT, G_TYPE_STRV, G_TYPE_INVALID);
    dbus_g_proxy_add_signal (thumbnailer->thumbnailer_proxy, "Started",
                             G_TYPE_UINT, G_TYPE_INVALID);

    dbus_g_proxy_connect_signal (thumbnailer->thumbnailer_proxy, "Error",
                                 G_CALLBACK (marlin_thumbnailer_thumbnailer_error),
                                 thumbnailer, NULL);
    dbus_g_proxy_connect_signal (thumbnailer->thumbnailer_proxy, "Finished",
                                 G_CALLBACK (marlin_thumbnailer_thumbnailer_finished),
                                 thumbnailer, NULL);
    dbus_g_proxy_connect_signal (thumbnailer->thumbnailer_proxy, "Ready",
                                 G_CALLBACK (marlin_thumbnailer_thumbnailer_ready),
                                 thumbnailer, NULL);
}



static gboolean
marlin_thumbnailer_file_is_supported (MarlinThumbnailer *thumbnailer,
                                      GOFFile        *file)
{
    const gchar *content_type;
    gboolean     supported = FALSE;
    guint        n;

    g_return_val_if_fail (MARLIN_IS_THUMBNAILER (thumbnailer), FALSE);
    g_return_val_if_fail (GOF_IS_FILE (file), FALSE);
    g_return_val_if_fail (G_IS_FILE (file->location), FALSE);

    /* acquire the thumbnailer lock */
    g_mutex_lock (&thumbnailer->lock);

    /* no types are supported if we don't have a thumbnailer */
    if (thumbnailer->thumbnailer_proxy == NULL)
    {
        /* release the thumbnailer lock */
        g_mutex_unlock (&thumbnailer->lock);
        return FALSE;
    }

    /* determine the content type of the passed file */
    //amtest
    //content_type = marlin_file_get_content_type (file);
    content_type = gof_file_get_ftype (file);

    /* abort if the content type is unknown.  Also, until such time that the thumbnailer backend can
     * provide cover art if available, do not attempt to thumbnail audio (lp: 1467224)*/
    if (content_type == NULL || g_content_type_is_a (content_type, "audio/*"))
    {
        /* release the thumbnailer lock */
        g_mutex_unlock (&thumbnailer->lock);
        return FALSE;
    }

    /* request the supported types on demand */
    if (thumbnailer->supported_schemes == NULL
        || thumbnailer->supported_types == NULL)
    {
        /* request the supported types from the thumbnailer D-Bus service. We only do
         * this once, so using a non-async call should be ok */
        marlin_thumbnailer_proxy_get_supported (thumbnailer->thumbnailer_proxy,
                                                &thumbnailer->supported_schemes,
                                                &thumbnailer->supported_types,
                                                NULL);
    }

    /* check if we have supported URI schemes and MIME types now */
    if (thumbnailer->supported_schemes != NULL
        && thumbnailer->supported_types != NULL)
    {
        /* go through all the URI schemes we support */
        for (n = 0; !supported && thumbnailer->supported_schemes[n] != NULL; ++n)
        {
            /* check if the file has the current URI scheme */
            //amtest
            //if (marlin_file_has_uri_scheme (file, thumbnailer->supported_schemes[n]))
            if (g_file_has_uri_scheme (file->location, thumbnailer->supported_schemes[n]))
            {
                /* check if the type of the file is a subtype of the supported type */
                if (g_content_type_is_a (content_type, thumbnailer->supported_types[n]))
                    supported = TRUE;
            }
        }
    }

    /* release the thumbnailer lock */
    g_mutex_unlock (&thumbnailer->lock);

    return supported;
}



static void
marlin_thumbnailer_thumbnailer_error (DBusGProxy        *proxy,
                                      guint              handle,
                                      const gchar      **uris,
                                      gint               code,
                                      const gchar       *message,
                                      MarlinThumbnailer *thumbnailer)
{
    MarlinThumbnailerIdle *idle;
    gpointer               request;

    g_return_if_fail (DBUS_IS_G_PROXY (proxy));
    g_return_if_fail (MARLIN_IS_THUMBNAILER (thumbnailer));

    /* look up the request ID for this D-Bus service handle */
    request = g_hash_table_lookup (thumbnailer->handle_request_mapping,
                                   GUINT_TO_POINTER (handle));

    /* check if we have a request for this handle */
    if (request != NULL)
    {
        /* allocate a new idle struct */
        idle = g_slice_new0 (MarlinThumbnailerIdle);
        idle->type = MARLIN_THUMBNAILER_IDLE_ERROR;
        idle->thumbnailer = g_object_ref (thumbnailer);

        /* copy the URIs because we need them in the idle function */
        idle->data.uris = g_strdupv ((gchar **)uris);

        /* remember the idle struct because we might have to remove it in finalize() */
        thumbnailer->idles = g_list_prepend (thumbnailer->idles, idle);

        /* call the error idle function when we have the time */
        idle->id = g_idle_add_full (G_PRIORITY_LOW,
                                    marlin_thumbnailer_error_idle, idle,
                                    marlin_thumbnailer_idle_free);
    }
}



static void
marlin_thumbnailer_thumbnailer_finished (DBusGProxy        *proxy,
                                         guint              handle,
                                         MarlinThumbnailer *thumbnailer)
{
    gpointer request;

    g_return_if_fail (DBUS_IS_G_PROXY (proxy));
    g_return_if_fail (MARLIN_IS_THUMBNAILER (thumbnailer));

    /* look up the request ID for this D-Bus service handle */
    request = g_hash_table_lookup (thumbnailer->handle_request_mapping,
                                   GUINT_TO_POINTER (handle));

    /* check if we have a request for this handle */
    if (GPOINTER_TO_UINT (request) > 0)
    {
        /* the request is finished, drop all the information about it */
        g_hash_table_remove (thumbnailer->handle_request_mapping, request);
        g_hash_table_remove (thumbnailer->request_handle_mapping, request);
    }
}



static void
marlin_thumbnailer_thumbnailer_ready (DBusGProxy        *proxy,
                                      guint32            handle,
                                      const gchar      **uris,
                                      MarlinThumbnailer *thumbnailer)
{
    MarlinThumbnailerIdle *idle;

    g_return_if_fail (DBUS_IS_G_PROXY (proxy));
    g_return_if_fail (MARLIN_IS_THUMBNAILER (thumbnailer));

    /* check if we have any ready URIs */
    if (uris != NULL)
    {
        /* allocate a new idle struct */
        idle = g_slice_new0 (MarlinThumbnailerIdle);
        idle->type = MARLIN_THUMBNAILER_IDLE_READY;
        idle->thumbnailer = g_object_ref (thumbnailer);

        /* copy the URI array because we need it in the idle function */
        idle->data.uris = g_strdupv ((gchar **)uris);

        /* remember the idle struct because we might have to remove it in finalize() */
        thumbnailer->idles = g_list_prepend (thumbnailer->idles, idle);
        /* call the ready idle function when we have the time */
        idle->id = g_idle_add_full (G_PRIORITY_LOW,
                                    marlin_thumbnailer_ready_idle, idle,
                                    marlin_thumbnailer_idle_free);
    }
}



static void
marlin_thumbnailer_queue_async_reply (DBusGProxy *proxy,
                                      guint       handle,
                                      GError     *error,
                                      gpointer    user_data)
{
    MarlinThumbnailerCall *call = user_data;
    MarlinThumbnailer     *thumbnailer = MARLIN_THUMBNAILER (call->thumbnailer);

    g_return_if_fail (DBUS_IS_G_PROXY (proxy));
    g_return_if_fail (call != NULL);
    g_return_if_fail (MARLIN_IS_THUMBNAILER (thumbnailer));

    g_mutex_lock (&thumbnailer->lock);

    if (error == NULL)
    {
        /* remember that this request and D-Bus handle belong together */
        g_hash_table_insert (thumbnailer->request_handle_mapping,
                             GUINT_TO_POINTER (call->request), GUINT_TO_POINTER (handle));
        g_hash_table_insert (thumbnailer->handle_request_mapping,
                             GUINT_TO_POINTER (handle), GUINT_TO_POINTER (call->request));
    }

    /* the queue call is finished, we can forget about its proxy call */
    g_hash_table_remove (thumbnailer->request_call_mapping, call->request);

    marlin_thumbnailer_call_free (call);

    g_mutex_unlock (&thumbnailer->lock);
}



static guint
marlin_thumbnailer_queue_async (MarlinThumbnailer *thumbnailer,
                                gchar            **uris,
                                const gchar      **mime_hints, gboolean large)
{
    MarlinThumbnailerCall *thumbnailer_call;
    DBusGProxyCall        *call;
    gpointer               request;
    guint                  request_no;

    g_return_val_if_fail (MARLIN_IS_THUMBNAILER (thumbnailer), 0);
    g_return_val_if_fail (uris != NULL, 0);
    g_return_val_if_fail (mime_hints != NULL, 0);
    g_return_val_if_fail (DBUS_IS_G_PROXY (thumbnailer->thumbnailer_proxy), 0);

    /* compute the next request ID, making sure it's never 0 */
    request_no = thumbnailer->last_request + 1;
    request_no = MAX (request_no, 1);

    /* remember the ID for the next request */
    thumbnailer->last_request = request_no;

    /* use the newly generated ID for this request */
    request = GUINT_TO_POINTER (request_no);

    /* allocate a new call struct for the async D-Bus call */
    thumbnailer_call = g_slice_new0 (MarlinThumbnailerCall);
    thumbnailer_call->request = request;
    thumbnailer_call->thumbnailer = g_object_ref (thumbnailer);

    /* queue thumbnails for the given URIs asynchronously */
    if(large)
    {
        call = marlin_thumbnailer_proxy_queue_async (thumbnailer->thumbnailer_proxy,
                                                 (const gchar **)uris, mime_hints,
                                                 "large", "foreground", 0,
                                                 marlin_thumbnailer_queue_async_reply,
                                                 thumbnailer_call);
    }
    else
    {
        call = marlin_thumbnailer_proxy_queue_async (thumbnailer->thumbnailer_proxy,
                                                 (const gchar **)uris, mime_hints,
                                                 "normal", "foreground", 0,
                                                 marlin_thumbnailer_queue_async_reply,
                                                 thumbnailer_call);
    }

    /* remember to which request the call struct belongs */
    g_hash_table_insert (thumbnailer->request_call_mapping, request, call);

    /* return the request ID used for this request */
    return request_no;
}


static gboolean
marlin_thumbnailer_error_idle (gpointer user_data)
{
    MarlinThumbnailerIdle *idle = user_data;
    GOFFile            *file;
    GFile                 *gfile;
    guint                  n;

    g_return_val_if_fail (idle != NULL, FALSE);
    g_return_val_if_fail (idle->type == MARLIN_THUMBNAILER_IDLE_ERROR, FALSE);

    /* iterate over all failed URIs */
    for (n = 0; idle->data.uris != NULL && idle->data.uris[n] != NULL; ++n)
    {
        /* look up the corresponding GOFFile from the cache */
        gfile = g_file_new_for_uri (idle->data.uris[n]);
        //amtest
        //file = marlin_file_cache_lookup (gfile);
        file = gof_file_get (gfile);
        g_object_unref (gfile);

        /* check if we have a file for this URI in the cache */
        if (file != NULL)
        {
            /* set thumbnail state to none unless the thumbnail has already been created.
             * This is to prevent race conditions with the other idle functions */
            if (gof_file_get_thumb_state (file) != GOF_FILE_THUMB_STATE_READY)
                gof_file_set_thumb_state (file, GOF_FILE_THUMB_STATE_NONE);
        }
        g_object_unref (file);
    }

    /* remove the idle struct */
    g_mutex_lock (&idle->thumbnailer->lock);
    idle->thumbnailer->idles = g_list_remove (idle->thumbnailer->idles, idle);
    g_mutex_unlock (&idle->thumbnailer->lock);

    /* remove the idle source, which also destroys the idle struct */
    return FALSE;
}



static gboolean
marlin_thumbnailer_ready_idle (gpointer user_data)
{
    MarlinThumbnailerIdle *idle = user_data;
    GOFFile            *file;
    GFile                 *gfile;
    guint                  n;

    g_return_val_if_fail (idle != NULL, FALSE);
    g_return_val_if_fail (idle->type == MARLIN_THUMBNAILER_IDLE_READY, FALSE);

    /* iterate over all failed URIs */
    for (n = 0; idle->data.uris != NULL && idle->data.uris[n] != NULL; ++n)
    {
        /* look up the corresponding GOFFile from the cache */
        gfile = g_file_new_for_uri (idle->data.uris[n]);
        //amtest
        //file = marlin_file_cache_lookup (gfile);
        file = gof_file_get (gfile);
        g_object_unref (gfile);

        //amtest
        /* check if we have a file for this URI in the cache */
        if (file != NULL)
        {
            /* set thumbnail state to ready - we now have a thumbnail */
            gof_file_set_thumb_state (file, GOF_FILE_THUMB_STATE_READY);
            /* ensure new thumbnail is displayed */
            gof_file_query_thumbnail_update (file);
        }
        g_object_unref (file);
    }

    /* remove the idle struct */
    g_mutex_lock (&idle->thumbnailer->lock);
    idle->thumbnailer->idles = g_list_remove (idle->thumbnailer->idles, idle);
    g_mutex_unlock (&idle->thumbnailer->lock);

    /* remove the idle source, which also destroys the idle struct */
    return FALSE;
}



static void
marlin_thumbnailer_call_free (MarlinThumbnailerCall *call)
{
    g_return_if_fail (call != NULL);

    /* drop the thumbnailer reference */
    g_object_unref (call->thumbnailer);

    /* free the struct */
    g_slice_free (MarlinThumbnailerCall, call);
}



static void
marlin_thumbnailer_idle_free (gpointer data)
{
    MarlinThumbnailerIdle *idle = data;

    g_return_if_fail (idle != NULL);

    /* free the URI array if necessary */
    if (idle->type == MARLIN_THUMBNAILER_IDLE_READY
        || idle->type == MARLIN_THUMBNAILER_IDLE_ERROR)
    {
        g_strfreev (idle->data.uris);
    }

    /* drop the thumbnailer reference */
    g_object_unref (idle->thumbnailer);

    /* free the struct */
    g_slice_free (MarlinThumbnailerIdle, idle);
}
#endif /* HAVE_DBUS */



/**
 * marlin_thumbnailer_new:
 *
 * Allocates a new #MarlinThumbnailer object, which can be used to
 * generate and store thumbnails for files.
 *
 * The caller is responsible to free the returned
 * object using g_object_unref() when no longer needed.
 *
 * Return value: a newly allocated #MarlinThumbnailer.
**/
MarlinThumbnailer*
marlin_thumbnailer_new (void)
{
    return g_object_new (MARLIN_TYPE_THUMBNAILER, NULL);
}

MarlinThumbnailer*
marlin_thumbnailer_get (void)
{
    if (mthumbnailer == NULL)
        mthumbnailer = marlin_thumbnailer_new ();
    else
        g_object_ref (G_OBJECT (mthumbnailer));

    return mthumbnailer;
}

gboolean
marlin_thumbnailer_queue_file (MarlinThumbnailer  *thumbnailer,
                               GOFFile            *file,
                               guint              *request,
                               gboolean large)
{
    GList files;

    g_return_val_if_fail (MARLIN_IS_THUMBNAILER (thumbnailer), FALSE);
    g_return_val_if_fail (GOF_IS_FILE (file), FALSE);

    /* fake a file list */
    files.data = file;
    files.next = NULL;
    files.prev = NULL;

    /* queue a thumbnail request for the file */
    return marlin_thumbnailer_queue_files (thumbnailer, &files, request, large);
}



gboolean
marlin_thumbnailer_queue_files (MarlinThumbnailer *thumbnailer,
                                GList             *files,
                                guint             *request, gboolean large)
{
    gboolean      success = FALSE;
#ifdef HAVE_DBUS
    const gchar **mime_hints;
    gchar       **uris;
    GList        *lp;
    GList        *supported_files = NULL;
    guint         n;
    guint         n_items;
#endif

    g_return_val_if_fail (MARLIN_IS_THUMBNAILER (thumbnailer), FALSE);
    g_return_val_if_fail (files != NULL, FALSE);

#ifdef HAVE_DBUS
    /* acquire the thumbnailer lock */
    g_mutex_lock (&thumbnailer->lock);

    if (thumbnailer->thumbnailer_proxy == NULL)
    {
        /* release the lock and abort */
        g_mutex_unlock (&thumbnailer->lock);
        return FALSE;
    }

    /* release the thumbnailer lock */
    g_mutex_unlock (&thumbnailer->lock);

    /* collect all supported files from the list that are neither in the
     * about to be queued (wait queue), nor already queued, nor already
     * processed (and awaiting to be refreshed) */
    for (lp = g_list_last (files); lp != NULL; lp = lp->prev)
    {
        /* It is up to the user whether or not remote files are thumbnailed*/
        if (marlin_thumbnailer_file_is_supported (thumbnailer, lp->data)) {
                supported_files = g_list_prepend (supported_files, lp->data);
        } else {
            gof_file_set_thumb_state (lp->data, GOF_FILE_THUMB_STATE_NONE);
        }
    }

    /* determine how many URIs are in the wait queue */
    n_items = g_list_length (supported_files);

    /* check if we have any supported files */
    if (n_items > 0)
    {
        /* allocate arrays for URIs and mime hints */
        uris = g_new0 (gchar *, n_items + 1);
        mime_hints = g_new0 (const gchar *, n_items + 1);

        /* fill URI and MIME hint arrays with items from the wait queue */
        for (lp = g_list_last (supported_files), n = 0; lp != NULL; lp = lp->prev, ++n)
        {
            /* set the thumbnail state to loading */
            gof_file_set_thumb_state (lp->data, GOF_FILE_THUMB_STATE_LOADING);

            /* save URI and MIME hint in the arrays */
            uris[n] = GOF_FILE (lp->data)->uri;
            mime_hints[n] = gof_file_get_ftype (GOF_FILE (lp->data));
        }

        /* NULL-terminate both arrays */
        uris[n] = NULL;
        mime_hints[n] = NULL;

        g_mutex_lock (&thumbnailer->lock);

        /* queue a thumbnail request for the URIs from the wait queue */
        if (request != NULL)
            *request = marlin_thumbnailer_queue_async (thumbnailer, uris, mime_hints, large);
        else
            marlin_thumbnailer_queue_async (thumbnailer, uris, mime_hints, large);

        g_mutex_unlock (&thumbnailer->lock);

        /* free mime hints array */
        g_free (mime_hints);

        /* free uri array */
        g_free (uris);

        /* free the list of supported files */
        g_list_free (supported_files);

        /* we assume success if we've come so far */
        success = TRUE;
    }
#endif /* HAVE_DBUS */

    return success;
}


void
marlin_thumbnailer_dequeue (MarlinThumbnailer *thumbnailer,
                            guint              request)
{
#ifdef HAVE_DBUS
    gpointer request_ptr;
    gpointer handle;
    DBusGProxyCall *call;
#endif

    g_return_if_fail (MARLIN_IS_THUMBNAILER (thumbnailer));

#ifdef HAVE_DBUS
    /* convert the number to a pointer */
    request_ptr = GUINT_TO_POINTER (request);

    /* acquire the thumbnailer lock */
    g_mutex_lock (&thumbnailer->lock);

    /* check if we have a valid thumbnailer proxy */
    if (thumbnailer->thumbnailer_proxy != NULL)
    {
        /* check if there is a pending dbus proxy call for this request */
        call = g_hash_table_lookup (thumbnailer->request_call_mapping, request_ptr);
        if (call != NULL) {
            /* Dequeue the call */
            dbus_g_proxy_cancel_call (thumbnailer->thumbnailer_proxy, call);
            g_hash_table_remove (thumbnailer->request_call_mapping, request_ptr);
        }

        /* check if there is a pending tumbler request handle for this request */
        handle = g_hash_table_lookup (thumbnailer->request_handle_mapping, request_ptr);
        if (GPOINTER_TO_UINT (handle) > 0) {
            /* Dequeue the request */
            marlin_thumbnailer_proxy_unqueue (thumbnailer->thumbnailer_proxy,
                                              GPOINTER_TO_UINT (handle), NULL);

            /* drop all the request information */
            g_hash_table_remove (thumbnailer->handle_request_mapping, handle);
            g_hash_table_remove (thumbnailer->request_handle_mapping, request_ptr);
        }
    }

    /* release the thumbnailer lock */
    g_mutex_unlock (&thumbnailer->lock);
#endif
}
