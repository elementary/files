# GLIB - Library of useful C routines

#GTESTER = gtester 			# for non-GLIB packages
GTESTER = /usr/bin/gtester		# for the GLIB package
GTESTER_REPORT = /usr/bin/gtester-report	# for the GLIB package

check_PROGRAMS = coremarlin_tests
coremarlin_tests_SOURCES = tests.c \
    marlincore-tests-gof.c

coremarlin_tests_LDADD = $(CORE_LIBS) $(top_srcdir)/libcore/libmarlincore.la $(NULL)
coremarlin_tests_CFLAGS = $(CORE_CFLAGS) -I.. -I$(top_srcdir)/libcore
TESTS_ENVIRONMENT= $(GTESTER)
TESTS = coremarlin_tests

