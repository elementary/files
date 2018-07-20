WIDGET_DEPS = [COMMON_DEPS, dependency ('zeitgeist-2.0')]
WIDGET_LIB = shared_library (
    WIDGET_LIB_NAME,
    'Interfaces/LocatableInterface.vala',
    'Interfaces/NavigatableInterface.vala',
    'Chrome/BasicLocationBar.vala',
    'Chrome/BasicBreadcrumbsEntry.vala',
    'Chrome/BreadcrumbElement.vala',
    'Chrome/BreadcrumbIconList.vala',
    'Chrome/ButtonWithMenu.vala',
    'Chrome/ImgEventBox.vala',
    'View/SearchResults.vala',
    'Interfaces/SearchableInterface.vala',
    'Chrome/ViewSwitcher.vala',
    'Animations/Animations.vala',
    'Resources.vala',
    'Welcome.vala',

    dependencies : WIDGET_DEPS,

    install: true,
    install_dir: [true, true, true],
    version: WIDGET_LIB_VER,
    soversion: '0',
    link_with: CORE_LIB
)

pkg = import ('pkgconfig')
pkg.generate (
    description: 'Common widgets for io.elementary.files and io.elementary.filechooser',
    filebase: WIDGET_LIB_NAME,
    libraries: WIDGET_LIB,
    name: WIDGET_LIB_NAME,
    version: WIDGET_LIB_VER,
    requires: WIDGET_DEPS
)
