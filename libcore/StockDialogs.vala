/* Copyright (c) 2018-19 elementary LLC (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, Inc.,; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

/* Common dialog buttons */
public const string CANCEL = _("_Cancel");
public const string DELETE = _("Delete");
public const string SKIP = _("_Skip");
public const string SKIP_ALL = _("S_kip All");
public const string RETRY = _("_Retry");
public const string DELETE_ALL = _("Delete _All");
public const string REPLACE = _("_Replace");
public const string REPLACE_ALL = _("Replace _All");
public const string MERGE = _("_Merge");
public const string MERGE_ALL = _("Merge _All");
public const string COPY_FORCE = _("Copy _Anyway");
public const string EMPTY_TRASH = _("Empty _Trash");

namespace Marlin {
    public struct RunSimpleDialogData {
        unowned Gtk.Window parent_window;
        bool ignore_close_box;
        Gtk.MessageType message_type;
        string primary_text;
        string secondary_text;
        unowned string? details_text;
        string[] button_titles;
        bool show_all;
        int result;
    }
}

namespace PF.Dialogs {
    public Granite.MessageDialog show_error_dialog (string primary_text,
                                                    string secondary_text,
                                                    Gtk.Window? parent) {
        /* Use default button type "CLOSE" */
        var dialog = new Granite.MessageDialog.with_image_from_icon_name (primary_text, secondary_text, "dialog-error");
        return display_dialog (dialog, parent);
    }

    public Granite.MessageDialog show_warning_dialog (string primary_text,
                                                      string secondary_text,
                                                      Gtk.Window? parent) {
        /* Use default button type "CLOSE" */
        var dialog = new Granite.MessageDialog.with_image_from_icon_name (primary_text, secondary_text,
                                                                          "dialog-warning");
        return display_dialog (dialog, parent);
    }

    private Granite.MessageDialog display_dialog (Granite.MessageDialog dialog, Gtk.Window? parent) {
        if (parent != null && parent is Gtk.Window) {
            dialog.set_transient_for (parent);
        }

        dialog.response.connect_after (() => {
            dialog.destroy ();
        });

        dialog.show ();
        return dialog;
    }

    public Gtk.Dialog get_simple_file_operation_dialog (Marlin.RunSimpleDialogData data) {
        unowned string image_name;
        switch (data.message_type) {
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

        var dialog = new Granite.MessageDialog.with_image_from_icon_name (data.primary_text,
                                                                          data.secondary_text,
                                                                          image_name,
                                                                          Gtk.ButtonsType.NONE);
        dialog.transient_for = data.parent_window as Gtk.Window;
        if (data.button_titles.length == 0) {
            dialog.add_button (_("Close"), 0);
        } else {
            var response_id = 0;
            foreach (unowned string title in data.button_titles) {
                dialog.add_button (title, response_id);
                if (title == DELETE || title == DELETE_ALL || title == EMPTY_TRASH) {
                    var button = dialog.get_widget_for_response (response_id);
                    button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
                }
                response_id++;
            };
        }

        if (data.details_text != null) {
            dialog.show_error_details (data.details_text);
        }

        return dialog;
    }
}
