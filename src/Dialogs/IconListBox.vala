/*-
 * Copyright (c) 2020 Adam Bieńkowski
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Adam Bieńkowski <donadigos159@gmail.com>
 * Code from https://github.com/donadigo/appeditor
 */

public class Marlin.View.IconListBox : Gtk.ListBox {
    private const int LOAD_BATCH = 20;

    private static Gee.ArrayList<string> icons;
    private static int max_index = -1;

    private Gee.ArrayList<string> added;
    private int current_index = 0;
    private string search_query = "";
    private Cancellable? search_cancellable = null;

    static construct {
        icons = new Gee.ArrayList<string> ();

        var icon_theme = Gtk.IconTheme.get_default ();
        var list = icon_theme.list_icons (null);
        list.@foreach ((icon_name) => {
            icons.add (icon_name);
        });

        max_index = icons.size - 1;
        icons.sort ((a, b) => strcmp (a, b));
    }

    construct {
        added = new Gee.ArrayList<string> ();

        set_sort_func (sort_func);
        set_filter_func (filter_func);
        load_next_icons ();
    }

    public IconListBox () {
        selection_mode = Gtk.SelectionMode.BROWSE;
        activate_on_single_click = false;
    }

    public string? get_selected_icon_name () {
        var row = get_selected_row ();
        if (row == null) {
            return null;
        }

        var icon_row = row as IconRow;
        if (icon_row == null) {
            return null;
        }

        return icon_row.icon_name;
    }

    public void add_icon_name (string icon_name) {
        var row = new IconRow (icon_name);
        add (row);

        added.add (icon_name);
    }

    public void load_next_icons () {
        int new_index = current_index + LOAD_BATCH;
        int bound = new_index.clamp (0, max_index);

        var slice = icons.slice (current_index, bound);

        foreach (var icon_name in slice) {
            add_icon_name (icon_name);
        }

        current_index = new_index;
        show_all ();
    }

    public void search (string query) {
        if (search_cancellable != null) {
            search_cancellable.cancel ();
        }

        search_cancellable = new Cancellable ();

        search_query = query;
        search_internal.begin (search_query);
    }

    private async void search_internal (string query) {
        new Thread<void*> ("search-internal", () => {
            string[] matched = search_icons (query);
            if (search_cancellable.is_cancelled ()) {
                return null;
            }

            Idle.add (() => {
                foreach (string icon_name in matched) {
                    add_icon_name (icon_name);
                }

                show_all ();
                invalidate_filter ();
                return false;
            });

            return null;
        });
    }

    private string[] search_icons (string query) {
        string[] matched = {};
        for (int i = 0; i < icons.size; i++) {
            string icon_name = icons[i];
            if (!added.contains (icon_name) && query_matches_name (query, icon_name)) {
                matched += icon_name;
            }
        }

        return matched;
    }

    private int sort_func (Gtk.ListBoxRow row1, Gtk.ListBoxRow row2) {
        var icon_row1 = row1 as IconRow;
        if (icon_row1 == null) {
            return 0;
        }

        var icon_row2 = row2 as IconRow;
        if (icon_row2 == null) {
            return 0;
        }

        return strcmp (icon_row1.icon_name, icon_row2.icon_name);
    }

    private bool filter_func (Gtk.ListBoxRow row) {
        if (search_query.strip () == "") {
            return true;
        }

        var icon_row = row as IconRow;
        if (icon_row == null) {
            return true;
        }

        return query_matches_name (search_query, icon_row.icon_name);
    }

    private static bool query_matches_name (string query, string icon_name) {
        return query.down () in icon_name.down ();
    }
}
