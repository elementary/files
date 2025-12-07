pantheon_files_deps = [
    common_deps,
    handy_dep,
    pantheon_files_core_dep,
    # zeitgeist_dep,
    project_config_dep,
    portal_dep,
    portal_gtk3_dep
]

pantheon_files_exec = executable (
    meson.project_name (),
    resources,

    'Application.vala',
    'DeepCount.vala',
    # 'EmblemRenderer.vala',
    # 'IconRenderer.vala',
    # 'TextRenderer.vala',
    'main.vala',
    'ProgressUIHandler.vala',

    'ZeitgeistManager.vala',

    'Dialogs/AbstractPropertiesDialog.vala',
    'Dialogs/ChooseAppDialog.vala',
    'Dialogs/PropertiesWindow.vala',
    'Dialogs/VolumePropertiesWindow.vala',

    'Dialogs/BulkRenamer/Renamer.vala',
    'Dialogs/BulkRenamer/RenamerModifier.vala',
    'Dialogs/BulkRenamer/RenamerDialog.vala',
    'Dialogs/BulkRenamer/RenamerListRow.vala',

    'Utils/MimeActions.vala',
    'Utils/Permissions.vala',
    'Utils/AppUtils.vala',

    'View/AbstractDirectoryView.vala',
    'View/AbstractTreeView.vala',
    'View/ColumnView.vala',
    'View/DirectoryNotFound.vala',
    'View/IconView.vala',
    'View/ListView.vala',
    'View/Miller.vala',
    'View/PrivacyModeOn.vala',
    'View/Slot.vala',
    'View/ViewContainer.vala',
    'View/Window.vala',

    # 'View/Widgets/AbstractEditableLabel.vala',
    'View/Widgets/AppMenu.vala',
    'View/Widgets/BreadcrumbsEntry.vala',
    'View/Widgets/LocationBar.vala',
    # 'View/Widgets/MultiLineEditableLabel.vala',
    'View/Widgets/OverlayBar.vala',
    'View/Widgets/PermissionButton.vala',
    'View/Widgets/ProgressInfoWidget.vala',
    # 'View/Widgets/SingleLineEditableLabel.vala',
    'View/Widgets/SearchResults.vala',
    'View/Widgets/Welcome.vala',

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
