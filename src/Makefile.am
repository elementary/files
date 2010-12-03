DATADIR = $(datadir)

bin_PROGRAMS = \
    marlin

marlin_CPPFLAGS = \
    -I$(top_srcdir) \
    $(CORE_CFLAGS) \
    -DPIXMAP_DIR=\""$(datadir)/pixmaps/marlin/"\"   \
    -DUI_DIR=\""$(datadir)/marlin/ui/"\"            \
    -DVERSION="\"$(VERSION)\"" 	                    \
    $(NULL)

marlin_VALAFLAGS = \
    -C \
    -H marlin-vala.h \
    --pkg gtk+-3.0 \
    --pkg gio-2.0 \
    --pkg gee-1.0 \
    $(NULL)

marlin_LDADD = \
    $(CORE_LIBS) \
    $(NULL)

marlin_VALASOURCES = \
    log.vala        	                    \
    View/Window.vala 	                    \
    View/Resources.vala	                    \
    View/DbusTags.vala	                    \
    View/ViewContainer.vala                 \
    View/ContextView.vala                   \
    View/Browser.vala                       \
    View/ViewMode.vala                      \
    View/Chrome/CompactToolMenuButton.vala  \
    View/Chrome/ToolButtonExtraOptions.vala \
    View/Chrome/ToolButtonWithMenu.vala     \
    View/Chrome/LocationBar.vala            \
    View/Chrome/ModeButton.vala             \
    View/Chrome/TopMenu.vala                \
    View/Chrome/ViewSwicher.vala            \
    View/Chrome/HPaned.vala                 \
	$(NULL)

marlin_SOURCES = \
    $(marlin_VALASOURCES:.vala=.c) 	        \
    View/xstuff.c                           \
    marlin-main.c                           \
    mysignal.c                              \
    eel-fcts.c                              \
    eel-i18n.c                              \
    eel-marshal.c                           \
    eel-glib-extensions.c                   \
    marlin-window-columns.c                 \
    gof-window-slot.c                       \
    nautilus-marshal-guts.c                 \
    gof-directory-async.c                   \
    nautilus-icon-info.c                    \
    gof-monitor.c                           \
    gof-file.c                              \
    fm-directory-view.c                     \
    exo-tree-view.c                         \
    fm-list-model.c                         \
    fm-list-view.c                          \
    fm-columns-view.c                       \
    nautilus-cell-renderer-text-ellipsized.c\
    marlin-toolbar-editor.c                 \
    $(NULL)

uidir = $(datadir)/marlin/ui
ui_DATA = \
	marlin-ui.xml \
	$(NULL)

BUILT_SOURCES = marlin.vala.stamp
EXTRA_DIST = \
	marlin.vala.stamp \
	$(marlin_VALASOURCES) \
	$(NULL)


marlin.vala.stamp: $(marlin_VALASOURCES)
	$(AM_V_GEN) $(VALAC) marlin.vapi $(marlin_VALAFLAGS) $^
	touch marlin.vala.stamp

CLEANFILES = \
	*.stamp \
	$(marlin_VALASOURCES:.vala=.c) \
	$(NULL)
