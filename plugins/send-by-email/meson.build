send_by_email_plugin_dir = join_paths(plugin_dir, 'core')

gdk_dep = [ dependency('gtk4-x11'), dependency('gtk4-wayland') ]

shared_module(
    'pantheon-files-send-by-email',
    'plugin.vala',
    'Portal.vala',
    dependencies: [pantheon_files_core_dep, gdk_dep],
    install: true,
    install_dir: send_by_email_plugin_dir
)

install_data(
    'pantheon-files-send-by-email.plug',
    install_dir: send_by_email_plugin_dir
)
