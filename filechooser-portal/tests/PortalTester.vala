public class PortalTester : Gtk.Application {
    public PortalTester () {
        Object (
            application_id: "io.elementary.Files.PortalTester",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }

    protected override void activate () {
        var window = new Gtk.ApplicationWindow (this);
        window.set_default_size (400, 400);
        window.title = "Files Portal Tester";

        var grid = new Gtk.Box (VERTICAL, 6) {
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER
        };
        var open_file_button = new Gtk.Button.with_label ("Open File");
        var open_folder_button = new Gtk.Button.with_label ("Open Folder");
        var save_button = new Gtk.Button.with_label ("Save");

        grid.append (open_file_button);
        grid.append (open_folder_button);
        grid.append (save_button);

        window.child = grid;

        open_file_button.clicked.connect (() => {
            var filechooser = new Gtk.FileChooserNative ("Custom Title", window, Gtk.FileChooserAction.OPEN, "Open", "Not Open");
            filechooser.response.connect ((id) => {
                if (id == Gtk.ResponseType.ACCEPT) {
                    var message_dialog = new Gtk.MessageDialog (
                        window,
                        Gtk.DialogFlags.MODAL,
                        Gtk.MessageType.INFO,
                        Gtk.ButtonsType.CLOSE,
                        "This file has been opened: %s",
                        filechooser.get_file ().get_path ()
                    );
                } else {
                    warning ("Ooops, operation cancelled!");
                }
            });
            filechooser.present ();
        });

        open_folder_button.clicked.connect (() => {
            var filechooser = new Gtk.FileChooserNative ("Custom Title", window, Gtk.FileChooserAction.SELECT_FOLDER, "Open Folder", "Not Open");
            filechooser.response.connect ((id) => {
                if (id == Gtk.ResponseType.ACCEPT) {
                    string? paths = null;
                    filechooser.get_files ().foreach ((file) => { paths = string.join (", ", file.get_path (), paths); });
                    var message_dialog = new Gtk.MessageDialog (
                        window,
                        Gtk.DialogFlags.MODAL,
                        Gtk.MessageType.INFO,
                        Gtk.ButtonsType.CLOSE,
                        "These files have been opened: %s",
                        paths
                    );
                } else {
                    warning ("Ooops, operation cancelled!");
                }

                message_dialog.present ();
            });
            filechooser.present ();
        });

        save_button.clicked.connect (() => {
            var filechooser = new Gtk.FileChooserNative ("Custom Title", window, Gtk.FileChooserAction.SAVE, "Save", "No thanks!");
            filechooser.response.connect ((id) => {
                if (id == Gtk.ResponseType.ACCEPT) {
                    var message_dialog = new Gtk.MessageDialog (
                        window,
                        Gtk.DialogFlags.MODAL,
                        Gtk.MessageType.INFO,
                        Gtk.ButtonsType.CLOSE,
                        "This file has been saved: %s",
                        filechooser.get_file ().get_path ()
                    );
                } else {
                    warning ("Ooops, operation cancelled!");
                }
            });
            filechooser.present ();
        });
    }

    public static int main (string[] args) {
        var app = new PortalTester ();
        return app.run (args);
    }
}
