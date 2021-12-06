pantheon_files_deps = [
    common_deps,
    handy_dep,
    pantheon_files_core_dep,
    plank_dep,
    zeitgeist_dep,
    project_config_dep,
]

pantheon_files_exec = executable (
    meson.project_name (),
    resources,

    'Application.vala',
    'ClipboardManager.vala',
    'DeepCount.vala',
    'EmblemRenderer.vala',
    'IconRenderer.vala',
    'main.vala',
    'ProgressUIHandler.vala',
    'TextRenderer.vala',
    'ZeitgeistManager.vala',

    'Dialogs/AbstractPropertiesDialog.vala',
    'Dialogs/ChooseAppDialog.vala',
    'Dialogs/PropertiesWindow.vala',
    'Dialogs/VolumePropertiesWindow.vala',

    'Utils/MimeActions.vala',
    'Utils/Permissions.vala',
    'Utils/AppUtils.vala',

    'View/AbstractDirectoryView.vala',
    'View/AbstractTreeView.vala',
    'View/Browser.vala',
    'View/ColumnView.vala',
    'View/DirectoryNotFound.vala',
    'View/IconView.vala',
    'View/ListView.vala',
    'View/Miller.vala',
    'View/PrivacyModeOn.vala',
    'View/Slot.vala',
    'View/ViewContainer.vala',
    'View/Window.vala',

    'View/Widgets/AbstractEditableLabel.vala',
    'View/Widgets/BreadcrumbsEntry.vala',
    'View/Widgets/HeaderBar.vala',
    'View/Widgets/Label.vala',
    'View/Widgets/LocationBar.vala',
    'View/Widgets/MultiLineEditableLabel.vala',
    'View/Widgets/OverlayBar.vala',
    'View/Widgets/PermissionButton.vala',
    'View/Widgets/ProgressInfoWidget.vala',
    'View/Widgets/SingleLineEditableLabel.vala',
    'View/Widgets/SearchResults.vala',
    'View/Widgets/Welcome.vala',


    'View/Sidebar/AbstractMountableRow.vala',
    'View/Sidebar/BookmarkListBox.vala',
    'View/Sidebar/BookmarkRow.vala',
    'View/Sidebar/DeviceListBox.vala',
    'View/Sidebar/DeviceRow.vala',
    'View/Sidebar/NetworkListBox.vala',
    'View/Sidebar/NetworkRow.vala',
    'View/Sidebar/SidebarWindow.vala',


    dependencies : [
        pantheon_files_deps,
    ],
    install: true,
)
