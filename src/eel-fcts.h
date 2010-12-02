#include <glib-object.h>

char    *eel_strdup_strftime (const char *format, struct tm *time_pieces);
GDate   *eel_g_date_new_tm (struct tm *time_pieces);
int     eel_strcmp (const char *string_a, const char *string_b);
