find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED
	gtk+-3.0
    gee-1.0
    glib-2.0
    granite)
set(CFLAGS
	${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER}
)
include_directories(${CMAKE_BINARY_DIR}/libcore/)
include_directories(${CMAKE_SOURCE_DIR}/libcore/)
add_definitions(${CFLAGS})
link_directories(${LIB_PATHS})
vala_precompile(VALA_C marlin-contractor
    plugin.vala
PACKAGES
    gtk+-3.0
    gee-1.0
    granite
    marlincore-C
    marlincore
    marlinwidgets
OPTIONS
    --thread
    --vapidir=${CMAKE_SOURCE_DIR}/libcore/
    --vapidir=${CMAKE_BINARY_DIR}/libcore/
    --vapidir=${CMAKE_BINARY_DIR}/libwidgets/
)
add_library(marlin-contractor SHARED
    ${VALA_C})
target_link_libraries(marlin-contractor marlincore marlinwidgets)
add_dependencies(marlin-contractor marlincore marlinwidgets)
install(TARGETS marlin-contractor DESTINATION lib/pantheon-files/plugins/core/)
install(FILES contractor.plug DESTINATION lib/pantheon-files/plugins/core/)
