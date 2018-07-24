i18n.merge_file (
    'desktop',
    input: meson.project_name () + '.desktop.in',
    output: meson.project_name () + '.desktop',
    install: true,
    install_dir: join_paths (get_option ('datadir'), 'applications'),
    po_dir: join_paths (meson.source_root (), 'po', 'extra'),
    type: 'desktop'
)

i18n.merge_file (
    'appdata',
    input: meson.project_name () + '.appdata.xml.in',
    output: meson.project_name () + '.appdata.xml',
    install: true,
    install_dir: join_paths (get_option ('datadir'), 'metainfo'),
    po_dir: join_paths (meson.source_root (), 'po', 'extra'),
    type: 'xml'
)

config_data = configuration_data()
config_data.set ('install_prefix', get_option ('prefix'))
config_data.set ('bin_dir', get_option ('bindir'))

configure_file (
    input: meson.project_name () + '.service.meson.in',
    output: meson.project_name () + '.service',
    configuration: config_data,
    install: true,
    install_dir: join_paths(get_option('datadir'), 'dbus-1', 'services')
)

configure_file (
    input: meson.project_name () + '-filemanager1.service.meson.in',
    output: meson.project_name () + '.Filemanager1.service',
    configuration: config_data,
    install: true,
    install_dir: join_paths(get_option('datadir'), 'dbus-1', 'services')
)

configure_file (
    input: meson.project_name () + '-pkexec.meson.in',
    output: meson.project_name () + '-pkexec',
    configuration: config_data,
    install: true,
    install_dir: get_option('bindir')
)

i18n.merge_file (
    'policy',
    input: meson.project_name () + '.policy.xml.meson.in.in',
    output: meson.project_name () + '.policy',
    configuration: config_data,
    install: true,
    install_dir: join_paths(get_option('datadir'), 'polkit-1', 'actions'),
    po_dir: join_paths (meson.source_root (), 'po', 'extra'),
    type: 'xml'
)

install_data (
    join_paths(meson.current_source_dir (), 'icons', 'poof.png'),
    install_dir: join_paths(get_option('datadir'), 'pixmaps', meson.project_name ())
)

install_data (
    join_paths (meson.current_source_dir (),'schemas', meson.project_name() + '.gschema.xml'),
    install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas')
)

test (
    'Validate desktop file',
    find_program ('desktop-file-validate'),
    args: join_paths (meson.current_build_dir (),  meson.project_name () + '.desktop')
)

test (
    'Validate appdata file',
    find_program ('appstreamcli'),
    args: ['validate', join_paths (meson.current_build_dir (), meson.project_name () + '.appdata.xml')]
)


