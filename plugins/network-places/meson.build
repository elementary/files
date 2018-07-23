PLUG_NAME = 'network-places'

PLUG_DEPS = [
    COMMON_DEPS,
]

SRC = [
    'plugin.vala'
]

PLUG_LIB = shared_library (
    meson.project_name (),
    SRC,

    dependencies : DEPS,
    install: true,
    link_with: [CORE_LIB, WIDGET_LIB]
)

pkg = import ('pkgconfig')
pkg.generate (
    description: 'io.elementary.files plugin for networking functions',
    filebase: PLUG_NAME,
    libraries: PLUG_LIB,
    name: PLUG_NAME,
    version: PROJECT_VER,
    requires: PLUG_DEPS
)

install_data (
    PLUG_NAME + '.plug',
    install_dir: PLUGIN_DIR
)
