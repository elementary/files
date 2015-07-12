find_package (PkgConfig)
include(GNUInstallDirs)

pkg_check_modules (DEPS REQUIRED glib-2.0 gthread-2.0 gtk+-3.0>=3.10 granite gee-0.8)
add_definitions (${DEPS_CFLAGS})
link_directories (${DEPS_LIBRARY_DIRS})
set (MODULE_NAME "pantheon-filechooser-module")
set (MODULE_LIBDIR "${CMAKE_INSTALL_LIBDIR}/gtk-3.0/modules/")

vala_precompile (VALA_C ${MODULE_NAME}
    ${CMAKE_SOURCE_DIR}/libwidgets/LocationBar.vala
    ${CMAKE_SOURCE_DIR}/libwidgets/BreadcrumbsElements.vala
    LocationBarChooser.vala
    FileChooserDialog.vala
    Plugin.vala
PACKAGES
    gtk+-3.0
    granite
    posix
    gee-0.8
OPTIONS
    --thread
)

link_libraries(${DEPS_LIBRARIES})
add_library (${MODULE_NAME} MODULE ${VALA_C})
target_link_libraries (${MODULE_NAME} ${DEPS_LIBRARIES} gthread-2.0)

# Installation
install (TARGETS ${MODULE_NAME} DESTINATION "${MODULE_LIBDIR}")
