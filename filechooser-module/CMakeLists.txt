find_package (PkgConfig)
include(GNUInstallDirs)

include_directories (${CMAKE_SOURCE_DIR}/libcore/)
include_directories (${CMAKE_BINARY_DIR}/libcore/)
include_directories (${CMAKE_BINARY_DIR}/libwidgets/)

pkg_check_modules (DEPS REQUIRED glib-2.0 gthread-2.0 gtk+-3.0>=3.10 granite gee-0.8)

pkg_check_modules (GRANITE REQUIRED "granite")
add_definitions (${GRANITE_CFLAGS})
link_libraries (${GRANITE_LIBRARIES})
link_directories (${GRANITE_LIBRARY_DIRS})

add_definitions (${DEPS_CFLAGS})
link_directories (${DEPS_LIBRARY_DIRS})
set (MODULE_NAME "pantheon-filechooser-module")
set (MODULE_LIBDIR "${CMAKE_INSTALL_LIBDIR}/gtk-3.0/modules/")

vala_precompile (VALA_C ${MODULE_NAME}
    FileChooserDialog.vala
    Plugin.vala
PACKAGES
    gtk+-3.0
    granite
    posix
    gee-0.8
    pantheon-files-widgets
    pantheon-files-core
    pantheon-files-core-C
OPTIONS
    --vapidir=${CMAKE_SOURCE_DIR}/libcore
    --vapidir=${CMAKE_BINARY_DIR}/libcore
    --vapidir=${CMAKE_BINARY_DIR}/libwidgets
)

link_libraries(${DEPS_LIBRARIES})
add_library (${MODULE_NAME} MODULE ${VALA_C})
target_link_libraries (${MODULE_NAME} ${DEPS_LIBRARIES} gthread-2.0)

# Installation
install (TARGETS ${MODULE_NAME} DESTINATION "${MODULE_LIBDIR}")

