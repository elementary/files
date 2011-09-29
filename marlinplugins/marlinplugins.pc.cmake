prefix=@PREFIX@
exec_prefix=@DOLLAR@{prefix}
libdir=@DOLLAR@{prefix}/lib
includedir=@DOLLAR@{prefix}/include/

Name: @PKGNAME@
Description: Marlin plugin library
Version: 0.1
Libs: -L@DOLLAR@{libdir} -lmarlinplugins
Cflags: -I@DOLLAR@{includedir}/${PKGNAME}
Requires: gtk+-3.0 glib-2.0 gio-2.0 gee-1.0 marlincore

