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
    --pkg marlin-core \
    --pkg marlincore \
    --pkg marlin-widgets \
    $(NULL)

marlinwidgets_tests_SOURCES = \
    tests-pathbar.vala \
    $(NULL)

marlinwidgets_tests_LDADD = $(CORE_LIBS) $(top_srcdir)/libcore/libmarlincore.la $(top_srcdir)/libwidgets/libmarlinwidgets.la

marlinwidgets_tests_CFLAGS = $(CORE_CFLAGS) -I.. -I$(top_srcdir)/libcore

TESTS_ENVIRONMENT= $(GTESTER)

TESTS = marlinwidgets_tests

