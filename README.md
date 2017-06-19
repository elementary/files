# Files
[![Translation status](https://l10n.elementary.io/widgets/files/-/svg-badge.svg)](https://l10n.elementary.io/projects/files/?utm_source=widget)

## Building, Testing, and Installation

You'll need the following dependencies:
* cmake
* libcanberra-dev
* libdbus-glib-1-dev
* libgail-3-dev
* libgee-0.8-dev
* libglib2.0-dev
* libgranite-dev
* libgtk-3-dev
* libnotify-dev
* libpango1.0-dev
* libplank-dev
* libsqlite3-dev
* libunity-dev
* libzeitgeist-2.0-dev
* valac

It's recommended to create a clean build environment

    mkdir build
    cd build/

Run `cmake` to configure the build environment and then `make` to build

    cmake -DCMAKE_INSTALL_PREFIX=/usr ..
    make

To install, use `make install`, then execute with `pantheon-files`

    sudo make install
    pantheon-files
