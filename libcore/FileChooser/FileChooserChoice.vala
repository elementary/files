/*
 * Copyright 2021 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

public class Files.FileChooserChoice : Gtk.Box {
    public Variant variant { get; construct; }

    public Variant? options { get; set construct; default = null; }
    public string label { get; set construct; }
    public string id { get; set construct; }
    public string selected { get; set construct; }

    private Gtk.Widget? choice_widget;

    public FileChooserChoice.from_variant (Variant variant) requires (
        variant.is_of_type (new VariantType ("(ssa(ss)s)"))
    ) {
        Object (variant: variant);
    }

    public FileChooserChoice (string id, string label, Variant? options, string selected) {
        Object (
            id: id,
            label: label,
            options: options,
            selected: selected
        );
    }

    construct {
        orientation = Gtk.Orientation.HORIZONTAL;
        halign = Gtk.Align.START;
        spacing = 6;

        if (variant != null) {
            string _id, _label, _selected;
            Variant? _options;

            variant.get ("(ss@a(ss)s)", out _id, out _label, out _options, out _selected);

            id = _id;
            label = _label;
            selected = _selected;
            options = _options;
        } else {
            // Assume other constructor used
        }

        var label = new Gtk.Label (label);
        bind_property ("label", label, "label", BindingFlags.DEFAULT);
        add (label);

        if (options == null || options.n_children () == 0) {
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
        } else if (options != null) {
            var combo = new Gtk.ComboBoxText ();
            var iter = options.iterator ();
            string key, val;

            while (iter.next ("(ss)", out key, out val)) {
                combo.append (key, val);
            }

            bind_property ("selected", combo, "active-id", BIDIRECTIONAL | SYNC_CREATE);
            choice_widget = combo;
        }

        if (choice_widget != null) { add (choice_widget); }
        show_all ();
    }
}
