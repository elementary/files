C_CORE_VAPI = vala.find_library('pantheon-files-core-C', dirs: meson.current_source_dir ())
C_CORE_DEP = declare_dependency (dependencies: [C_CORE_VAPI])

CORE_LIB = shared_library (
    CORE_LIB_NAME,
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

    'eel-string.c',
    'marlin-file-operations.c',
    'marlin-undostack-manager.c',
    'marlin-file-changes-queue.c',
    'fm-list-model.c',
    'gof-file.c',

    dependencies : [CORE_LIB_DEPS, C_CORE_DEP, OTHER_DEPS],
    install: true,
    install_dir: [true, true, true],
    version: CORE_LIB_VER,
    soversion: '0',
)

