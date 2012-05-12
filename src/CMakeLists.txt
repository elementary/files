# Vala stuff

find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.11.3" MINIMUM)
include(ValaPrecompile)
# pkgconfig, real C code

include_directories(${CMAKE_BINARY_DIR})
include_directories(${CMAKE_BINARY_DIR}/marlinplugins/)
include_directories(${CMAKE_CURRENT_SOURCE_DIR})
include_directories(${CMAKE_CURRENT_BINARY_DIR})
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../libcore/)
include_directories(${CMAKE_CURRENT_BINARY_DIR}/../libcore/)
include_directories(${CMAKE_CURRENT_BINARY_DIR}/../libwidgets/)
find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED
    varka
    granite
	glib-2.0>=2.29.0
	gthread-2.0
	gio-2.0
    gio-unix-2.0
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
    "-DGETTEXT_PACKAGE=\"pantheon-files\""
    "-DPIXMAP_DIR=\"${CMAKE_INSTALL_PREFIX}/share/pixmaps/pantheon-files/\""
    "-DUI_DIR=\"${CMAKE_INSTALL_PREFIX}/share/pantheon-files/ui/\""
     -O2
    )
vala_precompile(VALA_C
    marlin-deep-count.vala
    View/SettingsDialog.vala
    View/DiskRenderer.vala
    View/DirectoryNotFound.vala
    View/Window.vala
    View/Resources.vala
    View/DbusTags.vala
    View/ViewContainer.vala
    View/ContextView.vala
    View/OverlayBar.vala
    View/PropertiesWindow.vala
    View/Browser.vala
    View/ViewMode.vala
    View/Animations.vala
    View/LocationBar.vala
    View/Chrome/TopMenu.vala
    View/Chrome/ViewSwicher.vala
    View/Chrome/ColorWidget.vala
    View/Chrome/XsEntry.vala
    View/Chrome/IconFactory.vala
    View/Chrome/ImgEventBox.vala
    View/Chrome/CollapsiblePaned.vala
CUSTOM_VAPIS
    ${CMAKE_CURRENT_BINARY_DIR}/../libwidgets/marlinwidgets.vapi
    marlin.vapi
PACKAGES
    gtk+-3.0
    gio-2.0
    posix
    gee-1.0
    granite
    marlincore
    marlincore-C
GENERATE_HEADER
    marlin-vala
OPTIONS
    --vapidir=${CMAKE_SOURCE_DIR}/libcore/
    --vapidir=${CMAKE_BINARY_DIR}/libcore/
    --thread)
add_executable(pantheon-files
    eel-editable-label.c
    marlin-application.c
    gossip-cell-renderer-expander.c
    marlin-enum-types.c
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
    marlin-cell-renderer-text-ellipsized.c
    marlin-mime-actions.c
    fm-directory-view.c
    exo-icon-view.c
    exo-tree-view.c
    marlin-main.c
    fm-abstract-icon-view.c
    fm-icon-view.c
    fm-list-view.c
    fm-compact-view.c
    fm-columns-view.c
    marlin-toolbar-editor.c
    marlin-connect-server-dialog.c
    marlin-connect-server-operation.c
    marlin-progress-ui-handler.c
    marlin-progress-info-widget.c
    ${VALA_C} )

add_definitions("-DPLUGIN_DIR=\"${CMAKE_INSTALL_PREFIX}/lib/pantheon-files/plugins/\"")
target_link_libraries(pantheon-files marlincore marlinwidgets ${DEPS_LIBRARIES})

OPTION(WITH_UNITY "Add Unity launcher support" ON)
pkg_check_modules(UNITY unity>=4.0.0)

IF(WITH_UNITY AND UNITY_FOUND)
    include_directories(${UNITY_INCLUDE_DIRS})
    target_link_libraries (pantheon-files marlincore marlinwidgets ${UNITY_LIBRARIES})
    add_definitions("-DHAVE_UNITY=1")
ENDIF(WITH_UNITY AND UNITY_FOUND)

install(TARGETS pantheon-files RUNTIME DESTINATION bin)
install(FILES pantheon-files-ui.xml DESTINATION share/pantheon-files/ui/)
install(FILES fm-directory-view-ui.xml fm-icon-view-ui.xml DESTINATION share/pantheon-files/ui/)
include(Tests)
