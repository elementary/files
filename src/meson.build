pantheon_files_deps = [
    common_deps,
    adwaita_dep,
    pantheon_files_core_dep,
    # plank_dep, #Requires Gtk3
    # zeitgeist_dep,
    project_config_dep,
]

pantheon_files_exec = executable (
    meson.project_name (),
    resources,

    'Application.vala',
    'main.vala',
    'Services/ClipboardManager.vala',
    'Services/ProgressUIHandler.vala',
    'Services/ZeitgeistManager.vala',
    'Services/Browser.vala',

    'View/DirectoryNotFound.vala',
    'View/GridView.vala',
    'View/ListView.vala',
    'View/MultiSlot.vala',
    'View/PrivacyModeOn.vala',
    'View/ViewContainer.vala',
    'View/Window.vala',
    'View/Slot.vala',

    'View/Widgets/GridFileItem.vala',
    'View/Widgets/OverlayBar.vala',
    'View/Widgets/ProgressInfoWidget.vala',
    'View/Widgets/SearchResults.vala',

    'View/HeaderBar/HeaderBar.vala',
    'View/HeaderBar/PathBar.vala',

    'View/Sidebar/AbstractMountableRow.vala',
    'View/Sidebar/BookmarkListBox.vala',
    'View/Sidebar/BookmarkRow.vala',
    'View/Sidebar/DeviceListBox.vala',
    'View/Sidebar/DriveRow.vala',
    'View/Sidebar/NetworkListBox.vala',
    'View/Sidebar/NetworkRow.vala',
    'View/Sidebar/SidebarWindow.vala',
    'View/Sidebar/VolumeRow.vala',
    'View/Sidebar/VolumelessMountRow.vala',

    dependencies : [
        pantheon_files_deps,
    ],
    install: true,
)
