prefix=@PREFIX@
exec_prefix=@DOLLAR@{prefix}
libdir=@DOLLAR@{prefix}/@CMAKE_INSTALL_LIBDIR@
includedir=@DOLLAR@{prefix}/include/

Name: @PKGNAME@
Description: Pantheon Files widget library
Version: 0.1
Libs: -L@DOLLAR@{libdir} -lpantheon-files-widgets
Cflags: -I@DOLLAR@{includedir}/${PKGNAME}
Requires: gtk+-3.0 glib-2.0 gio-2.0 gee-0.8, zeitgeist-2.0, pantheon-files-core
