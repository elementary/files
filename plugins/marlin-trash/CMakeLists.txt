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
# Vala

find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.12.0" MINIMUM)
include(ValaPrecompile)
vala_precompile(VALA_C
    plugin.vala
PACKAGES
    gtk+-3.0
    gee-1.0
    marlincore-C
    marlincore
OPTIONS
    --thread
    --vapidir=${CMAKE_SOURCE_DIR}/libcore/
    --vapidir=${CMAKE_BINARY_DIR}/libcore/
)
add_definitions(${CFLAGS})
link_directories(${LIB_PATHS})
add_library(marlintrash SHARED 
    ${VALA_C})
target_link_libraries(marlintrash ${DEPS_LIBRARIES} marlincore)
install(TARGETS marlintrash DESTINATION lib/marlin/plugins/core/)
install(FILES marlintrash.plug DESTINATION lib/marlin/plugins/core/)
include_directories(${CMAKE_BINARY_DIR}/marlinplugins/)
