prefix=@PREFIX@
exec_prefix=@DOLLAR@{prefix}
libdir=@DOLLAR@{prefix}/lib
includedir=@DOLLAR@{prefix}/include

Name: @PKGNAME@
Description: Marlin core library
Version: 0.1
Libs: -L@DOLLAR@{libdir} -lmarlincore
Cflags: -I@DOLLAR@{includedir}/${PKGNAME}
Requires: gtk+-3.0 gio- gee-1.0

