include(Tests)
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

find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.12.0" MINIMUM)
include(ValaPrecompile)
vala_precompile(VALA_C
gof-callwhenready.vala
gof-directory-async.vala
PluginManager.vala
Plugin.vala
PACKAGES
gtk+-3.0
gio-2.0
gee-1.0
gmodule-2.0
CUSTOM_VAPIS
    ${CMAKE_CURRENT_SOURCE_DIR}/marlin-core.vapi
OPTIONS
--thread
GENERATE_VAPI
marlincore
GENERATE_HEADER
marlincore
)

configure_file (${CMAKE_CURRENT_SOURCE_DIR}/${PKGNAME}.pc.cmake ${CMAKE_CURRENT_BINARY_DIR}/${PKGNAME}.pc)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/${PKGNAME}.pc DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/pkgconfig/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/marlincore.h DESTINATION include/marlincore/)
install (FILES marlin-core.vapi DESTINATION share/vala/vapi)
install (FILES
    eel-accessibility.h
    eel-debug.h
    eel-fcts.h
    eel-gdk-extensions.h
    eel-gdk-pixbuf-extensions.h
    eel-gio-extensions.h
    eel-glib-extensions.h
    eel-gtk-extensions.h
    eel-gtk-macros.h
    eel-i18n.h
    eel-pango-extensions.h
    eel-stock-dialogs.h
    eel-string.h
    eel-ui.h
    eel-vfs-extensions.h
    gof-abstract-slot.h
    gof-file.h
    gof-monitor.h
    marlin-exec.h
    marlin-file-conflict-dialog.h
    marlin-file-operations.h
    marlin-file-utilities.h
    marlin-global-preferences.h
    marlin-icons.h
    marlin-abstract-sidebar.h
    marlin-plugins-hook.h
    marlin-progress-info.h
    marlin-progress-info-manager.h
    nautilus-cell-renderer-text-ellipsized.h
    nautilus-icon-info.h
    fm-list-model.h
    marlin-trash-monitor.h
    DESTINATION include/marlincore/)
# Check for the deps

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
	libnotify>=0.7.2)
# Link all

set(CFLAGS ${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER})
add_definitions(${CFLAGS} "-DUI_DIR=\"${CMAKE_INSTALL_PREFIX}/share/marlin/ui/\""
    -Wall )
set(LIBS
	${DEP_LIBRARIES}
)
link_libraries(${LIBS})
set(LIB_PATHS
	${DEPS_LIBRARY_DIRS}
)
link_directories(${LIB_PATHS})
add_library (${PKGNAME} SHARED
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
    marlin-file-utilities.c
    marlin-file-conflict-dialog.c
    fm-list-model.c
    marlin-progress-info.c
    marlin-progress-info-manager.c
    marlin-abstract-sidebar.c
    marlin-exec.c
    gof-abstract-slot.c
    gof-file.c
    gof-monitor.c
    nautilus-icon-info.c
    nautilus-cell-renderer-text-ellipsized.c
    marlin-trash-monitor.c
    ${VALA_C}
)
if(BUILD_STATIC MATCHES "Yes")
add_library(${PKGNAME}-static STATIC
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
    marlin-file-utilities.c
    marlin-file-conflict-dialog.c
    fm-list-model.c
    marlin-progress-info.c
    marlin-progress-info-manager.c
    marlin-abstract-sidebar.c
    marlin-exec.c
    gof-abstract-slot.c
    gof-file.c
    gof-monitor.c
    nautilus-icon-info.c
    nautilus-cell-renderer-text-ellipsized.c
    marlin-trash-monitor.c
    ${VALA_C}
)
# The library target "foo" already has a default OUTPUT_NAME of "foo", so we

# don't need to change it.

# The library target "foo-static" has a default OUTPUT_NAME of "foo-static",

#so change it.

SET_TARGET_PROPERTIES(${PKGNAME}-static PROPERTIES OUTPUT_NAME ${PKGNAME})
install (TARGETS ${PKGNAME}-static DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/)
endif(BUILD_STATI²C MATCHES "Yes")
set_target_properties (${PKGNAME} PROPERTIES
    VERSION ${MARLINCORE_VERSION}
    SOVERSION ${MARLINCORE_SOVERSION}
                       )
install (TARGETS ${PKGNAME} DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/)
add_executable(marlincore_tests
    tests/tests.c
    tests/marlincore-tests-gof.c
    tests/marlincore-tests-file.c
)
add_test_executable(marlincore_tests)
target_link_libraries(marlincore_tests marlincore ${DEPS_LIBRARIES})
#target_link_libraries(marlincore ${DEPS_LIBRARIES})
