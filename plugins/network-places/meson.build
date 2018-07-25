PLUG_NAME = 'network-places'

PLUG_DEPS = [
    COMMON_DEPS,
]

SRC = [
    'plugin.vala'
]

PLUG_LIB = shared_library (
    PLUG_NAME,
    SRC,

    dependencies : [DEPS, C_CORE_DEP],
	include_directories: [CORE_INC, SRC_INC],
    install: true,
	install_dir: INSTALL_DIR,
	link_with: [CORE_LIB, LIB_SRC]
)

install_data (
    PLUG_NAME + '.plug',
    install_dir: INSTALL_DIR
)
