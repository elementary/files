find_package (PkgConfig)

pkg_check_modules (DEPS REQUIRED glib-2.0 gthread-2.0 gtk+-3.0>=3.10 granite gee-0.8)
add_definitions (${DEPS_CFLAGS})
link_directories (${DEPS_LIBRARY_DIRS})
set (MODULE_NAME "pantheon-filechooser-module")
set (MOULDES_LIBDIR "/usr/lib/x86_64-linux-gnu")

vala_precompile (VALA_C ${MODULE_NAME}
    Plugin.vala
    LocationBar.vala
    LocationBarAbstract.vala
    FileChooserDialog.vala
    BreadcrumbsElements.vala
PACKAGES
    gtk+-3.0
    granite
    posix
    gee-0.8 
OPTIONS
    --Xcc=-lm
    --thread   
)

link_libraries(${DEPS_LIBRARIES})
add_library (${MODULE_NAME} MODULE ${VALA_C})
target_link_libraries (${MODULE_NAME} ${DEPS_LIBRARIES} gthread-2.0) 

# Installation
install (TARGETS ${MODULE_NAME} DESTINATION "${MOULDES_LIBDIR}/gtk-3.0/modules/")
