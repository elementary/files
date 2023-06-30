# Files
[![Packaging status](https://repology.org/badge/tiny-repos/elementary-files.svg)](https://repology.org/metapackage/pantheon-files)
[![Translation status](https://l10n.elementary.io/widgets/files/-/svg-badge.svg)](https://l10n.elementary.io/projects/files/?utm_source=widget)

![Files Screenshot](data/screenshot-grid.png?raw=true)

## Building, Testing, and Installation

You'll need the following dependencies:
* meson
* valac
* libcanberra-dev
* libcloudproviders-dev >= 0.3.0
* libdbus-glib-1-dev
* libgail-3-dev
* libgee-0.8-dev
* libgit2-glib-1.0-dev
* libglib2.0-dev
* libgranite-dev >= 6.1.0
* libgtk-4-dev
* libadwaita-1-dev
* libnotify-dev
* libpango1.0-dev
* libplank-dev
* libsqlite3-dev
* libunity-dev
* libzeitgeist-2.0-dev

Run `meson build` to configure the build environment. Change to the build directory and run `ninja` to build

```bash
meson build --prefix=/usr
cd build
ninja
```

To install, use `ninja install`, then execute with `io.elementary.files`

```bash
sudo ninja install
io.elementary.files
```
