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

        var grid = new Gtk.Grid () {
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER,
            orientation = Gtk.Orientation.VERTICAL,
            row_spacing = 6,
            margin = 6
        };
        var open_file_button = new Gtk.Button.with_label ("Open File");
        var open_folder_button = new Gtk.Button.with_label ("Open Folder");
        var save_button = new Gtk.Button.with_label ("Save");

        grid.add (open_file_button);
        grid.add (open_folder_button);
        grid.add (save_button);

        window.add (grid);

        var filter1 = new Gtk.FileFilter ();
        filter1.add_pattern ("*.txt");
        filter1.add_pattern ("*.pdf");
        filter1.add_pattern ("*.doc");
        filter1.set_filter_name ("TextGlob");

        var filter2 = new Gtk.FileFilter ();
        filter2.add_mime_type ("text/*");
        filter2.set_filter_name ("TextMime");

        var filter3 = new Gtk.FileFilter ();
        filter3.add_pattern ("*.*");
        filter3.add_pattern ("*");
        filter3.set_filter_name ("All Files");

        open_file_button.clicked.connect (() => {
            var filechooser = new Gtk.FileChooserNative ("Custom Title", window, Gtk.FileChooserAction.OPEN, "Open", "Not Open");
            filechooser.add_filter (filter1);
            filechooser.add_filter (filter2);
            filechooser.add_filter (filter3);
            filechooser.filter = filter1;
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
                    message_dialog.run ();
                    message_dialog.destroy ();
                } else {
                    warning ("Ooops, operation cancelled!");
                }
            });

            filechooser.show ();
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
                    message_dialog.run ();
                    message_dialog.destroy ();
                } else {
                    warning ("Ooops, operation cancelled!");
                }
            });

            filechooser.show ();
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
                    ) {
                        modal = true
                    };
                    message_dialog.show_all ();
                    message_dialog.destroy ();
                } else {
                    warning ("Ooops, operation cancelled!");
                }
            });

            filechooser.show ();
        });

        window.show_all ();
    }

    public static int main (string[] args) {
        var app = new PortalTester ();
        return app.run (args);
    }
}
