namespace Marlin {
    public class Bookmark {

        public bool has_custom_name = false;
        public signal void contents_changed ();
        public signal void deleted ();

        private string custom_name;
        public string label {
            get {
                    if (custom_name != null)
                        return custom_name;
                    else
                        return this.gof_file.get_display_name ();
            }

            set {
                    if (value != "" && value != custom_name) {
                        custom_name = value;
                        has_custom_name = true;
                    }
            }
        }

        public GOF.File gof_file {get; private set;}
        private GLib.FileMonitor monitor;

        public static CompareFunc<Bookmark> compare_with = (a, b) => {
            return (a.gof_file.location.equal (b.gof_file.location)) && (a.label == b.label) ? 0: 1;
        };

        public static CompareFunc<Bookmark> compare_uris = (a, b) => {
            return a.gof_file.location.equal (b.gof_file.location) ? 0 : 1;
        };

        private Bookmark (GOF.File gof_file, string? label = null) {

            if (label != null)
                this.label = label;

            this.gof_file = gof_file;
            connect_file ();
        }

        public Bookmark.from_uri (string uri, string? label = null) {
            this (GOF.File.get_by_uri (uri), label);
        }

        public Bookmark copy () {
            return new Bookmark.from_uri (this.get_uri (), this.custom_name);
        }

        public unowned GLib.File get_location () {
            return this.gof_file.location;
        }

        public string get_uri () {
            return this.get_location ().get_uri ();
        }

        public unowned GLib.Icon get_icon () {
            if (gof_file.icon == null)
                gof_file.get_folder_icon_from_uri_or_path ();

            return gof_file.icon;
        }

        public bool uri_known_not_to_exist () {

            if (!gof_file.location.is_native ())
                return false;

            string path_name = gof_file.location.get_path ();
            return !GLib.FileUtils.test (path_name, GLib.FileTest.EXISTS);
        }

//        private void set_uri (string new_uri) {
//            if (this.get_uri () == new_uri)
//                return;

//            disconnect_file ();
//            this.gof_file = GOF.File.get_by_uri (new_uri);
//            connect_file ();
//            contents_changed ();
//        }

        private void file_changed_callback (GLib.File file,
                                            GLib.File? other_file,
                                            GLib.FileMonitorEvent event_type) {
            switch (event_type) {
                case GLib.FileMonitorEvent.DELETED:
                        disconnect_file ();
                        deleted ();
                    break;

                case GLib.FileMonitorEvent.MOVED:
                        contents_changed ();
                    break;

                default:
                    break;
            }
        }

        private void disconnect_file () {

            if (monitor != null) {
                monitor.cancel ();
                monitor = null;
            }
        }

        private void connect_file () {
            if (!uri_known_not_to_exist ()) {
                try {
                    monitor = (this.get_location ()).monitor_file (GLib.FileMonitorFlags.SEND_MOVED, null);
                    monitor.changed.connect (file_changed_callback);
                }
                catch (GLib.Error error) {
                    warning ("Error connecting file monitor %s", error.message);
                }
            }
        }
    }
}
