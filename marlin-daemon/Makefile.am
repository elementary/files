
bin_PROGRAMS = \
    marlin-daemon

marlin_daemon_CPPFLAGS = \
    $(DAEMON_CFLAGS) \
    $(NULL)

marlin_daemon_VALAFLAGS = \
    -C \
    --pkg glib-2.0 \
    --pkg gio-2.0 \
    --pkg sqlite3 \
    $(NULL)

marlin_daemon_LDADD = \
    $(DAEMON_LIBS) \
    $(NULL)

marlin_daemon_VALASOURCES = \
    marlind-tagging.vala \
    $(NULL)

marlin_daemon_SOURCES = \
    $(marlin_daemon_VALASOURCES:.vala=.c) \
    $(NULL)

BUILT_SOURCES = marlin_daemon.vala.stamp
EXTRA_DIST = \
	marlin_daemon.vala.stamp \
	$(NULL)


marlin_daemon.vala.stamp: $(marlin_daemon_VALASOURCES)
	$(AM_V_GEN) $(VALAC) $(marlin_daemon_VALAFLAGS) $^
	touch $@

CLEANFILES = \
	*.stamp \
        $(marlin_daemon_VALASOURCES:.vala=.c) \
	$(NULL)
