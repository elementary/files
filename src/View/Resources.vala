namespace Marlin {
    public const string APP_TITLE = "Files";
    public const string COPYRIGHT = APP_YEARS + " Marlin Developers";
    public const string APP_YEARS = "2010-2015";
    public const string LAUNCHPAD_LABEL = "Website";
    public const string LAUNCHPAD_URL = "http://launchpad.net/pantheon-files";
    public const string HELP_URL = "https://answers.launchpad.net/pantheon-files";
    public const string BUG_URL = "https://bugs.launchpad.net/pantheon-files/+filebug";
    public const string TRANSLATE_URL = "https://translations.launchpad.net/pantheon-files";
    public const string COMMENTS = _("A simple and powerful file manager");

    public const string[] AUTHORS = {
        "ammonkey <am.monkeyd@gmail.com>",
        "Lucas Baudin <xapantu@gmail.com>",
        "Mathijs Henquet <mathijs.henquet@gmail.com>",
        "Robert Roth",
        "Vadim Rutkovsky",
        "Rico Tzschichholz",
        "Mario Guerriero <mario@elementaryos.org>",
        "Jeremy Wootten <jeremy@elementaryos.org>",
        null
    };

    public const string[] ARTISTS = {
        "Daniel Foré <daniel.p.fore@gmail.com>",
        null
    };

    public const string TRANSLATORS = _("Launchpad Translators");

    public const string ICON_ABOUT_LOGO = "system-file-manager";
    public const string ICON_FILESYSTEM = "drive-harddisk-system";
    public const string ICON_FILESYSTEM_SYMBOLIC = "drive-harddisk-symbolic";
    public const string ICON_FOLDER = "folder";
    public const string ICON_FOLDER_DOCUMENTS_SYMBOLIC = "folder-documents-symbolic";
    public const string ICON_FOLDER_DOWNLOADS_SYMBOLIC = "folder-download-symbolic";
    public const string ICON_FOLDER_MUSIC_SYMBOLIC = "folder-music-symbolic";
    public const string ICON_FOLDER_PICTURES_SYMBOLIC = "folder-pictures-symbolic";
    public const string ICON_FOLDER_REMOTE = "folder-remote";
    public const string ICON_FOLDER_REMOTE_SYMBOLIC = "folder-remote-symbolic";
    public const string ICON_FOLDER_TEMPLATES_SYMBOLIC = "folder-templates-symbolic";
    public const string ICON_FOLDER_VIDEOS_SYMBOLIC = "folder-videos-symbolic";
    public const string ICON_GO_HOME_SYMBOLIC = "go-home-symbolic";
    public const string ICON_HOME = "user-home";
    public const string ICON_NETWORK = "network-workgroup";
    public const string ICON_NETWORK_SERVER = "network-server";
    public const string ICON_TRASH = "user-trash";
    public const string ICON_TRASH_FULL = "user-trash-full";
    public const string ICON_TRASH_SYMBOLIC = "user-trash-symbolic";
    public const string ICON_RECENT = "document-open-recent";
    public const string ICON_RECENT_SYMBOLIC = "document-open-recent-symbolic";

    public const string TRASH_URI = "trash:///";
    public const string NETWORK_URI = "network:///";
    public const string RECENT_URI = "recent:///";

    public const string OPEN_IN_TERMINAL_DESKTOP_ID = "open-pantheon-terminal-here.desktop";

    public const string PROTOCOL_NAME_AFP = _("AFP");
    public const string PROTOCOL_NAME_DAV = _("DAV");
    public const string PROTOCOL_NAME_DAVS = _("DAVS");
    public const string PROTOCOL_NAME_FTP = _("FTP");
    public const string PROTOCOL_NAME_NETWORK = _("Network");
    public const string PROTOCOL_NAME_SFTP = _("SFTP");
    public const string PROTOCOL_NAME_SMB = _("SMB");
    public const string PROTOCOL_NAME_TRASH = _("Trash");
    public const string PROTOCOL_NAME_RECENT = _("Recent");

    public string protocol_to_name (string protocol) {
        /* Deal with protocol with or without : or / characters at the end */
        string s = protocol.delimit (":/", ' ').chomp ();

        switch (s) {
            case "recent":
                return Marlin.PROTOCOL_NAME_RECENT;
            case "trash":
                return Marlin.PROTOCOL_NAME_TRASH;
            case "network":
                return Marlin.PROTOCOL_NAME_NETWORK;
            case "smb": 
                return Marlin.PROTOCOL_NAME_SMB;
            case "ftp": 
                return Marlin.PROTOCOL_NAME_FTP;
            case "sftp": 
                return Marlin.PROTOCOL_NAME_SFTP;
            case "afp":
                return Marlin.PROTOCOL_NAME_AFP;
            case "dav":
                return Marlin.PROTOCOL_NAME_DAV;
            case "davs":
                return Marlin.PROTOCOL_NAME_DAVS;
            default:
                return protocol;
        }
    }

    public string get_smb_share_from_uri (string uri) {
        if (!(Uri.parse_scheme (uri) == "smb"))
            return (uri);

        string [] uri_parts = uri.split (Path.DIR_SEPARATOR_S);

        if (uri_parts.length < 4)
            return uri;
        else {
            var sb = new StringBuilder ();
            for (int i = 0; i < 4; i++)
                sb.append (uri_parts [i] + Path.DIR_SEPARATOR_S);

            return sb.str;
        }
    }
}
