set (PKGNAME marlinwidgets)
set (PKGNAME_ MARLINWIDGETS)
set (${PKGNAME_}_VERSION 0.1)
# increase when you broke the API

set (${PKGNAME_}_SOVERSION 0)
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")
# You hear that? It's kittens being killed by the gods of cmake

#install (FILES ${CMAKE_CURRENT_BINARY_DIR}/${PKGNAME}.pc DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/pkgconfig/)

# Check for the deps

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED gtk+-3.0 gee-1.0)

pkg_check_modules (GRANITE REQUIRED "granite")
add_definitions (${GRANITE_CFLAGS})
link_libraries (${GRANITE_LIBRARIES})
link_directories (${GRANITE_LIBRARY_DIRS})
# Link all

set(CFLAGS ${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER})
set(LIBS
    ${DEP_LIBRARIES}
)
add_definitions(${CFLAGS})

link_libraries(${LIBS})
set(LIB_PATHS
    ${DEPS_LIBRARY_DIRS}
)
link_directories(${LIB_PATHS})

include_directories (${CMAKE_CURRENT_BINARY_DIR})
include_directories (${CMAKE_BINARY_DIR})

vala_precompile(VALA_C ${PKGNAME}
    Animations.vala
    LocationBar.vala
    PoofWindow.vala
    BreadcrumbsElements.vala
    BreadcrumbsEntry.vala
PACKAGES
    gtk+-3.0
    granite
    gee-1.0
    posix
    marlincore
    marlincore-C
OPTIONS
    --thread
GENERATE_VAPI
    marlinwidgets
GENERATE_HEADER
    marlinwidgets
)
add_library (${PKGNAME} SHARED ${VALA_C})

set_target_properties (${PKGNAME} PROPERTIES
    VERSION ${MARLINWIDGETS_VERSION}
    SOVERSION ${MARLINWIDGETS_SOVERSION})

install (TARGETS ${PKGNAME} DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/)
target_link_libraries(${PKGNAME} ${DEPS_LIBRARIES})
add_subdirectory(tests)
