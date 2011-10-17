#include <glib-object.h>

char    *eel_strdup_strftime (const char *format, struct tm *time_pieces);
GDate   *eel_g_date_new_tm (struct tm *time_pieces);
char    *eel_get_date_as_string (guint64 d, gchar *date_format);
