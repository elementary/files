MODULE_NAME = '"pantheon-filechooser-module'

MODULE_DEPS = [
    COMMON_DEPS,
]

SRC = [
    'FileChooserDialog.vala',
    'Plugin.vala'
]

MODULE_LIB = shared_library (
    meson.project_name (),
    SRC,

    dependencies : DEPS,
    install: true,
    install_dir: MODULE_LIBDIR,
    link_with: [CORE_LIB, WIDGET_LIB]
)
