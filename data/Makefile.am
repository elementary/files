dbus_servicesdir = $(DBUSSERVICEDIR)
service_in_files =  marlin.service.in
dbus_services_DATA = $(service_in_files:.service.in=.service)

%.service: %.service.in
	sed -e "s|\@bindir\@|$(bindir)|" $< > $@

EXTRA_DIST = \
  $(service_in_files)

CLEANFILES = \
  marlin.service
