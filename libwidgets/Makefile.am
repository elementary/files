noinst_LTLIBRARIES = libmarlinwidgets.la
libmarlinwidgets_la_VALAFLAGS = \
    -C \
    -H marlinwidgets-vala.h \
    --pkg gtk+-3.0 \
    -g \
    --vapi marlin-widgets.vapi \
    --library marlinwidgets \
    $(NULL)


libmarlinwidgets_la_SOURCES = \
    ToolButtonWithMenu.vala     \
    AppMenu.vala                \
    ModeButton.vala             \
    CollapsablePaned.vala       \
    ImgEventBox.vala            \
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
