install(FILES openterminal.plug DESTINATION lib/marlin/plugins/)

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED
	gtk+-3.0
    gee-1.0
    glib-2.0)

set(CFLAGS
	${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER}
)

include_directories(${CMAKE_SOURCE_DIR}/libcore/)

add_definitions(${CFLAGS})

link_directories(${LIB_PATHS})

add_library(marlin-openterminal SHARED
    plugin.c)

target_link_libraries(marlin-openterminal marlincore marlinwidgets)
install(TARGETS marlin-openterminal DESTINATION lib/marlin/plugins/)
