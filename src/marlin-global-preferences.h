/***
    Copyright (c) 2015-2017 elementary LLC (http://launchpad.net/elementary)  

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.
***/

#ifndef H_MARLIN_GLOBAL_PREFERENCES
#define H_MARLIN_GLOBAL_PREFERENCES

GSettings  *settings;
GSettings  *marlin_icon_view_settings;
GSettings  *marlin_list_view_settings;
GSettings  *marlin_column_view_settings;
GSettings   *gnome_mouse_settings;

#define MARLIN_PREFERENCES_DATE_FORMAT                      "date-format"
#define MARLIN_PREFERENCES_SIDEBAR_CAT_PERSONAL_EXPANDER    "sidebar-cat-personal-expander"
#define MARLIN_PREFERENCES_SIDEBAR_CAT_DEVICES_EXPANDER     "sidebar-cat-devices-expander"
#define MARLIN_PREFERENCES_SIDEBAR_CAT_NETWORK_EXPANDER     "sidebar-cat-network-expander"
#define MARLIN_PREFERENCES_CONFIRM_TRASH                    "confirm-trash"

#endif
