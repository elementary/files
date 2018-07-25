project ('io.elementary.files', 'vala', 'c', meson_version: '>= 0.42.0')

PROJECT_VER = '0.3.6'
CORE_LIB_VER = '0.3.6'
WIDGET_LIB_VER = '0.3.6'
DOMAIN = 'io.elementary.'
SHORTNAME = 'files'
OLD_NAME = 'pantheon-files'
CORE_LIB_NAME = OLD_NAME + '-core'
C_LIB_NAME = CORE_LIB_NAME +'-C'
WIDGET_LIB_NAME = OLD_NAME + '-widgets'
SCHEMA_PATH = '/io/elementary/' + SHORTNAME + '/'
PLUGIN_DIR = join_paths(get_option('libdir'), meson.project_name (), 'plugins', 'core')
MODULE_LIBDIR = join_paths(get_option('libdir'), 'gtk-3.0', 'modules')
TERMINAL_NAME = 'pantheon-terminal'

vala_version_required = '0.34.0'
i18n = import ('i18n')
vala = meson.get_compiler('vala')
cc = meson.get_compiler('c')

if not vala.version().version_compare('>= @0@'.format(vala_version_required))
    error('Valac >= @0@ required!'.format(vala_version_required))
endif

UNITY = dependency ('unity', version: '>=4.0.0', required: false)
WITH_UNITY = get_option ('WITH_UNITY')
USE_UNITY = WITH_UNITY and UNITY.found ()

if USE_UNITY
    add_project_arguments (
        '--define=HAVE_UNITY',
        language: 'vala'
    )

    PLANK = dependency ('plank', required: true)
endif

if USE_UNITY and PLANK.found ()
    PLANK_0_11 = dependency ('plank', version: '>=0.10.9', required: false)
    if PLANK_0_11.found ()
        add_project_arguments (
            '--define=HAVE_PLANK_0_11',
            language: 'vala'
        )
    endif
endif

add_global_arguments (
    ['-DGETTEXT_PACKAGE="' + meson.project_name () + '"',
    '-w'],
    language:'c'
)

COMMON_DEPS = [
    dependency ('glib-2.0', version: '>=2.29.0'),
    dependency ('gio-2.0'),
    dependency ('gee-0.8'),
    dependency ('gmodule-2.0'),
    dependency ('granite', version: '>=0.3.0'),
	dependency('gtk+-3.0', version: '>=3.22', required: true),
    dependency ('gio-unix-2.0')
]

POSIX = vala.find_library('posix')
LINUX = vala.find_library('linux')
MATH = cc.find_library('m')

OTHER_DEPS = declare_dependency (dependencies: [POSIX, LINUX, MATH])

CORE_LIB_DEPS = [
    COMMON_DEPS,
	OTHER_DEPS,
    dependency ('pango', version: '>=1.1.2'),
    dependency ('sqlite3'),
    dependency ('libcanberra', version: '>=0.30'),
]

CORE_INC = include_directories ('libcore')
WIDGET_INC = include_directories ('libwidgets')
#SRC_INC = include_directories ('src')

C_CORE_VAPI = vala.find_library('pantheon-files-core-C', dirs: join_paths (meson.source_root (), 'libcore'))
C_CORE_DEP = declare_dependency (dependencies: [C_CORE_VAPI])

#WIDGET_VAPI = vala.find_library('pantheon-files-core-C', dirs: join_paths (meson.source_root (), 'libcore'))
#WIDGET_DEP = declare_dependency (dependencies: [C_CORE_VAPI])

#if get_option ('MODULE_ONLY')
#    subdir ('filechooser-module')
#else
#    if get_option ('LIB_ONLY')
#        subdir ('libcore')
#        subdir ('libwidgets')
#    else
        subdir ('libcore')
        subdir ('libwidgets')
        subdir ('src')
        subdir ('data')
        subdir ('pantheon-files-daemon')
        subdir ('plugins')
        subdir ('filechooser-module')
#        meson.add_install_script('meson/post_install.py')
#    endif
#endif

#subdir ('po')

