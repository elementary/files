gtk3_module_dir = join_paths(get_option('prefix'), get_option ('libdir'), 'gtk-3.0', 'modules')

shared_module(
    'pantheon-filechooser-module',
    'FileChooserDialog.vala',
    'Plugin.vala',

    dependencies : pantheon_files_widgets_dep,
    install: true,
    install_dir: gtk3_module_dir,
)
