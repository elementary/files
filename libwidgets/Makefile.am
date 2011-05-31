noinst_LTLIBRARIES = libmarlinwidgets.la
libmarlinwidgets_la_VALAFLAGS = \
    -C \
    -H marlinwidgets-vala.h \
    --pkg gtk+-3.0 \
    --pkg gio-2.0 \
    --pkg gee-1.0 \
    -g \
    --vapi marlin-widgets.vapi \
    --library marlinwidgets \
    --vapidir=$(top_srcdir)/libcore \
    --pkg marlin-core \
    $(NULL)


libmarlinwidgets_la_SOURCES = \
    ToolButtonWithMenu.vala     \
    AppMenu.vala                \
    LocationBar.vala            \
    ModeButton.vala             \
    CollapsablePaned.vala       \
    PopupLocationBar.vala       \
    $(NULL)

libmarlinwidgets_la_CFLAGS = \
    -I$(top_srcdir)/libcore/ \
    $(CORE_CFLAGS) \
    -DVERSION="\"$(VERSION)\"" 	                    \
    -DGETTEXT_PACKAGE=\""marlin"\" \
    -DUI_DIR=\""$(datadir)/marlin/ui/"\"            \
    -DPLUGIN_DIR=\""$(datadir)/marlin/plugins"\"    \
    $(NULL)

CLEANFILES = *.h *.c *.vapi

SUBDIRS = tests
