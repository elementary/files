pantheon_files_deps = [
    common_deps,
    handy_dep,
    pantheon_files_core_dep
]

pantheon_files_exec = executable (
    meson.project_name (),

    'AppMenu.vala',
    'Application.vala',
    'Window.vala',
    'ViewContainer.vala',
    'Miller.vala',
    'main.vala',
    'ProgressUIHandler.vala',

    dependencies : [
        pantheon_files_deps,
    ],
    install: true,
)
