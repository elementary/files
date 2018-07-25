PLUG_NAME = 'pantheon-files-contractor'

PLUG_DEPS = [
    COMMON_DEPS
]

SRC = [
    'plugin.vala'
]

PLUG_LIB = shared_library (
    meson.project_name (),
    SRC,

    dependencies : [DEPS, C_CORE_DEP],
	include_directories: CORE_INC,
    install: true,
	link_with: [CORE_LIB]
)

pkg = import ('pkgconfig')
pkg.generate (
    description: 'io.elementary.files plugin for Contractor functions',
    filebase: PLUG_NAME,
    libraries: PLUG_LIB,
    name: PLUG_NAME,
    version: PROJECT_VER,
    requires: PLUG_DEPS
)

install_data (
	'contractor.plug',
	install_dir: PLUGIN_DIR
)
