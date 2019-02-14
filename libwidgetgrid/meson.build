libname = 'widget-grid'
libver = '0.1'

valac = find_program ('valac')
libvala_version = run_command(valac, '--api-version').stdout().strip()
libvala_dep = dependency('libvala-@0@'.format(libvala_version))

dependency('gtk+-3.0', version: '>=3.22', required: true)

lib = shared_library (
    libname,
    'Interfaces/SelectionHandler.vala',
    'Interfaces/SelectionFrame.vala',
    'Interfaces/PositionHandler.vala',
    'Interfaces/Item.vala',
    'Interfaces/Model.vala',
    'View.vala',
    'AbstractItemFactory.vala',
    'WidgetData.vala',
    'SimpleModel.vala',
    'LayoutHandler.vala',
    'SelectionFrameRectangle.vala',
    'RowData.vala',

    dependencies : [
        dependency ('gtk+-3.0'),
        libvala_dep,
        dependency('gee-0.8'),
    ],

    install: false,
    version: libver,
    soversion: '0'
)

