config_data = configuration_data()
config_data.set('install_prefix', get_option('prefix'))
config_data.set('bin_dir', get_option('bindir'))
config_data.set('exec_name', meson.project_name())

configure_file(
    input: meson.project_name() + '.service.in',
    output: meson.project_name() + '.service',
    configuration: config_data,
    install: true,
    install_dir: join_paths(get_option('datadir'), 'dbus-1', 'services')
)

configure_file(
    input: meson.project_name() + '-filemanager1.service.in',
    output: meson.project_name() + '.Filemanager1.service',
    configuration: config_data,
    install: true,
    install_dir: join_paths(get_option('datadir'), 'dbus-1', 'services')
)

configure_file(
    input: meson.project_name() + '-pkexec.in',
    output: meson.project_name() + '-pkexec',
    configuration: config_data,
    install: true,
    install_dir: get_option('bindir')
)

policy_in = configure_file(
    input: meson.project_name() + '.policy.in.in',
    output:  meson.project_name() + '.policy.in',
    configuration: config_data,
    install: false,
)

desktop_in = configure_file(
    input: meson.project_name() + '.desktop.in.in',
    output: meson.project_name() + '.desktop.in',
    configuration: config_data,
    install: false,
)

appdata_in = configure_file(
    input: meson.project_name() + '.appdata.xml.in.in',
    output: meson.project_name() + '.appdata.xml.in',
    configuration: config_data,
    install: false,
)

i18n.merge_file(
    'policy',
    input: policy_in,
    output: meson.project_name() + '.policy',
    po_dir: join_paths(meson.source_root(), 'po', 'extra'),
    data_dirs: join_paths(meson.source_root(), 'po'),
    install: true,
    install_dir: join_paths(get_option('datadir'), 'polkit-1', 'actions'),
)

i18n.merge_file(
    'desktop',
    input: desktop_in,
    output: meson.project_name() + '.desktop',
    install: true,
    install_dir: join_paths(get_option('datadir'), 'applications'),
    po_dir: join_paths(meson.source_root(), 'po', 'extra'),
    type: 'desktop'
)

i18n.merge_file(
    'appdata',
    input: appdata_in,
    output: meson.project_name() + '.appdata.xml',
    install: true,
    install_dir: join_paths(get_option('datadir'), 'metainfo'),
    po_dir: join_paths(meson.source_root(), 'po', 'extra'),
    type: 'xml'
)

install_data(
    join_paths(meson.current_source_dir(), 'icons', 'poof.png'),
    install_dir: join_paths(get_option('datadir'), 'pixmaps', meson.project_name())
)

install_data(
    join_paths(meson.current_source_dir(),'schemas', meson.project_name() + '.gschema.xml'),
    install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas')
)
