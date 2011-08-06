install(FILES contractor.plug DESTINATION lib/marlin/plugins/)

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

vala_precompile(VALA_C
    plugin.vala
CUSTOM_VAPIS
    ${CMAKE_SOURCE_DIR}/libcore/marlin-core.vapi
    ${CMAKE_BINARY_DIR}/libwidgets/marlinwidgets.vapi
PACKAGES
    gtk+-3.0
    gee-1.0
OPTIONS
    --thread)

add_library(marlin-contractor SHARED
    ${VALA_C})

install(TARGETS marlin-contractor DESTINATION lib/marlin/plugins/)
