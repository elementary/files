/***
    Copyright (c) 2015-2018 elementary LLC <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors :
***/
namespace Files {
    public class ZeitgeistManager : Object {

        const string FILES_ACTOR = "application://" + APP_DESKTOP;
        const string ATTRS = FileAttribute.STANDARD_DISPLAY_NAME + "," + FileAttribute.STANDARD_CONTENT_TYPE;

        public static void report_event (string uri, string interpretation) {
#if HAVE_ZEITGEIST
            var file = GLib.File.new_for_commandline_arg (uri);

            file.query_info_async.begin (ATTRS, 0, Priority.DEFAULT, null, (obj, res) => {
                FileInfo info;
                try {
                    info = file.query_info_async.end (res);
                } catch (Error e) {
                    debug ("Fetching file info folder loggin to zeitgeist failed: %s", e.message);
                    return;
                }
                var log = Zeitgeist.Log.get_default ();

                var subject = new Zeitgeist.Subject ();
                subject.current_uri = subject.uri = uri;
                subject.text = info.get_display_name ();
                subject.mimetype = info.get_content_type ();
                subject.origin = Path.get_dirname (uri);
                subject.manifestation = Zeitgeist.NFO.FILE_DATA_OBJECT;
                subject.interpretation = Zeitgeist.NFO.FOLDER;

                var event = new Zeitgeist.Event ();
                event.interpretation = interpretation;
                event.manifestation = Zeitgeist.ZG.USER_ACTIVITY;
                event.actor = FILES_ACTOR;
                event.timestamp = new DateTime.now_local ().to_unix () * 1000;
                event.add_subject (subject);

                try {
                    log.insert_event_no_reply (event);
                } catch (Error e) {
                    warning (e.message);
                }
            });
#endif
        }
    }
}
