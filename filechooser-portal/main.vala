void on_file_chooser_bus_acquired (DBusConnection conn, string n) {
    try {
        string name = "/org/freedesktop/portal/desktop";
        var object = new FileChooser (conn);
        conn.register_object (name, object);
        debug ("FileChooser object registered with dbus connection name %s", name);
    } catch (IOError e) {
        error ("Could not register FileChooser service");
    }   
}

extern void exit (int exit_code);

void on_name_lost (DBusConnection connection, string name) {
    critical ("Name %s was not acquired", name);
    exit (-1);
}


void main (string[] args) {
    Gtk.init (ref args);

    Bus.own_name (BusType.SESSION, "org.freedesktop.portal.Desktop", BusNameOwnerFlags.REPLACE,
        on_file_chooser_bus_acquired,
        () => {},
        on_name_lost);

    Gtk.main ();
}
