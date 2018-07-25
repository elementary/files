MODULE_NAME = 'pantheon-filechooser-module'

SRC = [
    'FileChooserDialog.vala',
    'Plugin.vala'
]

MODULE_LIB = shared_library (
    MODULE_NAME,
    SRC,

    dependencies : [CORE_LIB_DEPS, C_CORE_DEP],
    include_directories: [CORE_INC, WIDGET_INC],
    install: true,
    install_dir: MODULE_LIBDIR,
    link_with: [CORE_LIB, WIDGET_LIB]
)
