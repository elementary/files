#include <config.h>
#include <glib.h>
#include <glib-object.h>

#include <locale.h>
#include <libintl.h>
#define _(x) gettext(x)
//#include <glib/gi18n.h>
//#include <libintl.h>

#include "marlin-application.h"

int
main (int argc, char *argv[])
{
    MarlinApplication *application;
    gint ret;

    g_type_init ();
    g_thread_init (NULL);
    
    /* Initialize gettext support */
    setlocale(LC_ALL, "" );
    bindtextdomain (GETTEXT_PACKAGE, GNOMELOCALEDIR);
    bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
    textdomain (GETTEXT_PACKAGE);

    g_set_application_name ("marlin");
    g_set_prgname ("marlin");

    application = marlin_application_new ();
    ret = g_application_run (G_APPLICATION (application), argc, argv);

    g_object_unref (application);

    return ret;
}

