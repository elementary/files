# GLIB - Library of useful C routines

#GTESTER = gtester 			# for non-GLIB packages
GTESTER = /usr/bin/gtester		# for the GLIB package
GTESTER_REPORT = /usr/bin/gtester-report	# for the GLIB package

check_PROGRAMS = marlinwidgets_tests

marlinwidgets_tests_VALAFLAGS = \
    --pkg gtk+-3.0 \
    --pkg gio-2.0 \
    --pkg gee-1.0 \
    -g \
    --vapidir $(top_srcdir)/libcore \
    --vapidir $(top_srcdir)/libwidgets \
    --vapidir $(top_srcdir)/src \
    --pkg marlin-core \
    --pkg marlin-widgets \
    $(NULL)

marlinwidgets_tests_SOURCES = \
    ../LocationBar.vala \
    ../PopupLocationBar.vala \
    ../Resources.vala \
    tests-pathbar.vala \
    $(NULL)

marlinwidgets_tests_LDADD = \
    $(top_srcdir)/libcore/libmarlincore.la \
    $(top_srcdir)/libwidgets/libmarlinwidgets.la \
    $(CORE_LIBS) \
    $(NULL)

marlinwidgets_tests_CFLAGS = $(CORE_CFLAGS) -I.. -I$(top_srcdir)/libcore -I$(top_srcdir)/src -I$(top_srcdir)/libwidgets -DGETTEXT_PACKAGE="\"marlin\""

TESTS_ENVIRONMENT= $(GTESTER)

TESTS = marlinwidgets_tests

