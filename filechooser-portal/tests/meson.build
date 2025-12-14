# project(
#     'io.elementary.Files.PortalTester',
#     'c', 'vala'
# )

vala_version_required = '0.50.0'
vala = meson.get_compiler('vala')
posix_dep = vala.find_library('posix')

executable(
    'io.elementary.files.portal-tester',
    # 'io.elementary.Files.PortalTester',
    'PortalTester.vala',
    dependencies: [
        pantheon_files_core_dep,
        # dependency('gdk-x11-3.0'),
        # dependency('gdk-wayland-3.0'),
        # handy_dep,
        # project_config_dep
        # dependency('gtk+-3.0', version: '>=3.20'),
        # posix_dep,
    ],
    install: true
)
