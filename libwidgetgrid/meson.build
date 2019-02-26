libname = 'libwidgetgrid'
libver = '0.1'

valac = find_program ('valac')
libvala_version = run_command(valac, '--api-version').stdout().strip()
libvala_dep = dependency('libvala-@0@'.format(libvala_version))

libwidgetgrid_deps = [
    libvala_dep,
    gtk_dep,
    gee_dep
]

widgetgrid_lib = shared_library (
    libname,
    'Interfaces/SelectionHandler.vala',
    'Interfaces/SelectionFrame.vala',
    'Interfaces/PositionHandler.vala',
    'Interfaces/CursorHandler.vala',
    'Interfaces/Item.vala',
    'Interfaces/Model.vala',
    'Interfaces/DataInterface.vala',
    'View.vala',
    'AbstractItemFactory.vala',
    'SimpleModel.vala',
    'LayoutHandler.vala',
    'SelectionFrameRectangle.vala',
    'RowData.vala',
    'WidgetData.vala',

    dependencies : [
        libwidgetgrid_deps
    ],

    install: false,
    version: libver,
    soversion: '0'
)

widgetgrid_dep = declare_dependency(
    link_with: widgetgrid_lib,
    include_directories: include_directories('.'),
    dependencies : [ libwidgetgrid_deps ],
)

pkg = import ('pkgconfig')
pkg.generate (
    description: 'High performance grid view for large amounts of data',
    filebase: libname,
    libraries: libname,
    name: libname,
    version: libver,
    requires: ['gtk+-3.0', 'valac', 'gee-0.8']
)
