/***
    Copyright (c) 2013 Julián Unrrein <junrrein@gmail.com>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.
***/
public static int main (string[] args) {
    /* Initiliaze gettext support */
    Intl.setlocale (LocaleCategory.ALL, "");
    Intl.textdomain (Config.GETTEXT_PACKAGE);
    Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALE_DIR);
    Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");

    Environment.set_application_name (Config.APP_NAME);
    Environment.set_prgname (Config.APP_NAME);

    var application = new Files.Application ();

    return application.run (args);
}
