project ('io.elementary.files',
         'vala', 'c',
         version: '0.3.6',
         meson_version: '>= 0.42.0'
)

shortname = 'files'
domain = 'io.elementary.'
schema_path = '/io/elementary/' + shortname + '/'
vala_version_required = '0.34.0'
i18n = import ('i18n')
vala = meson.get_compiler('vala')

if not vala.version().version_compare('>= @0@'.format(vala_version_required))
    error('Valac >= @0@ required!'.format(vala_version_required))
endif

dependency('gtk+-3.0', version: '>=3.22', required: true)

UNITY = dependency ('unity', version: '>=4.0.0', required: false)
USE_UNITY = WITH_UNITY and UNITY.found ()

if USE_UNITY
    add_project_arguments (
        '--define=HAVE_UNITY'
        language: 'vala'
    )
endif

add_global_arguments (
    ['-DGETTEXT_PACKAGE="' + meson.project_name () + '"',
    '-w'],
    language:'c'
)

COMMON_DEPS = [
    'granite>=0.3.0',
    'glib-2.0>=2.29.0',
    'gthread-2.0',
    'gio-2.0',
    'gio-unix-2.0',
    'pango>=1.1.2',
    'gtk+-3.0>=3.22',
    'gmodule-2.0',
    'gail-3.0',
    'gee-0.8',
    'sqlite3',
    'dbus-glib-1',
    'libcanberra>=0.30',
    'zeitgeist-2.0'
]

if WITH_UNITY and UNITY.found ()
    DEPS = [COMMON_DEPS, plank]
else
    DEPS = COMMON_DEPS
endif

if MODULE_ONLY
    subdir ('filechooser-module')
elseif LIB_ONLY
    subdir ('libcore')
    subdir ('libwidgets')
else
    subdir ('src')
    subdir ('data')
    subdir ('pantheon-files-daemon')
    subdir ('libcore')
    subdir ('libwidgets')
    subdir ('plugins')
    subdir ('filechooser-module')
    meson.add_install_script('meson/post_install.py')
endif

subdir ('po')

