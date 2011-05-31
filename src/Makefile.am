DATADIR = $(datadir)

bin_PROGRAMS = \
    marlin

marlin_CFLAGS = \
    -I$(top_srcdir)/libcore/ \
    -I$(top_srcdir)/libwidgets/ \
    $(CORE_CFLAGS) \
    -DPIXMAP_DIR=\""$(datadir)/pixmaps/marlin/"\"   \
    -DUI_DIR=\""$(datadir)/marlin/ui/"\"            \
    -DVERSION="\"$(VERSION)\"" 	                    \
    -DGETTEXT_PACKAGE=\""marlin"\" \
    $(NULL)


marlin_VALAFLAGS = \
    -C \
    -H marlin-vala.h \
    --pkg gtk+-3.0 \
    --pkg gio-2.0 \
    --pkg gee-1.0 \
    --vapidir=$(top_srcdir)/libcore/ \
    --vapidir=$(top_srcdir)/libwidgets/ \
    --pkg marlin-widgets \
    --pkg marlin-core \
    --vapidir=$(top_srcdir)/src/ \
    --pkg marlin \
    -g \
    $(NULL)

marlin_VALASOURCES = \
    Logger.vala                             \
    View/SettingsDialog.vala                \
    View/DirectoryNotFound.vala             \
    View/Window.vala 	                    \
    View/Resources.vala	                    \
    View/DbusTags.vala	                    \
    View/ViewContainer.vala                 \
    View/ContextView.vala                   \
    View/Browser.vala                       \
    View/ViewMode.vala                      \
    View/Animations.vala                    \
    View/Chrome/TopMenu.vala                \
    View/Chrome/ViewSwicher.vala            \
    View/Chrome/ColorWidget.vala


marlin.vala.stamp: $(marlin_VALASOURCES)
	$(AM_V_GEN) $(VALAC) $(marlin_VALAFLAGS) $^
	touch marlin.vala.stamp

marlin_LDADD = \
    $(top_srcdir)/libcore/libmarlincore.la \
    $(top_srcdir)/libwidgets/libmarlinwidgets.la \
    $(CORE_LIBS) \
    $(NULL)

BUILT_SOURCES = \
    marlin.vala.stamp \
    marlin-marshal.c \
    marlin-marshal.h \
    $(NULL)

marlin_CSOURCES = \
    eel-editable-label.c                    \
    marlin-application.c                    \
    mysignal.c                              \
    gossip-cell-renderer-expander.c         \
    marlin-enum-types.c                     \
    marlin-trash-monitor.c                  \
    marlin-bookmark.c                       \
    marlin-bookmark-list.c                  \
    marlin-dnd.c                            \
    marlin-clipboard-manager.c              \
    marlin-places-sidebar.c                 \
    marlin-window-columns.c                 \
    gof-window-slot.c                       \
    marlin-thumbnailer.c                    \
    marlin-icon-renderer.c                  \
    marlin-text-renderer.c                  \
    fm-directory-view.c                     \
    exo-icon-view.c                         \
    exo-tree-view.c                         \
    fm-list-model.c                         \
    fm-icon-view.c                          \
    fm-list-view.c                          \
    fm-columns-view.c                       \
    marlin-toolbar-editor.c                 \
    $(NULL)

marlin_SOURCES = \
    $(marlin_CSOURCES)                      \
	marlin-main.c                           \
    $(marlin_VALASOURCES:.vala=.c)          \
    $(NULL)

nodist_marlin_SOURCES = \
    $(BUILT_SOURCES) \
	$(NULL)

marlin-marshal.list: $(marlin_CSOURCES) Makefile.am
	$(AM_V_GEN)( cd $(srcdir) && \
	sed -n -e 's/.*marlin_marshal_\([[:upper:][:digit:]]*__[[:upper:][:digit:]_]*\).*/\1/p' \
	$(marlin_CSOURCES) ) \
	| sed -e 's/__/:/' -e 'y/_/,/' | sort -u > $@.tmp
	@if cmp -s $@.tmp $@; then \
		rm $@.tmp; \
	else \
		mv $@.tmp $@; \
	fi

%-marshal.c: %-marshal.list Makefile
	$(AM_V_GEN)echo "#include \"marlin-marshal.h\"" > $@ && \
	$(GLIB_GENMARSHAL) --body --prefix=$(subst -,_,$*)_marshal $< >> $*-marshal.c

%-marshal.h: %-marshal.list Makefile
	$(AM_V_GEN)$(GLIB_GENMARSHAL) --header --prefix=$(subst -,_,$*)_marshal $< > $*-marshal.h

uidir = $(datadir)/marlin/ui
ui_DATA = \
	marlin-ui.xml \
    fm-directory-view-ui.xml \
	$(NULL)

EXTRA_DIST = \
    marlin-marshall.list \
	marlin.vala.stamp \
	$(marlin_VALASOURCES) \
	$(NULL)

CLEANFILES = \
    marlin-marshall.list \
    $(BUILT_SOURCES) \
	$(marlin_VALASOURCES:.vala=.c) \
	$(NULL)


