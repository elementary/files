set(CMAKE_INCLUDE_CURRENT_DIR ON)
cmake_policy(VERSION 2.6)
cmake_minimum_required(VERSION 2.8)
find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED gtk+-3.0)
link_libraries(${DEPS_CFLAGS})

link_directories(${DEPS_LIBRARY_DIRS})

add_definitions(${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER})


add_library(hw SHARED hw.c)
target_link_libraries(hw ${DEPS_LIBRARIES})
