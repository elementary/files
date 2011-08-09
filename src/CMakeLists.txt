# Vala stuff

find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.11.3" MINIMUM)
include(ValaPrecompile)
# pkgconfig, real C code

include_directories(${CMAKE_BINARY_DIR})
include_directories(${CMAKE_CURRENT_SOURCE_DIR})
include_directories(${CMAKE_CURRENT_BINARY_DIR})
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../libcore/)
include_directories(${CMAKE_CURRENT_BINARY_DIR}/../libwidgets/)
find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED
	glib-2.0>=2.29.0
	gthread-2.0
	gio-2.0
	pango>=1.1.2
	gtk+-3.0>=3.0.3
	gail-3.0
	gee-1.0
	sqlite3
    dbus-glib-1
	libnotify>=0.7.2)
set(CFLAGS
	${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER}
)
set(LIB_PATHS
	${DEPS_LIBRARY_DIRS}
)
link_directories(${LIB_PATHS})
add_definitions(${CFLAGS}
    "-DGETTEXT_PACKAGE=\"marlin\""
    "-DPIXMAP_DIR=\"${CMAKE_INSTALL_PREFIX}/share/pixmaps/marlin/\""
    "-DUI_DIR=\"${CMAKE_INSTALL_PREFIX}/share/marlin/ui/\""
     -O2
    )
vala_precompile(VALA_C
    Logger.vala
    View/SettingsDialog.vala
    View/DirectoryNotFound.vala
    View/Window.vala
    View/Resources.vala
    View/DbusTags.vala
    View/ViewContainer.vala
    View/ContextView.vala
    View/Browser.vala
    View/ViewMode.vala
    View/Animations.vala
    View/LocationBar.vala
    View/PopupLocationBar.vala
    View/Chrome/TopMenu.vala
    View/Chrome/ViewSwicher.vala
    View/Chrome/ColorWidget.vala
CUSTOM_VAPIS
    ${CMAKE_CURRENT_SOURCE_DIR}/../libcore/marlin-core.vapi
    ${CMAKE_CURRENT_BINARY_DIR}/../libwidgets/marlinwidgets.vapi
    marlin.vapi
PACKAGES
    gtk+-3.0
    gio-2.0
    posix
    gee-1.0
GENERATE_HEADER
    marlin-vala
OPTIONS
    --thread)
add_executable(marlin
    eel-editable-label.c
    marlin-application.c
    mysignal.c
    gossip-cell-renderer-expander.c
    marlin-enum-types.c
    marlin-trash-monitor.c
    marlin-bookmark.c
    marlin-bookmark-list.c
    marlin-dnd.c
    marlin-clipboard-manager.c
    marlin-places-sidebar.c
    marlin-window-columns.c
    gof-window-slot.c
    marlin-thumbnailer.c
    marlin-icon-renderer.c
    marlin-text-renderer.c
    fm-directory-view.c
    exo-icon-view.c
    exo-tree-view.c
    fm-list-model.c
    marlin-main.c
    fm-icon-view.c
    fm-list-view.c
    fm-columns-view.c
    marlin-toolbar-editor.c
    marlin-connect-server-dialog.c
    marlin-connect-server-operation.c
    marlin-progress-ui-handler.c
    marlin-progress-info-widget.c
    ${VALA_C} )
target_link_libraries(marlin marlincore marlinwidgets ${DEPS_LIBRARIES})
install(TARGETS marlin RUNTIME DESTINATION bin)
install(FILES marlin-ui.xml DESTINATION share/marlin/ui/)
install(FILES fm-directory-view-ui.xml DESTINATION share/marlin/ui/)
