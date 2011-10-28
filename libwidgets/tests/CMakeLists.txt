include_directories(../../libcore/)
find_package(Vala REQUIRED)
include(ValaPrecompile)
vala_precompile(VALA_C
    tests-pathbar.vala
PACKAGES
    gtk+-3.0
    gee-1.0
    posix
    marlinwidgets
    marlin-core
OPTIONS
    --thread
    --vapidir=${CMAKE_BINARY_DIR}/libwidgets/
    --vapidir=${CMAKE_SOURCE_DIR}/libcore/
)

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED gtk+-3.0 gee-1.0)

add_definitions(${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER})

add_executable(widgets-test ${VALA_C})

link_directories(${DEPS_LIBRARY_DIRS})
target_link_libraries(widgets-test marlinwidgets ${DEPS_LIBRARIES})
add_test(widgets widgets-test)
