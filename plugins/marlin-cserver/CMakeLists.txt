# Check http://elementaryos.org/docs/developer-guide/cmake for documentation

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED
	gtk+-3.0
    gee-1.0
)
set(CFLAGS
	${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER}
)
include_directories(${CMAKE_SOURCE_DIR}/libcore/)
include_directories(${CMAKE_BINARY_DIR}/libcore/)

vala_precompile(VALA_C marlincserver
    plugin.vala
PACKAGES
    gtk+-3.0
    gee-1.0
    marlincore-C
    marlincore
    marlin
OPTIONS
    --thread
    --vapidir=${CMAKE_SOURCE_DIR}/libcore/
    --vapidir=${CMAKE_SOURCE_DIR}/plugins/marlin-cserver/
    --vapidir=${CMAKE_BINARY_DIR}/libcore/
)
add_definitions(${CFLAGS}
    "-DGETTEXT_PACKAGE=\"pantheon-files\""
    )
link_directories(${LIB_PATHS})
add_library(marlincserver SHARED 
    ${VALA_C})
target_link_libraries(marlincserver ${DEPS_LIBRARIES} marlincore)
install(TARGETS marlincserver DESTINATION lib/pantheon-files/plugins/core/)
install(FILES marlincserver.plug DESTINATION lib/pantheon-files/plugins/core/)
include_directories(${CMAKE_BINARY_DIR}/plugins/)
