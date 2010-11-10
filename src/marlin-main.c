#include <config.h>
#include "gof-directory-async.h"
#include "gof-window-slot.h"
#include "marlin-window-columns.h"
//#include <glib/gi18n.h>
//#include <libintl.h>
#include "marlin-global-preferences.h" 
#include "marlin-view-window.h"

#define _g_object_unref0(var) ((var == NULL) ? NULL : (var = (g_object_unref (var), NULL)))


static void     about (void);
static void     marlin_view_window_up (MarlinViewWindow *window);
//static void     marlin_view_window_back (MarlinViewWindow *window);
static void     marlin_view_window_path_changed (MarlinViewWindow *window, GFile *file, gpointer data);

static void _vala_array_destroy (gpointer array, gint array_length, GDestroyNotify destroy_func) {
	if ((array != NULL) && (destroy_func != NULL)) {
		int i;
		for (i = 0; i < array_length; i = i + 1) {
			if (((gpointer*) array)[i] != NULL) {
				destroy_func (((gpointer*) array)[i]);
			}
		}
	}
}

static void _vala_array_free (gpointer array, gint array_length, GDestroyNotify destroy_func) {
	_vala_array_destroy (array, array_length, destroy_func);
	g_free (array);
}


int
main (int argc, char *argv[])
{
        MarlinViewWindow *window;
	GtkWidget       *vbox;
	GtkWidget       *hbox;
	GtkWidget       *btn;
	GtkWidget       *entry;
        gchar           *path;

	gtk_init (&argc, &argv);
        /* Initialize gettext support */
	bindtextdomain (GETTEXT_PACKAGE, GNOMELOCALEDIR);
	bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
	textdomain (GETTEXT_PACKAGE);

        /* gsettings parameters */
        settings = g_settings_new ("org.gnome.marlin.preferences");
        /*gboolean showall = g_settings_get_boolean (settings, "showall");
        printf ("test gsettings showall: %d\n", showall);*/

	/*window = gtk_window_new (GTK_WINDOW_TOPLEVEL);
	gtk_window_set_title (GTK_WINDOW (window), "marlin");
	gtk_window_set_default_size (GTK_WINDOW (window), 600, 300);
	gtk_container_set_border_width (GTK_CONTAINER (window), 0);
	g_signal_connect (window, "destroy", gtk_main_quit, NULL);*/
	
        if (argc > 1) {
                path = argv[1];
	} else {
                path = g_strdup(g_get_home_dir());
	}
        
        window = marlin_view_window_new (path);

        g_signal_connect (window, "show-about", (GCallback) about, NULL);
	g_signal_connect (window, "up", (GCallback) marlin_view_window_up, NULL);
	/*g_signal_connect (window, "back", (GCallback) marlin_view_window_back, NULL);
	g_signal_connect (window, "forward", (GCallback) __lambda23__marlin_view_window_forward, NULL);
	g_signal_connect (window, "refresh", (GCallback) __lambda24__marlin_view_window_refresh, NULL);*/
	g_signal_connect (window, "quit", (GCallback) gtk_main_quit, NULL);
	g_signal_connect (window, "path-changed", (GCallback) marlin_view_window_path_changed, NULL);
	g_signal_connect (window, "browser-path-changed", (GCallback) marlin_view_window_path_changed, NULL);

        g_signal_emit_by_name (window, "path-changed", g_file_new_for_commandline_arg (path));

      	/*GtkBindingSet *binding_set;

        binding_set = gtk_binding_set_by_class (MARLIN_VIEW_WINDOW_CLASS (window));
	gtk_binding_entry_add_signal (binding_set, GDK_KEY_BackSpace, 0,
				      "up", 1,
				      G_TYPE_BOOLEAN, FALSE);*/


        gtk_main ();
        g_free (path);	
	return 0;
}

/* TODO Move this horror to a separate vala file */
static void about (void) {
	GtkAboutDialog* _tmp0_ = NULL;
	GtkAboutDialog* about;
	gchar* _tmp1_;
	gchar* _tmp2_;
	gchar** _tmp3_ = NULL;
	gchar** _tmp4_;
	gint _tmp4__length1;
	gchar* _tmp5_;
	gchar** _tmp6_ = NULL;
	gchar** _tmp7_;
	gint _tmp7__length1;
	_tmp0_ = (GtkAboutDialog*) gtk_about_dialog_new ();
	about = g_object_ref_sink (_tmp0_);
	gtk_about_dialog_set_program_name (about, "Marlin");
	gtk_window_set_icon_name ((GtkWindow*) about, "system-file-manager");
	gtk_about_dialog_set_logo_icon_name (about, "system-file-manager");
	gtk_about_dialog_set_website (about, "http://www.elementary-project.com");
	gtk_about_dialog_set_website_label (about, "elementary-project.com");
	gtk_about_dialog_set_copyright (about, "Copyright 2010 elementary Developers");
	_tmp1_ = g_strdup ("ammonkey <am.monkeyd@gmail.com>");
	_tmp2_ = g_strdup ("Mathijs Henquet <mathijs.henquet@gmail.com>");
	_tmp3_ = g_new0 (gchar*, 2 + 1);
	_tmp3_[0] = _tmp1_;
	_tmp3_[1] = _tmp2_;
	_tmp4_ = _tmp3_;
	_tmp4__length1 = 2;
	gtk_about_dialog_set_authors (about, _tmp4_);
	_tmp4_ = (_vala_array_free (_tmp4_, _tmp4__length1, (GDestroyNotify) g_free), NULL);
	_tmp5_ = g_strdup ("Daniel Foré <dan@elementary-project.com>");
	_tmp6_ = g_new0 (gchar*, 1 + 1);
	_tmp6_[0] = _tmp5_;
	_tmp7_ = _tmp6_;
	_tmp7__length1 = 1;
	gtk_about_dialog_set_artists (about, _tmp7_);
	_tmp7_ = (_vala_array_free (_tmp7_, _tmp7__length1, (GDestroyNotify) g_free), NULL);
	gtk_dialog_run ((GtkDialog*) about);
	g_signal_emit_by_name ((GtkWidget*) about, "destroy");
	_g_object_unref0 (about);
}

static void
marlin_view_window_up (MarlinViewWindow *window)
{
        GOFWindowSlot *slot;
        GFile *parent;

        if ((slot = GOF_WINDOW_SLOT (marlin_view_window_get_active_slot(window))) == NULL)
                return;
        if (slot->location == NULL) 
		return;
        parent = g_file_get_parent (slot->location);
	if (parent == NULL) 
		return;

        /*if (slot->mwcols != NULL)
                marlin_window_columns_change_location (slot, parent);
        else
                gof_window_slot_change_location (slot, parent);*/
        //g_signal_emit_by_name (window, "path-changed", "/home/am/Images");
        g_signal_emit_by_name (window, "path-changed", parent);
        g_object_unref (parent);
}

/*
static void
marlin_view_window_back (MarlinViewWindow *window)
{
        printf ("%s\n", G_STRFUNC);
}*/

static void
marlin_view_window_path_changed (MarlinViewWindow *window, GFile *file, gpointer data)
{
        GOFWindowSlot *slot;
        MarlinWindowColumns *mwcols;
        
        g_return_if_fail (file != NULL);
        if ((slot = GOF_WINDOW_SLOT (marlin_view_window_get_active_slot(window))) != NULL)
                load_dir_async_cancel(slot->directory);
        slot = gof_window_slot_new(file, GTK_WIDGET (window));
        //mwcols = marlin_window_columns_new(file, GTK_WIDGET (window));
}
