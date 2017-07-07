# Check http://elementaryos.org/docs/developer-guide/cmake for documentation

cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.8)
project (pantheon-files C)
enable_testing ()

include (GNUInstallDirs)
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)
set (GETTEXT_PACKAGE ${CMAKE_PROJECT_NAME})
set (PIXMAP_DIR "${CMAKE_INSTALL_PREFIX}/share/pixmaps/${CMAKE_PROJECT_NAME}/")
set (GNOMELOCALEDIR "${CMAKE_INSTALL_PREFIX}/share/locale/")
set (PLUGIN_DIR "${CMAKE_INSTALL_FULL_LIBDIR}/${CMAKE_PROJECT_NAME}/plugins/")
set (UI_DIR "${CMAKE_INSTALL_PREFIX}/share/${CMAKE_PROJECT_NAME}/ui/")
set (TESTDATA_DIR "${CMAKE_SOURCE_DIR}/data/tests")
set (PACKAGE_VERSION 0.3.5)
set (VERSION 0.3.5)
configure_file (${CMAKE_SOURCE_DIR}/config.h.cmake ${CMAKE_BINARY_DIR}/config.h)

add_definitions ("-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\"")
add_definitions ("-w")

option (LIB_ONLY "Build libcore and libwidgets only" FALSE)
option (MODULE_ONLY "Build only custom gtk filechooser dialog module" FALSE)

find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.34.0" MINIMUM)
include (ValaPrecompile)

find_package (PkgConfig)

OPTION (WITH_UNITY "Add Unity launcher support" ON)
pkg_check_modules (UNITY unity>=4.0.0)

if (WITH_UNITY AND UNITY_FOUND)
    pkg_check_modules (DEPS REQUIRED
        granite>=0.3.0
        glib-2.0>=2.29.0
        gthread-2.0
        gio-2.0
        gio-unix-2.0
        pango>=1.1.2
        gtk+-3.0>=3.14
        gmodule-2.0
        gail-3.0
        gee-0.8
        sqlite3
        dbus-glib-1
        libcanberra>=0.30
        zeitgeist-2.0
        plank)
else (WITH_UNITY AND UNITY_FOUND)
    pkg_check_modules (DEPS REQUIRED
        granite>=0.3.0
        glib-2.0>=2.29.0
        gthread-2.0
        gio-2.0
        gio-unix-2.0
        pango>=1.1.2
        gtk+-3.0>=3.14
        gmodule-2.0
        gail-3.0
        gee-0.8
        sqlite3
        dbus-glib-1
        libcanberra>=0.30
        zeitgeist-2.0)
endif (WITH_UNITY AND UNITY_FOUND)

if (MODULE_ONLY)
    add_subdirectory (filechooser-module)
ELSEIF (LIB_ONLY)
    add_subdirectory (libcore)
    add_subdirectory (libwidgets)
ELSE ()
    add_subdirectory (src)
    add_subdirectory (data)
    add_subdirectory (pantheon-files-daemon)
    add_subdirectory (libcore)
    add_subdirectory (libwidgets)
    add_subdirectory (plugins)
    add_subdirectory (filechooser-module)
    add_subdirectory (po)
ENDIF ()
