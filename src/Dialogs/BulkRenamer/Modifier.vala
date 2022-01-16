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

public class Modifier : Gtk.ListBoxRow {
    public enum RenameMode {
        TEXT,
        NUMBER,
        DATETIME,
        INVALID;

        public string to_string () {
            switch (this) {
                case RenameMode.NUMBER:
                    return _("Number sequence");

                case RenameMode.TEXT:
                    return _("Text");

                case RenameMode.DATETIME:
                    return _("Date");

                default:
                    assert_not_reached ();
            }
        }
    }

    public enum RenamePosition {
        SUFFIX,
        PREFIX,
        REPLACE;

        public string to_string () {
            switch (this) {
                case RenamePosition.SUFFIX:
                    return _("Suffix");

                case RenamePosition.PREFIX:
                    return _("Prefix");

                case RenamePosition.REPLACE:
                    return _("Replace");

                default:
                    assert_not_reached ();
            }
        }

        public string to_placeholder () {
            switch (this) {
                case RenamePosition.SUFFIX:
                    return _("Text to put at the end");

                case RenamePosition.PREFIX:
                    return _("Text to put at the start");

                case RenamePosition.REPLACE:
                    return _("Text to replace the target");

                default:
                    assert_not_reached ();
            }
        }
    }

    public enum RenameSortBy {
        NAME,
        CREATED,
        MODIFIED;

        public string to_string () {
            switch (this) {
                case RenameSortBy.NAME:
                    return _("Name");

                case RenameSortBy.CREATED:
                    return _("Creation Date");

                case RenameSortBy.MODIFIED:
                    return _("Last modification date");

                default:
                    assert_not_reached ();
            }
        }
    }

    public enum RenameDateFormat {
        DEFAULT_DATE,
        DEFAULT_DATETIME,
        LOCALE,
        ISO_DATE,
        ISO_DATETIME;

        public string to_string () {
            switch (this) {
                case RenameDateFormat.DEFAULT_DATE:
                    return _("Default Format - Date only");
                case RenameDateFormat.DEFAULT_DATETIME:
                    return _("Default Format - Date and Time");
                case RenameDateFormat.LOCALE:
                    return _("Locale Format - Date and Time");
                case RenameDateFormat.ISO_DATE:
                    return _("ISO 8601 Format - Date only");
                case RenameDateFormat.ISO_DATETIME:
                    return _("ISO 8601 Format - Date and Time");
                default:
                    assert_not_reached ();
            }
        }
    }

    public enum RenameDateType {
        NOW,
        CHOOSE;

        public string to_string () {
            switch (this) {
                case RenameDateType.NOW:
                    return _("Current Date");
                case RenameDateType.CHOOSE:
                    return _("Choose a date");
                default:
                    assert_not_reached ();
            }
        }
    }

    public enum RenameBase {
        ORIGINAL,
        CUSTOM;

        public string to_string () {
            switch (this) {
                case RenameBase.ORIGINAL:
                    return _("Original filename");
                case RenameBase.CUSTOM:
                    return _("Enter a base name");
                default:
                    assert_not_reached ();
            }
        }
    }

    public signal void remove_request ();
    public signal void update_request ();

    public bool allow_remove { get; set; }

    private Gtk.ComboBoxText position_combo;
    private Gtk.ComboBoxText mode_combo;
    private Gtk.ComboBoxText date_format_combo;
    private Granite.Widgets.DatePicker date_picker;
    private Granite.Widgets.TimePicker time_picker;
    private Gtk.Stack mode_stack;
    private Gtk.Stack position_stack;
    private Gtk.SpinButton digits_spin_button;
    private Gtk.SpinButton start_number_spin_button;
    private Gtk.Entry text_entry;
    private Gtk.Entry separator_entry;
    private Gtk.Entry search_entry;
    private Gtk.Revealer remove_revealer;

    public Modifier (bool _allow_remove) {
        Object (allow_remove: _allow_remove);
        remove_revealer.reveal_child = allow_remove;
    }

    construct {
        margin_top = 3;
        margin_bottom = 3;
        hexpand = true;

        var grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.HORIZONTAL,
            column_spacing = 12
        };

        mode_combo = new Gtk.ComboBoxText () {
            valign = Gtk.Align.CENTER
        };
        mode_combo.insert (RenameMode.TEXT, "TEXT", RenameMode.TEXT.to_string ());
        mode_combo.insert (RenameMode.NUMBER, "NUMBER", RenameMode.NUMBER.to_string ());
        mode_combo.insert (RenameMode.DATETIME, "DATETIME", RenameMode.DATETIME.to_string ());

        text_entry = new Gtk.Entry () {
            vexpand = false,
            hexpand = false,
            max_length = 64,
            max_width_chars = 64
        };

        var start_number_label = new Gtk.Label (_("Start Number"));
        start_number_spin_button = new Gtk.SpinButton.with_range (0, int.MAX, 1) {
            digits = 0
        };
        start_number_spin_button.set_value (0.0);

        var digits_label = new Gtk.Label (_("Digits"));

        digits_spin_button = new Gtk.SpinButton.with_range (0, 5, 1) {
            digits = 0
        };

        digits_spin_button.set_value (1.0);

        var digits_grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.HORIZONTAL,
            column_spacing = 6
        };

        digits_grid.add (start_number_label);
        digits_grid.add (start_number_spin_button);
        digits_grid.add (digits_label);
        digits_grid.add (digits_spin_button);

        date_format_combo = new Gtk.ComboBoxText () {
            valign = Gtk.Align.CENTER
        };
        date_format_combo.insert (RenameDateFormat.DEFAULT_DATE, "DEFAULT_DATE",
                                  RenameDateFormat.DEFAULT_DATE.to_string ());

        date_format_combo.insert (RenameDateFormat.DEFAULT_DATETIME, "DEFAULT_DATETIME",
                                  RenameDateFormat.DEFAULT_DATETIME.to_string ());

        date_format_combo.insert (RenameDateFormat.LOCALE, "LOCALE",
                                  RenameDateFormat.LOCALE.to_string ());

        date_format_combo.insert (RenameDateFormat.ISO_DATE, "ISO_DATE",
                                  RenameDateFormat.ISO_DATE.to_string ());

        date_format_combo.insert (RenameDateFormat.ISO_DATETIME, "ISO_DATETIME",
                                  RenameDateFormat.ISO_DATETIME.to_string ());

        date_picker = new Granite.Widgets.DatePicker ();
        time_picker = new Granite.Widgets.TimePicker ();

        var date_time_grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.HORIZONTAL,
            column_spacing = 6
        };
        date_time_grid.add (date_format_combo);
        date_time_grid.add (date_picker);
        date_time_grid.add (time_picker);

        mode_stack = new Gtk.Stack () {
            valign = Gtk.Align.CENTER,
            homogeneous =false,
            vexpand = false,
            hexpand = false
        };
        mode_stack.add_named (digits_grid, "NUMBER");
        mode_stack.add_named (text_entry, "TEXT");
        mode_stack.add_named (date_time_grid, "DATETIME");
        mode_stack.set_visible_child_name ("NUMBER");

        separator_entry = new Gtk.Entry () {
            halign = Gtk.Align.END,
            hexpand = true,
            max_length = 16,
            placeholder_text = _("Separator"),
            text = ""
        };

        var separator_label = new Gtk.Label (_("Separator:")) {
            halign = Gtk.Align.END,
            hexpand = false
        };

        var separator_grid = new Gtk.Grid () {
            hexpand = true,
            halign = Gtk.Align.END,
            margin_start = 12,
            orientation = Gtk.Orientation.HORIZONTAL,
            column_spacing = 6
        };
        separator_grid.add (separator_label);
        separator_grid.add (separator_entry);

        search_entry = new Gtk.Entry () {
            hexpand = true,
            halign = Gtk.Align.END,
            max_length = 64,
            max_width_chars = 64,
            placeholder_text = _("Target text to be replaced")
        };

        position_stack = new Gtk.Stack () {
            hexpand = true,
            valign = Gtk.Align.END
        };
        position_stack.add_named (separator_grid, "SEPARATOR");
        position_stack.add_named (search_entry, "TARGET");

        position_combo = new Gtk.ComboBoxText ();
        position_combo.insert (RenamePosition.SUFFIX, "NUMBER", RenamePosition.SUFFIX.to_string ());
        position_combo.insert (RenamePosition.PREFIX, "TEXT", RenamePosition.PREFIX.to_string ());
        position_combo.insert (RenamePosition.REPLACE, "DATETIME", RenamePosition.REPLACE.to_string ());
        position_combo.active = RenamePosition.SUFFIX;

        var remove_button = new Gtk.Button.from_icon_name ("process-stop", Gtk.IconSize.LARGE_TOOLBAR) {
            halign = Gtk.Align.END,
            valign = Gtk.Align.CENTER,
            tooltip_text = (_("Remove this modification"))

        };
        remove_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        remove_revealer = new Gtk.Revealer () {
            halign = Gtk.Align.END
        };
        remove_revealer.add (remove_button);

        grid.add (position_combo);
        grid.add (mode_combo);
        grid.add (mode_stack);
        grid.add (position_stack);
        grid.add (remove_revealer);

        add (grid);

        show_all ();

        mode_combo.changed.connect (change_rename_mode);
        position_combo.changed.connect (change_rename_position);

        date_format_combo.changed.connect (() => {
            update_request ();
        });

        date_picker.date_changed.connect (() => {
            update_request ();
        });

        time_picker.time_changed.connect (() => {
            update_request ();
        });

        digits_spin_button.value_changed.connect (() => {
            update_request ();
        });

        start_number_spin_button.value_changed.connect (() => {
            update_request ();
        });

        search_entry.focus_out_event.connect (() => {
            update_request ();
            return Gdk.EVENT_PROPAGATE;
        });

        search_entry.activate.connect (() => {
            update_request ();
        });

        text_entry.changed.connect (() => {
            update_request ();
        });

        separator_entry.changed.connect (() => {
            update_request ();
        });

        text_entry.placeholder_text = ((RenamePosition)(position_combo.get_active ())).to_placeholder ();
        position_combo.changed.connect (() => {
            text_entry.placeholder_text = ((RenamePosition)(position_combo.get_active ())).to_placeholder ();
            update_request ();
        });

        remove_button.clicked.connect (() => {
            remove_request ();
        });

        reset ();
    }

    public void reset () {
        mode_combo.active = RenameMode.TEXT;
        text_entry.text = "";
        separator_entry.text = "";
        search_entry.text = "";

        date_format_combo.set_active (RenameDateFormat.DEFAULT_DATE);
    }

    public void change_rename_mode () {
        switch (mode_combo.get_active ()) {
            case RenameMode.NUMBER:
                mode_stack.set_visible_child_name ("NUMBER");
                break;

            case RenameMode.TEXT:
                mode_stack.set_visible_child_name ("TEXT");
                break;

            case RenameMode.DATETIME:
                mode_stack.set_visible_child_name ("DATETIME");
                break;

            default:
                break;
        }

        update_request ();
    }

   public void change_rename_position () {
        if (position_combo.get_active () == RenamePosition.REPLACE) {
            position_stack.visible_child_name = "TARGET";
        } else {
            position_stack.visible_child_name = "SEPARATOR";
        }

        update_request ();
    }

    public string rename (string input, int index) {
        var seq = index + (int)(start_number_spin_button.get_value ());
        string new_text = "";

        switch (mode_combo.get_active ()) {
            case RenameMode.NUMBER:
                var template = "%%0%id".printf ((int)(digits_spin_button.get_value ()));
                new_text = template.printf (seq);
                break;

            case RenameMode.TEXT:
                new_text = text_entry.text;
                break;

            case RenameMode.DATETIME:
                new_text = get_formated_date_time (date_picker.date);
                break;

            default:
                break;
        }

        switch (position_combo.get_active ()) {
            case RenamePosition.SUFFIX:
                return input.concat (separator_entry.text, new_text);

            case RenamePosition.PREFIX:
                return new_text.concat (separator_entry.text, input);

            case RenamePosition.REPLACE:
                return input.replace (search_entry.text, new_text);

            default:
                break;
        }

        return input;
    }

    public string get_formated_date_time (DateTime? date) {
        var time = time_picker.time;
        var date_time = new DateTime.utc (
            date.get_year (), date.get_month (), date.get_day_of_month (),
            time.get_hour (), time.get_minute (), time.get_second ()
        );

        switch (date_format_combo.get_active ()) {
            case RenameDateFormat.DEFAULT_DATE:
                return date_time.format (Granite.DateTime.get_default_date_format (false, true, true));

            case RenameDateFormat.DEFAULT_DATETIME:
                return date_time.format (Granite.DateTime.get_default_date_format (false, true, true).
                                  concat (" ", Granite.DateTime.get_default_time_format ()));

            case RenameDateFormat.LOCALE:
                return date_time.format ("%c");

            case RenameDateFormat.ISO_DATE:
                return date_time.format ("%Y-%m-%d");

            case RenameDateFormat.ISO_DATETIME:
                return date_time.format ("%Y-%m-%d %H:%M:%S");

            default:
                assert_not_reached ();
        }
    }
}
