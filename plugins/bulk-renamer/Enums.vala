/*
 * Copyright (C) 2019      Jeremy Wootten
 *
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *  Authors:
 *  Jeremy Wootten <jeremywootten@gmail.com>
 *
*/

public enum RenameMode {
    TEXT,
    NUMBER,
    DATETIME,
    INVALID;

    public string to_string () {
        switch (this) {
            case RenameMode.NUMBER:
                return _("Number sequence");

            case RenameMode.TEXT:
                return _("Text");

            case RenameMode.DATETIME:
                return _("Date");

            default:
                assert_not_reached ();
        }
    }
}

public enum RenamePosition {
    SUFFIX,
    PREFIX,
    REPLACE;

    public string to_string () {
        switch (this) {
            case RenamePosition.SUFFIX:
                return _("Suffix");

            case RenamePosition.PREFIX:
                return _("Prefix");

            case RenamePosition.REPLACE:
                return _("Replace");

            default:
                assert_not_reached ();
        }
    }

    public string to_placeholder () {
        switch (this) {
            case RenamePosition.SUFFIX:
                return _("Text to put at the end");

            case RenamePosition.PREFIX:
                return _("Text to put at the start");

            case RenamePosition.REPLACE:
                return _("Text to replace the target");

            default:
                assert_not_reached ();
        }
    }
}

public enum RenameSortBy {
    NAME,
    CREATED,
    MODIFIED;

    public string to_string () {
        switch (this) {
            case RenameSortBy.NAME:
                return _("Name");

            case RenameSortBy.CREATED:
                return _("Creation Date");

            case RenameSortBy.MODIFIED:
                return _("Last modification date");

            default:
                assert_not_reached ();
        }
    }
}

public enum RenameDateFormat {
    DEFAULT_DATE,
    DEFAULT_DATETIME,
    LOCALE,
    ISO_DATE,
    ISO_DATETIME;

    public string to_string () {
        switch (this) {
            case RenameDateFormat.DEFAULT_DATE:
                return _("Default Format - Date only");
            case RenameDateFormat.DEFAULT_DATETIME:
                return _("Default Format - Date and Time");
            case RenameDateFormat.LOCALE:
                return _("Locale Format - Date and Time");
            case RenameDateFormat.ISO_DATE:
                return _("ISO 8601 Format - Date only");
            case RenameDateFormat.ISO_DATETIME:
                return _("ISO 8601 Format - Date and Time");
            default:
                assert_not_reached ();
        }
    }
}

public enum RenameDateType {
    NOW,
    CHOOSE;

    public string to_string () {
        switch (this) {
            case RenameDateType.NOW:
                return _("Current Date");
            case RenameDateType.CHOOSE:
                return _("Choose a date");
            default:
                assert_not_reached ();
        }
    }
}

public enum RenameBase {
    ORIGINAL,
    CUSTOM;

    public string to_string () {
        switch (this) {
            case RenameBase.ORIGINAL:
                return _("Original filename");
            case RenameBase.CUSTOM:
                return _("Enter a base name");
            default:
                assert_not_reached ();
        }
    }
}
