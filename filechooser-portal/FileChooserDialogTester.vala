public class FileChooserDialogTester : Gtk.Application {
    private Gtk.ApplicationWindow window;
    public bool set_filters { get; set; }
    public bool set_choices { get; set; }
    public bool set_multiple { get; set; }

    private Settings filechooser_settings; // Settings specific for the filechooser
    private Settings open_settings; // Settings specific for the filechooser when opening
    private Settings save_settings; // Settings specific for the filechooser when saving
    private Settings app_settings; // Settings from the files app (read only)
    private Settings gnome_interface_settings;
    private Settings gnome_privacy_settings;
    private Settings gtk_file_chooser_settings;

    private Files.Preferences prefs; // Note this gets a separate instance to the app

    public FileChooserDialogTester () {
        Object (
            application_id: "io.elementary.files.filechooserdialog-tester",
            flags: ApplicationFlags.FLAGS_NONE
        );

        filechooser_settings = new Settings ("io.elementary.files.file-chooser"); //Rename to match DBus name?
        open_settings = new Settings ("io.elementary.files.file-chooser.open"); //Rename to match DBus name?
        save_settings = new Settings ("io.elementary.files.file-chooser.save"); //Rename to match DBus name?
        app_settings = new Settings ("io.elementary.files.preferences");
        gnome_interface_settings = new Settings ("org.gnome.desktop.interface");
        gnome_privacy_settings = new Settings ("org.gnome.desktop.privacy");
        gtk_file_chooser_settings = new Settings ("org.gtk.Settings.FileChooser");
        prefs = Files.Preferences.get_default ();
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

        filechooser.set_current_name ("TestDoc.txt");
        filechooser.set_current_folder (Environment.get_home_dir ());

        show_filechooser_widget (filechooser);
    }

    private void on_filechooser_widget_response (Gtk.Dialog filechooser, int id) {
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
        //FileChooser settings
        var open = filechooser.action in (Gtk.FileChooserAction.OPEN | Gtk.FileChooserAction.SELECT_FOLDER);
        var settings = open ? open_settings : save_settings;
        var last_uri = settings.get_string ("last-folder-uri");
        filechooser.set_current_folder_uri (last_uri);


        int width, height;
        filechooser_settings.get ("window-size", "(ii)", out width, out height);
        filechooser.resize (width, height); //Using default-width property does not seem to work in this context.
        filechooser_settings.bind ("sidebar-width", filechooser.file_view, "sidebar-width", DEFAULT);

        //Files app settings (read-only)
        app_settings.bind ("singleclick-select", prefs, "singleclick-select", GET);
        app_settings.bind ("show-hiddenfiles", prefs, "show-hidden-files", GET);
        app_settings.bind ("show-remote-thumbnails", prefs, "show-remote-thumbnails", GET);
        app_settings.bind ("show-local-thumbnails", prefs, "show-local-thumbnails", GET);
        app_settings.bind ("date-format", prefs, "date-format", GET);
        // System settings (read-only)
        gnome_interface_settings.bind ("clock-format", prefs, "clock-format", GET);
        gnome_privacy_settings.bind ("remember-recent-files", prefs, "remember-history", GET);
        // Gtk Filechooser settings (sync)
        gtk_file_chooser_settings.bind ("sort-directories-first", prefs, "sort-directories-first", DEFAULT);

    }

    private void close_dialog (Files.FileChooserDialog filechooser) {
        var open = filechooser.action in (Gtk.FileChooserAction.OPEN | Gtk.FileChooserAction.SELECT_FOLDER);
        var settings = open ? open_settings : save_settings;
        settings.set_string ("last-folder-uri", filechooser.get_current_folder_uri ());

        int w, h;
        filechooser.get_size (out w, out h);
        filechooser_settings.set ("window-size", "(ii)", w, h);
        filechooser.destroy ();
    }

    public static int main (string[] args) {
        var app = new FileChooserDialogTester ();
        return app.run (args);
    }
}
