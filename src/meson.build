if USE_UNITY and PLANK.found ()
    PLANK_0_11 = dependency ('plank', version: '>=0.10.9', required: false)
    if PLANK_0_11.found ()
        add_project_arguments (
            '--define=HAVE_PLANK_0_11',
            language: 'vala'
        )
    endif
endif

COMMON_DEPS = [
    CORE_DEPS,
    dependency ('gio-unix-2.0'),
    dependency ('sqlite3'),
    dependency ('dbus-glib-1'),
    dependency ('zeitgeist-2.0')
]

if USE_UNITY
    SRC_DEPS = [COMMON_DEPS, UNITY, PLANK]
else
    SRC_DEPS = COMMON_DEPS
endif

COMMON_SRC = [
        'Application.vala',
        'ConnectServerOperation.vala',
        'main.vala',
        'marlin-deep-count.vala',
        'ProgressUIHandler.vala',
        'TextRenderer.vala',
        'QuicklistHandler.vala',
        'ClipboardManager.vala',
        'IconRenderer.vala',
        'Dialogs/AbstractPropertiesDialog.vala',
        'Dialogs/ChooseAppDialog.vala',
        'Dialogs/PropertiesWindow.vala',
        'Dialogs/VolumePropertiesWindow.vala',
        'Utils/MimeActions.vala',
        'Utils/Permissions.vala',
        'View/ColumnView.vala',
        'View/AbstractTreeView.vala',
        'View/IconView.vala',
        'View/ListView.vala',
        'ZeitgeistManager.vala',
        'View/DirectoryNotFound.vala',
        'View/AbstractDirectoryView.vala',
        'View/Window.vala',
        'View/ViewContainer.vala',
        'View/Browser.vala',
        'View/Sidebar.vala',
        'View/Slot.vala',
        'View/Miller.vala',
        'View/Widgets/AbstractEditableLabel.vala',
        'View/Widgets/BreadcrumbsEntry.vala',
        'View/Widgets/DiskRenderer.vala',
        'View/Widgets/Label.vala',
        'View/Widgets/LocationBar.vala',
        'View/Widgets/MultiLineEditableLabel.vala',
        'View/Widgets/OverlayBar.vala',
        'View/Widgets/PermissionButton.vala',
        'View/Widgets/ProgressInfoWidget.vala',
        'View/Widgets/SingleLineEditableLabel.vala',
        'View/Widgets/TopMenu.vala'
]

executable (
	meson.project_name (),
	COMMON_SRC,

	dependencies : SRC_DEPS,
	install: true
)

#IF USE_UNITY
#    executable (
#        meson.project_name (),
#        COMMON_SRC,

#        dependencies : [COMMON_DEPS, UNITY, PLANK],
#        install: true,
#        link_with: lib
#    )
#else
#    executable (
#        meson.project_name (),
#        COMMON_SRC,
#        'QuicklistHandler.vala',

#        dependencies : COMMON_DEPS,
#        install: true,
#        link_with: lib
#    )
#endif
