#include "eel-fcts.h"

#include <glib-object.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "eel-i18n.h"

#define C_STANDARD_STRFTIME_CHARACTERS "aAbBcdHIjmMpSUwWxXyYZ"
#define C_STANDARD_NUMERIC_STRFTIME_CHARACTERS "dHIjmMSUwWyY"
#define SUS_EXTENDED_STRFTIME_MODIFIERS "EO"

/**
 * eel_strdup_strftime:
 *
 * Cover for standard date-and-time-formatting routine strftime that returns
 * a newly-allocated string of the correct size. The caller is responsible
 * for g_free-ing the returned string.
 *
 * Besides the buffer management, there are two differences between this
 * and the library strftime:
 *
 *   1) The modifiers "-" and "_" between a "%" and a numeric directive
 *      are defined as for the GNU version of strftime. "-" means "do not
 *      pad the field" and "_" means "pad with spaces instead of zeroes".
 *   2) Non-ANSI extensions to strftime are flagged at runtime with a
 *      warning, so it's easy to notice use of the extensions without
 *      testing with multiple versions of the library.
 *
 * @format: format string to pass to strftime. See strftime documentation
 * for details.
 * @time_pieces: date/time, in struct format.
 * 
 * Return value: Newly allocated string containing the formatted time.
**/
char *
eel_strdup_strftime (const char *format, struct tm *time_pieces)
{
    GString *string;
    const char *remainder, *percent;
    char code[4], buffer[512];
    char *piece, *result, *converted;
    size_t string_length;
    gboolean strip_leading_zeros, turn_leading_zeros_to_spaces;
    char modifier;
    int i;

    /* Format could be translated, and contain UTF-8 chars,
     * so convert to locale encoding which strftime uses */
    converted = g_locale_from_utf8 (format, -1, NULL, NULL, NULL);
    g_return_val_if_fail (converted != NULL, NULL);

    string = g_string_new ("");
    remainder = converted;

    /* Walk from % character to % character. */
    for (;;) {
        percent = strchr (remainder, '%');
        if (percent == NULL) {
            g_string_append (string, remainder);
            break;
        }
        g_string_append_len (string, remainder,
                             percent - remainder);

        /* Handle the "%" character. */
        remainder = percent + 1;
        switch (*remainder) {
        case '-':
            strip_leading_zeros = TRUE;
            turn_leading_zeros_to_spaces = FALSE;
            remainder++;
            break;
        case '_':
            strip_leading_zeros = FALSE;
            turn_leading_zeros_to_spaces = TRUE;
            remainder++;
            break;
        case '%':
            g_string_append_c (string, '%');
            remainder++;
            continue;
        case '\0':
            g_warning ("Trailing %% passed to eel_strdup_strftime");
            g_string_append_c (string, '%');
            continue;
        default:
            strip_leading_zeros = FALSE;
            turn_leading_zeros_to_spaces = FALSE;
            break;
        }

        modifier = 0;
        if (strchr (SUS_EXTENDED_STRFTIME_MODIFIERS, *remainder) != NULL) {
            modifier = *remainder;
            remainder++;

            if (*remainder == 0) {
                g_warning ("Unfinished %%%c modifier passed to eel_strdup_strftime", modifier);
                break;
            }
        } 

        if (strchr (C_STANDARD_STRFTIME_CHARACTERS, *remainder) == NULL) {
            g_warning ("eel_strdup_strftime does not support "
                       "non-standard escape code %%%c",
                       *remainder);
        }

        /* Convert code to strftime format. We have a fixed
         * limit here that each code can expand to a maximum
         * of 512 bytes, which is probably OK. There's no
         * limit on the total size of the result string.
         */
        i = 0;
        code[i++] = '%';
        if (modifier != 0) {
#ifdef HAVE_STRFTIME_EXTENSION
            code[i++] = modifier;
#endif
        }
        code[i++] = *remainder;
        code[i++] = '\0';
        string_length = strftime (buffer, sizeof (buffer),
                                  code, time_pieces);
        if (string_length == 0) {
            /* We could put a warning here, but there's no
             * way to tell a successful conversion to
             * empty string from a failure.
             */
            buffer[0] = '\0';
        }

        /* Strip leading zeros if requested. */
        piece = buffer;
        if (strip_leading_zeros || turn_leading_zeros_to_spaces) {
            if (strchr (C_STANDARD_NUMERIC_STRFTIME_CHARACTERS, *remainder) == NULL) {
                g_warning ("eel_strdup_strftime does not support "
                           "modifier for non-numeric escape code %%%c%c",
                           remainder[-1],
                           *remainder);
            }
            if (*piece == '0') {
                do {
                    piece++;
                } while (*piece == '0');
                if (!g_ascii_isdigit (*piece)) {
                    piece--;
                }
            }
            if (turn_leading_zeros_to_spaces) {
                memset (buffer, ' ', piece - buffer);
                piece = buffer;
            }
        }
        remainder++;

        /* Add this piece. */
        g_string_append (string, piece);
    }

    /* Convert the string back into utf-8. */
    result = g_locale_to_utf8 (string->str, -1, NULL, NULL, NULL);

    g_string_free (string, TRUE);
    g_free (converted);

    return result;
}

/**
 * eel_g_date_new_tm:
 * 
 * Get a new GDate * for the date represented by a tm struct. 
 * The caller is responsible for g_free-ing the result.
 * @time_pieces: Pointer to a tm struct representing the date to be converted.
 * 
 * Returns: Newly allocated string formated date.
 * 
**/
GDate *
eel_g_date_new_tm (struct tm *time_pieces)
{
    /* tm uses 0-based months; GDate uses 1-based months.
     * tm_year needs 1900 added to get the full year.
     */
    return g_date_new_dmy (time_pieces->tm_mday,
                           time_pieces->tm_mon + 1,
                           time_pieces->tm_year + 1900);
}


static const char *TODAY_TIME_FORMATS [] = {
    /* Today, use special word.
     * strftime patterns preceeded with the widest
     * possible resulting string for that pattern.
     *
     * Note to localizers: You can look at man strftime
     * for details on the format, but you should only use
     * the specifiers from the C standard, not extensions.
     * These include "%" followed by one of
     * "aAbBcdHIjmMpSUwWxXyYZ". There are two extensions
     * in the Nautilus version of strftime that can be
     * used (and match GNU extensions). Putting a "-"
     * between the "%" and any numeric directive will turn
     * off zero padding, and putting a "_" there will use
     * space padding instead of zero padding.
     */
    N_("today at 00:00:00 PM"),
    N_("today at %-I:%M:%S %p"),

    N_("today at 00:00 PM"),
    N_("today at %-I:%M %p"),

    N_("today, 00:00 PM"),
    N_("today, %-I:%M %p"),

    N_("today"),
    N_("today"),

    NULL
};

static const char *YESTERDAY_TIME_FORMATS [] = {
    /* Yesterday, use special word.
     * Note to localizers: Same issues as "today" string.
     */
    N_("yesterday at 00:00:00 PM"),
    N_("yesterday at %-I:%M:%S %p"),

    N_("yesterday at 00:00 PM"),
    N_("yesterday at %-I:%M %p"),

    N_("yesterday, 00:00 PM"),
    N_("yesterday, %-I:%M %p"),

    N_("yesterday"),
    N_("yesterday"),

    NULL
};

static const char *CURRENT_WEEK_TIME_FORMATS [] = {
    /* Current week, include day of week.
     * Note to localizers: Same issues as "today" string.
     * The width measurement templates correspond to
     * the day/month name with the most letters.
     */
    N_("Wednesday, September 00 0000 at 00:00:00 PM"),
    N_("%A, %B %-d %Y at %-I:%M:%S %p"),

    N_("Mon, Oct 00 0000 at 00:00:00 PM"),
    N_("%a, %b %-d %Y at %-I:%M:%S %p"),

    N_("Mon, Oct 00 0000 at 00:00 PM"),
    N_("%a, %b %-d %Y at %-I:%M %p"),

    N_("Oct 00 0000 at 00:00 PM"),
    N_("%b %-d %Y at %-I:%M %p"),

    N_("Oct 00 0000, 00:00 PM"),
    N_("%b %-d %Y, %-I:%M %p"),

    N_("00/00/00, 00:00 PM"),
    N_("%m/%-d/%y, %-I:%M %p"),

    N_("00/00/00"),
    N_("%m/%d/%y"),

    NULL
};

/**
 * eel_get_date_as_string:
 * 
 * Get a formated date string where format equal iso, locale, informal.
 * The caller is responsible for g_free-ing the result.
 * @d: contains the UNIX time.
 * @date_format: string representing the format to convert the date to.
 * 
 * Returns: Newly allocated date.
 * 
**/
char *
eel_get_date_as_string (guint64 d, gchar *date_format)
{
    struct tm *file_time;
    const char **formats;
    const char *width_template;
    const char *format;
    char *date_string;
    GDate *today;
    GDate *file_date;
    guint32 file_date_age;
    int i;

    g_return_val_if_fail (date_format != NULL, NULL);
    file_time = localtime (&d);

    if (!strcmp (date_format, "locale"))
        return eel_strdup_strftime ("%c", file_time);
    else if (!strcmp (date_format, "iso"))
        return eel_strdup_strftime ("%Y-%m-%d %H:%M:%S", file_time);

    file_date = eel_g_date_new_tm (file_time);

    today = g_date_new ();
    g_date_set_time_t (today, time (NULL));

    /* Overflow results in a large number; fine for our purposes. */
    file_date_age = (g_date_get_julian (today) -
                     g_date_get_julian (file_date));

    g_date_free (file_date);
    g_date_free (today);

    /* Format varies depending on how old the date is. This minimizes
     * the length (and thus clutter & complication) of typical dates
     * while providing sufficient detail for recent dates to make
     * them maximally understandable at a glance. Keep all format
     * strings separate rather than combining bits & pieces for
     * internationalization's sake.
     */

    if (file_date_age == 0)	{
        formats = TODAY_TIME_FORMATS;
    } else if (file_date_age == 1) {
        formats = YESTERDAY_TIME_FORMATS;
    } else if (file_date_age < 7) {
        formats = CURRENT_WEEK_TIME_FORMATS;
    } else {
        formats = CURRENT_WEEK_TIME_FORMATS;
    }

    /* Find the date format that just fits the required width. Instead of measuring
     * the resulting string width directly, measure the width of a template that represents
     * the widest possible version of a date in a given format. This is done by using M, m
     * and 0 for the variable letters/digits respectively.
     */
    format = NULL;

    for (i = 0; ; i += 2) {
        width_template = (formats [i] ? _(formats [i]) : NULL);
        if (width_template == NULL) {
            /* no more formats left */
            g_assert (format != NULL);

            /* Can't fit even the shortest format -- return an ellipsized form in the
             * shortest format
             */

            date_string = eel_strdup_strftime (format, file_time);

            return date_string;
        }

        format = _(formats [i + 1]);

        /* don't care about fitting the width */
        break;
    }

    return eel_strdup_strftime (format, file_time);
}

