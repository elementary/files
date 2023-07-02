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

        var main_loop = new GLib.MainLoop ();
        var buttons = new GLib.List<string> ();
        for (unowned string? title = varargs.arg<string?> (); title != null ; title = varargs.arg<string?> ()) {
            buttons.append (title);
        }

        Idle.add (() => {
            var dialog = new Granite.MessageDialog.with_image_from_icon_name (primary_text,
                                                                              secondary_text,
                                                                              image_name,
                                                                              Gtk.ButtonsType.NONE);
            dialog.transient_for = parent_window;
            int response_id = 0;
            foreach (unowned string title in buttons) {
                unowned Gtk.Widget button = dialog.add_button (title, response_id);
                if (title == DELETE || title == DELETE_ALL || title == EMPTY_TRASH) {
                    button.add_css_class (Granite.STYLE_CLASS_DESTRUCTIVE_ACTION);
                }

                response_id++;
            }

            if (response_id == 0) {
                dialog.add_button (_("Close"), 0);
            }

            //FIXME: Granite.MessageDialog.show_error_details call Gtk.Widget.show_all ()
            // which breaks the current implementation in marlin-file-operation.c
            // as the dialog is being created in a thread but presented in the
            // Gtk thread. Remove the Idle.add once everything is done in the Gtk thread.
            if (details_text != null) {
                dialog.show_error_details (details_text);
            }

            dialog.response.connect ((response_id) => {
                result = response_id;
                main_loop.quit ();
                dialog.destroy ();
            });

            dialog.present ();
            return Source.REMOVE;
        });

        main_loop.run ();
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
        string? _new_name = null;
        bool _apply_to_all = false;

        time.stop ();
        info.pause ();

        var main_loop = new GLib.MainLoop (MainContext.get_thread_default ());

        Idle.add (() => {
            var dialog = new Files.FileConflictDialog (parent_window, src, dest, dest_dir);
            dialog.response.connect ((response_id) => {
                result = response_id;
                _apply_to_all = dialog.apply_to_all;
                if (response_id == Files.FileConflictDialog.ResponseType.RENAME) {
                    _new_name = dialog.new_name;
                }
                main_loop.quit ();
                dialog.destroy ();
            });

            dialog.show ();
            return Source.REMOVE;
        });

        main_loop.run ();

        new_name = _new_name;
        apply_to_all = _apply_to_all;
        info.resume ();
        time.continue ();
        return result;
    }
}
