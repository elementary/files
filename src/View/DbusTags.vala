[DBus (name = "org.elementary.marlin.db")]
interface CTags : Object {
    //public abstract bool   	showTable	(string table) 	throws IOError;
    public abstract async int 	getColor 	(string uri) 	throws IOError;
    public abstract async bool 	setColor 	(string uri, int color) 	throws IOError;
    //public abstract async void 	uris_setColor 	(string[] uris, int color) 	throws IOError;
    public abstract async bool 	deleteEntry	(string uri)	throws IOError;
    //public abstract bool	clearDB		()				throws IOError;
}

namespace Marlin.View {
    public class Tags : Object {

        private CTags tags;

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

        /*public async void uris_set_color (string[] uris, int n) throws IOError {
            yield tags.uris_setColor(uris, n);
        }*/

        public async void set_color (string uri, int n) throws IOError {
            if (n == 0)
                yield tags.deleteEntry(uri);
            else
                yield tags.setColor(uri, n);
        }

        public async void get_color (string uri, GOF.File myfile) throws IOError {
            if (myfile == null) 
                return;
            int n = yield tags.getColor(uri);
            myfile.color = Preferences.tags_colors[n];            
        }

    }
}

