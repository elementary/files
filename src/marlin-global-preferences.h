#ifndef H_MARLIN_GLOBAL_PREFERENCES
#define H_MARLIN_GLOBAL_PREFERENCES

GSettings  *settings;
GSettings  *marlin_icon_view_settings;
GSettings  *marlin_list_view_settings;
GSettings  *marlin_column_view_settings;

#define MARLIN_PREFERENCES_RGBA_COLORMAP                    "rgba-colormap"
#define MARLIN_PREFERENCES_DATE_FORMAT                      "date-format"
#define MARLIN_PREFERENCES_SIDEBAR_CAT_PERSONAL_EXPANDER    "sidebar-cat-personal-expander"
#define MARLIN_PREFERENCES_SIDEBAR_CAT_DEVICES_EXPANDER     "sidebar-cat-devices-expander"
#define MARLIN_PREFERENCES_SIDEBAR_CAT_NETWORK_EXPANDER     "sidebar-cat-network-expander"
#define MARLIN_PREFERENCES_CONFIRM_TRASH                    "confirm-trash"

#endif
