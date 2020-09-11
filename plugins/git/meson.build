git_plugin_dir = join_paths(plugin_dir, 'core')

ggit_dep = dependency('libgit2-glib-1.0')

shared_module(
    'pantheon-files-git',
    'plugin.vala',
    dependencies : [pantheon_files_core_dep, ggit_dep],
    install: true,
    install_dir: git_plugin_dir,
)

install_data(
    'pantheon-files-git.plug',
    install_dir: git_plugin_dir
)
