/*
 * Copyright 2021 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

public class Files.FileChooserChoice : Gtk.Box {
    public Variant variant { get; construct; }

    public Variant? options { get; private set; }
    public string label { get; private set; }
    public string id { get; private set; }
    public string selected { get; set; }

    private Gtk.Widget choice_widget;

    public FileChooserChoice.from_variant (Variant variant) requires (
        variant.is_of_type (new VariantType ("(ssa(ss)s)"))
    ) {
        Object (variant: variant);
    }

    construct {
        orientation = Gtk.Orientation.HORIZONTAL;
        halign = Gtk.Align.START;
        spacing = 6;

        string _id, _label, _selected;
        Variant? _options;

        variant.get ("(ss@a(ss)s)", out _id, out _label, out _options, out _selected);

        id = _id;
        label = _label;
        selected = _selected;
        options = _options;

        var label = new Gtk.Label (label);
        bind_property ("label", label, "label", BindingFlags.DEFAULT);
        add (label);

        if (options.n_children () == 0) {
            var check = new Gtk.CheckButton ();
            bind_property (
                "selected", check, "active", BIDIRECTIONAL | SYNC_CREATE,
                (b, s, ref t) => {
                    t.set_boolean (bool.parse ((string) s));
                    return true;
                },
                (b, s, ref t) => {
                    t.set_string (((bool) s).to_string ());
                    return true;
                }
            );
            choice_widget = check;
        } else {
            var combo = new Gtk.ComboBoxText ();
            var iter = options.iterator ();
            string key, val;

            while (iter.next ("(ss)", out key, out val)) {
                combo.append (key, val);
            }

            bind_property ("selected", combo, "active-id", BIDIRECTIONAL | SYNC_CREATE);
            choice_widget = combo;
        }

        add (choice_widget);
        show_all ();
    }
}
