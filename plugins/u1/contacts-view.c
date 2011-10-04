/* -*- Mode: C; tab-width: 8; indent-tabs-mode: t; c-basic-offset: 8 -*- */
/*
 * Copyright (C) 2009 Canonical Services Ltd (www.canonical.com)
 *
 * Authors: Rodrigo Moya <rodrigo.moya@canonical.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of version 2 of the GNU Lesser General Public
 * License as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#include <config.h>

#include <glib/gi18n-lib.h>
#include "contacts-view.h"
#include "highlight.h"

#ifdef BUILD_GRID_VIEW
#define AVATAR_SIZE 64
#else
#define AVATAR_SIZE 24
#endif

static void contacts_view_init (ContactsView *cv);
static void contacts_view_class_init (ContactsViewClass *klass);

G_DEFINE_TYPE(ContactsView, contacts_view, GTK_TYPE_SCROLLED_WINDOW)

#ifdef HAVE_NAUTILUS_30
#define SETTINGS_DOMAIN "org.gnome.nautilus.extensions.ubuntuone"
#define SETTINGS_CONTACTS_KEY "recently-used-contacts"
#else
#define RECENTLY_USED_CONTACTS_KEY "/apps/libubuntuone/recently-used"
#endif

#define CONTACTS_VIEW_COLUMN_NAME   0
#define CONTACTS_VIEW_COLUMN_MARKUP 1
#define CONTACTS_VIEW_COLUMN_EMAIL  2
#define CONTACTS_VIEW_COLUMN_PIXBUF 3
#define CONTACTS_VIEW_COLUMN_RECENT 4

typedef struct {
	gchar *name;
	gchar *markedup_name;
	gchar *email;
	GdkPixbuf *pixbuf;
} SelectedContactInfo;

enum {
	SELECTION_CHANGED_SIGNAL,
	CONTACTS_COUNT_CHANGED_SIGNAL,
	LAST_SIGNAL
};
static guint contacts_view_signals[LAST_SIGNAL];

static void
contacts_view_finalize (GObject *object)
{
	ContactsView *cv = CONTACTS_VIEW (object);

	if (cv->selection != NULL) {
		g_hash_table_destroy (cv->selection);
		cv->selection = NULL;
	}

	if (cv->recently_used != NULL) {
		g_hash_table_destroy (cv->recently_used);
		cv->recently_used = NULL;
	}

#ifdef HAVE_NAUTILUS_30
	if (cv->settings != NULL) {
		g_object_unref (G_OBJECT (cv->settings));
		cv->settings = NULL;
	}
#else
	if (cv->config_client != NULL) {
		g_object_unref (G_OBJECT (cv->config_client));
		cv->config_client = NULL;
	}
#endif

	if (cv->source_list != NULL) {
		g_object_unref (G_OBJECT (cv->source_list));
		cv->source_list = NULL;
	}

	if (cv->added_contacts != NULL) {
		g_hash_table_destroy (cv->added_contacts);
		cv->added_contacts = NULL;
	}

	while (cv->books != NULL) {
		EBook *book = (EBook *) cv->books->data;
		cv->books = g_slist_remove (cv->books, book);
		g_object_unref (G_OBJECT (book));
	}

	G_OBJECT_CLASS (contacts_view_parent_class)->finalize (object);
}

static void
contacts_view_class_init (ContactsViewClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS (klass);

	object_class->finalize = contacts_view_finalize;

	/* Signals */
	contacts_view_signals[SELECTION_CHANGED_SIGNAL] =
		g_signal_new ("selection-changed",
			      G_OBJECT_CLASS_TYPE (object_class),
			      G_SIGNAL_RUN_LAST,
			      G_STRUCT_OFFSET (ContactsViewClass, selection_changed),
			      NULL, NULL,
			      g_cclosure_marshal_VOID__VOID,
			      G_TYPE_NONE,
			      0);
	contacts_view_signals[CONTACTS_COUNT_CHANGED_SIGNAL] =
		g_signal_new ("contacts-count-changed",
			      G_OBJECT_CLASS_TYPE (object_class),
			      G_SIGNAL_RUN_LAST,
			      G_STRUCT_OFFSET (ContactsViewClass, contacts_count_changed),
			      NULL, NULL,
			      g_cclosure_marshal_VOID__INT,
			      G_TYPE_NONE, 1,
			      G_TYPE_INT);
}

static void
recently_used_to_list_cb (gpointer key, gpointer value, gpointer user_data)
{
	GSList **list = (GSList **) user_data;

	*list = g_slist_append (*list, key);
}

static void
save_recently_used_list (ContactsView *cv)
{
	GSList *list = NULL;

	g_hash_table_foreach (cv->recently_used, (GHFunc) recently_used_to_list_cb, &list);

#ifdef HAVE_NAUTILUS_30
	{
		gchar **strv = e_client_util_slist_to_strv (list);
		g_settings_set_strv (cv->settings, SETTINGS_CONTACTS_KEY,
				     (const gchar * const *) strv);
		g_strfreev (strv);
	}
#else
	gconf_client_set_list (cv->config_client, RECENTLY_USED_CONTACTS_KEY, GCONF_VALUE_STRING, list, NULL);
#endif

	g_slist_free (list);
}

static void
selection_changed_cb (GtkWidget *view, gpointer data)
{
	GtkTreeModel *model;
	GList *selected_items, *l;
	ContactsView *cv = CONTACTS_VIEW (data);

	/* We first remove all the previous selected items */
	g_hash_table_remove_all (cv->selection);

	/* Now add the new selection */
#ifdef BUILD_GRID_VIEW
	model = gtk_icon_view_get_model (GTK_ICON_VIEW (view));
	selected_items = gtk_icon_view_get_selected_items (GTK_ICON_VIEW (view));
#else
	selected_items = gtk_tree_selection_get_selected_rows (
		GTK_TREE_SELECTION (view),
		&model);
#endif

	for (l = selected_items; l != NULL; l = l->next) {
		GtkTreeIter iter;

		if (gtk_tree_model_get_iter (model, &iter, (GtkTreePath *) l->data)) {
			gchar *name, *email, *s;
			GdkPixbuf *icon;
			SelectedContactInfo *sci;

			gtk_tree_model_get (model, &iter,
					    CONTACTS_VIEW_COLUMN_NAME, &name,
					    CONTACTS_VIEW_COLUMN_EMAIL, &email,
					    CONTACTS_VIEW_COLUMN_PIXBUF, &icon,
					    -1);

			sci = g_new0 (SelectedContactInfo, 1);
			sci->name = g_strdup (name);
			sci->markedup_name = g_markup_escape_text (name, -1);
			sci->email = g_strdup (email);
			sci->pixbuf = g_object_ref (icon);
			g_hash_table_insert (cv->selection, g_strdup (name), sci);

			/* Add it to the recently used list */
			s = g_strdup (sci->name);
			g_hash_table_insert (cv->recently_used, s, s);
			save_recently_used_list (cv);
		}
	}

	/* Free memory */
	g_list_foreach (selected_items, (GFunc) gtk_tree_path_free, NULL);
	g_list_free (selected_items);

	/* Notify listeners the selection has changed */
	g_signal_emit_by_name (cv, "selection-changed", NULL);
}

static void
add_one_contact (ContactsView *cv,
		 const gchar *name,
		 const gchar *markedup_name,
		 const gchar *email,
		 EContact *contact,
		 GHashTable *selection_hash)
{
	GtkTreeIter new_row, current_row;
	EContactPhoto *photo = NULL;
	GtkTreeModel *model;
	GdkPixbuf *pixbuf;
	gboolean new_is_recent;

	/* Get the pixbuf for this contact */
	if (contact != NULL) {
		photo = e_contact_get (contact, E_CONTACT_PHOTO);
		if (photo == NULL)
			photo = e_contact_get (contact, E_CONTACT_LOGO);
	}

	if (photo) {
		gint width, height;
		GdkPixbufLoader *loader = gdk_pixbuf_loader_new ();

		gdk_pixbuf_loader_write (loader, photo->data.inlined.data, photo->data.inlined.length, NULL);
		gdk_pixbuf_loader_close (loader, NULL);
		pixbuf = gdk_pixbuf_loader_get_pixbuf (loader);

		if (pixbuf != NULL) {
			g_object_ref (G_OBJECT (pixbuf));

			/* Scale the image if it's too big */
			width = gdk_pixbuf_get_width (pixbuf);
			height = gdk_pixbuf_get_height (pixbuf);
			if (width > AVATAR_SIZE || height > AVATAR_SIZE) {
				GdkPixbuf *scaled;

				scaled = gdk_pixbuf_scale_simple ((const GdkPixbuf *) pixbuf,
								  AVATAR_SIZE, AVATAR_SIZE, GDK_INTERP_NEAREST);
				g_object_unref (G_OBJECT (pixbuf));
				pixbuf = scaled;
			}
		} else {
			GtkIconTheme *icon_theme = gtk_icon_theme_get_default ();

			pixbuf = gtk_icon_theme_load_icon (icon_theme, "avatar-default", AVATAR_SIZE, 0, NULL);
		}

		g_object_unref (G_OBJECT (loader));
	} else {
		GtkIconTheme *icon_theme = gtk_icon_theme_get_default ();

		pixbuf = gtk_icon_theme_load_icon (icon_theme, "avatar-default", AVATAR_SIZE, 0, NULL);
	}

	/* Add the contact to the contacts view */
#ifdef BUILD_GRID_VIEW
	model = gtk_icon_view_get_model (GTK_ICON_VIEW (cv->contacts_list));
#else
	model = gtk_tree_view_get_model (GTK_TREE_VIEW (cv->contacts_list));
#endif

	new_is_recent = g_hash_table_lookup (cv->recently_used, name) != NULL;

	if (gtk_tree_model_get_iter_first (model, &current_row)) {
		gchar *current_name;
		gboolean added = FALSE;

#ifdef BUILD_GRID_VIEW
		gtk_icon_view_scroll_to_path (GTK_ICON_VIEW (cv->contacts_list),
					      gtk_tree_model_get_path (GTK_TREE_MODEL (model), &current_row),
					      TRUE, 0.0, 0.0);
#endif

		do {
			gboolean current_is_recent, insert_before = FALSE;

			gtk_tree_model_get (model, &current_row,
					    CONTACTS_VIEW_COLUMN_NAME, &current_name,
					    -1);

			current_is_recent = g_hash_table_lookup (cv->recently_used, current_name) != NULL;

			if (g_hash_table_lookup (selection_hash, current_name) != NULL)
				continue;
			else if (new_is_recent) {
				if (current_is_recent) {
					if (g_ascii_strcasecmp (name, (const gchar *) current_name) < 0)
						insert_before = TRUE;
				} else
					insert_before = TRUE;
			} else if (!current_is_recent &&
				   g_ascii_strcasecmp (name, (const gchar *) current_name) < 0)
				insert_before = TRUE;

			if (insert_before) {
				gtk_list_store_insert_before (GTK_LIST_STORE (model), &new_row, &current_row);
				added = TRUE;

				break;
			}
		} while (gtk_tree_model_iter_next (model, &current_row));

		if (!added)
			gtk_list_store_append (GTK_LIST_STORE (model), &new_row);
	} else
		gtk_list_store_append (GTK_LIST_STORE (model), &new_row);

	gtk_list_store_set (GTK_LIST_STORE (model), &new_row,
			    CONTACTS_VIEW_COLUMN_NAME, name,
			    CONTACTS_VIEW_COLUMN_MARKUP, markedup_name,
			    CONTACTS_VIEW_COLUMN_EMAIL, email,
			    CONTACTS_VIEW_COLUMN_PIXBUF, pixbuf,
			    CONTACTS_VIEW_COLUMN_RECENT, new_is_recent,
			    -1);
}

static void
add_contacts (ContactsView *cv, GList *contacts, GHashTable *selection_hash, gchar *search_string)
{
	GList *l;
	GtkTreeModel *model;

	for (l = contacts; l != NULL; l = l->next) {
		EContact *contact = l->data;
		const gchar *email = NULL;
		GList *emails_list, *al;
		EContactName *contact_name;
		gchar *full_name = NULL;
		gchar *markedup_name = NULL;

		contact_name = (EContactName *) e_contact_get (contact, E_CONTACT_NAME);
		if (contact_name != NULL)
			full_name = e_contact_name_to_string (contact_name);
		else
			full_name = e_contact_get (contact, E_CONTACT_NAME_OR_ORG);

		emails_list = e_contact_get_attributes (contact, E_CONTACT_EMAIL);
		for (al = emails_list; al != NULL; al = al->next) {
			EVCardAttribute *attr = (EVCardAttribute *) al->data;

			email = e_vcard_attribute_get_value (attr);
			if (email != NULL)
				break;
		}

		if (full_name == NULL) {
			if (email != NULL)
				full_name = g_strdup (email);
			else
				g_warning ("Contact without name or email addresses");
		}

		markedup_name = highlight_result (search_string, full_name);

		/* We add the selected items when searching, so ignore them here */
		if (!g_hash_table_lookup (selection_hash, (gconstpointer) full_name)) {
			if (email != NULL) {
				add_one_contact (cv, full_name, markedup_name, email, contact, selection_hash);
				cv->matched_contacts += 1;
			}
		}

		g_list_foreach (emails_list, (GFunc) e_vcard_attribute_free, NULL);
		g_list_free (emails_list);
		e_contact_name_free (contact_name);
		g_free (markedup_name);
		g_free (full_name);
	}

#ifdef BUILD_GRID_VIEW
	model = gtk_icon_view_get_model (GTK_ICON_VIEW (cv->contacts_list));
#else
	model = gtk_tree_view_get_model (GTK_TREE_VIEW (cv->contacts_list));
#endif

	g_signal_emit_by_name (cv, "contacts-count-changed",
			       gtk_tree_model_iter_n_children (model, NULL));
}

static void
append_selected_to_model (GtkWidget *view,
			  const gchar *contact_name,
			  const gchar *contact_markedup_name,
			  const gchar *contact_email,
			  GdkPixbuf *pixbuf)
{
	GtkTreeIter new_row;
	GtkListStore *model;

#ifdef BUILD_GRID_VIEW
	model = GTK_LIST_STORE (gtk_icon_view_get_model (GTK_ICON_VIEW (view)));
#else
	model = GTK_LIST_STORE (gtk_tree_view_get_model (GTK_TREE_VIEW (view)));
#endif

	gtk_list_store_prepend (model, &new_row);
	gtk_list_store_set (model, &new_row,
			    CONTACTS_VIEW_COLUMN_NAME, contact_name,
			    CONTACTS_VIEW_COLUMN_MARKUP, contact_markedup_name,
			    CONTACTS_VIEW_COLUMN_EMAIL, contact_email,
			    CONTACTS_VIEW_COLUMN_PIXBUF, pixbuf,
			    CONTACTS_VIEW_COLUMN_RECENT, TRUE,
			    -1);

#ifdef BUILD_GRID_VIEW
	gtk_icon_view_select_path (GTK_ICON_VIEW (view),
				   gtk_tree_model_get_path (GTK_TREE_MODEL (model), &new_row));
#else
	gtk_tree_selection_select_path (
		gtk_tree_view_get_selection (GTK_TREE_VIEW (view)),
		gtk_tree_model_get_path (GTK_TREE_MODEL (model), &new_row));
#endif
}

static void
foreach_selected_to_model_cb (gpointer key, gpointer value, gpointer user_data)
{
	SelectedContactInfo *sci = (SelectedContactInfo *) value;
	ContactsView *cv = CONTACTS_VIEW (user_data);

	if (g_hash_table_lookup (cv->selection, sci->name) != NULL)
		return;

	append_selected_to_model (cv->contacts_list, sci->name, sci->markedup_name, sci->email, sci->pixbuf);
}

typedef struct {
	ContactsView *cv;
	GHashTable *selection_hash;
	EBookQuery *query;
	gchar *search_string;
} GetContactsCallbackData;

static void
got_contacts_cb (EBook *book, EBookStatus status, GList *contacts, gpointer user_data)
{
	GetContactsCallbackData *gccd = user_data;

	if (status == E_BOOK_ERROR_OK) {
		add_contacts (gccd->cv, contacts, gccd->selection_hash, gccd->search_string);
		if (gccd->selection_hash != gccd->cv->selection) {
			/* If it's a separate selection, add all contacts to the views */
			g_hash_table_foreach (gccd->selection_hash, (GHFunc) foreach_selected_to_model_cb, gccd->cv);
			g_hash_table_unref (gccd->selection_hash);
		}
	} else {
		g_warning ("Error retrieving contacts from addressbook %s: %d",
			   e_book_get_uri (book), status);
	}

	e_book_query_unref (gccd->query);
	g_free (gccd->search_string);
	g_free (gccd);
}

static void
retrieve_contacts (ContactsView *cv, EBook *book, const gchar *search_string, GHashTable *selection_hash)
{
	GetContactsCallbackData *gccd;

	gccd = g_new0 (GetContactsCallbackData, 1);
	gccd->cv = cv;
	gccd->query = e_book_query_any_field_contains (search_string);
	gccd->search_string = g_strdup (search_string);
	if (selection_hash == cv->selection)
		gccd->selection_hash = selection_hash;
	else
		gccd->selection_hash = g_hash_table_ref (selection_hash);

	e_book_async_get_contacts (book, gccd->query, (EBookListCallback) got_contacts_cb, gccd);
}

static void
book_opened_cb (EBook *book, EBookStatus status, gpointer user_data)
{
	ContactsView *cv = CONTACTS_VIEW (user_data);

	if (status != E_BOOK_ERROR_OK) {
		g_warning ("Error opening addressbook %s: %d", e_book_get_uri (book), status);
		g_object_unref (G_OBJECT (book));
		return;
	}

	/* Add the book to the list of opened books */
	cv->books = g_slist_append (cv->books, book);

	/* Get all contacts for this book */
	retrieve_contacts (cv, book, "", cv->selection);
}

static void
free_selected_contact_info (gpointer data)
{
	SelectedContactInfo *sci = (SelectedContactInfo *) data;

	if (sci != NULL) {
		if (sci->name != NULL)
			g_free (sci->name);
		if (sci->markedup_name != NULL)
			g_free (sci->markedup_name);
		if (sci->email != NULL)
			g_free (sci->email);
		if (sci->pixbuf != NULL)
			g_object_unref (sci->pixbuf);

		g_free (sci);
	}
}

static gboolean
row_separator_func (GtkTreeModel *model, GtkTreeIter *iter, gpointer user_data)
{
	gboolean current_is_recent, other_is_recent;
	GtkTreePath *path;
	gboolean result = FALSE;

	gtk_tree_model_get (model, iter,
			    CONTACTS_VIEW_COLUMN_RECENT, &current_is_recent,
			    -1);

	path = gtk_tree_model_get_path (model, iter);
	if (path != NULL) {
		if (gtk_tree_path_prev (path)) {
			GtkTreeIter previous;

			if (gtk_tree_model_get_iter (model, &previous, path)) {
				gtk_tree_model_get (model, &previous,
						    CONTACTS_VIEW_COLUMN_RECENT, &other_is_recent,
						    -1);
				if (other_is_recent && !current_is_recent)
					result = TRUE;
			}
		}

		gtk_tree_path_free (path);
	}

	return result;
}

static void
contacts_view_init (ContactsView *cv)
{
	GtkTreeModel *model;
	GError *error = NULL;
	GSList *gl;

	cv->matched_contacts = 0;
	cv->selection = g_hash_table_new_full (g_str_hash, g_str_equal,
					       (GDestroyNotify) g_free,
					       (GDestroyNotify) free_selected_contact_info);
	cv->added_contacts = g_hash_table_new_full (g_str_hash, g_str_equal, g_free, g_free);

	/* Get recently used contacts */
	cv->recently_used = g_hash_table_new_full (g_str_hash, g_str_equal, (GDestroyNotify) g_free, NULL);

#ifdef HAVE_NAUTILUS_30
	cv->settings = g_settings_new (SETTINGS_DOMAIN);
	{
		gchar **strv;

		strv = g_settings_get_strv (cv->settings, SETTINGS_CONTACTS_KEY);
		gl = e_client_util_strv_to_slist ((const gchar * const *) strv);
		g_strfreev (strv);
	}	
#else
	cv->config_client = gconf_client_get_default ();
	gl = gconf_client_get_list (cv->config_client, RECENTLY_USED_CONTACTS_KEY, GCONF_VALUE_STRING, NULL);
#endif
	for (; gl != NULL; gl = gl->next) {
		g_hash_table_insert (cv->recently_used, g_strdup (gl->data), g_strdup (gl->data));
	}
	g_slist_free (gl);

	/* Set up the scrolled window */
	gtk_scrolled_window_set_policy (GTK_SCROLLED_WINDOW (cv),
					GTK_POLICY_AUTOMATIC,
					GTK_POLICY_AUTOMATIC);

	/* Create the contacts list */
	model = GTK_TREE_MODEL (gtk_list_store_new (5, G_TYPE_STRING,
						    G_TYPE_STRING,
						    G_TYPE_STRING,
						    GDK_TYPE_PIXBUF,
						    G_TYPE_BOOLEAN,
						    NULL));

#ifdef BUILD_GRID_VIEW
	cv->contacts_list = gtk_icon_view_new_with_model (model);
	gtk_icon_view_set_text_column (GTK_ICON_VIEW (cv->contacts_list), CONTACTS_VIEW_COLUMN_NAME);
	gtk_icon_view_set_markup_column (GTK_ICON_VIEW (cv->contacts_list), CONTACTS_VIEW_COLUMN_MARKUP);
	gtk_icon_view_set_pixbuf_column (GTK_ICON_VIEW (cv->contacts_list), CONTACTS_VIEW_COLUMN_PIXBUF);
	gtk_icon_view_set_selection_mode (GTK_ICON_VIEW (cv->contacts_list), GTK_SELECTION_MULTIPLE);
	gtk_icon_view_set_item_width (GTK_ICON_VIEW (cv->contacts_list), 90);

	g_signal_connect (G_OBJECT (cv->contacts_list), "selection-changed",
			  G_CALLBACK (selection_changed_cb), cv);
#else
	cv->contacts_list = gtk_tree_view_new_with_model (model);
	gtk_tree_view_set_row_separator_func (GTK_TREE_VIEW (cv->contacts_list),
					      (GtkTreeViewRowSeparatorFunc) row_separator_func,
					      cv, NULL);
	gtk_tree_view_set_headers_visible (GTK_TREE_VIEW (cv->contacts_list), FALSE);
	gtk_tree_view_insert_column_with_attributes (GTK_TREE_VIEW (cv->contacts_list), -1,
						     "Avatar",
						     gtk_cell_renderer_pixbuf_new (),
						     "pixbuf", CONTACTS_VIEW_COLUMN_PIXBUF,
						     NULL);
	gtk_tree_view_insert_column_with_attributes (GTK_TREE_VIEW (cv->contacts_list), -1,
						     "Name",
						     gtk_cell_renderer_text_new (),
						     "markup", CONTACTS_VIEW_COLUMN_MARKUP,
						     NULL);
	gtk_tree_selection_set_mode (gtk_tree_view_get_selection (GTK_TREE_VIEW (cv->contacts_list)),
				     GTK_SELECTION_MULTIPLE);

	g_signal_connect (G_OBJECT (gtk_tree_view_get_selection (GTK_TREE_VIEW (cv->contacts_list))), "changed",
			  G_CALLBACK (selection_changed_cb), cv);
#endif

	gtk_widget_show (cv->contacts_list);
	gtk_scrolled_window_add_with_viewport (GTK_SCROLLED_WINDOW (cv), cv->contacts_list);

	/* Open all addressbooks */
	if (!e_book_get_addressbooks (&cv->source_list, &error)) {
		g_warning ("Could not get list of addressbooks: %s", error->message);
		g_error_free (error);

		return;
	}

	for (gl = e_source_list_peek_groups (cv->source_list); gl != NULL; gl = gl->next) {
		GSList *sl;

		for (sl = e_source_group_peek_sources ((ESourceGroup *) gl->data); sl != NULL; sl = sl->next) {
			EBook *book;

			error = NULL;

			/* Open this addressbook asynchronously */
			book = e_book_new ((ESource *) sl->data, &error);
			if (book != NULL) {
				e_book_async_open (book, FALSE, (EBookCallback) book_opened_cb, cv);
			} else {
				g_warning ("Could not open addressbook %s: %s", e_source_get_uri (sl->data), error->message);
				g_error_free (error);
			}
		}
	}
}

GtkWidget *
contacts_view_new (void)
{
	return g_object_new (TYPE_CONTACTS_VIEW, NULL);
}

void
contacts_view_search (ContactsView *cv, const gchar *search_string)
{
	GSList *l;
	GHashTable *tmp_selection;
	GHashTableIter hash_iter;
	gpointer key, value;
	GtkTreeModel *model;

	/* Make a copy of the selected items before changing the models */
	tmp_selection = g_hash_table_new_full (g_str_hash, g_str_equal,
					       (GDestroyNotify) g_free,
					       (GDestroyNotify) free_selected_contact_info);
	g_hash_table_iter_init (&hash_iter, cv->selection);
	while (g_hash_table_iter_next (&hash_iter, &key, &value)) {
		SelectedContactInfo *new_sci, *old_sci;

		old_sci = (SelectedContactInfo *) value;

		new_sci = g_new0 (SelectedContactInfo, 1);
		new_sci->name = g_strdup (old_sci->name);
		new_sci->markedup_name = g_markup_escape_text (old_sci->name, -1);
		new_sci->email = g_strdup (old_sci->email);
		new_sci->pixbuf = g_object_ref (old_sci->pixbuf);
		g_hash_table_insert (tmp_selection, g_strdup (old_sci->name), new_sci);
	}

	/* Reset the contact views */
#ifdef BUILD_GRID_VIEW
	model = gtk_icon_view_get_model (GTK_ICON_VIEW (cv->contacts_list));
#else
	model = gtk_tree_view_get_model (GTK_TREE_VIEW (cv->contacts_list));
	gtk_tree_view_scroll_to_point (GTK_TREE_VIEW (cv->contacts_list), 0, 0);
#endif
	gtk_list_store_clear (GTK_LIST_STORE (model));
	cv->matched_contacts = 0;

	g_signal_emit_by_name (cv, "contacts-count-changed",
			       gtk_tree_model_iter_n_children (model, NULL));

	/* Traverse all books */
	for (l = cv->books; l != NULL; l = l->next) {
		EBook *book = E_BOOK (l->data);

		if (!e_book_is_opened (book))
			continue;

		/* Cancel any pending operation before starting the new one*/
		e_book_cancel (book, NULL);
		retrieve_contacts (cv, book, search_string, tmp_selection);
	}

	/* If we added contacts in-memory, add them to the model now */
	g_hash_table_iter_init (&hash_iter, cv->added_contacts);
	while (g_hash_table_iter_next (&hash_iter, &key, &value)) {
		gchar *markup;

		/* We only add it if it's not on the other lists */
		if (!g_hash_table_lookup (tmp_selection, key)) {
			markup = g_markup_escape_text ((const gchar *) key, -1);
			add_one_contact (cv, (const gchar *) key,
					 (const gchar *) markup,
					 (const gchar *) value,
					 NULL, tmp_selection);
			g_free (markup);
		}
	}

	g_hash_table_unref (tmp_selection);
}

static void
add_selection_to_list_cb (gpointer key, gpointer value, gpointer user_data)
{
	SelectedContactInfo *sci = (SelectedContactInfo *) value;
	GSList **selection = (GSList **) user_data;

	*selection = g_slist_append (*selection, g_strdup (sci->email));
}

GSList *
contacts_view_get_selected_emails (ContactsView *cv)
{
	GSList *selection = NULL;

	g_hash_table_foreach (cv->selection, (GHFunc) add_selection_to_list_cb, &selection);
	return selection;
}

guint
contacts_view_get_contacts_count (ContactsView *cv)
{
	GtkTreeModel *model;

#ifdef BUILD_GRID_VIEW
	model = gtk_icon_view_get_model (GTK_ICON_VIEW (cv->contacts_list));
#else
	model = gtk_tree_view_get_model (GTK_TREE_VIEW (cv->contacts_list));
#endif

	return gtk_tree_model_iter_n_children (model, NULL);
}

guint
contacts_view_get_matched_contacts_count (ContactsView *cv)
{
	return cv->matched_contacts;
}

void
contacts_view_add_contact (ContactsView *cv, const gchar *contact_name, const gchar *contact_email)
{
	SelectedContactInfo *sci;
	GtkIconTheme *icon_theme;
	GSList *l;
	gchar *s;
	GdkPixbuf *pixbuf;
	gboolean added = FALSE;

	icon_theme = gtk_icon_theme_get_default ();

	/* First add the new contact to the list of selected ones */
	sci = g_new0 (SelectedContactInfo, 1);
	sci->name = g_strdup (contact_name);
	sci->markedup_name = g_markup_escape_text (contact_name, -1);
	sci->email = g_strdup (contact_email);
	pixbuf = gtk_icon_theme_load_icon (icon_theme, "avatar-default", AVATAR_SIZE, 0, NULL);
	sci->pixbuf = g_object_ref (pixbuf);
	g_hash_table_insert (cv->selection, g_strdup (contact_name), sci);

	/* Add it to the recently used list */
	s = g_strdup (sci->name);
	g_hash_table_insert (cv->recently_used, s, s);
	save_recently_used_list (cv);

	/* And now add it to the icon views */
	append_selected_to_model (cv->contacts_list, contact_name, sci->markedup_name, contact_email, pixbuf);

	g_object_unref (pixbuf);

	/* Add the contact to the CouchDB addressbook, if possible */
	for (l = cv->books; l != NULL; l = l->next) {
		const gchar *uri;

		uri = e_book_get_uri (E_BOOK (l->data));
		if (g_str_has_prefix (uri, "couchdb://127.0.0.1")) {
			EContact *contact;
			GError *error = NULL;

			contact = e_contact_new ();
			e_contact_set (contact, E_CONTACT_FULL_NAME, (gconstpointer) contact_name);
			e_contact_set (contact, E_CONTACT_EMAIL_1, (gconstpointer) contact_email);

			if (e_book_add_contact (E_BOOK (l->data), contact, &error))
				added = TRUE;
			else {
				g_warning ("Could not add contact to %s: %s", uri, error->message);
				g_error_free (error);
			}

			g_object_unref (G_OBJECT (contact));

			break;
		}
	}

	/* If the contact was not added, keep a copy of it so that it shows */
	if (!added)
		g_hash_table_insert (cv->added_contacts, g_strdup (contact_name), g_strdup (contact_email));
}
