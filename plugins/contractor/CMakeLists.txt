find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED
	gtk+-3.0
    gee-0.8
    glib-2.0
    granite)
set(CFLAGS
	${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER}
)
include_directories(${CMAKE_BINARY_DIR}/libcore/)
include_directories(${CMAKE_SOURCE_DIR}/libcore/)
add_definitions(${CFLAGS})
link_directories(${LIB_PATHS})
vala_precompile(VALA_C pantheon-files-contractor
    plugin.vala
PACKAGES
    gtk+-3.0
    gee-0.8
    granite
    pantheon-filescore-C
    pantheon-filescore
    pantheon-fileswidgets
OPTIONS
    --thread
    --vapidir=${CMAKE_SOURCE_DIR}/libcore/
    --vapidir=${CMAKE_BINARY_DIR}/libcore/
    --vapidir=${CMAKE_BINARY_DIR}/libwidgets/
)
add_library(pantheon-files-contractor SHARED
    ${VALA_C})
target_link_libraries(pantheon-files-contractor pantheon-filescore pantheon-fileswidgets)
add_dependencies(pantheon-files-contractor pantheon-filescore pantheon-fileswidgets)
install(TARGETS pantheon-files-contractor DESTINATION lib/pantheon-files/plugins/core/)
install(FILES contractor.plug DESTINATION lib/pantheon-files/plugins/core/)
