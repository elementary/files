pantheon_files_core_name = 'pantheon-files-core'

resources = gnome.compile_resources(
    'files-resources',
    meson.project_source_root() / 'data' / 'files.gresource.xml',
    source_dir: meson.project_source_root() / 'data'
)

config_data = configuration_data()
config_data.set('plugin_dir', plugin_dir)
config_data.set('version', meson.project_version())
config_data.set('testdata_dir', join_paths(meson.project_source_root(), 'data', 'tests'))
config_data.set('app_name', meson.project_name())
config_data.set('gettext_package', meson.project_name())
config_data.set('locale_dir', join_paths(get_option('prefix'), get_option('localedir')))

config_file = configure_file(
    input: 'config.h.in',
    output: 'config.h',
    configuration: config_data
)

project_config_dep = declare_dependency(
    sources: config_file,
    include_directories: include_directories('.')
)

pantheon_files_core_deps = [
    common_deps,
    posix_dep,
    linux_dep,
    math_dep,
    pango_dep,
    sqlite3_dep,
    libcanberra_dep,
    zeitgeist_dep,
    dependency('gdk-x11-3.0'),
    dependency('gdk-wayland-3.0'),
    portal_dep,
    portal_gtk3_dep,
    project_config_dep
]

pantheon_files_core_vala_files = files(
    'AbstractSlot.vala',
    'CallWhenReady.vala',
    'ClipboardManager.vala',
    'Directory.vala',
    'DndHandler.vala',
    'Enums.vala',
    'File.vala',
    'FileChanges.vala',
    'FileUtils.vala',
    'IconInfo.vala',
    'ListModel.vala',
    'MimeActions.vala',
    'Permissions.vala',
    'PixbufUtils.vala',
    'Preferences.vala',
    'PluginManager.vala',
    'Plugin.vala',
    'ProgressInfo.vala',
    'ProgressInfoManager.vala',
    'Resources.vala',
    'SoundManager.vala',
    'Thumbnailer.vala',
    'TrashMonitor.vala',
    'UserUtils.vala',
    'UndoManager.vala',
    'ZeitgeistManager.vala',

    'FileOperations/CommonJob.vala',
    'FileOperations/CopyMoveJob.vala',
    'FileOperations/CreateJob.vala',
    'FileOperations/DeleteJob.vala',
    'FileOperations/EmptyTrashJob.vala',
    'FileOperations/MountUtils.vala',

    'Interfaces/SidebarInterface.vala',
    'Interfaces/LocatableInterface.vala',
    'Interfaces/NavigatableInterface.vala',
    'Interfaces/SearchableInterface.vala',
    'Interfaces/SidebarListInterface.vala',
    'Interfaces/SidebarItemInterface.vala',
    'Interfaces/SlotToplevelInterface.vala',
    'Interfaces/MultiSlotInterface.vala',

    'View/ViewUtils.vala',
    'View/Dialogs/ChooseAppDialog.vala',
    'View/Dialogs/ConnectServerOperation.vala',
    'View/Dialogs/ConnectServerDialog.vala',
    'View/Dialogs/FileConflictDialog.vala',
    'View/Dialogs/AbstractPropertiesDialog.vala',
    'View/Dialogs/PropertiesWindow.vala',
    'View/Dialogs/VolumePropertiesWindow.vala',
    'View/Dialogs/StockDialogs.vala',
    'View/Dialogs/BulkRenamer/Renamer.vala',
    'View/Dialogs/BulkRenamer/RenamerModifier.vala',
    'View/Dialogs/BulkRenamer/RenamerDialog.vala',
    'View/Dialogs/BulkRenamer/RenamerListRow.vala',

    'View/HeaderBar/BasicBreadcrumbsEntry.vala',
    'View/HeaderBar/BasicLocationBar.vala',
    'View/HeaderBar/BreadcrumbElement.vala',
    'View/HeaderBar/BreadcrumbIconList.vala',
    'View/HeaderBar/ButtonWithMenu.vala',
    'View/HeaderBar/ViewSwitcher.vala',
    'View/HeaderBar/Browser.vala',
    'View/Renderers/EmblemRenderer.vala',
    'View/Renderers/IconRenderer.vala',
    'View/Renderers/TextRenderer.vala',
    'View/Sidebar/Bookmark.vala',
    'View/Sidebar/BookmarkList.vala',
    'View/Sidebar/SidebarPluginItem.vala',
    'View/Widgets/AbstractEditableLabel.vala',
    'View/Widgets/MultiLineEditableLabel.vala',
    'View/Widgets/SingleLineEditableLabel.vala',

    'View2/AbstractDirectoryView.vala',
    'View2/AbstractTreeView.vala',
    'View2/ColumnView.vala',
    'View2/DirectoryNotFound.vala',
    'View2/DeepCount.vala',
    'View2/IconView.vala',
    'View2/ListView.vala',
    # 'View2/Miller.vala',
    'View2/PrivacyModeOn.vala',
    'View2/Slot.vala',
    # 'View2/ViewContainer.vala',
    # 'View2/Window.vala',
    'View2/DetailsColumn.vala',
    'View2/ViewPreferences.vala',

    # 'View2/Widgets/AppMenu.vala',
    'View2/Widgets/BreadcrumbsEntry.vala',
    'View2/Widgets/LocationBar.vala',
    'View2/Widgets/OverlayBar.vala',
    'View2/Widgets/PermissionButton.vala',
    'View2/Widgets/ProgressInfoWidget.vala',
    'View2/Widgets/SearchResults.vala',
    'View2/Widgets/Welcome.vala',

    'View2/Sidebar/AbstractMountableRow.vala',
    'View2/Sidebar/BookmarkListBox.vala',
    'View2/Sidebar/BookmarkRow.vala',
    'View2/Sidebar/DeviceListBox.vala',
    'View2/Sidebar/DriveRow.vala',
    'View2/Sidebar/NetworkListBox.vala',
    'View2/Sidebar/NetworkRow.vala',
    'View2/Sidebar/SidebarWindow.vala',
    'View2/Sidebar/VolumeRow.vala',
    'View2/Sidebar/VolumelessMountRow.vala',

)

pantheon_files_core_c_files = files(
    'marlin-file-operations.c'
)

pantheon_files_core_h_files = files(
    'marlin-file-operations.h'
)

pantheon_files_core_files = [
    pantheon_files_core_vala_files,
    pantheon_files_core_c_files,
    pantheon_files_core_h_files,
]

pantheon_file_core_c_dep = vala.find_library('pantheon-files-core-C', dirs: join_paths(meson.current_source_dir()))

pantheon_files_core_library = shared_library(
    pantheon_files_core_name,
    pantheon_files_core_files,
    resources,
    dependencies : [ pantheon_files_core_deps, pantheon_file_core_c_dep ],
    install: true,
    install_dir: [true, join_paths(get_option('prefix'), get_option('includedir'), pantheon_files_core_name), true],
    version: meson.project_version(),
)

install_headers(
    pantheon_files_core_h_files,
    subdir: pantheon_files_core_name
)

pantheon_files_core_dep = declare_dependency(
    link_with: pantheon_files_core_library,
    include_directories: include_directories('.'),
    dependencies : [ pantheon_files_core_deps, pantheon_file_core_c_dep ],
)

pantheon_files_core_pkgconfig = pkg.generate(
    pantheon_files_core_library,
    subdirs: pantheon_files_core_name,
    filebase: pantheon_files_core_name,
    name: 'elementary Files Core Library',
    description: 'Core library used by io.elementary.files and by io.elementary.file-chooser',
    version: meson.project_version(),
)

subdir('tests')
