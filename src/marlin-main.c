
#include <config.h>
#include <glib.h>
#include <glib-object.h>

#include <locale.h>
#include <libintl.h>
#define _(x) gettext(x)
//#include <glib/gi18n.h>
//#include <libintl.h>

#include "marlin-application.h"

#define APP_NAME "marlin"

int
main (int argc, char *argv[])
{
    MarlinApplication *application;
    gint ret;

    g_type_init ();

    /* Initialize gettext support */
    setlocale (LC_ALL, g_get_language_names ()[0]);
    textdomain (GETTEXT_PACKAGE);

    g_set_application_name (APP_NAME);
    g_set_prgname (APP_NAME);

    application = marlin_application_new ();
    ret = g_application_run (G_APPLICATION (application), argc, argv);

    g_object_unref (application);

    return ret;
}

