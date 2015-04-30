// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2013 Pantheon Developers (http://launchpad.net/elementary)
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authored by: Corentin Noël <tintou@mailoo.org>
 */

public class PantheonModule.FileChooserDialog : GLib.Object {
    /* CATCHING DIALOGS SECTION BY: tintou (https://launchpad.net/~tintou) */
    Gee.TreeSet<Gtk.FileChooserDialog> tree_set;
    public FileChooserDialog () {
        tree_set = new Gee.TreeSet<Gtk.FileChooserDialog> ();
        /* It's the only way to get every new window */
        var map_id = GLib.Signal.lookup ("window-state-event", typeof (Gtk.Dialog));
        GLib.Signal.add_emission_hook (map_id, 0, (ihint, param_values) => {
            if (param_values [0].type () == typeof (Gtk.FileChooserDialog)) {
                var dialog = (Gtk.FileChooserDialog)param_values [0].dup_object ();
                if (tree_set.contains (dialog) == false) {
                    tree_set.add (dialog);
                    new CustomFileChooserDialog (dialog);  
                    dialog.destroy.connect (() => {
                        tree_set.remove (dialog);
                    });
                }
            }

            return true;
        }, null);
    }
}

public static PantheonModule.FileChooserDialog filechooser_module = null;
public void gtk_module_init ([CCode (array_length_cname = "argc", array_length_pos = 0.5)] ref unowned string[]? argv) {
    Gtk.init (ref argv);
    filechooser_module = new PantheonModule.FileChooserDialog ();
}
