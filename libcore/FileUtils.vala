/***
    Copyright (C) 2015 Elementary Developers

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/
namespace PF.FileUtils {
        const string reserved_chars = (GLib.Uri.RESERVED_CHARS_GENERIC_DELIMITERS + GLib.Uri.RESERVED_CHARS_SUBCOMPONENT_DELIMITERS + " ");

    public string? escape_uri (string uri, bool allow_utf8 = true) {
        string rc = reserved_chars.replace("#", "").replace ("*","");
        return Uri.escape_string ((Uri.unescape_string (uri) ?? uri), rc , allow_utf8);
    }

    public string get_formatted_time_attribute_from_info (GLib.FileInfo info, string attr, string format = "locale") {
        switch (attr) {
            case FileAttribute.TIME_MODIFIED:
            case FileAttribute.TIME_CREATED:
            case FileAttribute.TIME_ACCESS:
            case FileAttribute.TIME_CHANGED:
                uint64 t = info.get_attribute_uint64 (attr);
                if (t == 0)
                    return "";

                DateTime dt = new DateTime.from_unix_local ((int64)t);

                if (dt == null)
                    return "";

                return get_formatted_date_time (dt, format);

            default:
                break;
        }

        return "";
    }

    public string get_formatted_date_time (DateTime dt, string format = "locale") {
        if (format == "locale") {
            return dt.format ("%c");
        } else if (format == "iso") {
            return dt.format ("%Y-%m-%d %H:%M:%S");
        } else {
            return get_informal_date_time (dt);
        }
    }

    private string get_informal_date_time (DateTime dt) {
        DateTime now = new DateTime.now_local ();
        int now_year = now.get_year ();
        int disp_year = dt.get_year ();

        if (disp_year < now_year) {
            /* TRANSLATORS: This string determines the format and order in which the day month and year
             * are shown informally for a date that occurred in the previous year or before.
             * %-d expands to the numeric day of the month.
             * %b expands to the abbreviated name of the month according to the locale.
             * %Y expands to the 4-digit number of the year.
             * These components must not be altered, but their order may be changed to accord with
             * the informal custom for the locale.
             */   
            return dt.format (_("%-d %b %Y"));
        }

        int now_day = now.get_day_of_year ();
        int disp_day = dt.get_day_of_year ();

        if (disp_day < now_day - 7) {
            /* TRANSLATORS: This string determines the format and order in which the day month and year
             * are shown informally for a date that occurred in the current year but more than a week ago.
             * %-d expands to the numeric day of the month.
             * %b expands to the abbreviated name of the month according to the locale.
             * %Y expands to the 4-digit number of the year.
             * These components must not be altered, but their order may be changed to accord with
             * the informal custom for the locale.
             */ 
            return dt.format (_("%-d %b %Y"));
        }

        int now_weekday = now.get_day_of_week ();
        int disp_weekday = dt.get_day_of_week ();

        switch (now_weekday - disp_weekday) {
            case 0:
            /* TRANSLATORS: This string determines the format and order in which the day and time
             * are shown informally for a time that occurred today.
             * %-I expands to the numeric hour in 12 hour clock.
             * %M expands to the numeric minute.
             * %p expands to "am" or "pm" according to the locale. 
             * These components must not be altered, but their order may be changed to accord with
             * the informal custom for the locale.
             */ 
                return dt.format (_("Today at %-I:%M %p"));
            case 1:
            /* TRANSLATORS: This string determines the format and order in which the day and time
             * are shown informally for a time that occurred yesterday.
             * %-I expands to the numeric hour in 12 hour clock.
             * %M expands to the numeric minute.
             * %p expands to "am" or "pm" according to the locale. 
             * These components must not be altered, but their order may be changed to accord with
             * the informal custom for the locale.
             */ 
                return dt.format (_("Yesterday at %-I:%M %p"));
            default:
            /* TRANSLATORS: This string determines the format and order in which the day and time
             * are shown informally for a time that occurred in the past week.
             * %-I expands to the numeric hour in 12 hour clock.
             * %M expands to the numeric minute.
             * %p expands to "am" or "pm" according to the locale.
             * %A expands to the abbreviated name of the weekday according to the locale.   
             * These components must not be altered, but their order may be changed to accord with
             * the informal custom for the locale.
             */ 
                return dt.format (_("%A at %-I:%M %p"));
        }
    }
}
