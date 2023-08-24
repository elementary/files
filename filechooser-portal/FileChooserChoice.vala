/*
 * Copyright 2021 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

public class Files.FileChooserChoice : Gtk.Box {
    public Variant? options { get; construct; }
    public string label { get; set; }
    public string selected { get; set; }

    public FileChooserChoice.from_variant (Variant variant) requires (
        variant.is_of_type (new VariantType ("(ssa(ss)s)"))
    ) {
        string id, label, selected;
        Variant? options;

        variant.get ("(ss@a(ss)s)", out id, out label, out options, out selected);

        Object (name: id, label: label, options: options, selected: selected);
    }

    construct {
        orientation = Gtk.Orientation.HORIZONTAL;
        halign = Gtk.Align.START;
        spacing = 6;

        var label = new Gtk.Label (label);
        bind_property ("label", label, "label", BindingFlags.DEFAULT);
        append (label);

        if (options.n_children () == 0) {
            var check = new Gtk.CheckButton ();
            bind_property (
                "selected", check, "active", BindingFlags.BIDIRECTIONAL,
                (b, s, ref t) => {
                    t.set_boolean (bool.parse ((string) s));
                    return true;
                },
                (b, s, ref t) => {
                    t.set_string (((bool) s).to_string ());
                    return true;
                }
            );

            append (check);
        } else {
            var combo = new Gtk.ComboBoxText ();
            var iter = options.iterator ();
            string key, val;

            while (iter.next ("(ss)", out key, out val)) {
                combo.append (key, val);
            }

            bind_property ("selected", combo, "active-id", BindingFlags.BIDIRECTIONAL);
            append (combo);
        }
    }
}
