icon_info_test_exec = executable (
    'MarlinIconInfoTests',
    'MarlinIconInfoTests.vala',

    dependencies : [ pantheon_files_core_dep, project_config_dep ],
    install: false,
)

run_command ('gtk-update-icon-cache', '-f', '/usr/share/icons/hicolor')
test ('MarlinIconInfoTests', icon_info_test_exec)
