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

    dependencies : [DEPS, C_CORE_DEP],
    include_directories: [CORE_INC, WIDGET_INC],
    install: true,
    install_dir: MODULE_LIBDIR,
    link_with: [CORE_LIB, WIDGET_LIB]
)
