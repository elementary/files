prefix=@PREFIX@
exec_prefix=@DOLLAR@{prefix}
libdir=@DOLLAR@{prefix}/lib
includedir=@DOLLAR@{prefix}/include/

Name: @PKGNAME@
Description: Pantheon Files widgets library
Version: 0.1
Libs: -L@DOLLAR@{libdir} -lpantheon-files-widgets
Cflags: -I@DOLLAR@{includedir}/${PKGNAME}
Requires: gtk+-3.0 glib-2.0 gio-2.0 gee-0.8
