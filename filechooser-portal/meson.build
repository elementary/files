libexec_dir = join_paths(get_option('prefix'), get_option ('libexecdir'))

executable(
    'io.elementary.files.xdg-desktop-portal',
    'ExternalWindow.vala',
    'FileChooserChoice.vala',
    'FileChooserDialog.vala',
    'Main.vala',

    dependencies : [
        pantheon_files_core_dep,
        dependency('gdk-x11-3.0'),
        dependency('gdk-wayland-3.0'),
        handy_dep,
        project_config_dep
    ],
    install: true,
    install_dir: libexec_dir,
)

conf_data = configuration_data()
conf_data.set('libexecdir', libexec_dir)

systemd_systemduserunitdir = get_option('systemduserunitdir')
if systemd_systemduserunitdir != 'no'

  if systemd_systemduserunitdir == ''
    systemd_dep = dependency('systemd', version: '>= 206', required: false)
    assert(systemd_dep.found(), 'systemd required but not found, please provide a valid systemd user unit dir or disable it')
    systemd_systemduserunitdir = systemd_dep.get_variable('systemduserunitdir', pkgconfig_define: ['prefix', get_option('prefix')])
  endif

  configure_file(
      input: 'io.elementary.files.xdg-desktop-portal.service.in',
      output: '@BASENAME@',
      configuration: conf_data,
      install: true,
      install_dir: systemd_systemduserunitdir
  )
endif

install_data(
    'io.elementary.files.portal',
    install_dir: join_paths(get_option('prefix'), get_option('datadir'), 'xdg-desktop-portal', 'portals')
)

configure_file(
    input: 'org.freedesktop.impl.portal.desktop.elementary.files.service.in',
    output: '@BASENAME@',
    configuration: conf_data,
    install: true,
    install_dir: join_paths(get_option('prefix'), get_option('datadir'), 'dbus-1', 'services')
)

flatpak_builder = find_program('flatpak-builder', required: false)
if (flatpak_builder.found())
    custom_target(
        'portal-tester',
        command: [
            flatpak_builder,
            '--user',
            '--install',
            meson.current_build_dir() / 'tests' / 'builddir',
            meson.current_source_dir() / 'tests' / 'io.elementary.Files.PortalTester.yml',
            '--force-clean'
        ],
        capture: true,
        output: 'io.elementary.Files.PortalTester'
    )
endif
