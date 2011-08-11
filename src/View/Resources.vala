namespace Marlin {
    public const string APP_TITLE = "Marlin";
    public const string COPYRIGHT = "Copyright 2011 Elementary Developers";
    public const string ELEMENTARY_URL = "http://elementaryos.org";
    public const string HELP_URL = "http://elementaryos.org/support";
    public const string BUG_URL = "https://bugs.launchpad.net/marlin/+filebug";
    public const string TRANSLATE_URL = "https://translations.launchpad.net/marlin";
    public const string ELEMENTARY_LABEL = "elementaryos.org";
    public const string COMMENTS = "File Manager";
    
    public const string[] AUTHORS = { 
        "ammonkey <am.monkeyd@gmail.com>",
        "Mathijs Henquet <mathijs.henquet@gmail.com>",
        "Lucas Baudin <xapantu@gmail.com>",
        "Robert Roth",
        "Vadim Rutkovsky",
        "Rico Tzschichholz",
        null
    };
    
    public const string[] ARTISTS = { 
        "Daniel Foré <daniel.p.fore@gmail.com>",
        null
    };

    public const string ICON_ABOUT_LOGO = "system-file-manager";

    public const string LICENSE = """
Marlin is free software; you can redistribute it and/or modify it under the 
terms of the GNU Lesser General Public License as published by the Free 
Software Foundation; either version 2 of the License, or (at your option) 
any later version.

Marlin is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for 
more details.

You should have received a copy of the GNU Lesser General Public License 
along with Marlin; if not, write to the Free Software Foundation, Inc., 
51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
""";

    /*public const int DEFAULT_ICON_SCALE = 24;

    public Gdk.Pixbuf? get_icon(string name, int scale = DEFAULT_ICON_SCALE) {
        Gdk.Pixbuf? pixbuf = load_icon(name, 0);
        if (pixbuf == null)
            return null;
            
        if (scale <= 0)
            return pixbuf;
        
        Gdk.Pixbuf scaled_pixbuf = scale_pixbuf(pixbuf, scale, Gdk.InterpType.BILINEAR, false);
        
        return scaled_pixbuf;
    }*/

    public const string ICON_HOME = "user-home";
    public const string ICON_TRASH = "user-trash";
    public const string ICON_TRASH_FULL = "user-trash-full";
    public const string ICON_NETWORK = "network-workgroup";
    public const string ICON_NETWORK_SERVER = "network-server";
    public const string ICON_FILESYSTEM = "drive-harddisk-system";

    public const string ICON_FOLDER = "folder";
    public const string ICON_FOLDER_REMOTE = "folder-remote";

    public const string ROOT_FS_URI = "file:///";
    public const string TRASH_URI = "trash:///";
    public const string NETWORK_URI = "network:///";
}
