SUBDIRS = tests
noinst_LTLIBRARIES = libmarlincore.la

libmarlincore_la_VALAFLAGS = \
    -C \
    -H marlincore-vala.h \
    --pkg gtk+-3.0 \
    --pkg gio-2.0 \
    --pkg gee-1.0 \
    -g \
    --library marlincore \
    $(NULL)


libmarlincore_la_SOURCES = log.vala \
    gof-file.c nautilus-icon-info.c \
    eel-fcts.c                              \
    eel-i18n.c                              \
    eel-gtk-extensions.c                    \
    eel-gdk-extensions.c                    \
    eel-gdk-pixbuf-extensions.c             \
    eel-pango-extensions.c                  \
    eel-glib-extensions.c                   \
    eel-gio-extensions.c                    \
    eel-stock-dialogs.c                     \
    eel-debug.c                             \
    eel-string.c                            \
    eel-ui.c                                \
    gof-directory-async.c                   \
    marlin-exec.c                           \
    gof-monitor.c                           \
    nautilus-cell-renderer-text-ellipsized.c\
	marlin-plugin.c       					\
	marlin-plugin-manager.c                 \
    eel-vfs-extensions.c


libmarlincore_la_CFLAGS = \
    -I$(top_srcdir) \
    $(CORE_CFLAGS) \
    -DVERSION="\"$(VERSION)\"" 	                    \
    -DGETTEXT_PACKAGE=\""marlin"\" \
    -DUI_DIR=\""$(datadir)/marlin/ui/"\"            \
    -DPLUGIN_DIR=\""$(datadir)/marlin/plugins"\"    \
    $(NULL)
