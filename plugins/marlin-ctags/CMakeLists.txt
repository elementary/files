# Check http://elementaryos.org/docs/developer-guide/cmake for documentation

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED
	gtk+-3.0
    gio-2.0
    gee-0.8
)
set(CFLAGS
	${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER}
)
include_directories(${CMAKE_SOURCE_DIR}/libcore/)
include_directories(${CMAKE_BINARY_DIR}/libcore/)

vala_precompile(VALA_C marlinctags
    plugin.vala
PACKAGES
    gtk+-3.0
    gee-0.8
    posix
    marlincore-C
    marlincore
OPTIONS
    --thread
    --vapidir=${CMAKE_SOURCE_DIR}/libcore/
    --vapidir=${CMAKE_BINARY_DIR}/libcore/
)
add_definitions(${CFLAGS})
link_directories(${LIB_PATHS})
add_library(marlinctags SHARED 
    ${VALA_C})
target_link_libraries(marlinctags ${DEPS_LIBRARIES} marlincore)
add_dependencies(marlinctags marlincore)
install(TARGETS marlinctags DESTINATION lib/pantheon-files/plugins/core/)
install(FILES marlinctags.plug DESTINATION lib/pantheon-files/plugins/core/)
include_directories(${CMAKE_BINARY_DIR}/plugins/)