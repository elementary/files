NULL=

pixmapdir = $(datadir)/pixmaps/marlin
pixmap_DATA =\
	thumbnail_frame.png \
	home.png \
	arrow.png \
	arrow_hover.png \
        view-list-icons-symbolic.svg \
        view-list-details-symbolic.svg \
        view-list-compact-symbolic.svg \
        view-list-column-symbolic.svg \
	$(NULL)

icondir = $(datadir)/icons/hicolor/scalable/apps
icon_DATA = marlin.svg

gtk_update_icon_cache = gtk-update-icon-cache -f -t $(datadir)/icons/hicolor
install-data-hook: update-icon-cache
uninstall-hook: update-icon-cache
update-icon-cache:
	@-if test -z "$(DESTDIR)"; then \
		echo "Updating Gtk icon cache."; \
		$(gtk_update_icon_cache); \
	else \
		echo "*** Icon cache not updated.  After (un)install, run this:"; \
		echo "***   $(gtk_update_icon_cache)"; \
	fi


EXTRA_DIST = $(icon_DATA) \
             $(pixmap_DATA)
