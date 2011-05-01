SUBDIRS =               \
        src             \
        marlin-daemon   \
        data            \
        icons           \
        po              \
        $(NULL)

DISTCHECK_CONFIGURE_FLAGS = --disable-update-mimedb

ACLOCAL_AMFLAGS = -I m4

EXTRA_DIST = \
             org.gnome.marlin.gschema.xml.in

gsettings_SCHEMAS = org.gnome.marlin.gschema.xml
@GSETTINGS_RULES@
@INTLTOOL_XML_NOMERGE_RULE@
