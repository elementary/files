# Check http://elementaryos.org/docs/developer-guide/cmake for documentation

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED
    gtk+-3.0
    gee-0.8
)
set(CFLAGS
    ${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER}
)
include_directories(${CMAKE_SOURCE_DIR}/libcore/)
include_directories(${CMAKE_BINARY_DIR}/libcore/)

vala_precompile(VALA_C pantheon-filestrash
    plugin.vala
PACKAGES
    gtk+-3.0
    gee-0.8
    pantheon-files-core-C
    pantheon-files-core
OPTIONS
    --thread
    --vapidir=${CMAKE_SOURCE_DIR}/libcore/
    --vapidir=${CMAKE_BINARY_DIR}/libcore/
)
add_definitions(${CFLAGS})
link_directories(${LIB_PATHS})
add_library(pantheon-filestrash SHARED
    ${VALA_C})
target_link_libraries(pantheon-filestrash ${DEPS_LIBRARIES} pantheon-files-core)
add_dependencies(pantheon-filestrash pantheon-files-core)
install(TARGETS pantheon-filestrash DESTINATION ${PLUGIN_DIR}/core/)
install(FILES pantheon-files-trash.plug DESTINATION ${PLUGIN_DIR}/core/)
include_directories(${CMAKE_BINARY_DIR}/plugins/)
