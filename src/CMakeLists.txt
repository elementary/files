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
    gmodule-2.0
    gail-3.0
    gee-0.8
    sqlite3
    dbus-glib-1
    libnotify>=0.7.2
    plank
    zeitgeist-2.0)

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
        Application.vala
        Bookmark.vala
        BookmarkList.vala
        ConnectServerOperation.vala
        DndHandler.vala
        Enums.vala
        AbstractEditableLabel.vala
        SingleLineEditableLabel.vala
        MultiLineEditableLabel.vala
        main.vala
        marlin-deep-count.vala
        MimeActions.vala
        ProgressInfoWidget.vala
        ProgressUIHandler.vala
        TextRenderer.vala
        QuicklistHandler.vala
        View/ColumnView.vala
        View/AbstractTreeView.vala
        View/IconView.vala
        View/ListView.vala
        ZeitgeistManager.vala
        View/DiskRenderer.vala
        View/IconSpinnerRenderer.vala
        View/DirectoryNotFound.vala
        View/AbstractDirectoryView.vala
        View/SearchResults.vala
        View/Window.vala
        View/Resources.vala
        View/ViewContainer.vala
        View/OverlayBar.vala
        View/PropertiesWindow.vala
        View/Browser.vala
        View/LocationBar.vala
        View/Sidebar.vala
        View/Slot.vala
        View/Miller.vala
        View/Chrome/TopMenu.vala
        View/Chrome/ButtonWithMenu.vala
        View/Chrome/ViewSwicher.vala
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
        pantheon-files-core
        pantheon-files-core-C
        pantheon-files-widgets
        marlin
        zeitgeist-2.0
        plank
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
        DndHandler.vala
        Enums.vala
        AbstractEditableLabel.vala
        SingleLineEditableLabel.vala
        MultiLineEditableLabel.vala
        main.vala
        marlin-deep-count.vala
        MimeActions.vala
        ProgressInfoWidget.vala
        ProgressUIHandler.vala
        TextRenderer.vala
        View/ColumnView.vala
        View/AbstractTreeView.vala
        View/IconView.vala
        View/ListView.vala
        ZeitgeistManager.vala
        View/SearchResults.vala
        View/DiskRenderer.vala
        View/DirectoryNotFound.vala
        View/AbstractDirectoryView.vala
        View/Window.vala
        View/Resources.vala
        View/ViewContainer.vala
        View/IconSpinnerRenderer.vala
        View/OverlayBar.vala
        View/PropertiesWindow.vala
        View/Browser.vala
        View/LocationBar.vala
        View/Sidebar.vala
        View/Slot.vala
        View/Miller.vala
        View/Chrome/TopMenu.vala
        View/Chrome/ButtonWithMenu.vala
        View/Chrome/ViewSwicher.vala
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
        pantheon-files-core
        pantheon-files-core-C
        pantheon-files-widgets
        marlin
        zeitgeist-2.0
        plank
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
    marlin-clipboard-manager.c
    marlin-thumbnailer.c
    marlin-icon-renderer.c
    marlin-connect-server-dialog.c
    ${VALA_C} )

target_link_libraries (../pantheon-files m pantheon-files-core pantheon-files-widgets ${DEPS_LIBRARIES})
add_dependencies (../pantheon-files pantheon-files-core pantheon-files-widgets)

IF (WITH_UNITY AND UNITY_FOUND)
    include_directories (${UNITY_INCLUDE_DIRS})
    target_link_libraries (../pantheon-files pantheon-files-core pantheon-files-widgets ${UNITY_LIBRARIES})
    add_definitions ("-DHAVE_UNITY=1")
ENDIF (WITH_UNITY AND UNITY_FOUND)

install (TARGETS ../pantheon-files RUNTIME DESTINATION bin)
install (FILES View/directory_view_popup.ui DESTINATION ${UI_DIR})
include (Tests)
