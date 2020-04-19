sushi_plugin_dir = join_paths(plugin_dir, 'core')

shared_module(
    'pantheon-files-sushi',
    'plugin.vala',
    dependencies : pantheon_files_core_dep,
    install: true,
    install_dir: sushi_plugin_dir,
)

install_data(
    'pantheon-files-sushi.plug',
    install_dir: sushi_plugin_dir
)
