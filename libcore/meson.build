pantheon_files_core_name = 'pantheon-files-core'

resources = gnome.compile_resources(
    'files-resources',
    meson.project_source_root() / 'data' / 'files.gresource.xml',
    source_dir: meson.project_source_root() / 'data'
)

pantheon_files_core_deps = [
    common_deps,
    posix_dep,
    linux_dep,
    math_dep,
    pango_dep,
    sqlite3_dep,
    libcanberra_dep,
    handy_dep,
    zeitgeist_dep,
        dependency('gdk-x11-3.0'),
        dependency('gdk-wayland-3.0')
]

pantheon_files_core_vala_files = files(
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

    'View/AbstractSlot.vala',
    'View/AbstractEditableLabel.vala',
    'View/BasicAbstractDirectoryView.vala',
    'View/BasicAbstractTreeView.vala',
    'View/BasicSlot.vala',
    'View/BasicListView.vala',
    'View/BasicIconView.vala',
    'View/BasicWindow.vala',

    'View/Dialogs/FileChooserDialog.vala',
    'View/Dialogs/FileChooserChoice.vala',
    'View/Dialogs/ExternalWindow.vala',
    'View/Dialogs/StockDialogs.vala',
    'View/Dialogs/ConnectServerOperation.vala',
    'View/Dialogs/ConnectServerDialog.vala',
    'View/Dialogs/FileConflictDialog.vala',

    'View/HeaderBar/BasicBreadcrumbsEntry.vala',
    'View/HeaderBar/BasicLocationBar.vala',
    'View/HeaderBar/BreadcrumbElement.vala',
    'View/HeaderBar/BreadcrumbIconList.vala',
    'View/HeaderBar/ButtonWithMenu.vala',
    'View/HeaderBar/ViewSwitcher.vala',
    'View/HeaderBar/BasicHeaderBar.vala',
    'View/HeaderBar/Browser.vala',
    'View/HeaderBar/BrowserStack.vala',

    'View/Renderers/EmblemRenderer.vala',
    'View/Renderers/IconRenderer.vala',
    'View/Renderers/TextRenderer.vala',

    'View/Sidebar/BasicSidebarWindow.vala',
    'View/Sidebar/BasicBookmarkListBox.vala',
    'View/Sidebar/BasicDeviceListBox.vala',
    'View/Sidebar/BasicBookmarkRow.vala',
    'View/Sidebar/BasicAbstractMountableRow.vala',
    'View/Sidebar/BasicDriveRow.vala',
    'View/Sidebar/BasicVolumelessMountRow.vala',
    'View/Sidebar/BasicVolumeRow.vala',
    'View/Sidebar/Bookmark.vala',
    'View/Sidebar/BookmarkList.vala',
    'View/Sidebar/SidebarPluginItem.vala',

    'View/Widgets/BasicDirectoryNotFound.vala',
    'View/Widgets/SingleLineEditableLabel.vala',
    'View/Widgets/MultiLineEditableLabel.vala',
    'View/Widgets/BasicWelcome.vala',
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
