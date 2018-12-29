contractor_plugin_dir = join_paths(plugin_dir, 'core')

shared_module(
    'pantheon-files-contractor',
    'plugin.vala',
    dependencies : pantheon_files_core_dep,
    install: true,
    install_dir: contractor_plugin_dir,
)

install_data(
    'pantheon-files-contractor.plug',
    install_dir: contractor_plugin_dir,
)
