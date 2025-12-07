pantheon_files_core_name = 'pantheon-files-core'

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
    'AbstractSlot.vala',
    'AbstractEditableLabel.vala',
    'BasicAbstractDirectoryView.vala',
    'BasicAbstractTreeView.vala',
    'Bookmark.vala',
    'BookmarkList.vala',
    'Browser.vala',
    'BrowserStack.vala',
    'CallWhenReady.vala',
    'ClipboardManager.vala',
    'ConnectServerOperation.vala',
    'ConnectServerDialog.vala',
    'Directory.vala',
    'DndHandler.vala',
    'Enums.vala',
    'File.vala',
    'FileChanges.vala',
    'FileConflictDialog.vala',
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
    'SidebarPluginItem.vala',
    'SoundManager.vala',
    'StockDialogs.vala',
    'Thumbnailer.vala',
    'TrashMonitor.vala',
    'UserUtils.vala',
    'UndoManager.vala',
    'EmblemRenderer.vala',
    'IconRenderer.vala',
    'BasicTextRenderer.vala',
    # 'ZeitgeistManager.vala',
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
    'Widgets/BasicBreadcrumbsEntry.vala',
    'View/BasicListView.vala',
    'View/BasicSlot.vala',
    # 'View/BasicViewContainer.vala',
    'View/BasicWindow.vala',
    'View/BasicSidebarWindow.vala',
    'Widgets/BasicBookmarkListBox.vala',
    'Widgets/BasicDeviceListBox.vala',
    'Widgets/BasicBookmarkRow.vala',
    'Widgets/BasicAbstractMountableRow.vala',
    'Widgets/BasicDriveRow.vala',
    'Widgets/BasicVolumelessMountRow.vala',
    'Widgets/BasicVolumeRow.vala',
    'Widgets/BasicLocationBar.vala',
    'Widgets/BreadcrumbElement.vala',
    'Widgets/BreadcrumbIconList.vala',
    'Widgets/ButtonWithMenu.vala',
    'Widgets/BasicDirectoryNotFound.vala',
    'Widgets/BasicSingleLineEditableLabel.vala',
    'Widgets/BasicWelcome.vala',
    'Widgets/ViewSwitcher.vala',
    'Widgets/BasicHeaderBar.vala',
    'Widgets/FileChooserDialog.vala',
    'Widgets/FileChooserChoice.vala',
    'Widgets/ExternalWindow.vala'
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
