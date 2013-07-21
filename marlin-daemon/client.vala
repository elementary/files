[DBus (name = "org.elementary.marlin.db")]
interface Demo : Object {
    public abstract bool   	showTable	(string table) 	throws IOError;
    public abstract int 	getColor 	(string uri) 	throws IOError;
    public abstract bool 	setColor 	(string uri, int color) 	throws IOError;
    public abstract bool 	deleteEntry	(string uri)	throws IOError;
    public abstract bool	clearDB		()				throws IOError;
}

void main () {
    try {
        Demo demo = Bus.get_proxy_sync (BusType.SESSION, "org.elementary.marlin.db",
                                        "/org/elementary/marlin/db");

        //demo.setColor("file:///home/jordi", 3);
        //demo.isFileInDB("file:///home/jordi");
        //print("\n\nColor for file is %i\n",   demo.getColor("file:///home/jordi"));
        //demo.deleteEntry("file:///home/jordi");
        //demo.clearDB();
        demo.showTable ("tags");

        //demo.clearDB();

    } catch (IOError e) {
        stderr.printf ("%s\n", e.message);
    }
}
