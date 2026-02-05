/*
 * SPDX-License-Identifier: GPL-2.0+
 * SPDX-FileCopyrightText: 2026 elementary, Inc. (https://elementary.io)
 *
 * Authors : Jeremy Wootten <jeremywootten@gmail.com>
 */

namespace Files {
    public static ViewPreferences? view_preferences = null;

    public class ViewPreferences : Object {
        /* IconView Preferences */
            public ZoomLevel icon_default_zoom_level { get; set; }
            public ZoomLevel icon_maximum_zoom_level { get; set; }
            public ZoomLevel icon_minimum_zoom_level { get; set; }
            public ZoomLevel icon_zoom_level { get; set; }
        /* ListView Preferences */
            public ZoomLevel list_default_zoom_level { get; set; }
            public ZoomLevel list_maximum_zoom_level { get; set; }
            public ZoomLevel list_minimum_zoom_level { get; set; }
            public ZoomLevel list_zoom_level { get; set; }
        /* ColumnView Preferences */
            public ZoomLevel column_default_zoom_level { get; set; }
            public ZoomLevel column_maximum_zoom_level { get; set; }
            public ZoomLevel column_minimum_zoom_level { get; set; }
            public ZoomLevel column_zoom_level { get; set; }

            public int preferred_column_width { get; set; }

        /* Sidebar preferences */
            public bool sidebar_cat_devices_expander { get; set; }
            public bool sidebar_cat_network_expander { get; set; }
            public bool sidebar_cat_personal_expander { get; set; }
            public int sidebar_width { get; set; }
            public int sidebar_minimum_width { get; set; }

        /*Window preferences */
            public WindowState window_state { get; set; }
            public ViewMode default_viewmode { get; set; }
            public int window_width { get; set; }
            public int window_height { get; set; }

        public static ViewPreferences get_default () {
            if (view_preferences == null) {
                view_preferences = new ViewPreferences ();
            }

            return view_preferences;
        }

       public static void set_up_view_preferences (
            Settings? icon_settings,
            Settings? list_settings,
            Settings? column_settings,
            Settings? app_settings
        ) {
            var view_prefs = ViewPreferences.get_default ();
            if (icon_settings != null) {
                icon_settings.bind ("default-zoom-level", view_prefs, "icon-default-zoom-level", DEFAULT);
                icon_settings.bind ("minimum-zoom-level", view_prefs, "icon-minimum-zoom-level", DEFAULT);
                icon_settings.bind ("maximum-zoom-level", view_prefs, "icon-maximum-zoom-level", DEFAULT);
                icon_settings.bind ("zoom-level", view_prefs, "icon-zoom-level", DEFAULT);
            }

            if (list_settings != null) {
                list_settings.bind ("default-zoom-level", view_prefs, "list-default-zoom-level", DEFAULT);
                list_settings.bind ("minimum-zoom-level", view_prefs, "list-minimum-zoom-level", DEFAULT);
                list_settings.bind ("maximum-zoom-level", view_prefs, "list-maximum-zoom-level", DEFAULT);
                list_settings.bind ("zoom-level", view_prefs, "list-zoom-level", DEFAULT);
            }

            if (column_settings != null) {
                column_settings.bind ("default-zoom-level", view_prefs, "column-default-zoom-level", DEFAULT);
                column_settings.bind ("minimum-zoom-level", view_prefs, "column-minimum-zoom-level", DEFAULT);
                column_settings.bind ("maximum-zoom-level", view_prefs, "column-maximum-zoom-level", DEFAULT);
                column_settings.bind ("zoom-level", view_prefs, "column-zoom-level", DEFAULT);
                //TODO Separate preferred-col-width for list view
                column_settings.bind ("preferred-column-width", view_prefs, "preferred-column-width", DEFAULT);
            }

            if (app_settings != null) {
                app_settings.bind (
                    "sidebar-cat-devices-expander",
                    view_prefs, "sidebar-cat-devices-expander", DEFAULT
                );
                app_settings.bind (
                    "sidebar-cat-network-expander",
                    view_prefs, "sidebar-cat-network-expander", DEFAULT
                );
                app_settings.bind (
                    "sidebar-cat-personal-expander",
                    view_prefs, "sidebar-cat-personal-expander", DEFAULT
                );
                app_settings.bind ("sidebar-width", view_prefs, "sidebar-width", DEFAULT);
                app_settings.bind ("minimum-sidebar-width", view_prefs, "sidebar-minimum-width", DEFAULT);
                app_settings.bind ("window-state", view_prefs, "window-state", DEFAULT);
                app_settings.bind ("window-width", view_prefs, "window-width", DEFAULT);
                app_settings.bind ("window-height", view_prefs, "window-height", DEFAULT);
                app_settings.bind ("default-viewmode", view_prefs, "default-viewmode", DEFAULT);
            }
        }

        public static void get_zoom_levels (
            ViewMode mode,
            out ZoomLevel normal,
            out ZoomLevel minimum,
            out ZoomLevel maximum,
            out ZoomLevel current
        ) {

            normal = ZoomLevel.NORMAL;
            minimum = ZoomLevel.SMALLEST;
            maximum = ZoomLevel.LARGEST;
            current = ZoomLevel.NORMAL;

            var view_prefs = ViewPreferences.get_default ();
            switch (mode) {
                case ViewMode.ICON:
                    normal = view_prefs.icon_default_zoom_level;
                    minimum = view_prefs.icon_minimum_zoom_level;
                    minimum = view_prefs.icon_maximum_zoom_level;
                    current = view_prefs.icon_zoom_level;
                    break;

                case ViewMode.LIST:
                    normal = view_prefs.list_default_zoom_level;
                    minimum = view_prefs.list_minimum_zoom_level;
                    minimum = view_prefs.list_maximum_zoom_level;
                    current = view_prefs.list_zoom_level;
                    break;

                case ViewMode.MILLER_COLUMNS:
                    normal = view_prefs.column_default_zoom_level;
                    minimum = view_prefs.column_minimum_zoom_level;
                    minimum = view_prefs.column_maximum_zoom_level;
                    current = view_prefs.column_zoom_level;
                    break;

                default:
                    assert_not_reached ();
            }
        }
    }
}
