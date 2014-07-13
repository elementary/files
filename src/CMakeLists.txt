# Vala stuff

# pkgconfig, real C code

include_directories (${CMAKE_BINARY_DIR})
include_directories (${CMAKE_BINARY_DIR}/marlinplugins/)
include_directories (${CMAKE_CURRENT_SOURCE_DIR})
include_directories (${CMAKE_CURRENT_BINARY_DIR})
include_directories (${CMAKE_CURRENT_SOURCE_DIR}/../libcore/)
include_directories (${CMAKE_CURRENT_BINARY_DIR}/../libcore/)
include_directories (${CMAKE_CURRENT_BINARY_DIR}/../libwidgets/)

find_package (PkgConfig)

pkg_check_modules (DEPS REQUIRED
    granite>=0.3.0
    glib-2.0>=2.29.0
    gthread-2.0
    gio-2.0
    gio-unix-2.0
    pango>=1.1.2
    gtk+-3.0>=3.10
    gail-3.0
    gee-0.8
    sqlite3
    dbus-glib-1
    libnotify>=0.7.2)

set (CFLAGS
    ${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER}
)

set (LIB_PATHS
    ${DEPS_LIBRARY_DIRS}
)

link_directories (${LIB_PATHS})
add_definitions (${CFLAGS} -O2)

OPTION (WITH_UNITY "Add Unity launcher support" ON)
pkg_check_modules (UNITY unity>=4.0.0)

IF (WITH_UNITY AND UNITY_FOUND)
    vala_precompile (VALA_C pantheon-files
        View/Slot.vala
        Application.vala
        Bookmark.vala
        BookmarkList.vala
        ConnectServerOperation.vala
        main.vala
        marlin-deep-count.vala
#        MarlinEnums.vala
        #MillerView.vala
        MimeActions.vala
        ProgressInfoWidget.vala
        ProgressUIHandler.vala
        QuicklistHandler.vala
        #Slot.vala
        View/DiskRenderer.vala
        View/DirectoryNotFound.vala
        View/DirectoryView.vala
        View/Window.vala
        View/Resources.vala
        View/DbusTags.vala
        View/ViewContainer.vala
        View/OverlayBar.vala
        View/PropertiesWindow.vala
        View/Browser.vala
#        View/ViewMode.vala
        View/LocationBar.vala
        View/Sidebar.vala
        View/Miller.vala
        View/Chrome/TopMenu.vala
        View/Chrome/ButtonWithMenu.vala
        View/Chrome/ViewSwicher.vala
        View/Chrome/ColorWidget.vala
        View/Chrome/XsEntry.vala
        View/Chrome/ImgEventBox.vala
    PACKAGES
        gtk+-3.0
        gio-2.0
        posix
        gee-0.8
        granite
        libnotify
        unity
        marlincore
        marlincore-C
        marlinwidgets
        marlin
    GENERATE_HEADER
        marlin-vala
    OPTIONS
        --vapidir=${CMAKE_CURRENT_SOURCE_DIR}/
        --vapidir=${CMAKE_SOURCE_DIR}/libcore/
        --vapidir=${CMAKE_BINARY_DIR}/libcore/
        --vapidir=${CMAKE_BINARY_DIR}/libwidgets/
        --target-glib=2.32 # Needed for new thread API
        --thread
        -D HAVE_UNITY)
ELSE (WITH_UNITY AND UNITY_FOUND)
    vala_precompile (VALA_C pantheon-files
        Application.vala
        Bookmark.vala
        BookmarkList.vala
        ConnectServerOperation.vala
        main.vala
        marlin-deep-count.vala
#        MarlinEnums.vala
        #MillerView.vala
        MimeActions.vala
        ProgressInfoWidget.vala
        ProgressUIHandler.vala
        #Slot.vala
        View/DiskRenderer.vala
        View/DirectoryNotFound.vala
        View/DirectoryView.vala
        View/Window.vala
        View/Resources.vala
        View/DbusTags.vala
        View/ViewContainer.vala
        View/OverlayBar.vala
        View/PropertiesWindow.vala
        View/Browser.vala
#        View/ViewMode.vala
        View/LocationBar.vala
        View/Sidebar.vala
        View/Slot.vala
        View/Miller.vala
        View/Chrome/TopMenu.vala
        View/Chrome/ButtonWithMenu.vala
        View/Chrome/ViewSwicher.vala
        View/Chrome/ColorWidget.vala
        View/Chrome/XsEntry.vala
        View/Chrome/ImgEventBox.vala
    PACKAGES
        gtk+-3.0
        gio-2.0
        pango
        posix
        gee-0.8
        granite
        libnotify
        marlincore
        marlincore-C
        marlinwidgets
        marlin
    GENERATE_HEADER
        marlin-vala
    OPTIONS
        --vapidir=${CMAKE_CURRENT_SOURCE_DIR}/
        --vapidir=${CMAKE_SOURCE_DIR}/libcore/
        --vapidir=${CMAKE_BINARY_DIR}/libcore/
        --vapidir=${CMAKE_BINARY_DIR}/libwidgets/
        --target-glib=2.32 # Needed for new thread API
        --thread)
ENDIF (WITH_UNITY AND UNITY_FOUND)

add_executable (../pantheon-files
    eel-editable-label.c
    marlin-enum-types.c
    marlin-dnd.c
    marlin-clipboard-manager.c
#    marlin-window-columns.c
#    gof-window-slot.c
    marlin-thumbnailer.c
    marlin-icon-renderer.c
    marlin-text-renderer.c
    marlin-cell-renderer-text-ellipsized.c
    fm-directory-view.c
    exo-icon-view.c
    exo-tree-view.c
    fm-abstract-icon-view.c
    fm-icon-view.c
    fm-list-view.c
    fm-columns-view.c
    marlin-connect-server-dialog.c
    ${VALA_C} )

target_link_libraries (../pantheon-files m marlincore marlinwidgets ${DEPS_LIBRARIES})
add_dependencies (../pantheon-files marlincore marlinwidgets)

IF (WITH_UNITY AND UNITY_FOUND)
    include_directories (${UNITY_INCLUDE_DIRS})
    target_link_libraries (../pantheon-files marlincore marlinwidgets ${UNITY_LIBRARIES})
    add_definitions ("-DHAVE_UNITY=1")
ENDIF (WITH_UNITY AND UNITY_FOUND)

install (TARGETS ../pantheon-files RUNTIME DESTINATION bin)
install (FILES pantheon-files-ui.xml fm-directory-view-ui.xml fm-icon-view-ui.xml DESTINATION ${UI_DIR})
include (Tests)
