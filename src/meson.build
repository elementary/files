deps = [
    CORE_LIB_DEPS,
    dependency ('dbus-glib-1'),
    dependency ('zeitgeist-2.0')
]

MARLIN_VAPI = vala.find_library('marlin', dirs: meson.current_source_dir ())
MARLIN_DEP = declare_dependency (dependencies: [MARLIN_VAPI])

if USE_UNITY
    SRC_DEPS = [deps, UNITY, PLANK]
else
    SRC_DEPS = deps
endif

config_data = configuration_data()
config_data.set('plugin_dir', PLUGIN_DIR)
config_data.set('version', PROJECT_VER)
config_data.set('ui_dir', join_paths(meson.current_source_dir (), 'View'))
config_data.set('testdata_dir', join_paths(meson.source_root (), 'data', 'tests'))
config_data.set('app_name', meson.project_name ())
config_data.set('terminal_name', TERMINAL_NAME)

configure_file (
    input: 'config.h.in',
    output: 'config.h',
    configuration: config_data
)

executable (
	meson.project_name (),
	'main.vala',

	'Application.vala',
	'marlin-deep-count.vala',
	'ProgressUIHandler.vala',
	'QuicklistHandler.vala',
	'TextRenderer.vala',
	'ClipboardManager.vala',
	'IconRenderer.vala',
	'ZeitgeistManager.vala',

	'Dialogs/AbstractPropertiesDialog.vala',
	'Dialogs/ChooseAppDialog.vala',
	'Dialogs/PropertiesWindow.vala',
	'Dialogs/VolumePropertiesWindow.vala',

	'Utils/MimeActions.vala',
	'Utils/Permissions.vala',

	'View/Window.vala',
	'View/ColumnView.vala',
	'View/AbstractTreeView.vala',
	'View/IconView.vala',
	'View/ListView.vala',
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
	'View/Widgets/TopMenu.vala',

	dependencies : [SRC_DEPS, C_CORE_DEP, MARLIN_DEP, OTHER_DEPS],
	include_directories: [CORE_INC, WIDGET_INC],
	install: true,
	link_with: [CORE_LIB, WIDGET_LIB]
)
