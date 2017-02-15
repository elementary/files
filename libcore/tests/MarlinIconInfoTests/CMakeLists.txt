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
    marlin-icon-info_tests
)

link_directories (${LIB_PATHS})
add_definitions (${CFLAGS} -O2)


add_executable (${TEST_NAME}
    tests.c
    marlincore-tests-icon-info.c
)

target_link_libraries (${TEST_NAME} ${CORE_LIB} ${DEPS_LIBRARIES})
add_dependencies (${TEST_NAME} ${CORE_LIB})

add_test (core-${TEST_NAME} ${TEST_NAME})
