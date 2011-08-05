# Check http://elementaryos.org/docs/developer-guide/cmake for documentation

cmake_minimum_required (VERSION 2.6)
cmake_policy(VERSION 2.6)

project(Marlin)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/vala )
#configure_file (${CMAKE_SOURCE_DIR}/marlin/config.h.cmake ${CMAKE_BINARY_DIR}/marlin/config.h)

add_subdirectory (src)
add_subdirectory (data)
add_subdirectory (libcore)
add_subdirectory (libwidgets)
