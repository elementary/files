include_directories(${CMAKE_BINARY_DIR})
include_directories(${CMAKE_CURRENT_SOURCE_DIR})

set (CORE_LIB
    pantheon-files-core
)

set (CFLAGS
    ${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER}
)

set (LIB_PATHS
    ${DEPS_LIBRARY_DIRS}
)

set (TEST_NAME
    gof-directory-async_tests
)

link_directories (${LIB_PATHS})
add_definitions (${CFLAGS} -O2)

vala_precompile (VALA_TEST_C ${TEST_NAME}
  GOFDirectoryAsyncTests.vala
  PACKAGES
    gtk+-3.0
    granite
    gee-0.8
    posix
    pantheon-files-core
    pantheon-files-core-C
  OPTIONS
    --vapidir=${CMAKE_SOURCE_DIR}/libcore/
    --vapidir=${CMAKE_BINARY_DIR}/libcore/
    --thread
    --target-glib=2.32 # Needed for new thread API
)

add_executable (${TEST_NAME}
    ${VALA_TEST_C}
)

target_link_libraries (${TEST_NAME} ${CORE_LIB} ${DEPS_LIBRARIES})
add_dependencies (${TEST_NAME} ${CORE_LIB})

add_test (core-${TEST_NAME} ${TEST_NAME})

