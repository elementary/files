# Vala stuff

# pkgconfig, real C code

include_directories (${CMAKE_BINARY_DIR})
include_directories (${CMAKE_BINARY_DIR}/marlinplugins/)
include_directories (${CMAKE_CURRENT_SOURCE_DIR})
include_directories (${CMAKE_CURRENT_BINARY_DIR})
include_directories (${CMAKE_SOURCE_DIR}/libcore/)
include_directories (${CMAKE_BINARY_DIR}/libcore/)
include_directories (${CMAKE_SOURCE_DIR}/libwidgets/)
include_directories (${CMAKE_BINARY_DIR}/libwidgets/)

find_package (PkgConfig)

pkg_check_modules(PLANK011 QUIET plank>=0.10.9)
if (PLANK011_FOUND)
  set (PLANK_OPTIONS --define=HAVE_PLANK_0_11)
endif ()

set (CFLAGS
    ${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER}
)

set (LIB_PATHS
    ${DEPS_LIBRARY_DIRS}
)

link_directories (${LIB_PATHS})
add_definitions (${CFLAGS} -O2)

IF (WITH_UNITY AND UNITY_FOUND)
    vala_precompile (VALA_C ${CMAKE_PROJECT_NAME}
        Application.vala
        ConnectServerOperation.vala
        main.vala
        marlin-deep-count.vala
        ProgressUIHandler.vala
        TextRenderer.vala
        QuicklistHandler.vala
        ClipboardManager.vala
        IconRenderer.vala
        Thumbnailer.vala
        Dialogs/AbstractPropertiesDialog.vala
        Dialogs/ChooseAppDialog.vala
        Dialogs/PropertiesWindow.vala
        Dialogs/VolumePropertiesWindow.vala
        Utils/MimeActions.vala
        Utils/Permissions.vala
        View/ColumnView.vala
        View/AbstractTreeView.vala
        View/IconView.vala
        View/ListView.vala
        ZeitgeistManager.vala
        View/DirectoryNotFound.vala
        View/AbstractDirectoryView.vala
        View/Window.vala
        View/ViewContainer.vala
        View/Browser.vala
        View/Sidebar.vala
        View/Slot.vala
        View/Miller.vala
        View/Widgets/AbstractEditableLabel.vala
        View/Widgets/BreadcrumbsEntry.vala
        View/Widgets/DiskRenderer.vala
        View/Widgets/Label.vala
        View/Widgets/LocationBar.vala
        View/Widgets/MultiLineEditableLabel.vala
        View/Widgets/OverlayBar.vala
        View/Widgets/PermissionButton.vala
        View/Widgets/ProgressInfoWidget.vala
        View/Widgets/SingleLineEditableLabel.vala
        View/Widgets/TopMenu.vala
        Services/FileManager1.vala

    PACKAGES
        gtk+-3.0
        gio-2.0
        posix
        gee-0.8
        granite
        unity
        plank
        pantheon-files-core
        pantheon-files-core-C
        pantheon-files-widgets
        marlin
        zeitgeist-2.0
    GENERATE_HEADER
        marlin-vala
    OPTIONS
        --vapidir=${CMAKE_CURRENT_SOURCE_DIR}/
        --vapidir=${CMAKE_SOURCE_DIR}/libcore/
        --vapidir=${CMAKE_BINARY_DIR}/libcore/
        --vapidir=${CMAKE_BINARY_DIR}/libwidgets/
        --target-glib=2.32 # Needed for new thread API
        ${PLANK_OPTIONS}
        --thread
        -D HAVE_UNITY)
ELSE (WITH_UNITY AND UNITY_FOUND)
    vala_precompile (VALA_C ${CMAKE_PROJECT_NAME}
        Application.vala
        ConnectServerOperation.vala
        main.vala
        marlin-deep-count.vala
        ProgressUIHandler.vala
        TextRenderer.vala
        ClipboardManager.vala
        IconRenderer.vala
        Thumbnailer.vala
        Dialogs/AbstractPropertiesDialog.vala
        Dialogs/ChooseAppDialog.vala
        Dialogs/PropertiesWindow.vala
        Dialogs/VolumePropertiesWindow.vala
        Utils/MimeActions.vala
        Utils/Permissions.vala
        View/ColumnView.vala
        View/AbstractTreeView.vala
        View/IconView.vala
        View/ListView.vala
        ZeitgeistManager.vala
        View/DirectoryNotFound.vala
        View/AbstractDirectoryView.vala
        View/Window.vala
        View/ViewContainer.vala
        View/Browser.vala
        View/Sidebar.vala
        View/Slot.vala
        View/Miller.vala
        View/Widgets/AbstractEditableLabel.vala
        View/Widgets/BreadcrumbsEntry.vala
        View/Widgets/DiskRenderer.vala
        View/Widgets/Label.vala
        View/Widgets/LocationBar.vala
        View/Widgets/MultiLineEditableLabel.vala
        View/Widgets/OverlayBar.vala
        View/Widgets/PermissionButton.vala
        View/Widgets/ProgressInfoWidget.vala
        View/Widgets/SingleLineEditableLabel.vala
        View/Widgets/TopMenu.vala
        Services/FileManager1.vala

    PACKAGES
        gtk+-3.0
        gio-2.0
        pango
        posix
        gee-0.8
        granite
        pantheon-files-core
        pantheon-files-core-C
        pantheon-files-widgets
        marlin
        zeitgeist-2.0
    GENERATE_HEADER
        marlin-vala
    OPTIONS
        --vapidir=${CMAKE_CURRENT_SOURCE_DIR}/
        --vapidir=${CMAKE_SOURCE_DIR}/libcore/
        --vapidir=${CMAKE_BINARY_DIR}/libcore/
        --vapidir=${CMAKE_BINARY_DIR}/libwidgets/
        --target-glib=2.32 # Needed for new thread API
        ${PLANK_OPTIONS}
        --thread)
ENDIF (WITH_UNITY AND UNITY_FOUND)

add_executable (${CMAKE_PROJECT_NAME}
    marlin-connect-server-dialog.c
    ${VALA_C} )

target_link_libraries (${CMAKE_PROJECT_NAME} m pantheon-files-core pantheon-files-widgets ${DEPS_LIBRARIES})
add_dependencies (${CMAKE_PROJECT_NAME} pantheon-files-core pantheon-files-widgets)

IF (WITH_UNITY AND UNITY_FOUND)
    include_directories (${UNITY_INCLUDE_DIRS})
    target_link_libraries (${CMAKE_PROJECT_NAME} pantheon-files-core pantheon-files-widgets ${UNITY_LIBRARIES})
    add_definitions ("-DHAVE_UNITY=1")
ENDIF (WITH_UNITY AND UNITY_FOUND)

install (TARGETS ${CMAKE_PROJECT_NAME} RUNTIME DESTINATION bin)
install (FILES View/directory_view_popup.ui DESTINATION ${UI_DIR})

add_subdirectory (Services/tests)
