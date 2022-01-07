bulkrenamer_plugin_dir = join_paths(plugin_dir, 'core')

shared_module (
    'pantheon-files-bulk-renamer',
    'BulkRenamer.vala',
    'Enums.vala',
    'Modifier.vala',
    'RenamerDialog.vala',
    'plugin.vala',
    dependencies : pantheon_files_core_dep,
    install : true,
    install_dir : bulkrenamer_plugin_dir
)

install_data(
    'pantheon-files-bulk-renamer.plug',
    install_dir: bulkrenamer_plugin_dir,
)
