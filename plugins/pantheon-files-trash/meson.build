trash_plugin_dir = join_paths(plugin_dir, 'gtk4')

shared_module(
    'pantheon-files-trash',
    'plugin.vala',
    dependencies : pantheon_files_core_dep,
    install: true,
    install_dir: trash_plugin_dir,
)

install_data(
    'pantheon-files-trash.plug',
    install_dir: trash_plugin_dir
)
