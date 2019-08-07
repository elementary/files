git_plugin_dir = join_paths(plugin_dir, 'core')

shared_module(
    'pantheon-files-git',
    'plugin.vala',
    dependencies : pantheon_files_core_dep,
    install: true,
    install_dir: git_plugin_dir,
)

install_data(
    'pantheon-files-git.plug',
    install_dir: git_plugin_dir
)
