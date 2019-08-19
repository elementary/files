cloudproviders_plugin_dir = join_paths(plugin_dir, 'core')

cloudproviders_dep = dependency('cloudproviders', version: '>=0.3.0')

shared_module(
    'pantheon-files-cloudproviders',
    'plugin.vala',
    dependencies: [ pantheon_files_core_dep, cloudproviders_dep],
    install: true,
    install_dir: cloudproviders_plugin_dir
)

install_data(
    'pantheon-files-cloudproviders.plug',
    install_dir: cloudproviders_plugin_dir
)
