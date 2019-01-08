find_package (PkgConfig)
include(GNUInstallDirs)

include_directories (${CMAKE_SOURCE_DIR}/libcore/)
include_directories (${CMAKE_BINARY_DIR}/libcore/)
include_directories (${CMAKE_BINARY_DIR}/libwidgets/)

if (MODULE_ONLY)
    include_directories (${CMAKE_INSTALL_PREFIX}/include/pantheon-files-widgets/)
    include_directories (${CMAKE_INSTALL_PREFIX}/include/pantheon-files-core/)
endif ()

pkg_check_modules (DEPS REQUIRED glib-2.0 gthread-2.0 gtk+-3.0>=3.10 granite gee-0.8)

if (MODULE_ONLY)
    pkg_check_modules (DEPS REQUIRED pantheon-files-widgets pantheon-files-core)
endif ()

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
    linux
    pantheon-files-widgets
    pantheon-files-core
    pantheon-files-core-C
    gof-file
OPTIONS
    --vapidir=${CMAKE_SOURCE_DIR}/libcore
    --vapidir=${CMAKE_BINARY_DIR}/libcore
    --vapidir=${CMAKE_BINARY_DIR}/libwidgets
)

link_libraries(${DEPS_LIBRARIES})
add_library (${MODULE_NAME} MODULE ${VALA_C})
target_link_libraries (${MODULE_NAME} ${DEPS_LIBRARIES} pantheon-files-widgets pantheon-files-core)

# Installation
install (TARGETS ${MODULE_NAME} DESTINATION "${MODULE_LIBDIR}")

