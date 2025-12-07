public class PortalTester : Gtk.Application {
    private Gtk.ApplicationWindow window;

    public PortalTester () {
        Object (
            application_id: "io.elementary.Files.PortalTester",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }

    protected override void activate () {
        window = new Gtk.ApplicationWindow (this);
        window.set_default_size (400, 400);
        window.title = "Files Portal Tester";

        var grid = new Gtk.Grid () {
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER,
            orientation = Gtk.Orientation.VERTICAL,
            row_spacing = 6,
            margin = 6
        };
        var open_file_button = new Gtk.Button.with_label ("Open File"); //FileChooserAction.OPEN
        var open_files_button = new Gtk.Button.with_label ("Open Files"); //FileChooserAction.OPEN with select-multiple
        var select_folder_button = new Gtk.Button.with_label ("Select Folder"); //FileChooserAction.SELECT_FOLDER
        var save_button = new Gtk.Button.with_label ("Save"); //FileChooserAction.SAVE

        grid.add (open_file_button);
        grid.add (open_files_button);
        grid.add (select_folder_button);
        grid.add (save_button);

        window.add (grid);

        open_file_button.clicked.connect (on_open_file);
        open_file_button.clicked.connect (on_open_files);
        select_folder_button.clicked.connect (on_select_folder);
        save_button.clicked.connect (on_save_file);

        window.show_all ();
    }

    private void on_open_files () {
        on_open_file_or_files (true);
    }

    private void on_open_file () {
        on_open_file_or_files (false);
    }

    private void on_open_file_or_files (bool multiple) {
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

        var filechooser = new Gtk.FileChooserNative (
            "Files Portal Tester - OPEN", //Honored by freedesktop portal as window title
            window,
            Gtk.FileChooserAction.OPEN,
            "TestOpen",  // Honored freedesktop portal
            "TestCancel" // Ignored by freedesktop portal
        );

        filechooser.set_select_multiple (multiple);
        filechooser.add_filter (filter1);
        filechooser.add_filter (filter2);
        filechooser.add_filter (filter3);
        filechooser.filter = filter1;
        filechooser.response.connect ((id) => {
            if (id == Gtk.ResponseType.ACCEPT) {
                warning ("OPEN response accept");
                var path = filechooser.get_file ().get_path ();
                var message_dialog = new Gtk.MessageDialog (
                    window,
                    Gtk.DialogFlags.MODAL,
                    Gtk.MessageType.INFO,
                    Gtk.ButtonsType.CLOSE,
                    "This file has been selected: %s",
                    path
                );
                message_dialog.run ();
                message_dialog.destroy ();
            } else {
                warning ("Ooops, operation cancelled! - OPEN response was %s", ((Gtk.ResponseType)id).to_string ());
            }
            filechooser.destroy ();
        });

        filechooser.show ();
    }

    private void on_select_folder () {
        var filechooser = new Gtk.FileChooserNative (
            "Files Portal Tester - SELECT FOLDER",
            window,
            Gtk.FileChooserAction.SELECT_FOLDER,
            "TestSelect",
            "TestCancel"
        );

        // Filechooser should only display folders, single selection

        filechooser.response.connect ((id) => {
            if (id == Gtk.ResponseType.ACCEPT) {
                warning ("SELECT response accept");
                var message_dialog = new Gtk.MessageDialog (
                    window,
                    Gtk.DialogFlags.MODAL,
                    Gtk.MessageType.INFO,
                    Gtk.ButtonsType.CLOSE,
                    "This folder has been selected: %s",
                    filechooser.get_file ().get_path ()
                );
                message_dialog.run ();
                message_dialog.destroy ();
            } else {
                warning ("Ooops, Select operation cancelled! - response was %s", id.to_string ());
            }

            filechooser.destroy ();
        });

        filechooser.show ();
    }

    private void on_save_file () {
        var filechooser = new Gtk.FileChooserNative (
            "Files Portal Tester - SAVE",
            window,
            Gtk.FileChooserAction.SAVE,
            "TestSave",
            "TestCancel"
        );

        filechooser.set_current_name ("TestDoc.txt");
        //TODO Allow entry of file basename
        var current_folder = Environment.get_home_dir ();
        //TODO Allow entry of folder path
        filechooser.set_current_folder (current_folder);

        filechooser.response.connect ((id) => {
            switch ((Gtk.ResponseType)id) {
                case ACCEPT:
                case OK:
                    warning ("Save response ACCEPT");
                    var message_dialog = new Gtk.MessageDialog (
                        window,
                        Gtk.DialogFlags.MODAL,
                        Gtk.MessageType.INFO,
                        Gtk.ButtonsType.CLOSE,
                        "This file has been saved: %s",
                        filechooser.get_file ().get_path ()
                    );
                    message_dialog.run ();
                    message_dialog.destroy ();
                    break;
                default:
                    warning ("Ooops, Save operation cancelled! - response was %s", ((Gtk.ResponseType)id).to_string ());
                    break;
            }

            filechooser.destroy ();
        });

        filechooser.show ();
    }


    public static int main (string[] args) {
        var app = new PortalTester ();
        return app.run (args);
    }
}
