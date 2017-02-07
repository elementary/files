set (PKGNAME pantheon-files-core)
set (PKGNAME_ PANTHEON_FILES_CORE)
set (${PKGNAME_}_VERSION 0.1)
# increase the version number if you break the API

include_directories(${CMAKE_BINARY_DIR})
include_directories(${CMAKE_CURRENT_SOURCE_DIR})

set (CFLAGS
    ${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER}
)

set (LIB_PATHS
    ${DEPS_LIBRARY_DIRS}
)

link_directories (${LIB_PATHS})
add_definitions (${CFLAGS} -O2)

vala_precompile (VALA_TEST_C ${PKGNAME}-vala_tests
  UtilTests.vala
  PACKAGES
    granite
    gtk+-3.0
    gio-2.0
    gee-0.8
    gmodule-2.0
    libcanberra
    pantheon-files-core
    pantheon-files-core-C
  OPTIONS
    --vapidir=${CMAKE_CURRENT_SOURCE_DIR}/
    --thread
    --target-glib=2.32 # Needed for new thread API
)

add_executable (${PKGNAME}-vala_tests
    ${VALA_TEST_C}
)

target_link_libraries (${PKGNAME}-vala_tests pantheon-files-core ${DEPS_LIBRARIES})
add_dependencies (${PKGNAME}-vala_tests pantheon-files-core)

add_test (core-vala-tests ${PKGNAME}-vala_tests)

