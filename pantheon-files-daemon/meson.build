DEPS = [
    CORE_LIB_DEPS,
    dependency ('libnotify', version: '>=0.7.2'),
]

SRC = [
    'main.vala',
    'FileManager1.vala',
    'marlind-tagging.vala'
]

executable (
    meson.project_name (),
    SRC,

    dependencies : DEPS,
    install: true,
)
