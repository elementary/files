public class PortalTester : Gtk.Application {
    private Gtk.ApplicationWindow window;
    public bool set_filters { get; set; }
    public bool set_choices { get; set; }
    public bool set_multiple { get; set; }
    public bool use_widget { get; set; }

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
        var widget_option = new Gtk.CheckButton.with_label ("Use Widget not Portal");

        filters_option.bind_property ("active", this, "set-filters");
        choices_option.bind_property ("active", this, "set-choices");
        multiple_option.bind_property ("active", this, "set-multiple");
        widget_option.bind_property ("active", this, "use-widget");

        // bind_property ("set-choices", choices_option, "active");
        // bind_property ("set-multiple", multiple_option, "active");

        var option_grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.VERTICAL,
            row_spacing = 6,
            margin = 6
        };

        option_grid.add (filters_option);
        option_grid.add (choices_option);
        option_grid.add (multiple_option);
        option_grid.add (widget_option);

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
        if (!use_widget) {
            var filechooser = new Gtk.FileChooserNative (
                "Files Portal Tester - OPEN", //Honored by freedesktop portal as window title
                window,
                Gtk.FileChooserAction.OPEN,
                "TestOpen",  // Honored freedesktop portal
                "TestCancel" // Ignored by freedesktop portal
            );

            show_filechooser (filechooser);
        } else {
            var filechooser = new Files.FileChooserDialog (Gtk.FileChooserAction.OPEN, "", "TestOpenWidget");
            show_filechooser_widget (filechooser);
        }
    }

    private void on_select_folder () {
        var filechooser = new Gtk.FileChooserNative (
            "Files Portal Tester - SELECT FOLDER",
            window,
            Gtk.FileChooserAction.SELECT_FOLDER,
            "TestSelect",
            "TestCancel"
        );

        show_filechooser (filechooser);
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
        filechooser.set_current_folder (Environment.get_home_dir ());

        show_filechooser (filechooser);
    }

    private void on_filechooser_response (Gtk.NativeDialog filechooser, int id) {
        switch ((Gtk.ResponseType)id) {
            case ACCEPT:
            case OK:
                var uris = ((Gtk.FileChooser)filechooser).get_uris ();
                var uri_list = "\n";
                foreach (var uri in uris) {
                    uri_list += uri + "\n";
                }

                var choice1 = ((Gtk.FileChooser)filechooser).get_choice ("1");
                var choice2 = ((Gtk.FileChooser)filechooser).get_choice ("2");
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

        filechooser.destroy ();
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

        filechooser.destroy ();
    }

    /* Note:  Gtk.FileChooserNative supports adding choices and sends through portal but does NOT
     * support retrieving the current user choice from the portal again!!  Just returns the value
     * originally set
     */
    private void filechooser_add_choices (Gtk.FileChooserNative filechooser) {
        filechooser.add_choice (
            "1",
            "Combo choice",
            {"1a", "1b", "1c"},
            {"Choice 1a", "Choice 1b", "Choice 1c"}
        );
        filechooser.set_choice ("1", "1c");

        filechooser.add_choice (
            "2",
            "Boolean choice",
            null,
            null
        );
        filechooser.set_choice ("2", "false");

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

    private void filechooser_add_filters (Gtk.FileChooserNative filechooser) {
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

    private void show_filechooser (Gtk.FileChooserNative filechooser) {
        if (set_filters) {
            filechooser_add_filters (filechooser);
        }

        if (set_choices) {
            filechooser_add_choices (filechooser);
        }

        filechooser.set_select_multiple (set_multiple);
        filechooser.response.connect (on_filechooser_response);
        filechooser.show ();
    }

    private void show_filechooser_widget (Files.FileChooserDialog filechooser_widget) {
    warning ("show filechooser widget");
        if (set_filters) {
            filechooser_widget_add_filters (filechooser_widget);
        }

        if (set_choices) {
            filechooser_widget_add_choices (filechooser_widget);
        }

        filechooser_widget.select_multiple = set_multiple;
        filechooser_widget.response.connect (on_filechooser_widget_response);
        filechooser_widget.run ();
        filechooser_widget.destroy ();
    }

    public static int main (string[] args) {
        var app = new PortalTester ();
        return app.run (args);
    }
}
