include (Tests)

set (PKGNAME marlincore)
set (PKGNAME_ MARLINCORE)
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
    gof-callwhenready.vala
    gof-directory-async.vala
    gof-preferences.vala
    PluginManager.vala
    Plugin.vala
PACKAGES
    granite
    gtk+-3.0
    gio-2.0
    gee-0.8
    gmodule-2.0
    marlincore-C
OPTIONS
    --vapidir=${CMAKE_CURRENT_SOURCE_DIR}/
    --thread
    --target-glib=2.32 # Needed for new thread API
GENERATE_VAPI
    marlincore
GENERATE_HEADER
    marlincore
)

set (C_SOURCE_FILES
    eel-fcts.c
    eel-i18n.c
    eel-gtk-extensions.c
    eel-gdk-extensions.c
    eel-gdk-pixbuf-extensions.c
    eel-pango-extensions.c
    eel-glib-extensions.c
    eel-gio-extensions.c
    eel-stock-dialogs.c
    eel-debug.c
    eel-string.c
    eel-accessibility.c
    eel-ui.c
    eel-vfs-extensions.c
    marlin-file-operations.c
    marlin-undostack-manager.c
    marlin-file-changes-queue.c
    marlin-file-utilities.c
    marlin-file-conflict-dialog.c
    fm-list-model.c
    marlin-progress-info.c
    marlin-progress-info-manager.c
    marlin-exec.c
#    gof-abstract-slot.c
    gof-file.c
    marlin-icon-info.c
    marlin-trash-monitor.c
    ${VALA_C})

set (C_HEADER_FILES
    eel-accessibility.h
    eel-debug.h
    eel-fcts.h
    eel-gdk-extensions.h
    eel-gdk-pixbuf-extensions.h
    eel-gio-extensions.h
    eel-glib-extensions.h
    eel-gtk-extensions.h
    eel-i18n.h
    eel-pango-extensions.h
    eel-stock-dialogs.h
    eel-string.h
    eel-ui.h
    eel-vfs-extensions.h
#    gof-abstract-slot.h
    gof-file.h
    marlin-exec.h
    marlin-file-conflict-dialog.h
    marlin-file-operations.h
    marlin-undostack-manager.h
    marlin-file-changes-queue.h
    marlin-file-utilities.h
    marlin-icons.h
    marlin-progress-info.h
    marlin-progress-info-manager.h
    marlin-icon-info.h
    fm-list-model.h
    marlin-trash-monitor.h)

configure_file (${CMAKE_CURRENT_SOURCE_DIR}/${PKGNAME}.pc.cmake ${CMAKE_CURRENT_BINARY_DIR}/${PKGNAME}.pc)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/${PKGNAME}.pc DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/pkgconfig/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/marlincore.h DESTINATION include/marlincore/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/marlincore.vapi DESTINATION share/vala/vapi)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/marlincore.deps DESTINATION share/vala/vapi)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/marlincore-C.vapi DESTINATION share/vala/vapi)
install (FILES ${C_HEADER_FILES} DESTINATION include/marlincore/)
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
	sqlite3
	libnotify>=0.7.2)
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
    VERSION ${MARLINCORE_VERSION}
    SOVERSION ${MARLINCORE_SOVERSION})

target_link_libraries (${PKGNAME} ${DEPS_LIBRARIES})

install (TARGETS ${PKGNAME} DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/)

add_executable (marlincore_tests
    tests/tests.c
    tests/marlincore-tests-gof.c
    tests/marlincore-tests-file.c
    tests/marlincore-tests-icon-info.c)

add_test (core marlincore_tests)

target_link_libraries (marlincore_tests marlincore ${DEPS_LIBRARIES})
add_dependencies (marlincore_tests marlincore)
