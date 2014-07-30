
namespace Marlin {
    public class ZeitgeistManager : Object {
        const string FILES_ACTOR = "application://pantheon-files.desktop";
        const string ATTRS = FileAttribute.STANDARD_DISPLAY_NAME + "," + FileAttribute.STANDARD_CONTENT_TYPE;

        public static void report_event (string uri, string interpretation) {
            var file = File.new_for_commandline_arg (uri);

            file.query_info_async (ATTRS, 0, Priority.DEFAULT, null, (obj, res) => {
                FileInfo info;
                try {
                    info = file.query_info_async.end (res);
                } catch (Error e) {
                    warning ("Fetching file info folder loggin to zeitgeist failed: %s", e.message);
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
        }
    }
}

