dbus_servicesdir = $(DBUSSERVICEDIR)
service_in_files =  marlin.service.in
dbus_services_DATA = $(service_in_files:.service.in=.service)

%.service: %.service.in
	sed -e "s|\@bindir\@|$(bindir)|" $< > $@

desktopdir       = $(datadir)/applications
desktop_DATA     = $(desktop_in_files:.desktop.in=.desktop)
desktop_in_files = marlin.desktop.in
@INTLTOOL_DESKTOP_RULE@

EXTRA_DIST = \
  $(service_in_files) \
  $(desktop_in_files) \
  $(NULL)

CLEANFILES = \
  marlin.service \
  $(desktop_DATA) \
  $(NULL)
