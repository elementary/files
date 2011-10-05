# Check http://elementaryos.org/docs/developer-guide/cmake for documentation

cmake_minimum_required (VERSION 2.6)
cmake_policy(VERSION 2.6)
project(Marlin-Dropbox)
list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake )
set(GETTEXT_PACKAGE "marlin-dropbox")
set(PACKAGE_VERSION 0.1)
set(VERSION 0.1)
configure_file (${CMAKE_SOURCE_DIR}/config.h.cmake ${CMAKE_BINARY_DIR}/config.h)

install(FILES dropbox.plug DESTINATION lib/marlin/plugins/)
find_package(PkgConfig)
pkg_check_modules(DROPBOX REQUIRED
    gtk+-3.0
    gee-1.0
    glib-2.0
    marlincore
    )
set(CFLAGS
	${DROPBOX_CFLAGS} ${DROPBOX_CFLAGS_OTHER} 
)
include_directories(${CMAKE_BINARY_DIR})
include_directories(${CMAKE_SOURCE_DIR}/libcore/)
include_directories(${CMAKE_BINARY_DIR}/libcore/)
add_definitions(${CFLAGS})
link_directories(${LIB_PATHS})
add_library(marlin-dropbox SHARED
    plugin.c dropbox-client-util.c dropbox-command-client.c dropbox-client.c dropbox-hooks.c)
target_link_libraries(marlin-dropbox marlincore marlinwidgets ${DROPBOX_LIBRARIES})
install(TARGETS marlin-dropbox DESTINATION lib/marlin/plugins/)
