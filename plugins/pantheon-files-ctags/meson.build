ctags_plugin_dir = join_paths(plugin_dir, 'core')

shared_module(
    'pantheon-files-ctags',
    'plugin.vala',
    dependencies : pantheon_files_core_dep,
    install: true,
    install_dir: ctags_plugin_dir,
)

install_data(
    'pantheon-files-ctags.plug',
    install_dir: ctags_plugin_dir
)
