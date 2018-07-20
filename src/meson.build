deps = [
    CORE_LIB_DEPS,
    dependency ('dbus-glib-1'),
    dependency ('zeitgeist-2.0')
]

if USE_UNITY
    SRC_DEPS = [deps, UNITY, PLANK]
else
    SRC_DEPS = deps
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

#IF USE_UNITY
    executable (
        meson.project_name (),
        COMMON_SRC,

        dependencies : SRC_DEPS,
        install: true,
        link_with: [CORE_LIB, WIDGET_LIB]
    )
#else
#    executable (
#        meson.project_name (),
#        COMMON_SRC,
#        'QuicklistHandler.vala',

#        dependencies : SRC_DEPS,
#        install: true,
#        link_with: CORE_LIB,
#        link_with: WIDGET_LIB
#    )
#endif
