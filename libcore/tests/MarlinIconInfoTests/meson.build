TEST_NAME = 'MarlinIconInfoTests'
TEST_EXEC = executable (
    TEST_NAME,
    TEST_NAME + '.vala',

    dependencies : [CORE_LIB_DEPS, C_CORE_DEP, OTHER_DEPS],
    include_directories: [ROOT_INC, CORE_INC, SRC_INC],
    install: false,
    link_with: [CORE_LIB]
)

test (TEST_NAME, TEST_EXEC)

