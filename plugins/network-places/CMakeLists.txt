# Check http://elementaryos.org/docs/developer-guide/cmake for documentation

set(PLUGIN_LIB_NAME "network-places")

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED
    gtk+-3.0
    gee-0.8
)

set(CFLAGS ${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER})

add_definitions(${CFLAGS})
include_directories(${CMAKE_SOURCE_DIR}/libcore/)
include_directories(${CMAKE_BINARY_DIR}/libcore/)

vala_precompile(VALA_C pantheon-filescserver
    plugin.vala
PACKAGES
    gtk+-3.0
    gee-0.8
    pantheon-files-core-C
    pantheon-files-core
OPTIONS
    --thread
    --vapidir=${CMAKE_SOURCE_DIR}/libcore/
    --vapidir=${CMAKE_SOURCE_DIR}/plugins/pantheon-files-cserver/
    --vapidir=${CMAKE_BINARY_DIR}/libcore/
)

link_directories(${LIB_PATHS})

add_library(${PLUGIN_LIB_NAME} SHARED ${VALA_C})
target_link_libraries(${PLUGIN_LIB_NAME} ${DEPS_LIBRARIES} pantheon-files-core)
add_dependencies(${PLUGIN_LIB_NAME} pantheon-files-core)
install(TARGETS ${PLUGIN_LIB_NAME} DESTINATION ${PLUGIN_DIR}/core/)
install(FILES ${PLUGIN_LIB_NAME}.plug DESTINATION ${PLUGIN_DIR}/core/)
include_directories(${CMAKE_BINARY_DIR}/plugins/)
