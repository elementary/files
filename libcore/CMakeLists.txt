set (PKGNAME pantheon-files-core)
set (PKGNAME_ PANTHEON_FILES_CORE)
set (${PKGNAME_}_VERSION 0.1)
# increase when you broke the API

set (${PKGNAME_}_SOVERSION 0)
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")
# You hear that? It's kittens being killed by the gods of cmake

include_directories(${CMAKE_BINARY_DIR})
include_directories(${CMAKE_CURRENT_SOURCE_DIR})

vala_precompile(VALA_C ${PKGNAME}
    AbstractSidebar.vala
    AbstractSlot.vala
    Bookmark.vala
    BookmarkList.vala
    DndHandler.vala
    Enums.vala
    PixbufUtils.vala
    FileUtils.vala
    FileConflictDialog.vala
    gof-callwhenready.vala
    gof-directory-async.vala
    gof-preferences.vala
    PluginManager.vala
    Plugin.vala
    ProgressInfo.vala
    ProgressInfoManager.vala
    SoundManager.vala
    StockDialogs.vala
    TrashMonitor.vala
    UserUtils.vala
    IconInfo.vala
PACKAGES
    granite
    gtk+-3.0
    gio-2.0
    gee-0.8
    gmodule-2.0
    libcanberra
    pantheon-files-core-C
    posix
    linux
    zeitgeist-2.0
OPTIONS
    --vapidir=${CMAKE_CURRENT_SOURCE_DIR}/
    --thread
    --target-glib=2.32 # Needed for new thread API
GENERATE_VAPI
    pantheon-files-core
GENERATE_HEADER
    pantheon-files-core
)

set (C_SOURCE_FILES
    #eel-stock-dialogs.c
    eel-string.c
    marlin-file-operations.c
    marlin-undostack-manager.c
    marlin-file-changes-queue.c
    fm-list-model.c
    gof-file.c
    ${VALA_C})

set (C_HEADER_FILES
    #eel-stock-dialogs.h
    eel-string.h
    gof-file.h
    marlin-file-operations.h
    marlin-undostack-manager.h
    marlin-file-changes-queue.h
    marlin-icons.h
    fm-list-model.h)

configure_file (${CMAKE_CURRENT_SOURCE_DIR}/${PKGNAME}.pc.cmake ${CMAKE_CURRENT_BINARY_DIR}/${PKGNAME}.pc)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/${PKGNAME}.pc DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/pantheon-files-core.h DESTINATION include/pantheon-files-core/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/pantheon-files-core.vapi DESTINATION share/vala/vapi)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/pantheon-files-core.deps DESTINATION share/vala/vapi)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/pantheon-files-core-C.vapi DESTINATION share/vala/vapi)
install (FILES ${C_HEADER_FILES} DESTINATION include/pantheon-files-core/)
# Check for the deps

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED
    glib-2.0>=2.29.0
    gthread-2.0
    gio-2.0
    pango>=1.1.2
    gtk+-3.0>=3.4.0
    gail-3.0
    gee-0.8
    gmodule-2.0
    sqlite3
    libcanberra>=0.30
    granite)

# Link all

set(CFLAGS ${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER})
add_definitions(${CFLAGS})
set(LIBS
    ${DEP_LIBRARIES}
)

link_libraries(${LIBS})

set (LIB_PATHS ${DEPS_LIBRARY_DIRS})

link_directories (${LIB_PATHS})

add_library (${PKGNAME} SHARED ${C_SOURCE_FILES})

set_target_properties (${PKGNAME} PROPERTIES
    VERSION ${PANTHEON_FILES_CORE_VERSION}
    SOVERSION ${PANTHEON_FILES_CORE_SOVERSION})

target_link_libraries (${PKGNAME} m ${DEPS_LIBRARIES})

install (TARGETS ${PKGNAME} DESTINATION ${CMAKE_INSTALL_LIBDIR})

add_subdirectory (tests)
