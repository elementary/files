TEST_NAME = 'GOFDirectoryAsyncTests'
TEST_EXEC = executable (
    TEST_NAME,
    'GOFDirectoryAsyncTests.vala',

    dependencies : [CORE_LIB_DEPS, C_CORE_DEP, OTHER_DEPS],
    include_directories: [CORE_INC],
    install: false,
    link_with: [CORE_LIB]
)

test (TEST_NAME, TEST_EXEC)

