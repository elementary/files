project ('io.elementary.files', 'vala', 'c', meson_version: '>= 0.42.0')

PROJECT_VER = '0.3.6'
DOMAIN = 'io.elementary.'
SHORTNAME = 'files'
LIBNAME = meson.project_name () + '-core'
SCHEMA_PATH = '/io/elementary/' + SHORTNAME + '/'

vala_version_required = '0.34.0'
i18n = import ('i18n')
vala = meson.get_compiler('vala')

if not vala.version().version_compare('>= @0@'.format(vala_version_required))
    error('Valac >= @0@ required!'.format(vala_version_required))
endif

dependency('gtk+-3.0', version: '>=3.22', required: true)

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

add_global_arguments (
    ['-DGETTEXT_PACKAGE="' + meson.project_name () + '"',
    '-w'],
    language:'c'
)

CORE_DEPS = [
    dependency ('glib-2.0', version: '>=2.29.0'),
    dependency ('gthread-2.0'),
    dependency ('gio-2.0'),
    dependency ('pango', version: '>=1.1.2'),
    dependency ('gtk+-3.0', version: '>=3.4.0'),
    dependency ('gail-3.0'),
    dependency ('gee-0.8'),
    dependency ('gmodule-2.0'),
    dependency ('sqlite3'),
    dependency ('libcanberra', version: '>=0.30'),
    dependency ('granite', version: '>=0.3.0')
]


if get_option ('MODULE_ONLY')
    subdir ('filechooser-module')
else
    if get_option ('LIB_ONLY')
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
endif

subdir ('po')

