send_by_email_plugin_dir = join_paths(plugin_dir, 'core')

gdk_dep = [ dependency('gdk-x11-3.0'), dependency('gdk-wayland-3.0') ]

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
