/*-
 * Copyright 2026 elementary, Inc. (https://elementary.io)
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
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
 * Boston, MA 02110-1335 USA.
 *
 * Authored by: Jeremy Wootten <jeremywootten@gmail.com>
 */

 public class Files.FileFilter : Object {
    private enum RuleType {
        GLOB,
        MIME
    }

    private struct Rule {
        RuleType type;
        string text;
    }

    public string name { get; set; }
    private List<Rule?> rules;
    // Create from filechooser portal variant type "sa(us)"
    public FileFilter.from_gvariant (Variant filter_variant) {
        VariantIter iter;
        string _name;
        RuleType _type;
        string _text;

        filter_variant.@get ("sa(us)", out _name, out iter);
        name = _name;
        while (iter.next ("(us)", out _type, out _text)) {
            add_rule (_type, _text);
        }
    }

    construct {
        rules = new List<Rule?> ();
    }

    public void add_mime_type (string mime_type) {
        add_rule (RuleType.MIME, mime_type);
    }

    public void add_pattern (string glob) {
        add_rule (RuleType.GLOB, glob);
    }

    private void add_rule (RuleType _type, string _text) {
        rules.append (Rule () { type = _type, text = _text });
    }

    public Variant to_gvariant () {
        var vb = new VariantBuilder (new VariantType ("sa(us)"));
        vb.add (name);
        vb.open (new VariantType ("a(us)"));
        rules.foreach ((rule) => {
            vb.add ("(us)", rule.type, rule.text);
        });
        vb.close ();

        return vb.end ();
    }

    //TODO decide whether should accept or reject by default
    public bool filter (Files.File file) {
        var res = false;
        foreach (Rule rule in rules) {
            if (rule.type == MIME) {
                if (ContentType.is_mime_type (file.get_ftype (), rule.text)) {
                    res = true;
                    break;
                }
            } else if (file.is_folder ()) {
                res = true;
                break;
            } else {
                int posix_match_res = Posix.fnmatch (rule.text, file.basename);
                res = posix_match_res == 0;
                break;
            }
        }

        return res;
    }
 }
