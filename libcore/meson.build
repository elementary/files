CORE_LIB = shared_library (
    CORE_LIB_NAME,
    'AbstractSidebar.vala',
    'AbstractSlot.vala',
    'Bookmark.vala',
    'BookmarkList.vala',
    'ConnectServerOperation.vala',
    'ConnectServerDialog.vala',
    'DndHandler.vala',
    'Enums.vala',
    'PixbufUtils.vala',
    'FileUtils.vala',
    'FileConflictDialog.vala',
    'gof-callwhenready.vala',
    'gof-directory-async.vala',
    'gof-preferences.vala',
    'PluginManager.vala',
    'Plugin.vala',
    'ProgressInfo.vala',
    'ProgressInfoManager.vala',
    'SidebarPluginItem.vala',
    'SoundManager.vala',
    'StockDialogs.vala',
    'TrashMonitor.vala',
    'UserUtils.vala',
    'IconInfo.vala',
    'Thumbnailer.vala',

    'eel-string.c',
    'marlin-file-operations.c',
    'marlin-undostack-manager.c',
    'marlin-file-changes-queue.c',
    'fm-list-model.c',
    'gof-file.c',

    dependencies : [CORE_LIB_DEPS, C_CORE_DEP, OTHER_DEPS],
    install: true,
    install_dir: [true, join_paths(get_option('prefix'), get_option('includedir'), CORE_LIB_NAME), true],
    version: CORE_LIB_VER,
    soversion: '0',
)

install_headers(
    'eel-string.h',
    'marlin-file-operations.h',
    'marlin-undostack-manager.h',
    'marlin-file-changes-queue.h',
    'fm-list-model.h',
    'gof-file.h',

    subdir: CORE_LIB_NAME
)

pkg = import ('pkgconfig')
pkg.generate (
    libraries: CORE_LIB,
    description: 'Core library io.elementary.files and io.elementary.filechooser',
    filebase: CORE_LIB_NAME,
    name: 'lib'+ CORE_LIB_NAME,
    version: CORE_LIB_VER,
    subdirs: CORE_LIB_NAME
)

subdir ('tests')
