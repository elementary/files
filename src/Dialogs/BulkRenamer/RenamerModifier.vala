/*
 * Copyright (C) 2019-2022 elementary LLC. <https://elementary.io>
 *
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *  Authors:
 *  Jeremy Wootten <jeremywootten@gmail.com>
 *
*/

public class Files.RenamerModifier : Object {
    static int modifier_id = 0;

    protected class EditWidget : Gtk.Bin {
        public RenamerModifier modifier { get; construct; }

        public EditWidget (RenamerModifier modifier) {
            Object (
                modifier: modifier
            );
        }

        construct {
            var grid = new Gtk.Grid () {
                column_homogeneous = true,
                column_spacing = 6,
                row_spacing = 6,
                margin = 12
            };
            Gtk.Widget controls;
            var flags = BindingFlags.DEFAULT;
            switch (modifier.mode) {
                case RenameMode.NUMBER:
                    var start_number_label = new Gtk.Label (_("Start Number")) {
                        halign = Gtk.Align.END
                    };
                    var start_number_spin_button = new Gtk.SpinButton.with_range (0, int.MAX, 1) {
                        halign = Gtk.Align.START,
                        value = modifier.start
                    };

                    var digits_label = new Gtk.Label (_("Digits")) {
                        halign = Gtk.Align.END
                    };

                    var digits_spin_button = new Gtk.SpinButton.with_range (1, int.MAX, 1) {
                        halign = Gtk.Align.START,
                        value = modifier.digits
                    };

                    var number_grid = new Gtk.Grid () {
                        column_homogeneous = true,
                        column_spacing = 6,
                        row_spacing = 6
                    };
                    number_grid.attach (start_number_label, 0, 0);
                    number_grid.attach (start_number_spin_button, 1, 0);
                    number_grid.attach (digits_label, 0, 1);
                    number_grid.attach (digits_spin_button, 1, 1);
                    controls = number_grid;

                    digits_spin_button.bind_property ("value", modifier, "digits", flags);
                    start_number_spin_button.bind_property ("value", modifier, "start", flags);

                    break;
                case RenameMode.DATETIME:
                    var date_source_combo = new Gtk.ComboBoxText () {
                        valign = Gtk.Align.CENTER,
                        active = modifier.source
                    };
                    date_source_combo.insert (RenameDateSource.DEFAULT, "DEFAULT",
                                              RenameDateSource.DEFAULT.to_string ());
                    date_source_combo.insert (RenameDateSource.MODIFIED, "MODIFICATION_DATE",
                                              RenameDateSource.MODIFIED.to_string ());
                    date_source_combo.insert (RenameDateSource.NOW, "CURRENT_DATE",
                                              RenameDateSource.NOW.to_string ());

                    var date_format_combo = new Gtk.ComboBoxText () {
                        valign = Gtk.Align.CENTER,
                        active = modifier.format
                    };
                    date_format_combo.insert (RenameDateFormat.DEFAULT, "DEFAULT",
                                              RenameDateFormat.DEFAULT.to_string ());

                    date_format_combo.insert (RenameDateFormat.DEFAULT_DATETIME, "DEFAULT_DATETIME",
                                              RenameDateFormat.DEFAULT_DATETIME.to_string ());

                    date_format_combo.insert (RenameDateFormat.LOCALE, "LOCALE",
                                              RenameDateFormat.LOCALE.to_string ());

                    date_format_combo.insert (RenameDateFormat.ISO_DATE, "ISO_DATE",
                                              RenameDateFormat.ISO_DATE.to_string ());

                    date_format_combo.insert (RenameDateFormat.ISO_DATETIME, "ISO_DATETIME",
                                              RenameDateFormat.ISO_DATETIME.to_string ());

                    var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
                    box.add (date_source_combo);
                    box.add (date_format_combo);
                    controls = box;

                    date_source_combo.bind_property ("active", modifier, "source", flags);
                    date_format_combo.bind_property ("active", modifier, "format", flags);

                    break;
                case RenameMode.TEXT:
                    var text_entry = new Gtk.Entry () {
                        vexpand = false,
                        hexpand = false,
                        max_length = 64,
                        max_width_chars = 15,
                        text = modifier.text
                    };
                    controls = text_entry;
                    text_entry.bind_property ("text", modifier, "text", flags);

                    break;
                default:
                    assert_not_reached ();
                    break;
            };

            var separator_entry = new Gtk.Entry () {
                halign = Gtk.Align.START,
                max_length = 3,
                text = modifier.separator
            };

            var separator_label = new Gtk.Label (_("Separator")) {
                halign = Gtk.Align.END,
            };

            separator_entry.bind_property ("text", modifier, "separator", flags);

            grid.attach (separator_label, 0, 0);
            grid.attach (separator_entry, 1, 0);
            grid.attach (controls, 0, 1, 2, 1);
            add (grid);
            show_all ();
        }
    }

    /* -------------------------------end of Edit Widget class----------------------------*/
    private const int DEFAULT_DIGITS = 1;
    private const int DEFAULT_START = 1;

    public EditWidget? edit_widget { get; private set; default = null; }
    public RenameMode mode { get; construct; }
    public RenamePosition pos  { get; construct; }

    public int start { get; set; default = 1;}
    public int digits { get; set; default = 1;}
    public int source { get; set; default = 0;}
    public int format { get; set; default = 0;}
    public int id { get; construct; }
    public string text { get; set; default = "";}
    public string separator { get; set; default = "-";}

    public signal void update_request ();

    public RenamerModifier.default_number (RenamePosition pos) {
        Object (
            mode: RenameMode.NUMBER,
            pos: pos
        );
    }

    public RenamerModifier.default_date (RenamePosition pos) {
        Object (
            mode: RenameMode.DATETIME,
            pos: pos
        );
    }

    public RenamerModifier.default_text (RenamePosition pos) {
        Object (
            mode: RenameMode.TEXT,
            pos: pos
        );
    }

    construct {
        id = modifier_id++;
    }

    public unowned Gtk.Widget get_modifier_widget () {
        if (edit_widget == null) {
            edit_widget = new EditWidget (this);
        }

        return edit_widget;
    }

    public string rename (string input, int index, Files.File file) {
        string new_text = "";
        switch (mode) {
            case RenameMode.NUMBER:
                if (start >= 0 && digits >= 0) {
                    var template = "%%0%id".printf (digits);
                    new_text = template.printf (index + start);
                } else {
                    critical ("Invalid start number %i or digits %i", start, digits);
                }
                break;

            case RenameMode.TEXT:
                new_text = text;
                break;

            case RenameMode.DATETIME:
                uint64 dt;
                switch (source) {
                    case RenameDateSource.MODIFIED:
                        dt = file.modified;
                        break;
                    case RenameDateSource.NOW:
                        dt = (uint64)get_monotonic_time ();
                        break;
                    default: // Created
                        dt = file.info.get_attribute_uint64 (GLib.FileAttribute.TIME_CREATED);
                        break;
                }

                new_text = get_formated_datetime (dt);
                break;

            default:
                break;
        }

        switch (pos) {
            case RenamePosition.SUFFIX:
                return input.concat (separator, new_text);

            case RenamePosition.PREFIX:
                return new_text.concat (separator, input);

            default:
                break;
        }

        return input;
    }

    public string get_formated_datetime (uint64 dt) {
        var datetime = new DateTime.from_unix_local ((int64)dt);
        switch ((uint)format) {
            case RenameDateFormat.DEFAULT_DATETIME:
                return datetime.format (Granite.DateTime.get_default_date_format (false, true, true).
                                  concat (" ", Granite.DateTime.get_default_time_format ()));

            case RenameDateFormat.LOCALE:
                return datetime.format ("%c");

            case RenameDateFormat.ISO_DATE:
                return datetime.format ("%Y-%m-%d");

            case RenameDateFormat.ISO_DATETIME:
                return datetime.format ("%Y-%m-%d %H:%M:%S");

            default:
                return datetime.format (Granite.DateTime.get_default_date_format (false, true, true));
        }
    }

}
