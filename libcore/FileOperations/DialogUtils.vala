namespace PF {
    private static int run_simple_dialog_va (Gtk.Window? parent_window,
                                             GLib.Timer time,
                                             PF.Progress.Info info,
                                             Gtk.MessageType message_type,
                                             owned string primary_text,
                                             owned string secondary_text,
                                             string? details_text,
                                             bool show_all,
                                             va_list varargs) {
        int result = 0;
        time.stop ();
        info.pause ();

        unowned string image_name;
        switch (message_type) {
            case Gtk.MessageType.ERROR:
                image_name = "dialog-error";
                break;
            case Gtk.MessageType.WARNING:
                image_name = "dialog-warning";
                break;
            case Gtk.MessageType.QUESTION:
                image_name = "dialog-question";
                break;
            default:
                image_name = "dialog-information";
                break;
        }

        var dialog = new Granite.MessageDialog.with_image_from_icon_name (primary_text,
                                                                          secondary_text,
                                                                          image_name,
                                                                          Gtk.ButtonsType.NONE);
        dialog.transient_for = parent_window;

        int response_id = 0;
        for (unowned string? title = varargs.arg<string?> (); title != null ; title = varargs.arg<string?> ()) {
            dialog.add_button (title, response_id);
            if (title == DELETE || title == DELETE_ALL || title == EMPTY_TRASH) {
                unowned Gtk.Widget button = dialog.get_widget_for_response (response_id);
                button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
            }

            response_id++;
        }

        if (response_id == 0) {
            dialog.add_button (_("Close"), 0);
        }

        var main_loop = new GLib.MainLoop ();
        dialog.response.connect ((response_id) => {
            result = response_id;
            main_loop.quit ();
        });

        Idle.add (() => {
            //FIXME: Granite.MessageDialog.show_error_details call Gtk.Widget.show_all ()
            // which breaks the current implementation in marlin-file-operation.c
            // as the dialog is being created in a thread but presented in the
            // Gtk thread. Remove the Idle.add once everything is done in the Gtk thread.
            if (details_text != null) {
                dialog.show_error_details (details_text);
            }

            dialog.show_all ();
            return Source.REMOVE;
        });

        main_loop.run ();
        dialog.destroy ();
        info.resume ();
        time.continue ();
        return result;
    }

    public static int run_error (Gtk.Window? parent_window,
                                 GLib.Timer time,
                                 PF.Progress.Info info,
                                 owned string primary_text,
                                 owned string secondary_text,
                                 string? details_text,
                                 bool show_all,
                                 ...) {
        return run_simple_dialog_va (parent_window,
                                     time,
                                     info,
                                     Gtk.MessageType.ERROR,
                                     (owned) primary_text,
                                     (owned) secondary_text,
                                     details_text,
                                     show_all,
                                     va_list ());
    }

    public static int run_warning (Gtk.Window? parent_window,
                                   GLib.Timer time,
                                   PF.Progress.Info info,
                                   owned string primary_text,
                                   owned string secondary_text,
                                   string? details_text,
                                   bool show_all,
                                   ...) {
        return run_simple_dialog_va (parent_window,
                                     time,
                                     info,
                                     Gtk.MessageType.WARNING,
                                     (owned) primary_text,
                                     (owned) secondary_text,
                                     details_text,
                                     show_all,
                                     va_list ());
    }

    public static int run_question (Gtk.Window? parent_window,
                                    GLib.Timer time,
                                    PF.Progress.Info info,
                                    owned string primary_text,
                                    owned string secondary_text,
                                    string? details_text,
                                    bool show_all,
                                    ...) {
        return run_simple_dialog_va (parent_window,
                                     time,
                                     info,
                                     Gtk.MessageType.QUESTION,
                                     (owned) primary_text,
                                     (owned) secondary_text,
                                     details_text,
                                     show_all,
                                     va_list ());
    }

    public static int run_conflict_dialog (Gtk.Window? parent_window,
                                           GLib.Timer time,
                                           PF.Progress.Info info,
                                           GLib.File src,
                                           GLib.File dest,
                                           GLib.File dest_dir,
                                           out string? new_name,
                                           out bool apply_to_all) {
        int result = 0;
        time.stop ();
        info.pause ();

        var dialog = new Marlin.FileConflictDialog (parent_window, src, dest, dest_dir);
        var main_loop = new GLib.MainLoop ();

        string? _new_name = null;
        bool _apply_to_all = false;
        dialog.response.connect ((response_id) => {
            result = response_id;
            switch (response_id) {
                case Marlin.FileConflictDialog.ResponseType.RENAME:
                    _new_name = dialog.new_name;
                    break;
                case Gtk.ResponseType.CANCEL:
                case Gtk.ResponseType.NONE:
                    break;
                default:
                    _apply_to_all = dialog.apply_to_all;
                    break;
            }

            main_loop.quit ();
        });

        Idle.add (() => {
            dialog.show ();
            return Source.REMOVE;
        });

        main_loop.run ();
        dialog.destroy ();
        new_name = _new_name;
        apply_to_all = _apply_to_all;
        info.resume ();
        time.continue ();
        return result;
    }
}
