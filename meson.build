project(
    'io.elementary.files',
    'vala', 'c',
    version: '7.1.0',
    meson_version: '>= 0.59.0'
)

#
# Meson module imports
#
pkg = import('pkgconfig')
i18n = import('i18n')

#
# Define the global directories and variables
#
plugin_dir = join_paths(get_option('prefix'), get_option('libdir'), meson.project_name(), 'plugins')

add_project_arguments(
    ['-DGETTEXT_PACKAGE="' + meson.project_name() + '"',
    '-DHANDY_USE_UNSTABLE_API',
    '-w'],
    language:'c'
)

#
# Define Vala minimal version
#
vala_version_required = '0.50.0'
vala = meson.get_compiler('vala')
cc = meson.get_compiler('c')

if not vala.version().version_compare('>= @0@'.format(vala_version_required))
    error('Valac >= @0@ required!'.format(vala_version_required))
endif

#
# Project dependencies
#
min_glib_version = '2.64.6'

glib_dep = dependency('glib-2.0', version: '>='+min_glib_version)
gobject_dep = dependency('gobject-2.0', version: '>='+min_glib_version)
gio_dep = dependency('gio-2.0', version: '>='+min_glib_version)
gio_unix_dep = dependency('gio-unix-2.0', version: '>='+min_glib_version)
gmodule_dep = dependency('gmodule-2.0', version: '>='+min_glib_version)
gee_dep = dependency('gee-0.8')
gtk_dep = dependency('gtk+-3.0', version: '>=3.22.25')
granite_dep = dependency('granite', version: '>=6.1.0')
handy_dep = dependency('libhandy-1', version: '>=0.83.0')
portal_dep = dependency('libportal')
portal_gtk3_dep = dependency('libportal-gtk3')

common_deps = [
    glib_dep,
    gobject_dep,
    gio_dep,
    gio_unix_dep,
    gmodule_dep,
    gee_dep,
    gtk_dep,
    granite_dep
]

pango_dep = dependency('pango', version: '>=1.1.2')
sqlite3_dep = dependency('sqlite3')
libcanberra_dep = dependency('libcanberra', version: '>=0.30')

posix_dep = vala.find_library('posix')
linux_dep = vala.find_library('linux')
math_dep = cc.find_library('m')

zeitgeist_dep = dependency('zeitgeist-2.0', required: get_option('with-zeitgeist'))
if (zeitgeist_dep.found())
    add_project_arguments('--define=HAVE_ZEITGEIST', language: 'vala')
endif

add_project_arguments(
    ['--vapidir', join_paths(meson.current_source_dir(), 'vapi')],
    language: 'vala'
)


#Configuration file

config_data = configuration_data()
config_data.set('plugin_dir', plugin_dir)
config_data.set('version', meson.project_version())
config_data.set('testdata_dir', join_paths(meson.project_source_root(), 'data', 'tests'))
config_data.set('app_name', meson.project_name())
config_data.set('gettext_package', meson.project_name())
config_data.set('locale_dir', join_paths(get_option('prefix'), get_option('localedir')))

config_file = configure_file(
    input: 'config.h.in',
    output: 'config.h',
    configuration: config_data
)

project_config_dep = declare_dependency(
    sources: config_file,
    include_directories: include_directories('.')
)

gnome = import('gnome')
resources = gnome.compile_resources(
    'files-resources', 'data/files.gresource.xml',
    source_dir: 'data',
    c_name: 'files'
)

# Profiler linking code taken from https://github.com/RidgeRun/gst-inference/blob/master/meson.build
# with some amendments
# 'libprofiler' and 'libtcmalloc' are provided by installing (e.g.) 'google-perftools' and 'libgoogle-pertools-dev'
# Profiling is not active unless either (but best not both) the correct environment variables are set at runtime
# or the profiling is switched on/off in the code using the CPU_PROFILING and HEAP_PROFILING conditional compilation flags
# with the commands Profiler.start (<path-to-profile-output>) and Profiler.stop () and the corresponding HeapProfiler functions
# It is advisable not to run cpu profiling at the same time as heap profiling
# If meson options are changed then rebuild with 'cd .. && sudo rm -R ./build && build'
# See https://github.com/gperftools/gperftools/blob/master/docs/cpuprofile.adoc
# and https://github.com/gperftools/gperftools/blob/master/docs/heapprofile.adoc
if get_option('cpu-profiling-enabled')
  profiler_dep = dependency ('libprofiler')
  if(profiler_dep.found())
    message('CPU profiling enabled: Building with profiling support.')
    add_global_link_arguments ('-lprofiler', language: 'c')
    add_project_arguments ('--define=PROFILING', language: 'vala')
    common_deps += profiler_dep
  else
    message('MESON_FAIL: CPU profiling requested but libprofiler (gperftools) not found.')
  endif
endif
if get_option('heap-profiling-enabled')
  heap_profiler_dep = dependency ('libtcmalloc')
  if(heap_profiler_dep.found())
    message('Heap profiling enabled: Building with heap profiling support.')
    add_global_link_arguments ('-ltcmalloc', language: 'c')
    add_project_arguments ('--define=HEAP_PROFILING', language: 'vala')
    common_deps += heap_profiler_dep
  else
    message('MESON_FAIL: Heap profiling requested but libtcmalloc (gperftools) not found.')
  endif
endif

subdir('libcore')
subdir('src')
subdir('data')
subdir('pantheon-files-daemon')
subdir('plugins')
subdir('filechooser-portal')
subdir('po')

gnome.post_install(
    glib_compile_schemas: true,
    update_desktop_database: true
)
