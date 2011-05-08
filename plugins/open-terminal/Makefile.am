lib_LTLIBRARIES = libmarlin-openterminal.la
libmarlin_openterminal_la_LIBADD = $(top_srcdir)/libcore/libmarlincore.la
libdir=$(prefix)/share/marlin/plugins
libmarlin_openterminal_la_SOURCES = plugin.c


libmarlin_openterminal_la_CFLAGS = \
    -I$(top_srcdir) \
    $(CORE_CFLAGS) \
    -DVERSION="\"$(VERSION)\"" 	                    \
    -DGETTEXT_PACKAGE=\""marlin"\" \
    -DUI_DIR=\""$(datadir)/marlin/ui/"\"            \
    $(NULL)

pkgdatadir=$(prefix)/share/marlin/plugins
nobase_dist_pkgdata_DATA = openterminal.plug
EXTRA_DIST = $(nobase_dist_pkgdata_DATA)
