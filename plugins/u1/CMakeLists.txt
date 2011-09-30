install(FILES ubuntuone.plug DESTINATION lib/marlin/plugins/)
find_package(PkgConfig)
pkg_check_modules(UBUNTUONE REQUIRED
    gtk+-3.0
    gee-1.0
    glib-2.0
    libsyncdaemon-1.0>=1.7
    )
set(CFLAGS
	${UBUNTUONE_CFLAGS} ${UBUNTUONE_CFLAGS_OTHER} 
)
include_directories(${CMAKE_BINARY_DIR})
include_directories(${CMAKE_SOURCE_DIR}/libcore/)
include_directories(${CMAKE_BINARY_DIR}/libcore/)
add_definitions(${CFLAGS})
link_directories(${LIB_PATHS})
add_library(marlin-ubuntuone SHARED
    plugin.c file-watcher.c)
target_link_libraries(marlin-ubuntuone marlincore marlinwidgets ${UBUNTUONE_LIBRARIES})
install(TARGETS marlin-ubuntuone DESTINATION lib/marlin/plugins/)
