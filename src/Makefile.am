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
    -g \
    $(NULL)

marlin_LDADD = \
    $(CORE_LIBS) \
    $(NULL)

BUILT_SOURCES = \
    marlin-marshal.c \
    marlin-marshal.h \
    marlin.vala.stamp \
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
    View/Chrome/AdvancedMenuToolButton.vala \
    View/Chrome/AppMenu.vala                \
    View/Chrome/ToolButtonWithMenu.vala     \
    View/Chrome/LocationBar.vala            \
    View/Chrome/ModeButton.vala             \
    View/Chrome/TopMenu.vala                \
    View/Chrome/ViewSwicher.vala            \
    View/Chrome/CollapsablePaned.vala       \
    View/Chrome/ColorWidget.vala            \
    $(NULL)

marlin_CSOURCES = \
    marlin-main.c                           \
    marlin-application.c                    \
    mysignal.c                              \
    eel-fcts.c                              \
    eel-i18n.c                              \
    eel-gtk-extensions.c                    \
    eel-gdk-extensions.c                    \
    eel-gdk-pixbuf-extensions.c             \
    eel-glib-extensions.c                   \
    eel-gio-extensions.c                    \
    eel-stock-dialogs.c                     \
    eel-debug.c                             \
    eel-string.c                            \
    eel-ui.c                                \
    eel-vfs-extensions.c                    \
    gossip-cell-renderer-expander.c         \
    marlin-trash-monitor.c                  \
    marlin-bookmark.c                       \
    marlin-bookmark-list.c                  \
    marlin-exec.c                           \
    marlin-dnd.c                            \
    marlin-clipboard-manager.c              \
    marlin-file-utilities.c                 \
    marlin-file-operations.c                \
    marlin-file-conflict-dialog.c           \
    marlin-progress-info.c                  \
    marlin-progress-info-manager.c          \
    marlin-progress-ui-handler.c            \
    marlin-progress-info-widget.c           \
    marlin-places-sidebar.c                 \
    marlin-window-columns.c                 \
    gof-window-slot.c                       \
    gof-directory-async.c                   \
    nautilus-icon-info.c                    \
    gof-monitor.c                           \
    gof-file.c                              \
    fm-directory-view.c                     \
    exo-tree-view.c                         \
    fm-list-model.c                         \
    fm-icon-view.c                          \
    fm-list-view.c                          \
    fm-columns-view.c                       \
    nautilus-cell-renderer-text-ellipsized.c\
    marlin-toolbar-editor.c                 \
    $(NULL)

marlin_SOURCES = \
    $(marlin_VALASOURCES:.vala=.c)          \
    $(marlin_CSOURCES)                      \
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


marlin.vala.stamp: $(marlin_VALASOURCES)
	$(AM_V_GEN) $(VALAC) marlin.vapi $(marlin_VALAFLAGS) $^
	touch marlin.vala.stamp

CLEANFILES = \
    marlin-marshall.list \
    $(BUILT_SOURCES) \
	$(marlin_VALASOURCES:.vala=.c) \
	$(NULL)

