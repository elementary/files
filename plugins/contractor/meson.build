PLUG_NAME = 'pantheon-files-contractor'
INSTALL_DIR = join_paths(PLUGIN_DIR, 'core')
PLUG_DEPS = [
    COMMON_DEPS
]

SRC = [
    'plugin.vala'
]

PLUG_LIB = shared_library (
    PLUG_NAME,
    SRC,

    dependencies : [DEPS, C_CORE_DEP],
    include_directories: CORE_INC,
    install: true,
    install_dir: INSTALL_DIR,
    link_with: [CORE_LIB]
)

install_data (
    'pantheon-files-contractor.plug',
    install_dir: INSTALL_DIR
)
