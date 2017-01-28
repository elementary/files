prefix=@PREFIX@
exec_prefix=@DOLLAR@{prefix}
libdir=@DOLLAR@{prefix}/@CMAKE_INSTALL_LIBDIR@
includedir=@DOLLAR@{prefix}/include/

Name: @PKGNAME@
Description: Pantheon Files core library
Version: 0.1
Libs: -L@DOLLAR@{libdir} -lpantheon-files-core
Cflags: -I@DOLLAR@{includedir}/${PKGNAME}
Requires: gtk+-3.0 glib-2.0 gio-2.0 gee-0.8 libcanberra
