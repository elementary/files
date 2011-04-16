#ifndef H_MARLIN_GLOBAL_PREFERENCES
#define H_MARLIN_GLOBAL_PREFERENCES

GSettings  *settings;

static gchar *tags_colors[10] = { NULL, "#fce94f", "#fcaf3e", "#997666", "#8ae234", "#729fcf", "#ad7fa8", "#ef2929", "#d3d7cf", "#888a85" };

#define MARLIN_PREFERENCES_RGBA_COLORMAP                    "rgba-colormap"
#define MARLIN_PREFERENCES_DATE_FORMAT                      "date-format"
#define MARLIN_PREFERENCES_SIDEBAR_ICON_SIZE                "sidebar-icon-size"
#define MARLIN_PREFERENCES_SIDEBAR_CAT_PERSONAL_EXPANDER    "sidebar-cat-personal-expander"
#define MARLIN_PREFERENCES_SIDEBAR_CAT_DEVICES_EXPANDER     "sidebar-cat-devices-expander"
#define MARLIN_PREFERENCES_SIDEBAR_CAT_NETWORK_EXPANDER     "sidebar-cat-network-expander"
#define MARLIN_PREFERENCES_CONFIRM_TRASH                    "confirm-trash"

#endif
