lib_LTLIBRARIES = libmarlin-openterminal.la
#libmarlin_openterminal_la_LIBADD = $(top_srcdir)/libcore/libmarlincore.la
libmarlin_contractor_la_VALAFLAGS = \
    --pkg gtk+-3.0 \
    --pkg gio-2.0 \
    --pkg gee-1.0 \
    -g

libdir=$(prefix)/share/marlin/plugins
libmarlin_openterminal_la_SOURCES = plugin.vala $(top_srcdir)/libcore/marlin-core.vapi


libmarlin_openterminal_la_CFLAGS = \
    -I$(top_srcdir)/libcore \
    $(CORE_CFLAGS) \
    -DVERSION="\"$(VERSION)\"" 	                    \
    -DGETTEXT_PACKAGE=\""marlin"\" \
    -DUI_DIR=\""$(datadir)/marlin/ui/"\"            \
    $(NULL)

pkgdatadir=$(prefix)/share/marlin/plugins
nobase_dist_pkgdata_DATA = openterminal.plug
EXTRA_DIST = $(nobase_dist_pkgdata_DATA)

gsettings_SCHEMAS = org.gnome.marlin.plugins.gschema.xml

@GSETTINGS_RULES@
@INTLTOOL_XML_NOMERGE_RULE@
