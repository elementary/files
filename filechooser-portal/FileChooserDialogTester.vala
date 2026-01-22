public class FileChooserDialogTester : Gtk.Application {
    private Gtk.ApplicationWindow window;
    public bool set_filters { get; set; }
    public bool set_choices { get; set; }
    public bool set_multiple { get; set; }

    private Files.Preferences prefs; // Note this gets a separate instance to the app

    public FileChooserDialogTester () {
        Object (
            application_id: "io.elementary.files.filechooserdialog-tester",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }

    protected override void activate () {
        window = new Gtk.ApplicationWindow (this);
        window.set_default_size (400, 400);
        window.title = "Files Dialog Widget Tester";


        var open_file_button = new Gtk.Button.with_label ("Open File"); //FileChooserAction.OPEN
        var open_files_button = new Gtk.Button.with_label ("Open Files"); //FileChooserAction.OPEN with select-multiple
        var select_folder_button = new Gtk.Button.with_label ("Select Folder"); //FileChooserAction.SELECT_FOLDER
        var save_button = new Gtk.Button.with_label ("Save"); //FileChooserAction.SAVE

        var grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.VERTICAL,
            row_spacing = 6,
            margin = 6
        };
        grid.add (open_file_button);
        grid.add (open_files_button);
        grid.add (select_folder_button);
        grid.add (save_button);

        var filters_option = new Gtk.CheckButton.with_label ("Set Filters");
        var choices_option = new Gtk.CheckButton.with_label ("Set Choices");
        var multiple_option = new Gtk.CheckButton.with_label ("Select Multiple");

        filters_option.bind_property ("active", this, "set-filters");
        choices_option.bind_property ("active", this, "set-choices");
        multiple_option.bind_property ("active", this, "set-multiple");

        var option_grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.VERTICAL,
            row_spacing = 6,
            margin = 6
        };

        option_grid.add (filters_option);
        option_grid.add (choices_option);
        option_grid.add (multiple_option);

        var main_box = new Gtk.Box (VERTICAL, 24) {
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER,
        };
        main_box.add (grid);
        main_box.add (option_grid);
        window.add (main_box);

        open_file_button.clicked.connect (on_open_file);
        select_folder_button.clicked.connect (on_select_folder);
        save_button.clicked.connect (on_save_file);

        window.show_all ();
    }

    private void on_open_file () {
        var filechooser = new Files.FileChooserDialog (Gtk.FileChooserAction.OPEN, "", "TestOpenWidget");
        show_filechooser_widget (filechooser);
    }

    private void on_select_folder () {
        var filechooser = new Files.FileChooserDialog (Gtk.FileChooserAction.SELECT_FOLDER, "", "TestSelectFolderWidget");
        show_filechooser_widget (filechooser);
    }

    private void on_save_file () {
        var filechooser = new Files.FileChooserDialog (Gtk.FileChooserAction.SAVE, "", "TestSaveWidget");

        filechooser.set_current_folder (Environment.get_home_dir ());
        filechooser.set_current_name ("TestDoc.txt");

        show_filechooser_widget (filechooser);
    }

    private void on_filechooser_widget_response (Gtk.Dialog filechooser, int id) {
    warning ("on filechooser response");
        switch ((Gtk.ResponseType)id) {
            case ACCEPT:
            case OK:
                var uris = ((Files.FileChooserDialog)filechooser).get_uris ();
                var uri_list = "\n";
                foreach (var uri in uris) {
                    uri_list += uri + "\n";
                }

                var choice1 = ((Files.FileChooserDialog)filechooser).get_choice ("1");
                var choice2 = ((Files.FileChooserDialog)filechooser).get_choice ("2");
                //FIXME FileCooserNative returns the choices originally set!!!
                var choice_list = "Choice 1: %s".printf (choice1) + "\n" + "Choice 2: %s".printf (choice2);

                var message_dialog = new Gtk.MessageDialog (
                    window,
                    Gtk.DialogFlags.MODAL,
                    Gtk.MessageType.INFO,
                    Gtk.ButtonsType.CLOSE,
                    "Selected: %s \nChoices: %s\n",
                    uri_list, choice_list
                );
                message_dialog.run ();
                message_dialog.destroy ();
                break;
            default:
                warning ("Ooops, Save operation cancelled! - response was %s", ((Gtk.ResponseType)id).to_string ());
                break;
        }

        close_dialog ((Files.FileChooserDialog)filechooser);
    }

    private void filechooser_widget_add_choices (Files.FileChooserDialog filechooser) {
        var vb = new VariantBuilder (new VariantType ("a(ss)"));
        vb.add ("(ss)", "1a", "Choice 1a");
        vb.add ("(ss)", "1b", "Choice 1b");
        vb.add ("(ss)", "1c", "Choice 1c");

        filechooser.add_choice (new Files.FileChooserChoice (
            "1",
            "Combo choice",
            vb.end (),
            "1c"
        ));

        filechooser.add_choice (new Files.FileChooserChoice (
            "2",
            "Boolean choice",
            null,
            "true"
        ));
    }

    private void filechooser_widget_add_filters (Files.FileChooserDialog filechooser) {
        var filter1 = new Files.FileFilter ();
        filter1.add_pattern ("*.txt");
        filter1.add_pattern ("*.pdf");
        filter1.add_pattern ("*.doc");
        filter1.name = "TextGlob";

        var filter2 = new Files.FileFilter ();
        filter2.add_mime_type ("text/*");
        filter2.name = "TextMime";

        var filter3 = new Files.FileFilter ();
        filter3.add_pattern ("*.*");
        filter3.add_pattern ("*");
        filter3.name = "All Files";

        filechooser.add_filter (filter1);
        filechooser.add_filter (filter2);
        filechooser.add_filter (filter3);
        filechooser.filter = filter1;
    }

    private void show_filechooser_widget (Files.FileChooserDialog filechooser_widget) {
        set_up_dialog (filechooser_widget);
        if (set_filters) {
            filechooser_widget_add_filters (filechooser_widget);
        }

        if (set_choices) {
            filechooser_widget_add_choices (filechooser_widget);
        }

        filechooser_widget.select_multiple = set_multiple;
        filechooser_widget.response.connect (on_filechooser_widget_response);
        filechooser_widget.run ();
    }

    private void set_up_dialog (Files.FileChooserDialog filechooser) {

    }

    private void close_dialog (Files.FileChooserDialog filechooser) {
        filechooser.destroy ();
    }

    public static int main (string[] args) {
        var app = new FileChooserDialogTester ();
        return app.run (args);
    }
}
