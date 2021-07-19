pantheon_files_widgets_name = 'pantheon-files-widgets'

pantheon_files_widgets_deps = [
    common_deps,
    zeitgeist_dep
]

pantheon_files_widgets_files = files(
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
    'Resources.vala',
    'Welcome.vala',
)

pantheon_files_widgets_library = shared_library(
    pantheon_files_widgets_name,
    pantheon_files_widgets_files,
    dependencies : [pantheon_files_core_dep, pantheon_files_widgets_deps],

    install: true,
    install_dir: [true, true, true],
    version: meson.project_version(),
)

pantheon_files_widgets_dep = declare_dependency(
    link_with: pantheon_files_widgets_library,
    include_directories: include_directories('.'),
    dependencies : [pantheon_files_core_dep, pantheon_files_widgets_deps],
)

pkg.generate(
    libraries: pantheon_files_widgets_library,
    subdirs:  pantheon_files_widgets_name,
    filebase: pantheon_files_widgets_name,
    name: 'elementary Files Widgets Library',
    description: 'Common widgets for io.elementary.files and io.elementary.filechooser',
    version: meson.project_version(),
    requires: [ pantheon_files_widgets_deps, pantheon_files_core_library],
)
