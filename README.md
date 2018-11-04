# Files Dropbox plugin
[![Bountysource](https://www.bountysource.com/badge/tracker?tracker_id=65602118)

## Building, Testing, and Installation

You'll need the following dependencies:
* cmake
* libgranite-dev >= 5.2.0
* libgtk-3-dev
* libgee-0.8-dev
* libglib2.0-dev
* libpantheon-files-core.dev

You will also need to have installed:

* Pantheon Files
* The 64-bit proprietary Dropbox command line client.

Files is preinstalled in elementaryos or install the pantheon-files package.

To install the 64-bit Dropbox client these instructions are from the Dropbox website:

    Open a terminal and run:

    `cd ~ && wget -O - "https://www.dropbox.com/download?plat=lnx.x86_64" | tar xzf -`

    Next, run the Dropbox daemon from the newly created .dropbox-dist folder.
    `~/.dropbox-dist/dropboxd`

   If you're running Dropbox on your server for the first time, you'll be asked to copy and paste a link
   in a working browser to create a new account or add your server to an existing account.
   Once you do, your Dropbox folder will be created in your home directory.


Create a clean build environment in the root of the source tree and move to it.
```
    mkdir build
    cd build/
```
Configure the build environment:

    `cmake -DCMAKE_INSTALL_PREFIX=/usr ..`

Install the plugin:

    `sudo make install`

Run Files, either from the desktop or in the terminal with:

    `io.elementary.files`

Navigate to the ~/Dropbox folder.  If you are connected to Dropbox then status icons will appear
againt the items and the context menu contains additional Dropbox related items.  You may wish
to drag the folder onto the sidebar (Personal category) to create a bookmark.
