# Check http://elementaryos.org/docs/developer-guide/cmake for documentation

cmake_minimum_required (VERSION 2.6)
cmake_policy(VERSION 2.6)
project (pantheon-files-dropbox C)
set (PARENT_PROJECT "io.elementary.files")

include (GNUInstallDirs)
list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake )
set(GETTEXT_PACKAGE ${CMAKE_PROJECT_NAME})
set(PACKAGE_VERSION 0.2)
set(VERSION 0.2)
set (PLUGIN_DIR "${CMAKE_INSTALL_FULL_LIBDIR}/${PARENT_PROJECT}/plugins/")

configure_file (${CMAKE_SOURCE_DIR}/config.h.cmake ${CMAKE_BINARY_DIR}/config.h)
configure_file (${CMAKE_SOURCE_DIR}/dropbox.plug.cmake ${CMAKE_BINARY_DIR}/dropbox.plug)

install(FILES ${CMAKE_BINARY_DIR}/dropbox.plug DESTINATION ${PLUGIN_DIR}/)

find_package(PkgConfig)
pkg_check_modules(DROPBOX REQUIRED
    gtk+-3.0
    gee-0.8
    glib-2.0
    pantheon-files-core
    )
set(CFLAGS
    ${DROPBOX_CFLAGS} ${DROPBOX_CFLAGS_OTHER}
)
include_directories(${CMAKE_BINARY_DIR})
include_directories(${CMAKE_SOURCE_DIR}/libcore/)
include_directories(${CMAKE_BINARY_DIR}/libcore/)
add_definitions(${CFLAGS})
link_directories(${LIB_PATHS})
add_library(${CMAKE_PROJECT_NAME} SHARED
    plugin.c dropbox-client-util.c dropbox-command-client.c dropbox-client.c dropbox-hooks.c)
target_link_libraries(${CMAKE_PROJECT_NAME} pantheon-files-core ${DROPBOX_LIBRARIES})
install(TARGETS ${CMAKE_PROJECT_NAME} DESTINATION ${PLUGIN_DIR})
