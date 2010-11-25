[DBus (name = "org.elementary.marlin.db")]
interface CTags : Object {
    //public abstract bool   	showTable	(string table) 	throws IOError;
    public abstract async int 	getColor 	(string uri) 	throws IOError;
    public abstract async bool 	setColor 	(string uri, int color) 	throws IOError;
    public abstract async void 	uris_setColor 	(string[] uris, int color) 	throws IOError;
    public abstract async bool 	deleteEntry	(string uri)	throws IOError;
    //public abstract bool	clearDB		()				throws IOError;
}

namespace Marlin.View {
    public class Tags : Object {

        private CTags tags;

        static string[] tags_colors = { null, "red", "orange", "yellow", "green", "blue", "violet", "gray" };

        public Tags() {
            try {
                tags = Bus.get_proxy_sync (BusType.SESSION, "org.elementary.marlin.db",
                                           "/org/elementary/marlin/db");
            } catch (IOError e) {
                stderr.printf ("%s\n", e.message);
            }
            //run();
        }

        /*public async void run () throws IOError {
                tags = yield Bus.get_proxy_sync (BusType.SESSION, "org.elementary.marlin.db",
                                           "/org/elementary/marlin/db");
        }*/

        public async void uris_set_color (string[] uris, int n) throws IOError {
            yield tags.uris_setColor(uris, n);
        }

        public async void set_color (string uri, int n) throws IOError {
        /*    tags.setColor(uri, n);*/
        //public async void set_color (string uri, int n) {
            //try {
            if (n == 0)
                yield tags.deleteEntry(uri);
            else
                yield tags.setColor(uri, n);
            /*} catch (IOError e) {
                stderr.printf ("%s\n", e.message);
            }*/

        }

        public async void get_color (string uri, GOF.File myfile) throws IOError {
            int n = yield tags.getColor(uri);
            //myfile.color = "red";
            myfile.color = tags_colors[n];
        }

    }
}

/*void main () {
    try {
        Demo demo = Bus.get_proxy_sync (BusType.SESSION, "org.elementary.marlin.db",
                                        "/org/elementary/marlin/db");

        demo.setColor("file:///home/jordi", 3);
        //demo.isFileInDB("file:///home/jordi");
        print("\n\nColor for file is %i\n",   demo.getColor("file:///home/jordi"));
        //demo.deleteEntry("file:///home/jordi");

        //demo.clearDB();

    } catch (IOError e) {
        stderr.printf ("%s\n", e.message);
    }
}
*/
