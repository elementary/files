# Test macros for Marlin, feel free to re-use them.

macro(add_test_executable EXE_NAME)
    add_custom_command(TARGET check
        COMMAND gtester ${CMAKE_CURRENT_BINARY_DIR}/${EXE_NAME})
endmacro()
