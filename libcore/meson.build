pantheon_files_core_name = 'pantheon-files-core'

pantheon_files_core_deps = [
    common_deps,
    posix_dep,
    linux_dep,
    math_dep,
    pango_dep,
    sqlite3_dep,
    libcanberra_dep,
]

pantheon_files_core_vala_files = files(
    'AbstractSlot.vala',
    'Bookmark.vala',
    'BookmarkList.vala',
    'ConnectServerOperation.vala',
    'ConnectServerDialog.vala',
    'DndHandler.vala',
    'Enums.vala',
    'File.vala',
    'PixbufUtils.vala',
    'FileChanges.vala',
    'FileUtils.vala',
    'FileConflictDialog.vala',
# <<<<<<< HEAD
#     'gof-callwhenready.vala',
#     'gof-directory-async.vala',
#     'gof-preferences.vala',
    'ListModel.vala',
# =======
    'CallWhenReady.vala',
    'Directory.vala',
    'Preferences.vala',
# >>>>>>> master
    'PluginManager.vala',
    'Plugin.vala',
    'ProgressInfo.vala',
    'ProgressInfoManager.vala',
    'SidebarPluginItem.vala',
    'SoundManager.vala',
    'StockDialogs.vala',
    'TrashMonitor.vala',
    'UserUtils.vala',
    'UndoManager.vala',
    'IconInfo.vala',
    'Thumbnailer.vala',
    'FileOperations/CommonJob.vala',
    'FileOperations/EmptyTrashJob.vala',
    'FileOperations/MountUtils.vala',
    'FileOperations/DialogUtils.vala',
    'Interfaces/SidebarInterface.vala',
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
