set (PKGNAME pantheon-files-widgets)
set (WIDGET_LIB_VERSION 0.4.0)
# increase when you broke the API

set (WIDGET_SOVERSION 0)
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")
# You hear that? It's kittens being killed by the gods of cmake

include_directories (${CMAKE_SOURCE_DIR}/libcore/)
include_directories (${CMAKE_BINARY_DIR}/libcore/)

# Check for the deps

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED gtk+-3.0 gee-0.8 granite zeitgeist-2.0)

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

vala_precompile(VALA_C ${PKGNAME}
    Interfaces/LocatableInterface.vala
    Interfaces/NavigatableInterface.vala
    Chrome/BasicLocationBar.vala
    Chrome/BasicBreadcrumbsEntry.vala
    Chrome/BreadcrumbElement.vala
    Chrome/BreadcrumbIconList.vala
    Chrome/ButtonWithMenu.vala
    Chrome/ImgEventBox.vala
    View/SearchResults.vala
    Interfaces/SearchableInterface.vala
    Chrome/ViewSwitcher.vala
    Animations/Animations.vala
    Resources.vala
    Welcome.vala
PACKAGES
    gtk+-3.0
    granite
    gee-0.8
    posix
    pantheon-files-core
    pantheon-files-core-C
    zeitgeist-2.0
OPTIONS
    --vapidir=${CMAKE_SOURCE_DIR}/libcore
    --vapidir=${CMAKE_BINARY_DIR}/libcore
    --target-glib=2.32 # Needed for new thread API
    --thread
GENERATE_VAPI
    pantheon-files-widgets
GENERATE_HEADER
    pantheon-files-widgets
)

configure_file (${CMAKE_CURRENT_SOURCE_DIR}/${PKGNAME}.pc.cmake ${CMAKE_CURRENT_BINARY_DIR}/${PKGNAME}.pc)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/${PKGNAME}.pc DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/pantheon-files-widgets.h DESTINATION include/pantheon-files-widgets/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/pantheon-files-widgets.vapi DESTINATION share/vala/vapi)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/pantheon-files-widgets.deps DESTINATION share/vala/vapi)
install (FILES ${C_HEADER_FILES} DESTINATION include/pantheon-files-widgets/)

add_library (${PKGNAME} SHARED ${VALA_C})
add_dependencies (${PKGNAME} pantheon-files-core)

set_target_properties (${PKGNAME} PROPERTIES
    VERSION ${WIDGET_LIB_VERSION}
    SOVERSION ${WIDGET_SOVERSION})

install (TARGETS ${PKGNAME} DESTINATION ${CMAKE_INSTALL_LIBDIR})
target_link_libraries(${PKGNAME} pantheon-files-core ${DEPS_LIBRARIES})
