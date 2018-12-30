project('io.elementary.files', 'vala', 'c', version: '4.1.1', meson_version: '>= 0.42.0')

#
# Meson module imports
#
pkg = import('pkgconfig')
i18n = import('i18n')

#
# Define the global directories and variables
#
plugin_dir = join_paths(get_option('prefix'), get_option('libdir'), meson.project_name(), 'plugins')
ui_dir = join_paths(get_option('prefix'), get_option('datadir'), meson.project_name(), 'ui')
terminal_name = 'pantheon-terminal'

add_project_arguments(
    ['-DGETTEXT_PACKAGE="' + meson.project_name() + '"',
    '-w'],
    language:'c'
)

#
# Define Vala minimal version
#
vala_version_required = '0.34.0'
vala = meson.get_compiler('vala')
cc = meson.get_compiler('c')

if not vala.version().version_compare('>= @0@'.format(vala_version_required))
    error('Valac >= @0@ required!'.format(vala_version_required))
endif

#
# Project dependencies
#
min_glib_version = '2.40'

glib_dep = dependency('glib-2.0', version: '>='+min_glib_version)
gobject_dep = dependency('gobject-2.0', version: '>='+min_glib_version)
gio_dep = dependency('gio-2.0', version: '>='+min_glib_version)
gio_unix_dep = dependency('gio-unix-2.0', version: '>='+min_glib_version)
gmodule_dep = dependency('gmodule-2.0', version: '>='+min_glib_version)
gee_dep = dependency('gee-0.8')
gtk_dep = dependency('gtk+-3.0', version: '>=3.22')
granite_dep = dependency('granite', version: '>=5.2.0')

common_deps = [
    glib_dep,
    gobject_dep,
    gio_dep,
    gio_unix_dep,
    gmodule_dep,
    gee_dep,
    gtk_dep,
    granite_dep,
]

pango_dep = dependency('pango', version: '>=1.1.2')
sqlite3_dep = dependency('sqlite3')
libcanberra_dep = dependency('libcanberra', version: '>=0.30')
zeitgeist_dep = dependency('zeitgeist-2.0')

notify_dep = dependency('libnotify', version: '>=0.7.2')

posix_dep = vala.find_library('posix')
linux_dep = vala.find_library('linux')
math_dep = cc.find_library('m')

unity_dep = []
plank_dep = []
if get_option('with-unity')
    unity_dep = dependency('unity', version: '>=4.0.0')
    add_project_arguments('--define=HAVE_UNITY', language: 'vala')

    plank_dep = dependency('plank')
    if plank_dep.version().version_compare('>=0.10.9')
        add_project_arguments('--define=HAVE_PLANK_0_11', language: 'vala')
    endif
endif

#
# Configuration file
#
config_data = configuration_data()
config_data.set('plugin_dir', plugin_dir)
config_data.set('version', meson.project_version())
config_data.set('ui_dir', ui_dir)
config_data.set('testdata_dir', join_paths(meson.source_root(), 'data', 'tests'))
config_data.set('app_name', meson.project_name())
config_data.set('terminal_name', terminal_name)

config_file = configure_file(
    input: 'config.h.in',
    output: 'config.h',
    configuration: config_data
)

project_config_dep = declare_dependency(
    sources: config_file,
    include_directories: include_directories('.')
)

subdir('libcore')
subdir('libwidgets')
subdir('src')
subdir('data')
subdir('pantheon-files-daemon')
subdir('plugins')
subdir('filechooser-module')
meson.add_install_script('meson/post_install.py')

subdir('po')
