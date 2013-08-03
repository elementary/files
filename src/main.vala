/***
  Copyright (C) 2013 Julián Unrrein <junrrein@gmail.com>

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

const string APP_NAME = "pantheon-files";
const string GETTEXT_PACKAGE = "pantheon-files";

public static int main (string[] args) {
    Gtk.init (ref args);

    /* Initiliaze gettext support */
    Intl.setlocale (LocaleCategory.ALL, Intl.get_language_names ()[0]);
    Intl.textdomain (GETTEXT_PACKAGE);

    Environment.set_application_name (APP_NAME);
    Environment.set_prgname (APP_NAME);

    var application = new Marlin.Application ();

    return application.run (args);
}
