LIB_VER = PROJECT_VER
LIB = shared_library (
    LIBNAME,
    'AbstractSidebar.vala',
    'AbstractSlot.vala',
    'Bookmark.vala',
    'BookmarkList.vala',
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
    'SoundManager.vala',
    'StockDialogs.vala',
    'TrashMonitor.vala',
    'UserUtils.vala',
    'IconInfo.vala',
    'Thumbnailer.vala',

    'eel-string.c,
    'marlin-file-operations.c',
    'marlin-undostack-manager.c',
    'marlin-file-changes-queue.c',
    'fm-list-model.c',
    'gof-file.c',

    dependencies : CORE_DEPS,
    install: true,
    install_dir: [true, true, true],
    version: LIBVER,
    soversion: '0'
)

pkg = import ('pkgconfig')
pkg.generate (
    description: 'Core functions for io.elementary.files',
    filebase: LIBNAME,
    libraries: lib,
    name: LIBNAME,
    version: LIBVER,
    requires: CORE_DEPS
)
